/*
 * Motor Rollo: Matter-over-Thread roller blind on an ESP32-H2 Super Mini with a DRV8833 and an N20
 * motor without encoder.
 *
 * Endpoint 1 is a Matter Window Covering (roller shade, lift, position aware). There is no position
 * sensor and no battery divider: the position comes from the motor's run time (separate times for up
 * and down) and is kept in NVS, so it survives a restart. The device is a sleepy Thread end device
 * (ICD): it light-sleeps between polls and wakes the motor driver only to move.
 *
 * Matter's lift position is in hundredths of a percent: 0 = fully open (up), 10000 = fully closed (down).
 * Fully closed can be set short of the full height (ROLLO_VIRTUAL_MAX_PERCENT); the percentages then
 * span only that range.
 *
 * Endpoints 2-5 are On/Off switches used as buttons: jog up, jog down (ROLLO_JOG_MS each), "set fully
 * up" and "set fully down" (take where the blind stands as fully up / the virtual fully down, without
 * moving). Each turns itself off once done.
 * The motor direction can be swapped over Matter: the MotorDirectionReversed bit of the Mode attribute.
 *
 * BOOT button: a short press opens a pairing window (15 min, over the network) so another
 * controller can join; holding it 10 s clears every pairing and restarts.
 *
 * Status LED: blue blinking = waiting to be paired, blue/white = pairing, green = just paired,
 * orange blinking = Thread network lost, white blinking = identify, red = BOOT held. Off in normal
 * operation.
 */

#include <algorithm>
#include <atomic>
#include <cinttypes>
#include <cstdlib>

#include <esp_err.h>
#include <esp_log.h>
#include <esp_pm.h>
#include <esp_timer.h>
#include <nvs.h>
#include <nvs_flash.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <freertos/task.h>

#include <esp_matter.h>
#include <esp_matter_ota.h>
#include <common_macros.h>

#include <platform/ESP32/OpenthreadLauncher.h>
#include <app/server/Server.h>
#include <app-common/zap-generated/attributes/Accessors.h>
#include <app/clusters/window-covering-server/window-covering-delegate.h>
#include <app/clusters/window-covering-server/window-covering-server.h>

#include <button_gpio.h>
#include <iot_button.h>

#include "board.h"
#include "led.h"
#include "units.h"

static const char *TAG = "rollo";

using namespace esp_matter;
using namespace esp_matter::endpoint;
using namespace chip::app::Clusters;
using chip::app::DataModel::Nullable;
using std::chrono::microseconds;
using std::chrono::milliseconds;

/** Now, by esp_timer's clock. */
static microseconds uptime()
{
    return microseconds(esp_timer_get_time());
}

/** Lift positions in hundredths of a percent, as Matter counts them. */
static constexpr uint16_t LIFT_OPEN = 0;       // fully up
static constexpr uint16_t LIFT_CLOSED = 10000; // fully down
/** Commands that are not a position (all above LIFT_CLOSED). */
static constexpr uint16_t CMD_STOP = UINT16_MAX;          // stop where it is
static constexpr uint16_t CMD_JOG_UP = UINT16_MAX - 1;    // run up for JOG_TIME
static constexpr uint16_t CMD_JOG_DOWN = UINT16_MAX - 2;  // run down for JOG_TIME
static constexpr uint16_t CMD_SET_OPEN = UINT16_MAX - 3;    // stop and take where it is as fully up
static constexpr uint16_t CMD_SET_CLOSED = UINT16_MAX - 4;  // stop and take where it is as fully down

static uint16_t covering_endpoint_id;
/** On/Off endpoints that act as buttons: jog up, jog down, set fully up / down. They turn off once done. */
static uint16_t jog_up_endpoint_id;
static uint16_t jog_down_endpoint_id;
static uint16_t set_open_endpoint_id;
static uint16_t set_closed_endpoint_id;
static QueueHandle_t cmd_queue;
/** One slot: a new command replaces a waiting one. */
static constexpr UBaseType_t CMD_QUEUE_LENGTH = 1;
static constexpr TickType_t NO_WAIT = 0;

/**
 * Where the fabric is, in Matter's lift units (past LIFT_CLOSED below the virtual fully down, see
 * VIRTUAL_MAX). Read from NVS at startup; afterwards only the motor task writes it.
 */
static volatile uint32_t position = LIFT_OPEN;
/** The motor task is working on a command. */
static volatile bool motor_busy;

/**
 * Motor direction reversed: the MotorDirectionReversed bit of the Window Covering Mode attribute, which
 * a controller can write (Matter keeps it across restarts). The Matter thread sets reverse_requested; the
 * motor task takes it over into reverse_applied between moves (apply_reverse).
 */
static std::atomic<bool> reverse_requested{false};
static bool reverse_applied;

/* ---- Virtual fully down ---- */

/**
 * Matter's fully closed is VIRTUAL_MAX of the full height (in hundredths of a percent): every lift
 * position Matter sees, and position above, is a share of 0..VIRTUAL_MAX. Only the saved position is
 * of the full height, so it stays right when the setting changes.
 *
 * position can be past LIFT_CLOSED: the blind is lower than the virtual fully down (the setting was
 * lowered, or the direction swapped). Matter then sees it as closed, and the next move starts from
 * where it really is.
 */
static constexpr uint32_t VIRTUAL_MAX = CONFIG_ROLLO_VIRTUAL_MAX_PERCENT * 100;

/** A lift position (of the virtual range) as a share of the full height. */
static uint16_t to_physical(uint32_t lift)
{
    const uint32_t physical = (lift * VIRTUAL_MAX + LIFT_CLOSED / 2) / LIFT_CLOSED;
    return static_cast<uint16_t>(std::min<uint32_t>(physical, LIFT_CLOSED));
}

/** A share of the full height as a lift position: past LIFT_CLOSED below the virtual fully down. */
static uint32_t from_physical(uint16_t physical)
{
    return (static_cast<uint32_t>(physical) * LIFT_CLOSED + VIRTUAL_MAX / 2) / VIRTUAL_MAX;
}

/** What Matter sees of a position. */
static uint16_t matter_lift(uint32_t lift)
{
    return static_cast<uint16_t>(std::min<uint32_t>(lift, LIFT_CLOSED));
}

/* ---- Position in NVS (of the full height) ---- */

static constexpr const char *NVS_NAMESPACE = "rollo";
static constexpr const char *NVS_KEY_LIFT = "lift";

static bool load_position(uint32_t *lift)
{
    nvs_handle_t nvs;
    if (nvs_open(NVS_NAMESPACE, NVS_READONLY, &nvs) != ESP_OK) {
        return false;
    }
    uint16_t physical = 0;
    const bool ok = nvs_get_u16(nvs, NVS_KEY_LIFT, &physical) == ESP_OK && physical <= LIFT_CLOSED;
    nvs_close(nvs);
    if (ok) {
        *lift = from_physical(physical);
    }
    return ok;
}

static void save_position(uint32_t lift)
{
    nvs_handle_t nvs;
    if (nvs_open(NVS_NAMESPACE, NVS_READWRITE, &nvs) != ESP_OK) {
        ESP_LOGW(TAG, "Position not saved");
        return;
    }
    nvs_set_u16(nvs, NVS_KEY_LIFT, to_physical(lift));
    nvs_commit(nvs);
    nvs_close(nvs);
}

/* ---- Matter state updates (always on the Matter thread) ---- */

static void schedule(void (*fn)(intptr_t), intptr_t arg = 0)
{
    chip::DeviceLayer::PlatformMgr().ScheduleWork(fn, arg);
}

/** While moving: where the fabric is now. */
static void report_position(intptr_t lift)
{
    WindowCovering::LiftPositionSet(covering_endpoint_id, WindowCovering::NPercent100ths(matter_lift(lift)));
}

/**
 * The motor stopped here. When it stopped short of the target (Stop, or a restart) the target follows,
 * so the controller shows the blind as standing still; unless a newer command is already on its way.
 */
static void report_target(intptr_t lift)
{
    WindowCovering::Attributes::TargetPositionLiftPercent100ths::Set(covering_endpoint_id,
                                                                     WindowCovering::NPercent100ths(matter_lift(lift)));
}

/** The button endpoints go back to off. */
static void release_buttons()
{
    for (uint16_t endpoint : {jog_up_endpoint_id, jog_down_endpoint_id, set_open_endpoint_id, set_closed_endpoint_id}) {
        OnOff::Attributes::OnOff::Set(endpoint, false);
    }
}

static void report_stopped(intptr_t lift)
{
    report_position(lift);
    if (!motor_busy && uxQueueMessagesWaiting(cmd_queue) == 0) {
        report_target(lift);
        release_buttons();
    }
}

/* ---- Motor task: runs the fabric to the commanded position by time ---- */

static constexpr microseconds TRAVEL_UP = milliseconds(CONFIG_ROLLO_TRAVEL_UP_MS);
static constexpr microseconds TRAVEL_DOWN = milliseconds(CONFIG_ROLLO_TRAVEL_DOWN_MS);
static constexpr microseconds TOP_OVERRUN = milliseconds(CONFIG_ROLLO_TOP_OVERRUN_MS);
static constexpr microseconds JOG_TIME = milliseconds(CONFIG_ROLLO_JOG_MS);
/** How often the motor task checks for new commands and the position while the motor runs. */
static constexpr milliseconds MOTOR_TICK = 20ms;
/** How often the position is reported while moving. */
static constexpr microseconds REPORT_INTERVAL = 1s;

/** Run time over the virtual range 0..LIFT_CLOSED in one direction. */
static int64_t virtual_travel_us(motor_dir_t dir)
{
    return (dir == motor_dir_t::up ? TRAVEL_UP : TRAVEL_DOWN).count() * VIRTUAL_MAX / LIFT_CLOSED;
}

/**
 * Runs the motor for JOG_TIME, whatever the position says, unless a new command arrives first (as in
 * run_to). That way a blind that is out of step can be brought to the real top and taken as fully up
 * there (CMD_SET_OPEN). The position follows, but stays within fully up and the bottom of the full
 * height.
 */
static bool jog(motor_dir_t dir, uint16_t *next)
{
    const int64_t travel_us = virtual_travel_us(dir);
    const int64_t bottom = from_physical(LIFT_CLOSED);
    const int64_t start = position;
    const int64_t jog_lift = JOG_TIME.count() * LIFT_CLOSED / travel_us;
    const int64_t end = dir == motor_dir_t::up ? std::max<int64_t>(start - jog_lift, LIFT_OPEN) : std::min(start + jog_lift, bottom);
    schedule(report_target, end);

    ESP_LOGI(TAG, "Jogging %s for %d ms", dir == motor_dir_t::up ? "up" : "down", static_cast<int>(to_ms(JOG_TIME)));
    const microseconds t0 = uptime();
    board_motor_start(dir, reverse_applied);
    for (;;) {
        const bool interrupted = xQueueReceive(cmd_queue, next, pdMS_TO_TICKS(MOTOR_TICK.count())) == pdTRUE;

        const microseconds now = uptime();
        const int64_t moved = (now - t0).count() * LIFT_CLOSED / travel_us;
        const int64_t lift = dir == motor_dir_t::up ? std::max<int64_t>(start - moved, LIFT_OPEN) : std::min(start + moved, bottom);
        position = static_cast<uint32_t>(lift);

        if (interrupted) {
            board_motor_stop();
            return true;
        }
        if (now - t0 >= JOG_TIME) {
            break;
        }
    }
    board_motor_stop();
    return false;
}

/**
 * Runs the motor from the current position towards target until it gets there or a new command
 * arrives (returned in *next, the function then returns true). The position is worked out from the
 * run time: TRAVEL_UP or TRAVEL_DOWN for the full height, of which the virtual range 0..LIFT_CLOSED
 * takes VIRTUAL_MAX. A move to fully up runs TOP_OVERRUN longer, into the stop at the head, which
 * corrects any drift.
 */
static bool run_to(uint16_t target, uint16_t *next)
{
    const bool overrun = target == LIFT_OPEN && TOP_OVERRUN > 0us;
    if (target == position && !overrun) {
        return false;
    }
    const motor_dir_t dir = target <= position ? motor_dir_t::up : motor_dir_t::down;
    const int64_t travel_us = virtual_travel_us(dir);
    const int64_t start = position;
    const microseconds t0 = uptime();
    microseconds last_report = t0;
    bool overrunning = false;
    microseconds overrun_end{};

    ESP_LOGI(TAG, "Moving %s from %" PRIu32 " to %u (1/100 %%)", dir == motor_dir_t::up ? "up" : "down", position, target);
    board_motor_start(dir, reverse_applied);
    for (;;) {
        const bool interrupted = xQueueReceive(cmd_queue, next, pdMS_TO_TICKS(MOTOR_TICK.count())) == pdTRUE;

        const microseconds now = uptime();
        const int64_t moved = (now - t0).count() * LIFT_CLOSED / travel_us;
        int64_t lift = 0;
        bool reached = false;
        if (dir == motor_dir_t::up) {
            lift = std::max<int64_t>(start - moved, target);
            reached = lift <= target;
        } else {
            lift = std::min<int64_t>(start + moved, target);
            reached = lift >= target;
        }
        position = static_cast<uint32_t>(lift);

        if (interrupted) {
            board_motor_stop();
            return true;
        }
        if (reached && overrun) {
            if (!overrunning) {
                overrunning = true;
                overrun_end = now + TOP_OVERRUN;
            }
            reached = now >= overrun_end;
        }
        if (reached) {
            break;
        }
        if (now - last_report >= REPORT_INTERVAL) {
            last_report = now;
            schedule(report_position, position);
        }
    }
    board_motor_stop();
    return false;
}

/**
 * Takes over a changed motor direction (only while the motor stands). The blind hasn't moved, but
 * everything it did so far ran the other way round: where we thought it was up, it is down. So the
 * position is mirrored, over the full height.
 */
static void apply_reverse()
{
    const bool requested = reverse_requested;
    if (requested == reverse_applied) {
        return;
    }
    reverse_applied = requested;
    position = from_physical(LIFT_CLOSED - to_physical(position));
    ESP_LOGI(TAG, "Motor direction %s, position now %" PRIu32 " (1/100 %%)", requested ? "reversed" : "normal", position);
}

/** Carries out one command; true when a newer one arrived meanwhile (in *next). */
static bool execute(uint16_t cmd, uint16_t *next)
{
    switch (cmd) {
    case CMD_STOP:
        return false;
    case CMD_JOG_UP:
        return jog(motor_dir_t::up, next);
    case CMD_JOG_DOWN:
        return jog(motor_dir_t::down, next);
    case CMD_SET_OPEN:
        ESP_LOGI(TAG, "Position %" PRIu32 " taken as fully up", position);
        position = LIFT_OPEN;
        return false;
    case CMD_SET_CLOSED:
        ESP_LOGI(TAG, "Position %" PRIu32 " taken as fully down", position);
        position = LIFT_CLOSED;
        return false;
    default:
        return run_to(cmd, next);
    }
}

static void motor_task(void *)
{
    uint16_t cmd;
    for (;;) {
        // Peek first, so motor_busy is set before the command leaves the queue (report_stopped looks at both).
        xQueuePeek(cmd_queue, &cmd, portMAX_DELAY);
        motor_busy = true;
        xQueueReceive(cmd_queue, &cmd, NO_WAIT);
        apply_reverse();
        // A command that arrives while moving replaces the current one.
        while (execute(cmd, &cmd)) {
            apply_reverse();
        }
        apply_reverse();
        save_position(position);
        motor_busy = false;
        schedule(report_stopped, position);
    }
}

static void send_command(uint16_t cmd)
{
    xQueueOverwrite(cmd_queue, &cmd);
}

/** The motor direction from the Mode attribute (Matter thread). A change stops the motor first. */
static void update_reverse(uint8_t mode, bool at_startup)
{
    const bool reversed = (mode & chip::to_underlying(WindowCovering::Mode::kMotorDirectionReversed)) != 0;
    if (at_startup) {
        reverse_applied = reversed;  // the saved position already belongs to this direction
        reverse_requested = reversed;
        ESP_LOGI(TAG, "Motor direction %s", reversed ? "reversed" : "normal");
        return;
    }
    if (reversed != reverse_requested.exchange(reversed)) {
        send_command(CMD_STOP);  // the motor task mirrors the position, saves and reports it
    }
}

/* ---- Window covering delegate: Matter's movement commands land here (Matter thread) ---- */

class CoveringDelegate : public WindowCovering::Delegate {
public:
    /* UpOrOpen, DownOrClose and GoToLiftPercentage have already set the target position. */
    CHIP_ERROR HandleMovement(WindowCovering::WindowCoveringType type) override
    {
        if (type != WindowCovering::WindowCoveringType::Lift) {
            return CHIP_NO_ERROR;
        }
        WindowCovering::NPercent100ths target;
        WindowCovering::Attributes::TargetPositionLiftPercent100ths::Get(covering_endpoint_id, target);
        if (!target.IsNull()) {
            send_command(target.Value());
        }
        return CHIP_NO_ERROR;
    }

    /* The motor task sets the target to where the motor stopped (report_stopped). */
    CHIP_ERROR HandleStopMotion() override
    {
        send_command(CMD_STOP);
        return CHIP_ERROR_IN_PROGRESS;
    }
};

static CoveringDelegate covering_delegate;

/* ---- Pairing state: status LED and sleep (on the Matter thread) ---- */

static bool pairing_session;        // a controller is pairing the device right now
static bool restart_after_pairing;  // paired since the last restart: restart once pairing is over

static void update_status()
{
    auto &server = chip::Server::GetInstance();
    const bool pairable = server.GetCommissioningWindowManager().IsCommissioningWindowOpen();

    // No light sleep while pairing is possible (sleeping between radio events can miss the phone's
    // Bluetooth messages and stall pairing at "connecting"), nor until the restart after a pairing.
    static esp_pm_lock_handle_t awake;
    static bool held;
    if (!awake) {
        esp_pm_lock_create(ESP_PM_NO_LIGHT_SLEEP, PM_LOCK_NO_ARG, "pairing", &awake);
    }
    if ((pairable || pairing_session || restart_after_pairing) != held) {
        held = !held;
        held ? esp_pm_lock_acquire(awake) : esp_pm_lock_release(awake);
    }

    if (pairing_session) {
        led_set(LED_JOINING);
    } else if (pairable) {
        led_set(LED_PAIRING);
    } else if (server.GetFabricTable().FabricCount() > 0 && !chip::DeviceLayer::ConnectivityMgr().IsThreadAttached()) {
        led_set(LED_NO_THREAD);
    } else {
        led_set(LED_OFF);
    }
}

/** How long the LED shows "paired". */
static constexpr auto PAIRED_LED_TIME = 2s;

static void paired_shown(void *)
{
    led_override_clear();
}

static void show_paired()
{
    static esp_timer_handle_t timer;
    if (!timer) {
        const esp_timer_create_args_t args = {.callback = paired_shown, .name = "paired"};
        esp_timer_create(&args, &timer);
    }
    led_override(LED_PAIRED);
    esp_timer_stop(timer);
    esp_timer_start_once(timer, to_us(PAIRED_LED_TIME));
}

/* ---- BOOT button ---- */

/** How long a short press keeps the pairing window open. */
static constexpr auto PAIRING_WINDOW = 15min;

static void open_pairing_window(intptr_t)
{
    auto &window = chip::Server::GetInstance().GetCommissioningWindowManager();
    if (window.IsCommissioningWindowOpen()) {
        return;
    }
    // Over the network only: Bluetooth is released once the device is paired.
    CHIP_ERROR err = window.OpenBasicCommissioningWindow(std::chrono::duration_cast<chip::System::Clock::Seconds16>(PAIRING_WINDOW),
                                                         chip::CommissioningWindowAdvertisement::kDnssdOnly);
    if (err == CHIP_NO_ERROR) {
        ESP_LOGI(TAG, "Pairing window open for %d min", static_cast<int>(PAIRING_WINDOW / 1min));
    } else {
        ESP_LOGW(TAG, "Pairing window failed to open");
    }
}

static void reset_pairings(intptr_t)
{
    esp_matter::factory_reset();  // erases the pairings and restarts
}

/** Holding BOOT this long clears every pairing; the LED turns red after BUTTON_HINT_TIME. */
static constexpr auto BUTTON_RESET_TIME = 10s;
static constexpr auto BUTTON_HINT_TIME = 1s;

static bool button_resetting;

static void button_click(void *, void *)
{
    schedule(open_pairing_window);
}

static void button_hint(void *, void *)
{
    led_override(LED_RESETTING);  // keep holding to reset
}

static void button_reset(void *, void *)
{
    ESP_LOGW(TAG, "Button held %u s: clearing all pairings", static_cast<unsigned>(BUTTON_RESET_TIME / 1s));
    button_resetting = true;
    led_override(LED_RESET);
    schedule(reset_pairings);
}

static void button_released(void *, void *)
{
    if (!button_resetting) {
        led_override_clear();
    }
}

/**
 * BOOT button through Espressif's button component, as in their ICD example: with power save on,
 * it wakes the chip from light sleep on a press and lets it sleep again in between.
 */
static void button_init()
{
    const button_config_t button_config = {.long_press_time = static_cast<uint16_t>(to_ms(BUTTON_HINT_TIME))};
    const button_gpio_config_t gpio_config = {.gpio_num = PIN_BUTTON, .active_level = BUTTON_PRESSED_LEVEL, .enable_power_save = true};
    button_handle_t button = nullptr;
    if (iot_button_new_gpio_device(&button_config, &gpio_config, &button) != ESP_OK) {
        ESP_LOGE(TAG, "No BOOT button");
        return;
    }
    button_event_args_t reset_args = {};
    reset_args.long_press.press_time = static_cast<uint16_t>(to_ms(BUTTON_RESET_TIME));
    iot_button_register_cb(button, BUTTON_SINGLE_CLICK, nullptr, button_click, nullptr);
    iot_button_register_cb(button, BUTTON_LONG_PRESS_START, nullptr, button_hint, nullptr);
    iot_button_register_cb(button, BUTTON_LONG_PRESS_START, &reset_args, button_reset, nullptr);
    iot_button_register_cb(button, BUTTON_PRESS_UP, nullptr, button_released, nullptr);
}

/* ---- Recovery restarts (on the Matter thread) ---- */

/**
 * After pairing over Bluetooth, the ESP32-H2 stops hearing its Thread parent once it light-sleeps
 * (Bluetooth is shut down after pairing and leaves Thread reception broken until a restart). So after
 * a pairing the device stays awake, giving the controller time to read it in, and restarts once
 * nothing has paired for this long.
 */
static constexpr auto RESTART_AFTER_PAIRING = 3min;
/** Without a Thread parent this long (while paired), the device restarts to recover. */
static constexpr auto RESTART_WHEN_DETACHED = 5min;
/** How often the conditions above are checked. */
static constexpr auto RECOVERY_CHECK_INTERVAL = 10s;

static microseconds pairing_quiet_since;
static bool detached;
static microseconds detached_since;

static bool pairing_busy()
{
    auto &server = chip::Server::GetInstance();
    if (pairing_session || server.GetCommissioningWindowManager().IsCommissioningWindowOpen()) {
        return true;
    }
    return server.GetFailSafeContext().IsFailSafeArmed();
}

static void recovery_check(intptr_t)
{
    const microseconds now = uptime();
    if (restart_after_pairing) {
        if (pairing_busy()) {
            pairing_quiet_since = now;
        } else if (now - pairing_quiet_since >= RESTART_AFTER_PAIRING) {
            ESP_LOGI(TAG, "Pairing done: restarting once");
            esp_restart();
        }
    }

    const bool paired = chip::Server::GetInstance().GetFabricTable().FabricCount() > 0;
    if (!paired || chip::DeviceLayer::ConnectivityMgr().IsThreadAttached()) {
        detached = false;
    } else if (!detached) {
        detached = true;
        detached_since = now;
    } else if (now - detached_since >= RESTART_WHEN_DETACHED) {
        ESP_LOGW(TAG, "No Thread parent for %d min: restarting", static_cast<int>(RESTART_WHEN_DETACHED / 1min));
        esp_restart();
    }
}

static void recovery_tick(void *)
{
    schedule(recovery_check);
}

/* ---- Matter callbacks ---- */

static void app_event_cb(const ChipDeviceEvent *event, intptr_t arg)
{
    namespace DeviceEventType = chip::DeviceLayer::DeviceEventType;
    switch (event->Type) {
    case DeviceEventType::kCommissioningComplete:
        ESP_LOGI(TAG, "Commissioning complete");
        pairing_session = false;
        restart_after_pairing = true;
        pairing_quiet_since = uptime();
        show_paired();
        break;
    case DeviceEventType::kFailSafeTimerExpired:
        ESP_LOGW(TAG, "Commissioning failed, fail safe timer expired");
        pairing_session = false;
        break;
    case DeviceEventType::kCommissioningSessionStarted:
        pairing_session = true;
        break;
    case DeviceEventType::kCommissioningSessionStopped:
        pairing_session = false;
        break;
    case DeviceEventType::kServerReady: {
        // The Mode attribute is kept by Matter: take over the saved motor direction. ModeSet also brings
        // ConfigStatus (LiftMovementReversed) in line with it.
        chip::BitMask<WindowCovering::Mode> mode = WindowCovering::ModeGet(covering_endpoint_id);
        WindowCovering::ModeSet(covering_endpoint_id, mode);
        update_reverse(mode.Raw(), true);
        break;
    }
    case DeviceEventType::kCommissioningWindowOpened:
    case DeviceEventType::kCommissioningWindowClosed:
    case DeviceEventType::kFabricRemoved:
    case DeviceEventType::kThreadStateChange:
        break;
    default:
        return;
    }
    update_status();
}

static esp_err_t app_identification_cb(identification::callback_type_t type, uint16_t endpoint_id, uint8_t effect_id,
                                       uint8_t effect_variant, void *priv_data)
{
    // Only the LED: moving the blind to show which one it is would cost position accuracy.
    if (type == identification::START) {
        led_override(LED_IDENTIFY);
    } else if (type == identification::STOP) {
        led_override_clear();
    }
    return ESP_OK;
}

static esp_err_t app_attribute_update_cb(attribute::callback_type_t type, uint16_t endpoint_id, uint32_t cluster_id,
                                         uint32_t attribute_id, esp_matter_attr_val_t *val, void *priv_data)
{
    if (type == attribute::POST_UPDATE && endpoint_id == covering_endpoint_id && cluster_id == WindowCovering::Id &&
        attribute_id == WindowCovering::Attributes::Mode::Id) {
        update_reverse(val->val.u8, false);
    }
    // The button endpoints act when switched on; off is only them going back (release_buttons).
    if (type == attribute::POST_UPDATE && cluster_id == OnOff::Id && attribute_id == OnOff::Attributes::OnOff::Id && val->val.b) {
        if (endpoint_id == jog_up_endpoint_id) {
            send_command(CMD_JOG_UP);
        } else if (endpoint_id == jog_down_endpoint_id) {
            send_command(CMD_JOG_DOWN);
        } else if (endpoint_id == set_open_endpoint_id) {
            send_command(CMD_SET_OPEN);
        } else if (endpoint_id == set_closed_endpoint_id) {
            send_command(CMD_SET_CLOSED);
        }
    }
    return ESP_OK;
}

static constexpr uint32_t MOTOR_TASK_STACK = 3072;
static constexpr UBaseType_t MOTOR_TASK_PRIORITY = 5;
static constexpr int OPENTHREAD_QUEUE_SIZE = 10;

extern "C" void app_main()
{
    nvs_flash_init();

    esp_pm_config_t pm_config = {
        .max_freq_mhz = CONFIG_ESP_DEFAULT_CPU_FREQ_MHZ,
        .min_freq_mhz = CONFIG_ESP_DEFAULT_CPU_FREQ_MHZ,
#ifdef CONFIG_ROLLO_LIGHT_SLEEP
        .light_sleep_enable = true,
#else
        .light_sleep_enable = false,
#endif
    };
    esp_pm_configure(&pm_config);

    // Without a sensor the position after a restart is the one saved after the last move. A blind
    // that was never moved is taken to be fully up.
    uint32_t lift = LIFT_OPEN;
    if (load_position(&lift)) {
        ESP_LOGI(TAG, "Position from NVS: %" PRIu32 " (1/100 %%, virtual fully down at %" PRIu32 " of the full height)", lift,
                 VIRTUAL_MAX);
    } else {
        ESP_LOGW(TAG, "No saved position, assuming fully up");
    }
    position = lift;

    board_init();
    led_init();
    cmd_queue = xQueueCreate(CMD_QUEUE_LENGTH, sizeof(uint16_t));
    xTaskCreate(motor_task, "motor", MOTOR_TASK_STACK, nullptr, MOTOR_TASK_PRIORITY, nullptr);
    button_init();

    node::config_t node_config;
    node_t *node = node::create(&node_config, app_attribute_update_cb, app_identification_cb);
    ABORT_APP_ON_FAILURE(node != nullptr, ESP_LOGE(TAG, "Failed to create Matter node"));

    window_covering::config_t covering_config(chip::to_underlying(WindowCovering::EndProductType::kRollerShade));
    auto &wc = covering_config.window_covering;
    wc.type = chip::to_underlying(WindowCovering::Type::kRollerShade);
    wc.config_status = chip::to_underlying(WindowCovering::ConfigStatus::kOperational) |
                       chip::to_underlying(WindowCovering::ConfigStatus::kLiftPositionAware);
    wc.feature_flags = cluster::window_covering::feature::lift::get_id() |
                       cluster::window_covering::feature::position_aware_lift::get_id();
    wc.features.position_aware_lift.current_position_lift_percent_100ths = nullable<uint16_t>(matter_lift(lift));
    wc.features.position_aware_lift.target_position_lift_percent_100ths = nullable<uint16_t>(matter_lift(lift));
    wc.delegate = &covering_delegate;
    endpoint_t *covering = window_covering::create(node, &covering_config, ENDPOINT_FLAG_NONE, nullptr);
    ABORT_APP_ON_FAILURE(covering != nullptr, ESP_LOGE(TAG, "Failed to create window covering endpoint"));
    covering_endpoint_id = endpoint::get_id(covering);

    // Endpoints 2-5: jog up, jog down, set fully up, set fully down. Plain On/Off plug-ins, which Home
    // Assistant shows as switches; each turns itself off once done.
    for (uint16_t *id : {&jog_up_endpoint_id, &jog_down_endpoint_id, &set_open_endpoint_id, &set_closed_endpoint_id}) {
        on_off_plug_in_unit::config_t button_config;
        endpoint_t *button = on_off_plug_in_unit::create(node, &button_config, ENDPOINT_FLAG_NONE, nullptr);
        ABORT_APP_ON_FAILURE(button != nullptr, ESP_LOGE(TAG, "Failed to create button endpoint"));
        *id = endpoint::get_id(button);
    }

    esp_openthread_platform_config_t ot_config = {
        .radio_config = {.radio_mode = RADIO_MODE_NATIVE},
        .host_config = {.host_connection_mode = HOST_CONNECTION_MODE_NONE},
        .port_config = {.storage_partition_name = "nvs",
                        .netif_queue_size = OPENTHREAD_QUEUE_SIZE,
                        .task_queue_size = OPENTHREAD_QUEUE_SIZE},
    };
    set_openthread_platform_config(&ot_config);

    esp_err_t err = esp_matter::start(app_event_cb);
    ABORT_APP_ON_FAILURE(err == ESP_OK, ESP_LOGE(TAG, "Failed to start Matter, err:%d", err));

    const esp_timer_create_args_t recovery_args = {.callback = recovery_tick, .name = "recovery"};
    esp_timer_handle_t recovery;
    esp_timer_create(&recovery_args, &recovery);
    esp_timer_start_periodic(recovery, to_us(RECOVERY_CHECK_INTERVAL));
}

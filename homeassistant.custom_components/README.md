# Smart floor heating

A Home Assistant integration for floor heating. It learns how each room heats up and cools down, and plans the valves hours ahead.

Normal thermostats and setpoint automations work badly with floor heating. The screed takes hours to respond, so they react too late, overshoot, and switch back and forth. This controller instead:

- **learns a model of each room** from its own data: how long the heat stays, how long the floor lags behind the valve, how much the sun and other sources (people, cooking) add.
- **plans 24 h ahead** every valve cycle, using the schedule and the weather forecast. Pre-heating before comfort time and stopping early before setback come out of the plan by themselves, because the model knows how slow the floor is.
- **uses the room sensor, not the valve's.** Valve heads on a manifold measure the warm manifold. Here they are only opened and closed.
- **ignores short airing.** The valve closes only after a window has been open longer than the window delay. Learning pauses while a window is open and for an hour after.
- **lowers the target when nobody is home**, after the away delay.
- **is easy on batteries.** Each valve opens at most once per cycle (60 min by default), and only for whole stretches of at least 10 minutes.

## How it works

Every minute it reads the room sensors, outdoor temperature, sun and windows. Every 30 minutes the averages go into the learner. At the start of each valve cycle it plans the next 24 h and opens the valve for the planned share of the cycle.

The room is modelled as two heat stores, the screed and the room:

```
room[k+1] = room[k] + a·(outdoor − room) + b·floor_duty + e·(floor_room − room) + c·sun + d
```

`floor_duty` and `floor_room` are the valve opening and the room temperature, smoothed by the screed's time constant. `a`..`e` are learned with recursive least squares, which forgets slowly over about 10 days. The screed time constant is picked from 0.5–8 h by which candidate predicts best 6 h ahead. Until about two days of data are in, the model blends from a typical-room guess.

The planner tries valve levels of 0, 25, 50, 75 and 100 % per cycle. It picks the plan with the lowest cost: being cold during comfort time costs the most, being cold during setback costs less, being more than 0.2 K too warm during comfort time or more than 0.3 K above eco outside it costs something, and energy costs a little ("Comfort vs. savings" sets the last two).

The model and planner are in [`model.py`](smart_floor_heating/model.py) and have no Home Assistant code. [`tests/test_model.py`](tests/test_model.py) runs them for three weeks against a simulated two-node room with sensor noise. On that room it learns the cool-down time constant within 5 % and stays within 0.25 K of comfort.

## Install

1. Copy [`smart_floor_heating`](smart_floor_heating) into your Home Assistant config as `custom_components/smart_floor_heating`, for example with the Samba share, SSH or the File editor add-on.
2. Restart Home Assistant.
3. Go to **Settings → Devices & services → Add integration → Smart floor heating**. Add one entry per room.

### Settings per room

| Setting | What to pick |
|---|---|
| Valves | The thermostats / valve heads of that room's heating circuit (one or more `climate` entities). |
| Room temperature sensors and thermostats | Temperature sensors and room thermostats (`climate` entities, their current temperature) in the room itself. With several, their average is used. Don't add valve heads on the manifold: they measure the manifold, not the room. |
| Weather | Your weather entity, for the outdoor and sun forecast. |
| Outdoor temperature sensor | Optional, used instead of the weather's current temperature. |
| Schedule | Optional `schedule` helper: on = comfort, off = eco. Without one the room stays at comfort. Can be changed later with the room's "Comfort schedule" select. |
| Windows and doors | Binary sensors. |
| Window delay | How long a window must be open before the valve closes (default 30 min). |
| Presence | People, trackers, `input_boolean`s. Away when none of them is home. |
| Away delay | How long nobody must be home before the away temperature applies (default 60 min). |
| Comfort / eco / away temperature | Start values. Change them later with the room's number entities. |
| Comfort vs. savings | How much energy counts against comfort, and how hard it pushes the room down to eco outside comfort time. A screed holds heat for a long time, so "Comfort first" barely lets it cool at night; "Save energy" lets it cool most, at the risk of slightly cool evenings. |
| Valve cycle | 30, 60, 90 or 120 min. Longer saves battery, shorter reacts faster. |
| Valve setpoint to open / close | What the valve is set to. Default: the valve's own max and min. |

### Homematic IP valve heads (eTRV-C on the manifold)

- The controller sets the heating group to manual mode (`heat`). That also stops the Homematic heating profile, which would otherwise change the setpoint back.
- To open, it sets the group's **maximum** temperature. The eTRV-C measures the manifold, which is often 23–25 °C, so a maximum of 25 °C may not open it fully. Set the group's maximum to 30 °C in the Homematic IP app, or set "Valve setpoint to open" higher.

## Time control

Everything here is a `select`, `text` or `time` entity of the room, so it can sit on a dashboard and be changed without opening the settings. What applies, from strongest to weakest:

1. **Preset** on the thermostat: comfort, eco or away hold until you set it back to `schedule`.
2. **Away**: nobody home (Presence = "Away when nobody is home"), or a calendar event / out-of-office time set to away.
3. **Eco** from a calendar event or out-of-office time set to eco.
4. **Comfort schedule**: on = comfort, off = eco. No schedule = comfort.

| Entity | Meaning |
|---|---|
| Comfort schedule | Which `schedule` helper gives the comfort times, or none. Edit its times under Settings → Helpers. |
| Presence | Away when nobody is home, or ignore presence. |
| Calendar and presence | *Either one*: a calendar event or nobody home each lower the target. *Only when both say away*: calendar events and out-of-office times count only while nobody is home (ahead of time they are assumed right, so the planner can still pre-heat for your return). |
| Out of office on / from / back home at / means | A fixed weekly time away: days (never, Mon–Fri, Mon–Sat, every day), leave and return time, eco or away. |
| *Calendar*: during events | One per calendar in Home Assistant: ignore it, eco or away during its events. |
| *Calendar*: event names | Comma-separated names, whole words, any case, e.g. `FD, S1, GD`. Empty: every event of that calendar. |

Calendar events and out-of-office times are known ahead of time, so the planner lets the room cool before you leave and heats it so it is warm when you are back. A new calendar shows up after reloading the integration.

## Entities per room

| Entity | Meaning |
|---|---|
| `climate.<room>` | The room's thermostat. Current temperature from the room sensors. Setting the temperature changes the active target (comfort or eco). Presets: `schedule` (follow schedule and presence), `comfort`, `eco`, `away`. Off closes the valves. |
| `number.<room>_comfort/eco/away_temperature` | The three targets. |
| `sensor.<room>_heat_retention` | Hours until the room loses 1 K if the heating stops now, with the forecast weather. The "how long the heat stays" number. |
| `sensor.<room>_cool_down_time_constant` | Hours for room and screed to lose 63 % of their heat above outdoor. Bigger = better insulated / more mass. |
| `sensor.<room>_floor_lag` | How long the screed takes to pass heat on (learned). |
| `sensor.<room>_valve_duty` | Share of the current cycle the valve is open. |
| `sensor.<room>_temperature_in_3_h` | Predicted room temperature. The `forecast` attribute has the hourly plan for 24 h (temperature and valve %). |
| `sensor.<room>_next_heating` | When the valve opens next. |
| `sensor.<room>_model_error_6_h_ahead` | How well the model predicts the room 6 h ahead, in K. Attributes: learning status, samples, and all learned values. Below about 0.2 K the model is good. |

## The first days

The first two days run on a typical-room guess, blended towards what it learns. After about 96 usable half-hour steps (two days without open windows or sensor gaps) it runs on its own model. Fast-changing weather and a schedule with real setbacks help it learn faster than a steady room does.

## Tests

```bash
python -m pytest homeassistant.custom_components/tests
```

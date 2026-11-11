"""Constants for Smart floor heating."""

from __future__ import annotations

DOMAIN = "smart_floor_heating"
PLATFORMS = ["climate", "number", "select", "sensor", "text", "time"]
STORAGE_VERSION = 1

CONF_NAME = "name"
CONF_VALVES = "valves"
CONF_ROOM_SENSORS = "room_sensors"
CONF_WEATHER = "weather"
CONF_OUTDOOR_SENSOR = "outdoor_sensor"
CONF_SCHEDULE = "schedule"
CONF_WINDOWS = "windows"
CONF_WINDOW_DELAY = "window_delay"
CONF_PRESENCE = "presence"
CONF_AWAY_DELAY = "away_delay"
CONF_COMFORT_TEMP = "comfort_temp"
CONF_ECO_TEMP = "eco_temp"
CONF_AWAY_TEMP = "away_temp"
CONF_CYCLE = "cycle"
CONF_SAVINGS = "savings"
CONF_OPEN_SETPOINT = "open_setpoint"
CONF_CLOSED_SETPOINT = "closed_setpoint"

DEFAULT_WINDOW_DELAY_MIN = 30
DEFAULT_AWAY_DELAY_MIN = 60
DEFAULT_COMFORT_TEMP = 21.5
DEFAULT_ECO_TEMP = 20.5
DEFAULT_AWAY_TEMP = 19.5
DEFAULT_CYCLE_MIN = 60
CYCLE_CHOICES_MIN = (30, 60, 90, 120)
DEFAULT_SAVINGS = "balanced"

# How much the planner weighs energy against comfort, and how hard it pushes
# the room down to the setback target at night: (energy, setback).
SAVINGS_WEIGHTS = {
    "comfort": (0.05, 0.2),
    "balanced": (0.15, 0.5),
    "savings": (0.4, 1.5),
}

TEMP_MIN = 5.0
TEMP_MAX = 28.0

HORIZON_H = 24
RETENTION_HORIZON_H = 72
RETENTION_DROP_K = 1.0
MIN_SWITCH_MIN = 10  # shortest valve open or closed stretch inside a cycle
LEARN_PAUSE_AFTER_WINDOW_MIN = 60
FORECAST_MAX_AGE_MIN = 60
SAVE_DELAY_S = 60
MIN_STEP_COVERAGE = 0.5  # share of minute samples a step needs to be learned from

PRESET_SCHEDULE = "schedule"
PRESET_COMFORT = "comfort"
PRESET_ECO = "eco"
PRESET_AWAY = "away"
PRESETS = [PRESET_SCHEDULE, PRESET_COMFORT, PRESET_ECO, PRESET_AWAY]

CALENDAR_OFF = "off"
CALENDAR_TARGETS = [CALENDAR_OFF, "eco", "away"]  # "eco"/"away" equal TARGET_ECO/TARGET_AWAY
PRESENCE_ON = "on"
PRESENCE_OFF = "off"
COMBINE_EITHER = "either"
COMBINE_BOTH = "both"
SCHEDULE_NONE = "none"

# Fixed out-of-office times: which days, and their weekday numbers.
OFFICE_DAYS = {
    "off": (),
    "mon_fri": (0, 1, 2, 3, 4),
    "mon_sat": (0, 1, 2, 3, 4, 5),
    "every_day": (0, 1, 2, 3, 4, 5, 6),
}
OFFICE_TARGETS = ["eco", "away"]
OFFICE_DEFAULT = {"days": "off", "leave": "07:30:00", "back": "17:30:00", "target": "eco"}

TARGET_COMFORT = "comfort"
TARGET_ECO = "eco"
TARGET_AWAY = "away"

HOME_STATES = {"home", "on"}

# Cloud cover by weather condition, when the forecast has no cloud_coverage.
CONDITION_CLOUD = {
    "sunny": 0,
    "clear-night": 0,
    "partlycloudy": 50,
    "windy": 30,
    "windy-variant": 60,
    "cloudy": 90,
    "fog": 100,
    "hail": 100,
    "lightning": 100,
    "lightning-rainy": 100,
    "pouring": 100,
    "rainy": 100,
    "snowy": 100,
    "snowy-rainy": 100,
    "exceptional": 80,
}
SUN_CLOUD_DAMPING = 0.75  # full overcast still lets a quarter through

"""Closed-loop test of the room model against a simulated floor-heated room.

The simulated room is a two-node physics model (screed and room air), not the
learner's own structure, with sensor noise and rounding. Run with:

    python -m pytest homeassistant.custom_components/tests
"""

from __future__ import annotations

import importlib.util
import math
from pathlib import Path
import random
import sys

_spec = importlib.util.spec_from_file_location(
    "sfh_model",
    Path(__file__).resolve().parent.parent / "smart_floor_heating" / "model.py",
)
model = importlib.util.module_from_spec(_spec)
sys.modules["sfh_model"] = model
_spec.loader.exec_module(model)

COMFORT = 21.5
SETBACK = 19.5
COMFORT_FROM_H = 6
COMFORT_TO_H = 22
CYCLE_STEPS = 2  # 60 min valve cycle
HORIZON_STEPS = 48  # 24 h


class SimRoom:
    """Screed + room air, 1-minute Euler steps."""

    def __init__(self, room: float = 20.0, floor: float = 22.0) -> None:
        self.room = room
        self.floor = floor
        self.c_floor = 8.0  # kWh/K
        self.c_room = 1.5
        self.r_floor_room = 0.4  # K/kW
        self.r_room_out = 12.0
        self.power = 4.0  # kW into the screed with the valve open
        self.sun_power = 0.8

    def tick(self, valve_open: bool, outdoor: float, sun: float, minutes: int = 1):
        dt = minutes / 60
        q_fr = (self.floor - self.room) / self.r_floor_room
        q_ro = (self.room - outdoor) / self.r_room_out
        self.floor += dt * ((self.power if valve_open else 0.0) - q_fr) / self.c_floor
        self.room += dt * (q_fr - q_ro + self.sun_power * sun) / self.c_room


def outdoor_at(hour: float) -> float:
    return 2.0 + 4.0 * math.sin((hour % 24 - 9) / 24 * 2 * math.pi)


def sun_at(hour: float, day: int) -> float:
    h = hour % 24
    if not 8 <= h <= 17:
        return 0.0
    cloudy = 0.2 if day % 3 == 0 else 1.0
    return cloudy * math.sin((h - 8) / 9 * math.pi)


def is_comfort(hour: float) -> bool:
    return COMFORT_FROM_H <= hour % 24 < COMFORT_TO_H


def horizon(start_h: float, day: int) -> list:
    steps = []
    for i in range(HORIZON_STEPS):
        h = start_h + i * model.STEP_H
        comfort = is_comfort(h + model.STEP_H)
        steps.append(
            model.StepInput(
                outdoor=outdoor_at(h),
                sun=sun_at(h, day + int(h // 24)),
                target=COMFORT if comfort else SETBACK,
                comfort=comfort,
            )
        )
    return steps


def run(days: int, seed: int = 1):
    rng = random.Random(seed)
    room = SimRoom()
    rm = model.RoomModel()
    log = []
    duty_plan: list[float] = []
    step_min = int(model.STEP_H * 60)
    for step in range(int(days * 24 / model.STEP_H)):
        hour = step * model.STEP_H
        day = int(hour // 24)
        measured = round(room.room + rng.gauss(0, 0.05), 2)
        if step % CYCLE_STEPS == 0:
            duty_plan = rm.plan(measured, horizon(hour, day), CYCLE_STEPS).duties
        duty = duty_plan[step % CYCLE_STEPS] if duty_plan else 0.0
        open_min = round(duty * CYCLE_STEPS * step_min)  # open at cycle start
        open_this_step = max(0, min(step_min, open_min - (step % CYCLE_STEPS) * step_min))
        temps = []
        for m in range(step_min):
            room.tick(m < open_this_step, outdoor_at(hour), sun_at(hour, day))
            temps.append(room.room)
        avg = sum(temps) / len(temps) + rng.gauss(0, 0.03)
        rm.observe(avg, outdoor_at(hour), sun_at(hour, day), open_this_step / step_min, True)
        log.append((hour, room.room, open_this_step / step_min))
    return rm, room, log


def test_learns_and_keeps_comfort():
    rm, room, log = run(days=21)
    p = rm.params()
    true_tau = room.r_room_out * (room.c_room + room.c_floor)
    print(
        f"tau {p.tau_h:.1f} h (true room+floor ~{true_tau:.0f} h), "
        f"floor {p.floor_tau_h} h, gain {p.heat_gain_k_per_h:.2f} K/h, "
        f"rmse {rm.rmse:.3f}"
    )
    assert rm.trusted
    # Last week: comfort periods within 0.5 K below target, not more than 1 K over.
    last_week = [(h, t) for h, t, _ in log if h >= 14 * 24 and is_comfort(h)]
    worst_cold = max(COMFORT - t for _, t in last_week)
    worst_warm = max(t - COMFORT for _, t in last_week)
    print(f"last week in comfort: worst cold {worst_cold:.2f} K, worst warm {worst_warm:.2f} K")
    assert worst_cold < 0.5
    assert worst_warm < 1.0
    assert 10 < p.tau_h < 300


def test_preheats_before_comfort():
    _, _, log = run(days=21)
    # Valve opens before 06:00 on the last days, and closes before 22:00.
    for day in range(18, 21):
        pre = [d for h, _, d in log if day * 24 + 2 <= h < day * 24 + COMFORT_FROM_H]
        late = [d for h, _, d in log if day * 24 + 20 <= h < day * 24 + 22]
        assert sum(pre) > 0, f"day {day}: no pre-heat"
        assert sum(late) < len(late), f"day {day}: heating right up to setback"


def test_storage_round_trip():
    rm, _, _ = run(days=3)
    again = model.RoomModel.from_dict(rm.to_dict())
    assert again.params() == rm.params()


def test_heat_retention_matches_real_cooldown():
    """Hours to lose 1 K with the valve shut, model vs the simulated room."""
    rm, room, log = run(days=21)
    start = room.room
    real, hours = None, 0.0
    while hours < 72:
        room.tick(False, 0.0, 0.0, minutes=6)
        hours += 0.1
        if room.room <= start - 1.0:
            real = hours
            break
    steps = [model.StepInput(0.0, 0.0, SETBACK, False)] * int(72 / model.STEP_H)
    predicted = rm.hours_until(start, steps, 0.0, lambda t: t <= start - 1.0)
    print(f"1 K drop with valve shut: real {real:.1f} h, predicted {predicted} h")
    assert real and predicted
    assert abs(predicted - real) / real < 0.35


def test_cools_at_night():
    """Outside comfort time the room drifts below the comfort target."""
    _, _, log = run(days=21)
    night = [t for h, t, _ in log if h >= 14 * 24 and not is_comfort(h)]
    mean = sum(night) / len(night)
    print(f"night mean {mean:.2f} °C")
    assert mean < COMFORT - 0.1

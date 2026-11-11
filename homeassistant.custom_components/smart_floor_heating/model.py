"""Room model, online learner and planner for slow floor heating.

Pure Python with no Home Assistant imports, so it can be tested on its own.

A floor-heated room is two heat stores: the screed and the room. The screed
is warmed by the water and gives heat to the room in proportion to how much
warmer it is. With a floor time constant floor_tau, the screed temperature is
exactly

    screed = smooth(room) + g * smooth(duty)

where smooth() is a first-order filter with time constant floor_tau. That
makes the room equation linear in its unknowns, in steps of STEP_H hours:

    room[k+1] = room[k] + a * (outdoor[k] - room[k])
                        + b * floor_duty[k]
                        + e * (floor_room[k] - room[k])
                        + c * sun[k] + d

- duty: share of the step the valve was open (0..1).
- floor_duty, floor_room: duty and room temperature smoothed by the screed.
- a: heat lost to outdoor. b: heat from the water through the screed.
- e: heat the screed stores and gives back (still warm after the valve shuts).
- c: sun. d: everything else (people, cooking, the neighbours).

a..e are learned with recursive least squares. floor_tau is not linear, so one
learner runs per candidate value and the one that predicts best EVAL_STEPS
ahead wins. One step ahead, sensor noise hides the difference.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass, field
import math
from typing import Callable

STEP_H = 0.5
FLOOR_TAU_CANDIDATES_H = (0.5, 1.0, 2.0, 3.0, 4.0, 6.0, 8.0)
N_PARAMS = 5  # a, b, e, c, d

# Prior guess before anything is learned: the room air on its own cools with a
# 30 h time constant, half output holds it 20 K above outdoor, the screed
# gives back heat moderately, the floor needs ~2 h.
PRIOR_TAU_H = 30.0
PRIOR_HOLD_DELTA_K = 20.0
PRIOR_HOLD_DUTY = 0.5
PRIOR_E = 0.2
PRIOR_SUN_K_PER_H = 0.3
PRIOR_FLOOR_TAU_H = 2.0

FORGETTING = 0.998  # memory of ~500 steps, about 10 days
P_INIT = (1e-4, 0.05, 0.05, 0.01, 1e-4)
P_MAX = 10.0
ERR_EMA_ALPHA = 0.02
EVAL_STEPS = 12  # candidates are scored on their 6 h ahead prediction

# Bounds the planner uses, whatever the learner says.
TAU_MIN_H = 2.0
TAU_MAX_H = 300.0
B_MIN = 0.01
E_MAX = 0.9
MAX_STEP_CHANGE_K = 1.5  # bigger jumps between steps are sensor glitches

# Learned enough to trust: about two days of usable data.
MIN_SAMPLES_TRUSTED = 96

# Planner cost weights. The energy weight is set per room ("savings").
W_COLD_COMFORT = 10.0
W_COLD_SETBACK = 2.0
W_WARM = 6.0
OVERSHOOT_K = 0.2
DEFAULT_W_ENERGY = 0.15
DUTY_LEVELS = (0.0, 0.25, 0.5, 0.75, 1.0)
PLAN_PASSES = 3


def _prior_theta() -> list[float]:
    a = STEP_H / PRIOR_TAU_H
    b = a * PRIOR_HOLD_DELTA_K / PRIOR_HOLD_DUTY
    return [a, b, PRIOR_E, PRIOR_SUN_K_PER_H * STEP_H, 0.0]


def _clamp(theta: list[float]) -> tuple[float, float, float, float, float]:
    a = min(max(theta[0], STEP_H / TAU_MAX_H), STEP_H / TAU_MIN_H)
    b = max(theta[1], B_MIN)
    e = min(max(theta[2], 0.0), E_MAX)
    return a, b, e, max(theta[3], 0.0), theta[4]


def _blend(prior: list[float], learned: list[float], samples: int) -> list[float]:
    w = min(samples / MIN_SAMPLES_TRUSTED, 1.0)
    return [pr + (le - pr) * w for pr, le in zip(prior, learned)]


def _room_step(
    p: tuple[float, float, float, float, float],
    room: float,
    outdoor: float,
    sun: float,
    floor_duty: float,
    floor_room: float,
) -> float:
    a, b, e, c, d = p
    return room + a * (outdoor - room) + b * floor_duty + e * (floor_room - room) + c * sun + d


@dataclass
class Learner:
    """Recursive least squares for one floor_tau candidate."""

    floor_tau_h: float
    theta: list[float] = field(default_factory=_prior_theta)
    p: list[list[float]] = field(
        default_factory=lambda: [
            [P_INIT[i] if i == j else 0.0 for j in range(N_PARAMS)]
            for i in range(N_PARAMS)
        ]
    )
    floor_duty: float = 0.0
    floor_room: float | None = None
    err_ema: float | None = None
    samples: int = 0

    @property
    def k_floor(self) -> float:
        return min(1.0, STEP_H / self.floor_tau_h)

    def advance_floor(self, duty: float, room: float) -> None:
        self.floor_duty += (duty - self.floor_duty) * self.k_floor
        if self.floor_room is None:
            self.floor_room = room
        else:
            self.floor_room += (room - self.floor_room) * self.k_floor

    def regressors(self, room: float, outdoor: float, sun: float) -> list[float]:
        floor_room = room if self.floor_room is None else self.floor_room
        return [outdoor - room, self.floor_duty, floor_room - room, sun, 1.0]

    def score(self, err: float) -> None:
        self.err_ema = (
            err * err
            if self.err_ema is None
            else (1 - ERR_EMA_ALPHA) * self.err_ema + ERR_EMA_ALPHA * err * err
        )

    def update(self, x: list[float], y: float) -> None:
        err = y - sum(t * xi for t, xi in zip(self.theta, x))
        px = [sum(self.p[i][j] * x[j] for j in range(N_PARAMS)) for i in range(N_PARAMS)]
        denom = FORGETTING + sum(x[i] * px[i] for i in range(N_PARAMS))
        gain = [v / denom for v in px]
        self.theta = [t + g * err for t, g in zip(self.theta, gain)]
        for i in range(N_PARAMS):
            for j in range(N_PARAMS):
                self.p[i][j] = (self.p[i][j] - gain[i] * px[j]) / FORGETTING
        # Keep P from blowing up while nothing changes (no excitation).
        for i in range(N_PARAMS):
            if self.p[i][i] > P_MAX:
                scale = math.sqrt(P_MAX / self.p[i][i])
                for j in range(N_PARAMS):
                    self.p[i][j] *= scale
                    self.p[j][i] *= scale
        self.samples += 1

    def to_dict(self) -> dict:
        return {
            "floor_tau_h": self.floor_tau_h,
            "theta": self.theta,
            "p": self.p,
            "floor_duty": self.floor_duty,
            "floor_room": self.floor_room,
            "err_ema": self.err_ema,
            "samples": self.samples,
        }

    @classmethod
    def from_dict(cls, data: dict) -> Learner:
        learner = cls(
            floor_tau_h=data["floor_tau_h"],
            theta=list(data["theta"]),
            p=[list(row) for row in data["p"]],
            floor_duty=data.get("floor_duty", 0.0),
            floor_room=data.get("floor_room"),
            err_ema=data.get("err_ema"),
            samples=data.get("samples", 0),
        )
        if len(learner.theta) != N_PARAMS:  # stored by an older model layout
            return cls(floor_tau_h=data["floor_tau_h"])
        return learner


@dataclass(frozen=True)
class Params:
    """Model parameters as the planner uses them, already clamped."""

    a: float
    b: float
    e: float
    c: float
    d: float
    floor_tau_h: float

    @property
    def as_tuple(self) -> tuple[float, float, float, float, float]:
        return self.a, self.b, self.e, self.c, self.d

    @property
    def heat_gain_k_per_h(self) -> float:
        """How fast the floor warms the room at full output, in K/h."""
        return self.b / STEP_H

    @property
    def tau_h(self) -> float:
        """Cool-down time constant of room and screed together, valve shut.

        The slow eigenvalue of the two-store system: after this many hours
        the room has lost 63 % of its excess heat over outdoor.
        """
        k = min(1.0, STEP_H / self.floor_tau_h)
        m11 = 1 - self.a - self.e
        m12 = self.e
        m21 = k * m11
        m22 = 1 - k + k * self.e
        tr, det = m11 + m22, m11 * m22 - m12 * m21
        disc = max(tr * tr / 4 - det, 0.0)
        slow = tr / 2 + math.sqrt(disc)
        if not 0 < slow < 1:
            return TAU_MAX_H
        return min(-STEP_H / math.log(slow), TAU_MAX_H)


@dataclass
class StepInput:
    """What the planner knows about one future step."""

    outdoor: float
    sun: float
    target: float
    comfort: bool  # inside a comfort period (as opposed to setback)


@dataclass
class Plan:
    duties: list[float]  # one per step
    temps: list[float]  # predicted room temperature at the end of each step


class RoomModel:
    """All learners for one room, plus the bookkeeping between steps."""

    def __init__(self, learners: list[Learner] | None = None) -> None:
        self.learners = learners or [Learner(t) for t in FLOOR_TAU_CANDIDATES_H]
        self._last: tuple[float, float, float] | None = None  # room, outdoor, sun
        # (room, outdoor, sun, duty, [(floor_duty, floor_room) per learner])
        self._history: deque = deque(maxlen=EVAL_STEPS + 1)

    # ---- learning -------------------------------------------------------

    def observe(
        self, room: float, outdoor: float, sun: float, duty: float, learn: bool
    ) -> None:
        """Feed one finished step: averages over it and the valve's open share.

        With learn=False (window open, sensor gap) the floor state still moves
        on, but the parameters are left alone.
        """
        if (
            learn
            and self._last is not None
            and abs(room - self._last[0]) <= MAX_STEP_CHANGE_K
        ):
            prev_room, prev_out, prev_sun = self._last
            y = room - prev_room
            for learner in self.learners:
                learner.update(learner.regressors(prev_room, prev_out, prev_sun), y)
        for learner in self.learners:
            learner.advance_floor(duty, room)
        if learn:
            self._last = (room, outdoor, sun)
            self._history.append(
                (
                    room,
                    outdoor,
                    sun,
                    duty,
                    [(l.floor_duty, l.floor_room) for l in self.learners],
                )
            )
            if len(self._history) == self._history.maxlen:
                self._score_candidates()
        else:
            self.forget_last()

    def _score_candidates(self) -> None:
        """Free-run each candidate over the stored window, compare with now."""
        history = list(self._history)
        actual = history[-1][0]
        for idx, learner in enumerate(self.learners):
            p = _clamp(learner.theta)
            k = learner.k_floor
            room, outdoor, sun = history[0][0], history[0][1], history[0][2]
            floor_duty, floor_room = history[0][4][idx]
            for entry in history[1:]:
                room = _room_step(p, room, outdoor, sun, floor_duty, floor_room)
                floor_duty += (entry[3] - floor_duty) * k
                floor_room += (room - floor_room) * k
                outdoor, sun = entry[1], entry[2]
            learner.score(room - actual)

    def forget_last(self) -> None:
        """Don't learn across a gap (restart, sensor outage)."""
        self._last = None
        self._history.clear()

    @property
    def best(self) -> Learner:
        scored = [l for l in self.learners if l.err_ema is not None]
        if not scored or self.samples < MIN_SAMPLES_TRUSTED // 4:
            return min(
                self.learners, key=lambda l: abs(l.floor_tau_h - PRIOR_FLOOR_TAU_H)
            )
        return min(scored, key=lambda l: l.err_ema)

    @property
    def samples(self) -> int:
        return max(l.samples for l in self.learners)

    @property
    def trusted(self) -> bool:
        return self.samples >= MIN_SAMPLES_TRUSTED

    @property
    def rmse(self) -> float | None:
        """Typical error of the 6 h ahead prediction, in K."""
        err = self.best.err_ema
        return None if err is None else math.sqrt(err)

    def params(self) -> Params:
        best = self.best
        theta = (
            best.theta
            if self.trusted
            else _blend(_prior_theta(), best.theta, self.samples)
        )
        a, b, e, c, d = _clamp(theta)
        return Params(a=a, b=b, e=e, c=c, d=d, floor_tau_h=best.floor_tau_h)

    # ---- prediction and planning ---------------------------------------

    def simulate(
        self, room: float, steps: list[StepInput], duties: list[float]
    ) -> list[float]:
        params = self.params()
        p = params.as_tuple
        k = min(1.0, STEP_H / params.floor_tau_h)
        best = self.best
        floor_duty = best.floor_duty
        floor_room = room if best.floor_room is None else best.floor_room
        temps = []
        for step, duty in zip(steps, duties):
            room = _room_step(p, room, step.outdoor, step.sun, floor_duty, floor_room)
            floor_duty += (duty - floor_duty) * k
            floor_room += (room - floor_room) * k
            temps.append(room)
        return temps

    def plan(
        self,
        room: float,
        steps: list[StepInput],
        steps_per_cycle: int,
        w_energy: float = DEFAULT_W_ENERGY,
    ) -> Plan:
        """Pick a duty per valve cycle over the horizon (receding horizon).

        Cost: being colder than target (much more inside comfort periods),
        being more than OVERSHOOT_K warmer during comfort, and energy. Pre-heat
        before comfort and coasting before setback come out of this on their
        own, because the model knows how slow the floor is.
        """
        n_cycles = math.ceil(len(steps) / steps_per_cycle)
        p = self.params()
        choice = [
            min(DUTY_LEVELS, key=lambda lv: abs(lv - _hold_duty(p, s)))
            for s in steps[::steps_per_cycle]
        ]

        def expand(c: list[float]) -> list[float]:
            return [c[i // steps_per_cycle] for i in range(len(steps))]

        def cost(c: list[float]) -> float:
            duties = expand(c)
            return _cost(steps, self.simulate(room, steps, duties), duties, w_energy)

        best = cost(choice)
        for _ in range(PLAN_PASSES):
            improved = False
            for i in range(n_cycles):
                keep = choice[i]
                for lv in DUTY_LEVELS:
                    if lv == keep:
                        continue
                    choice[i] = lv
                    value = cost(choice)
                    if value < best - 1e-9:
                        best, keep, improved = value, lv, True
                choice[i] = keep
            if not improved:
                break
        duties = expand(choice)
        return Plan(duties=duties, temps=self.simulate(room, steps, duties))

    def hours_until(
        self,
        room: float,
        steps: list[StepInput],
        duty: float,
        reached: Callable[[float], bool],
    ) -> float | None:
        """Hours until reached(temp) is true with a constant duty, or None."""
        temps = self.simulate(room, steps, [duty] * len(steps))
        for i, temp in enumerate(temps):
            if reached(temp):
                return (i + 1) * STEP_H
        return None

    # ---- storage ---------------------------------------------------------

    def to_dict(self) -> dict:
        return {"learners": [l.to_dict() for l in self.learners]}

    @classmethod
    def from_dict(cls, data: dict | None) -> RoomModel:
        if not data or "learners" not in data:
            return cls()
        stored = {l["floor_tau_h"]: Learner.from_dict(l) for l in data["learners"]}
        return cls([stored.get(t) or Learner(t) for t in FLOOR_TAU_CANDIDATES_H])


def _cost(
    steps: list[StepInput], temps: list[float], duties: list[float], w_energy: float
) -> float:
    total = 0.0
    for step, temp, duty in zip(steps, temps, duties):
        cold = step.target - temp
        if cold > 0:
            total += (W_COLD_COMFORT if step.comfort else W_COLD_SETBACK) * cold * cold
        elif step.comfort and -cold > OVERSHOOT_K:
            warm = -cold - OVERSHOOT_K
            total += W_WARM * warm * warm
        total += w_energy * duty
    return total


def _hold_duty(p: Params, step: StepInput) -> float:
    """Duty that holds the step's target in steady state (screed at room)."""
    need = p.a * (step.target - step.outdoor) - p.c * step.sun - p.d
    return min(max(need / p.b, 0.0), 1.0)

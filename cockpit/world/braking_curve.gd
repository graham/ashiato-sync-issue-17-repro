class_name BrakingCurve
extends RefCounted
## THE SPEED TO BE DOING RIGHT NOW, given how far there is left to run.
##
## WHY IT EXISTS (lane/flightcore, 2026-09-19, from the user: the AI's actions are "very jerky and oscillate", and "we
## should anticipate the approach so as not to overshoot"). Every leg an autopilot is given here hands it a new speed at
## the moment the phase changes -- `p.downwind_speed`, then `p.final_speed` -- and a step into a proportional loop is a
## kick. Worse, the step arrives where the aeroplane already is rather than where it can still slow down from: the gym
## measured the jets flying **past** a waypoint by more than half the distance they were sent, because nothing anywhere
## works out when to begin.
##
## THE WORKSHOP ALREADY OWNS THE ANSWER and it is in a train. `../../previous_projects/august-15-train/scripts/auto_driver.gd`:
## "outer: distance to the next stop -> the speed to be doing right now; inner: speed error -> throttle or brake. The
## outer loop is a braking curve, `v = sqrt(2 a d)`: the speed from which the train could still stop on the marker at a
## comfortable rate." Three things it does that matter as much as the formula:
##   * it plans on LESS deceleration than it has, so something is left for a late correction;
##   * it aims a little SHORT of the marker, so the last few metres are crept rather than braked;
##   * and the curve is evaluated EVERY TICK against the range now, so the setpoint slides instead of stepping.
## `../pid-control/docs/STRATEGY.md` names that file as the example it never ported. This is the porting.
##
## WHAT IS DELIBERATELY NOT HERE. No state, no integrator, no memory: every function is arithmetic on what it is handed,
## so the planner may call it on the rota and the tick may call it again without the two disagreeing. It does not know
## about aeroplanes, waypoints or phases. And it holds no limits of its own -- the deceleration, the bank and the climb
## are the CRAFT'S, measured (`tests/vehicle_gym.gd`) or asked of the model, never typed beside the arithmetic.

## Plan on this share of the deceleration actually available, so there is something left when the plan turns out to be
## optimistic. The train used four fifths; a wing has less to spare because it cannot brake, so three quarters.
const PLAN_ON: float = 0.75
## And aim this far short, in seconds of flying at the arrival speed, so the last of it is crept rather than braked.
const AIM_SHORT_S: float = 1.5
## Below this a deceleration is treated as none, which makes the curve say "you cannot slow down, do not pretend to".
const NO_BRAKE: float = 0.005


## THE SPEED TO BE DOING RIGHT NOW: `sqrt(arrive^2 + 2 a d)`, capped at the speed it would otherwise fly.
##
## `range` is how far there is left to run, `arrive` the speed wanted at the end of it, `decel` what the craft was
## measured to shed a second, and `cruise` the speed it flies when nothing else is asked. Far out this returns `cruise`
## and nothing happens; inside the braking distance it slides down to `arrive`, and it never asks for less than
## `arrive` -- a curve that undershoots the arrival speed is a curve that stops short of the marker.
static func speed_for(range_left: float, arrive: float, decel: float, cruise: float) -> float:
	var a: float = maxf(decel, 0.0) * PLAN_ON
	if a < NO_BRAKE:
		# NOTHING TO BRAKE WITH, so do not pretend: hold the arrival speed from here and arrive slow rather than
		# promise a deceleration the aeroplane cannot make. The gym found seven kinds in this state.
		return minf(cruise, arrive)
	var run: float = maxf(range_left - arrive * AIM_SHORT_S, 0.0)
	return clampf(sqrt(arrive * arrive + 2.0 * a * run), minf(arrive, cruise), cruise)


## HOW FAR OUT THE SLOWING HAS TO BEGIN, `d = (v^2 - arrive^2) / 2a`, plus the room it was aimed short by. The distance
## at which `speed_for` stops returning `cruise`, and the number a planner puts a gate at.
static func begins_at(speed: float, arrive: float, decel: float) -> float:
	var a: float = maxf(decel, 0.0) * PLAN_ON
	if a < NO_BRAKE:
		return INF
	return maxf(speed * speed - arrive * arrive, 0.0) / (2.0 * a) + arrive * AIM_SHORT_S


## THE ROOM A TURN TAKES, `R = v^2 / (g tan(bank))`: the radius the craft turns on at this speed and this bank. A
## heading change of `psi` radians eats about `R * psi` of the run, which is why the slowing begins at
## `begins_at() + turn_room() * psi` and not at `begins_at()` alone.
static func turn_room(speed: float, bank: float) -> float:
	var lean: float = tan(clampf(bank, 0.02, 1.3))
	return speed * speed / maxf(9.81 * lean, 0.01)


## WHEN TO BEGIN LEVELLING OFF, `climb^2 / 2a`: the height still to be gained at which a craft climbing at `climb` must
## start easing, if it is to stop climbing exactly on the level. The mixers ease at `climb / 0.45` instead, which is a
## time constant and not a distance, and is why a fast climb goes through.
static func level_off_lead(climb: float, vertical: float) -> float:
	var a: float = maxf(vertical, 0.0) * PLAN_ON
	if a < NO_BRAKE:
		return INF
	return climb * climb / (2.0 * a)

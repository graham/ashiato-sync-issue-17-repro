#pragma once
/// AUTOPILOTS THAT MOVE LEVERS, NOT VEHICLES.
///
/// Ported from the `pid_control` addon in `../pid-control`, and the one rule it is built
/// around is the one worth restating here: **a PID outputs the controls a human could
/// hold** -- throttle, pitch, roll, rudder, brake -- and never a velocity or a force on the
/// hull. Everything downstream of this file is the same simulation a player flies. An AI
/// that set velocities would fly a different aeroplane from the one in your hands, and any
/// difference between them would be invisible until it mattered.
///
/// The shape is cascaded loops: an OUTER loop whose output is a LIMIT (max climb rate, max
/// bank, max yaw rate) and an INNER loop that tracks it. That is what stops an autopilot
/// asking for a 4 g pull to fix a hundred feet of altitude.
///
/// Sign conventions here are this game's, taken from ControlInput and not from the addon:
///   pitch  +1 nose up      roll +1 right wing down     rudder +1 nose right
/// and heading is a compass angle: 0 along -Z, increasing to the right, so a positive
/// heading error means turn right, which means positive bank and positive rudder. The
/// addon needed sign gymnastics for this; here the levers already agree.

#include <algorithm>
#include <cmath>

namespace ashiato_gd {
namespace cockpit {
namespace ai {

constexpr float kPi = 3.14159274f;
constexpr float kTau = 6.28318548f;

inline float clamp(float v, float lo, float hi) {
    return v < lo ? lo : (v > hi ? hi : v);
}

/// The short way round, always in [-pi, pi]. Wrap BEFORE the PID sees it: a scalar loop
/// handed 359 degrees of error will happily turn the long way.
inline float angle_error(float current, float target) {
    float d = std::fmod(target - current + kPi, kTau);
    if (d < 0.0f) {
        d += kTau;
    }
    return d - kPi;
}

/// A scalar PID. Does not wrap angles, know about vehicles, or apply forces.
///
/// Two details that are not decoration:
///   * the derivative is on the MEASURED value, so a step in the setpoint does not spike D;
///   * it does not integrate while the output is against a stop, or the integrator winds
///     up during a climb the aircraft cannot make and then flies it into the ground on the
///     way back down.
struct Pid {
    float kp = 0.0f;
    float ki = 0.0f;
    float kd = 0.0f;
    float out_min = -1.0f;
    float out_max = 1.0f;
    float integral_limit = 1e30f;

    float integral = 0.0f;
    float last_output = 0.0f;
    bool saturated = false;
    float previous = 0.0f;
    bool has_previous = false;

    void configure(float p, float i, float d, float lo, float hi,
                   float i_limit = 1e30f) {
        kp = p;
        ki = i;
        kd = d;
        out_min = lo;
        out_max = hi;
        integral_limit = i_limit;
    }

    void reset() {
        integral = 0.0f;
        last_output = 0.0f;
        saturated = false;
        has_previous = false;
    }

    float step(float error, float measured, float dt) {
        if (dt <= 1e-9f) {
            return last_output;
        }
        if (!saturated && ki != 0.0f) {
            integral = clamp(integral + error * dt, -integral_limit, integral_limit);
        }
        float derivative = 0.0f;
        if (has_previous && kd != 0.0f) {
            derivative = -kd * (measured - previous) / dt;
        }
        previous = measured;
        has_previous = true;
        const float raw = kp * error + ki * integral + derivative;
        last_output = clamp(raw, out_min, out_max);
        saturated = (last_output >= out_max - 1e-9f && error > 0.0f)
            || (last_output <= out_min + 1e-9f && error < 0.0f);
        return last_output;
    }
};

/// Where the vehicle is and what it is doing, in the terms an autopilot thinks in.
struct Situation {
    float altitude = 0.0f;
    float climb_rate = 0.0f;
    /// Compass angle of the nose: 0 along -Z, increasing to the right.
    float heading = 0.0f;
    /// Positive is right wing down, the same sign as the roll lever.
    float bank = 0.0f;
    float pitch = 0.0f;
    float airspeed = 0.0f;
    /// Velocity across the wings as a fraction of speed. Positive is drifting right.
    float sideslip = 0.0f;
    /// About the vehicle's own up, positive turning right, to match the rudder.
    float yaw_rate = 0.0f;
    float forward_speed = 0.0f;
};

/// What the autopilot is aiming for.
struct Bugs {
    float heading = 0.0f;
    float altitude = 0.0f;
    float airspeed = 0.0f;
    /// A bank to HOLD, which only a machine that translates by tilting can use. An
    /// aeroplane derives its bank from its heading error and ignores this.
    float bank = 0.0f;
    /// A CLIMB RATE TO HOLD INSTEAD OF A HEIGHT, metres a second, when `holds_climb` (lane/pattern): an aeroplane's
    /// flare, which is a sink rate bled away over the last few metres rather than a height, and which has to be flown
    /// below 1.3 x the stall, where the altitude loop's slow rule would command a descent (`AircraftMixer::step`).
    bool holds_climb = false;
    float climb = 0.0f;
};

/// What it moves. Exactly the axes a player's hands reach.
struct Levers {
    float throttle = 0.0f;
    float pitch = 0.0f;
    float roll = 0.0f;
    float rudder = 0.0f;
    float brake = 0.0f;
};

/// Where a follower sits, in the leader's own frame: right, up, and BEHIND.
struct Slot {
    float right = 0.0f;
    float up = 0.0f;
    float behind = 0.0f;
};

/// Everything a follower needs to know about the machine it is flying off.
struct FormationInput {
    float lead_x = 0.0f;
    float lead_y = 0.0f;
    float lead_z = 0.0f;
    /// Compass angle of the leader's nose, flat.
    float lead_heading = 0.0f;
    /// Compass angle of the leader's TRACK -- where it is actually going, which is not the
    /// same thing. Falls back to the nose when it is too slow for a track to mean anything.
    float lead_track = 0.0f;
    float lead_speed = 0.0f;
    float own_x = 0.0f;
    float own_y = 0.0f;
    float own_z = 0.0f;
    /// How fast the follower is closing on the slot along the formation axis, positive
    /// when it is catching up.
    float closing_rate = 0.0f;
    /// The leader's own rate of turn, positive to the right, in rad/s.
    float lead_turn_rate = 0.0f;
    /// HOW FAST IT IS SLIDING ACROSS the formation axis, positive to the right, relative to
    /// the leader. The other half of the lateral problem, and the half that was missing.
    float drift_rate = 0.0f;
};

struct FormationSolution {
    Bugs bugs;
    float slot_x = 0.0f;
    float slot_y = 0.0f;
    float slot_z = 0.0f;
    /// Metres behind the slot, positive.
    float along = 0.0f;
    /// Metres right of the slot, positive.
    float crosstrack = 0.0f;
};

/// FORMATION GUIDANCE, and the one thing it must not do is steer at the slot.
///
/// Flying at a bearing is what an autopilot chasing a point does, and it is wrong here for
/// a reason that only shows up in the air: when the leader turns, the slot swings across
/// and lands in the follower's REAR hemisphere. A bearing controller sees a 170 degree
/// error and dutifully flies a full circle to fix it, and the formation comes apart every
/// time the flight changes heading.
///
/// So the heading bug is the LEADER'S heading plus a CLAMPED intercept -- never more than
/// half a radian of cut toward the slot. The follower always flies roughly where the
/// leader is flying, and closes sideways as a correction on top of that. Ported from
/// `formation_guide.gd` in ../pid-control, which is where the 360 was found.
struct FormationGuide {
    // GAIN SCHEDULING ON THE CROSSTRACK, and it is the difference between a formation and
    // a limit cycle.
    //
    // A single look-ahead cannot do this job. Set it short enough to drag a follower back
    // from two hundred metres and the intercept is SATURATED for anything over about
    // fifty, which is bang-bang control: full cut, overshoot, full cut the other way. That
    // is what the flights were doing -- measured, 61 m of crosstrack error against 18 m
    // along track and 0 m vertically, which is not a follower failing to catch up, it is
    // one swinging through its slot.
    //
    // So both the aim point and the cap move with how far out it is: hard and short when
    // it has ground to make up, long and gentle as it arrives, so the last few metres are
    // flown rather than fought.
    /// GENTLE OUT TO FORTY METRES, not twenty-five. The whole schedule is about where the
    /// follower stops chasing and starts settling, and it was settling far too late: one
    /// fifteen metres out was still being flown as though it had ground to make up, which
    /// is a correction it does not need and then has to take back out again.
    float near_hold = 40.0f;
    float far_hold = 150.0f;
    /// Aim point, in metres ahead. SHORT is aggressive.
    ///
    /// The FAR end stays where it is -- that is what stopped the stragglers, and a follower
    /// a kilometre out genuinely does need hauling back. The NEAR end is much longer again,
    /// because arriving is a different job from catching up and the last few metres should
    /// be flown rather than fought.
    float look_ahead_far = 28.0f;
    float look_ahead_near = 190.0f;
    /// The most cut the follower will take toward its slot. This IS the anti-360: it is
    /// the only thing stopping a lead turn -- which throws the slot into the follower's
    /// rear hemisphere -- from being answered with a full circle.
    float max_intercept_far = 1.25f;
    /// A NUDGE, and a firm one. Sixteen degrees at the slot was a swerve and made the
    /// formation look nervous; eight was so gentle that closing the last few metres
    /// SIDEWAYS took most of a leg. Twelve, with the aim point shortened to match, which is
    /// what puts the lateral authority in the middle of the range where it is needed rather
    /// than at the cap.
    float max_intercept_near = 0.20f;
    /// Catch-up: sqrt(2 a d), so it can still brake back to the leader's speed rather
    /// than arriving at a closing rate it cannot lose.
    ///
    /// MORE OF IT, because the leader may be a PERSON. An autopilot leader flies long
    /// straight legs at a fixed cruise and a follower has all day; a human rolls into a
    /// turn, changes their mind, and opens the throttle, and a follower that can only find
    /// forty metres a second of overtake spends the rest of the sortie behind.
    /// Closing HARD but braking harder: the cap and the acceleration are what let a
    /// follower catch a human leader, and the damping is what stops it arriving with speed
    /// it cannot lose and sailing on through the slot.
    float catch_accel = 7.0f;
    float catch_damp = 1.4f;
    float catch_cap = 70.0f;
    /// A HELICOPTER DOES NOT GO WHERE ITS NOSE POINTS, it goes where the disc is tilted,
    /// and a follower that only yaws toward its slot crabs its way there taking a long
    /// time about it. Measured, aeroplanes in trail held 22 m and helicopters 89 m on the
    /// same guidance.
    ///
    /// So for a machine that translates, the heading bug stays on the FLIGHT'S heading --
    /// the trail stays lined up -- and the crosstrack is answered with a bank instead,
    /// which is how a helicopter actually side-steps into position.
    bool translates = false;
    /// Radians of bank per metre of crosstrack, and the most it will use.
    ///
    /// THE ONLY LATERAL AUTHORITY A HELICOPTER HAS. It does not turn toward its slot, it
    /// leans at it, so this is to a trail what the intercept is to a flight -- and it was
    /// the weakest thing in the guidance: helicopters held 33 m where aeroplanes held 5.
    float side_step = 0.011f;
    float max_side_step = 0.45f;
    /// Radians of bank per metre a second of sideways closing speed. Big relative to
    /// `side_step` on purpose: a helicopter carries its drift for a long time, so the rate
    /// is worth far more to it than the position is.
    float side_damp = 0.10f;
    /// Radians of cut per metre a second, for a machine that turns toward its slot.
    float cross_damp = 0.05f;

    /// TURN FEED-FORWARD, and the flights do not hold station without it.
    ///
    /// A follower sits `behind` metres back, which at cruise is most of a second behind
    /// the leader in time. Flying the leader's CURRENT heading means starting every turn
    /// that much late and spending the whole of it outside the slot, and a flight whose
    /// leader is always turning towards its next waypoint is a flight always mid-turn.
    /// Rolling in early by the leader's own turn rate is what closes it.
    ///
    /// MORE THAN ONE, deliberately. At exactly one the follower rolls in as the leader's
    /// current rate says it should, which is right for a leader holding a steady turn and
    /// late for one still tightening it -- and a human leader is always still tightening
    /// it. Anticipating a little past the measured rate is what lets a flight stay together
    /// through a turn somebody is flying by hand. A LITTLE: at 1.35 the anticipation was
    /// itself something to correct, and a follower that rolls in too early spends the rest
    /// of the turn coming back out of it.
    float turn_lead = 1.15f;

    /// STACKING UP: how far out of its slot a follower has to be before it starts climbing
    /// above the formation, and how far out counts as fully lost. Metres.
    float stack_from = 150.0f;
    float stack_to = 1200.0f;
    /// How much higher than its slot a fully lost follower flies. Metres.
    ///
    /// A rejoin from a long way out is the one leg where a follower is in real trouble. It
    /// is chasing a slot rather than a waypoint, so nothing it is doing has been checked
    /// against the terrain; it is at whatever height it fell out at, which is usually LOW,
    /// because falling behind and sinking are the same mistake; and it is the one aircraft
    /// nobody can see, because it is the one that is not where the formation is.
    ///
    /// Climbing fixes all three at once. Height is the cheapest safety margin an aeroplane
    /// has, and an aircraft above the formation is against the sky rather than against the
    /// ground, which is the difference between finding it and losing it.
    ///
    /// It comes back down as it closes, because the term is scaled by how far out it is:
    /// arriving in the slot and arriving at the slot's height are the same manoeuvre.
    float stack_up = 250.0f;

    FormationSolution follow(const FormationInput& in, const Slot& slot) const {
        // THE AXIS THE FORMATION IS BUILT ON, and for a helicopter it is the leader's
        // TRACK rather than its nose.
        //
        // Those are the same thing for an aeroplane -- its flight path follows its nose to
        // within a fraction of a degree, which took some doing -- but a helicopter's nose
        // and its direction of travel are only loosely related: it goes where the disc is
        // tilted and can point anywhere while doing it. A trail built on the leader's NOSE
        // therefore lays its slots out sideways across the flight path whenever the leader
        // is crabbing, and the whole line ends up flying at an angle to where it is going.
        //
        // Built on the track, single file means single file: the slots sit along the path
        // the leader is actually flying, and the followers point down it.
        const float axis = translates ? in.lead_track : in.lead_heading;
        // The leader's flat frame: forward is -Z at heading zero.
        const float forward_x = std::sin(axis);
        const float forward_z = -std::cos(axis);
        const float right_x = -forward_z;
        const float right_z = forward_x;

        FormationSolution out;
        out.slot_x = in.lead_x + right_x * slot.right - forward_x * slot.behind;
        out.slot_y = in.lead_y + slot.up;
        out.slot_z = in.lead_z + right_z * slot.right - forward_z * slot.behind;

        const float dx = in.own_x - out.slot_x;
        const float dz = in.own_z - out.slot_z;
        out.crosstrack = dx * right_x + dz * right_z;
        out.along = -(dx * forward_x + dz * forward_z);

        // Right of the slot means cut left, so the intercept is negative.
        // 0 when it is sitting in the slot, 1 when it is a long way across from it.
        const float effort = clamp((std::fabs(out.crosstrack) - near_hold)
                                       / std::fmax(far_hold - near_hold, 1.0f),
                                   0.0f, 1.0f);
        const float aim = look_ahead_near + (look_ahead_far - look_ahead_near) * effort;
        const float cap = max_intercept_near
            + (max_intercept_far - max_intercept_near) * effort;
        // DAMPED ON THE RATE, which it was not, and that is what an oscillation IS.
        //
        // The cut was a pure function of how far across the follower was: full correction
        // while it is out of position, no correction at all the instant it arrives, and
        // therefore nothing anywhere that notices it is arriving FAST. A proportional
        // controller with no rate term does not settle, it hunts -- it flies through the
        // slot, sees the error reverse, and hauls back the other way.
        //
        // Subtracting the sideways closing speed is the missing half. Coming in quickly, it
        // eases off early; drifting out, it leans on it sooner. Same authority, and it
        // arrives instead of crossing.
        const float intercept = clamp(
            -std::atan2(out.crosstrack, std::fmax(aim, 10.0f))
                - in.drift_rate * cross_damp,
            -cap, cap);
        // How far behind the leader this slot is, in SECONDS, and therefore how much of
        // the leader's turn the follower has to start early to arrive rolled in with it.
        const float lag = slot.behind / std::fmax(in.lead_speed, 8.0f);
        out.bugs.heading = axis + in.lead_turn_rate * lag * turn_lead
            + (translates ? 0.0f : intercept);
        // Right of the slot means tilt left, so the bank is the opposite sign.
        // And the same for a machine that LEANS at its slot instead of turning toward it.
        // A helicopter's side-step was the worst offender: bank straight off crosstrack,
        // no rate term, which is a spring with no damper bolted to a hovering aircraft.
        out.bugs.bank = translates
            ? clamp(-out.crosstrack * side_step - in.drift_rate * side_damp,
                    -max_side_step, max_side_step)
            : 0.0f;
        // HOW LOST IT IS: 0 sitting in the slot, 1 a long way from it, and the climb it
        // flies is that fraction of `stack_up`.
        const float adrift = std::sqrt(out.crosstrack * out.crosstrack
                                       + out.along * out.along);
        const float lost = clamp((adrift - stack_from)
                                     / std::fmax(stack_to - stack_from, 1.0f),
                                 0.0f, 1.0f);
        out.bugs.altitude = out.slot_y + stack_up * lost;
        out.bugs.airspeed = closing_speed(out.along, in.closing_rate, in.lead_speed);
        return out;
    }

    /// `along` positive is behind the slot. Damped by the closing rate, so the follower
    /// does not floor it and then sail past.
    float closing_speed(float along, float closing_rate, float lead_speed) const {
        float extra = 0.0f;
        if (along > 0.5f) {
            extra = std::sqrt(2.0f * catch_accel * along);
        } else if (along < -0.5f) {
            extra = -std::sqrt(2.0f * catch_accel * -along);
        }
        extra -= catch_damp * closing_rate;
        const float cap = std::fmax(catch_cap, lead_speed * 0.45f);
        return std::fmax(lead_speed + clamp(extra, -cap, cap), lead_speed * 0.25f);
    }
};

/// A WING. Altitude through climb rate through the stick; heading through bank through the
/// stick; speed through the throttle; sideslip through the rudder.
struct AircraftMixer {
    /// Metres a second, at cruise. Set per kind from `climb_angle` and `climb_share` -- see
    /// CockpitWorld::gentle_climb -- and never typed.
    float max_climb_rate = 30.0f;
    /// THE STEEPEST DESCENT, metres a second, where it is not the climb's: 0 is `max_climb_rate`, as every wing flew
    /// until lane/cessnafm. A descent is paid for by the drag at idle, not the engine, and a propeller's climb budget --
    /// 2.6 m/s on the surface Cessna -- flew its final at 4.2 degrees chasing a path it had been left above. Never less
    /// than the climb's.
    float max_descent_rate = 0.0f;
    float max_bank = 0.90f;   // radians, about 50 degrees
    /// HOW FAST THE BANK IT ASKS FOR MAY CHANGE, radians a second; 0 is as fast as the loops like. A BAD PILOT'S HANDS
    /// (lane/combat): an attacker rolls into and out of its turns slowly, which is most of why it overshoots.
    float bank_rate = 0.0f;
    float bank_asked = 0.0f;
    bool bank_asked_known = false;
    float stall_speed = 24.0f;
    /// The speed it is flown at, which is where the whole of `max_climb_rate` is allowed.
    float cruise_speed = 0.0f;
    /// THE STEEPEST CLIMB, as the flight path's angle: 0.10 rad is under six degrees. A rate
    /// that is gentle at seventy metres a second is a zoom at forty, which is why it is an
    /// angle. The light aeroplane climbed at twenty-three degrees before this existed.
    float climb_angle = 0.10f;
    /// And no more than this share of what the engine can sustain at cruise, so the speed
    /// loop still has throttle left while it climbs.
    float climb_share = 0.6f;
    /// CLIMB PAID FOR IN SPEED. At cruise the whole climb is allowed; at this multiple of the
    /// stall none of it is; and below that the ceiling is a DESCENT, so a wing that has got
    /// slow puts its nose down and gets its speed back instead of pulling towards the stall.
    ///
    /// THIRTY PER CENT, not ten: "be careful not to stall" is not an aeroplane ten per cent over
    /// it. Which is why every powered wing now cruises at 1.45 times the stall rather than
    /// 1.30 -- see `default_cruise` -- or the band this fades across would have been nothing.
    float slow_margin = 1.30f;
    float climb_throttle_gain = 0.012f;
    /// A banked wing has to pull harder to hold height, and the pilot knows it before the
    /// altimeter does. Feed-forward, so the altitude loop is not chasing its own turn.
    float load_factor_gain = 0.35f;
    float throttle_trim = 0.45f;
    /// WHETHER THERE IS AN ENGINE, and it changes which lever holds the speed.
    ///
    /// A powered aeroplane holds its SPEED with the throttle and its HEIGHT with the stick.
    /// A glider has only the stick, so it holds its speed with that and spends height to do
    /// it -- which is not a degraded version of the same law, it is a different one.
    ///
    /// Left true, a glider is flown by an autopilot that answers every metre it loses by
    /// pulling the nose up and opening a throttle that is not there. Measured: it left 520 m
    /// and reached 40, crossed its own climb rate eight times in a minute, and came to a
    /// complete stop in the air -- 0 m/s, which is not a glide, it is a stall followed by a
    /// mush. The whole time it had a perfectly good glide available to it.
    bool powered = true;
    /// THE GLIDER'S OWN SPEED LOOP, and it is a separate loop rather than a scaled copy of
    /// `speed_loop` for one reason: `speed_loop` HAS NO DERIVATIVE TERM.
    ///
    /// That is correct for what it drives. A throttle is a slow, weak lever and an engine
    /// damps itself; P and a little I settle it. Pitch is a fast, strong one, and the same
    /// gains with nothing damping them make a glider chase its own nose -- it crossed its
    /// own climb rate nine times a minute.
    ///
    /// Scaling the gain down instead was tried and is worse than either: too weak to hold
    /// the speed at all, it sank 310 m and reached 13 m/s against a stall of 31. The
    /// missing term was damping, not authority, and you cannot get damping by turning a
    /// proportional gain down.
    ///
    /// The derivative is on MEASURED airspeed, so what it damps is acceleration -- and it
    /// does nothing at all to a glider already flying steadily.
    Pid glide_loop;

    Pid altitude_outer;
    Pid climb_inner;
    Pid heading_outer;
    Pid bank_inner;
    Pid speed_loop;
    Pid slip_loop;

    AircraftMixer() {
        // HARDER THAN IT WAS, on every loop, and the stick underneath it got harder too --
        // a controller can only be as quick as the aeroplane it is asking.
        //
        // The outer loops command a LIMIT and the inner ones track it, so raising an outer
        // gain buys a earlier commitment to the turn and raising an inner one buys a
        // shorter time to reach the bank that turn needs. A follower rejoining a flight
        // that a HUMAN is leading needs both: a person can roll into ninety degrees of
        // heading change in a second and a half, which is quicker than any autopilot was
        // ever asked to answer.
        // BACKED OFF from the first tightening, which held station beautifully and flew
        // like something being corrected constantly. The gains that matter for CATCHING UP
        // are the far end of the formation schedule, not these -- so the loops came down
        // and their damping went up, which buys the same settling time without the twitch.
        altitude_outer.configure(0.45f, 0.0f, 0.0f, -max_climb_rate, max_climb_rate);
        heading_outer.configure(1.7f, 0.0f, 0.0f, -max_bank, max_bank);
        // A RATE LOOP WITH NO RATE TERM HUNTS, which is the same lesson the formation
        // guidance learned about crosstrack and it took a tiltrotor to find it here.
        //
        // The climb loop drives the stick from a climb-rate ERROR and nothing was watching
        // how fast that error was closing. On a light aeroplane it does not show: the wing
        // is slow enough to be its own damping. Put the same gains on eighteen tonnes with
        // 900 kN m of control authority and it answers instantly, overshoots, answers back,
        // and settles into a one-hertz buzz -- 66 changes of climb direction in a minute,
        // inside one metre of altitude, which is invisible on an instrument and is exactly
        // the sort of thing you feel in a headset.
        //
        // The derivative is on the MEASURED climb rate, so what it actually damps is
        // vertical acceleration, and it does nothing at all to an aeroplane already flying
        // smoothly.
        climb_inner.configure(0.13f, 0.016f, 0.05f, -1.0f, 1.0f, 8.0f);
        bank_inner.configure(2.2f, 0.0f, 0.45f, -1.0f, 1.0f);
        speed_loop.configure(0.04f, 0.008f, 0.0f, -0.60f, 0.60f, 20.0f);
        glide_loop.configure(0.045f, 0.004f, 0.055f, -0.70f, 0.70f, 20.0f);
        slip_loop.configure(1.4f, 0.0f, 0.14f, -0.6f, 0.6f);
    }

    void reset() {
        bank_asked_known = false;
        altitude_outer.reset();
        climb_inner.reset();
        heading_outer.reset();
        bank_inner.reset();
        speed_loop.reset();
        glide_loop.reset();
        slip_loop.reset();
    }

    Levers step(const Situation& now, const Bugs& want, float dt) {
        // A WING THAT IS SLOW MAY NOT CLIMB, and one slower still is told to descend.
        //
        // It used to be scaled by airspeed over the stall and clamped at one, which allowed
        // the WHOLE climb right down to the stall itself. Measured on 2026-09-14: a tanker
        // asked for thirty metres a second held that ask from 52 m/s all the way down to 9,
        // with its nose at sixty degrees, and fell. Now the allowance runs from all of it at
        // cruise to none of it at `slow_margin` over the stall, and goes negative below.
        const float slow = std::fmax(stall_speed, 1.0f) * slow_margin;
        const float cruise = std::fmax(cruise_speed, slow + 1.0f);
        const float spare = clamp((now.airspeed - slow) / (cruise - slow), -1.0f, 1.0f);
        altitude_outer.out_min = -std::fmax(max_climb_rate, max_descent_rate);
        altitude_outer.out_max = powered ? max_climb_rate * spare : 0.0f;
        heading_outer.out_min = -max_bank;
        heading_outer.out_max = max_bank;

        const float wanted_climb = want.holds_climb
            ? want.climb
            : altitude_outer.step(want.altitude - now.altitude, now.altitude, dt);
        if (climb_inner.saturated) {
            altitude_outer.saturated = true;
        }
        float stick_pitch = climb_inner.step(wanted_climb - now.climb_rate, now.climb_rate,
                                             dt);

        // Turn right for a positive heading error, which is a positive bank.
        float wanted_bank = heading_outer.step(
            angle_error(now.heading, want.heading), now.heading, dt);
        if (bank_rate > 0.0f) {
            if (!bank_asked_known) {
                bank_asked = now.bank;
                bank_asked_known = true;
            }
            const float step = bank_rate * dt;
            bank_asked = clamp(wanted_bank, bank_asked - step, bank_asked + step);
            wanted_bank = bank_asked;
        }
        if (bank_inner.saturated) {
            heading_outer.saturated = true;
        }
        const float stick_roll = bank_inner.step(wanted_bank - now.bank, now.bank, dt);

        // Hold the nose up through the bank rather than waiting to notice the descent.
        float cos_bank = std::fabs(std::cos(now.bank));
        cos_bank = std::fmax(cos_bank, 0.2f);
        stick_pitch = clamp(stick_pitch + load_factor_gain * (1.0f / cos_bank - 1.0f),
                            -1.0f, 1.0f);

        const float trim = speed_loop.step(want.airspeed - now.airspeed, now.airspeed, dt);
        Levers out;
        out.throttle = clamp(throttle_trim + trim + climb_throttle_gain * wanted_climb,
                             0.0f, 1.0f);
        out.pitch = stick_pitch;
        if (!powered) {
            // THE STICK HOLDS THE SPEED AND THE HEIGHT PAYS FOR IT.
            //
            // `trim` is what the throttle WOULD have been opened by, so it is positive when
            // the aeroplane is slow. On a glider that same error moves the nose instead, and
            // downwards: the sign is the whole of the difference between a glide and a
            // stall.
            //
            // The climb loop still has the stick when the glider is FAST, which is what
            // stops it diving away in a thermal -- it may trade the speed it has for height
            // and may not go looking for more.
            //
            // AND THE CLIMB LOOP LETS GO ENTIRELY. Leaving it a share of the stick was the
            // first attempt and it porpoised: a glider is always below the height it is
            // bugged to, because sinking is all it can do, so the climb loop asked for the
            // nose up on every frame while the speed loop asked for it down. Nine crossings
            // of its own climb rate in a minute, which is two loops arguing.
            //
            // ONE LOOP HAS THE STICK. Pitch holds the speed; the sink is whatever the wing
            // gives you at that speed, and rising air is what makes it go up -- the glider
            // does not have to reach for height, it has to be somewhere the air is going
            // there anyway.
            out.throttle = 0.0f;
            out.pitch = clamp(-glide_loop.step(want.airspeed - now.airspeed,
                                               now.airspeed, dt),
                              -1.0f, 1.0f);
        }
        out.roll = stick_roll;
        // Nose toward the airflow: drifting right wants the nose right.
        out.rudder = slip_loop.step(now.sideslip, now.sideslip, dt);
        return out;
    }
};

/// A ROTOR DISC, which is a different aircraft entirely: it goes where it TILTS, so
/// forward speed is the pitch axis and altitude is the throttle, and the tail rotor turns
/// it on the spot without needing any airspeed at all.
struct HeliMixer {
    float max_tilt = 0.35f;         // radians of nose-down at full chase
    float max_yaw_rate = 0.9f;
    float hover_throttle = 0.5f;

    Pid altitude_outer;
    Pid climb_inner;
    Pid heading_outer;
    Pid yaw_inner;
    Pid speed_loop;
    Pid pitch_inner;
    Pid level_loop;

    HeliMixer() {
        altitude_outer.configure(0.6f, 0.0f, 0.0f, -12.0f, 12.0f);
        climb_inner.configure(0.10f, 0.03f, 0.0f, -0.5f, 0.5f, 6.0f);
        heading_outer.configure(1.4f, 0.0f, 0.0f, -max_yaw_rate, max_yaw_rate);
        yaw_inner.configure(1.2f, 0.0f, 0.0f, -1.0f, 1.0f);
        // Outputs a nose-down ANGLE, not a stick. See the note in step().
        speed_loop.configure(0.05f, 0.008f, 0.0f, -1.0f, 1.0f, 10.0f);
        pitch_inner.configure(2.6f, 0.0f, 0.5f, -1.0f, 1.0f);
        level_loop.configure(2.0f, 0.0f, 0.4f, -1.0f, 1.0f);
    }

    void reset() {
        altitude_outer.reset();
        climb_inner.reset();
        heading_outer.reset();
        yaw_inner.reset();
        speed_loop.reset();
        pitch_inner.reset();
        level_loop.reset();
    }

    Levers step(const Situation& now, const Bugs& want, float dt) {
        const float wanted_climb = altitude_outer.step(want.altitude - now.altitude,
                                                       now.altitude, dt);
        Levers out;
        out.throttle = clamp(hover_throttle
                                 + climb_inner.step(wanted_climb - now.climb_rate,
                                                    now.climb_rate, dt),
                             0.0f, 1.0f);

        const float wanted_yaw = heading_outer.step(angle_error(now.heading, want.heading),
                                                    now.heading, dt);
        out.rudder = yaw_inner.step(wanted_yaw - now.yaw_rate, now.yaw_rate, dt);

        // Nose DOWN to accelerate -- but as an ATTITUDE, through a second loop, and the
        // difference is not academic. This game's pitch lever commands a RATE: hold it and
        // the aircraft keeps rotating. Wiring a speed error straight to it asks for a
        // permanent nose-down rate, so the helicopter tips past the vertical, points its
        // rotor at the horizon, stops making lift and flies into the ground. All ten of
        // them did, at once, which is at least an unambiguous way to find out.
        //
        // So: speed error picks a tilt to hold, and an inner loop holds it.
        const float chase = speed_loop.step(want.airspeed - now.forward_speed,
                                            now.forward_speed, dt);
        const float wanted_pitch = clamp(-chase * max_tilt, -max_tilt, max_tilt);
        out.pitch = pitch_inner.step(wanted_pitch - now.pitch, now.pitch, dt);
        // Bank is a LEVER here, not a by-product: a helicopter that rolls goes sideways,
        // which is exactly what a follower side-stepping into its slot wants. Left to
        // itself the bug is zero and this holds it level.
        out.roll = level_loop.step(want.bank - now.bank, now.bank, dt);
        return out;
    }
};

/// WHEELS. Heading through a yaw rate through the steering; speed through throttle and
/// brake. No altitude and no bank, because a car has neither.
struct GroundMixer {
    float max_yaw_rate = 1.2f;

    Pid heading_outer;
    Pid yaw_inner;
    Pid speed_loop;

    GroundMixer() {
        heading_outer.configure(1.4f, 0.0f, 0.0f, -max_yaw_rate, max_yaw_rate);
        // P only: the yaw rate is very nearly algebraic in the steering, so a derivative
        // on it fights the loop rather than damping it.
        yaw_inner.configure(1.3f, 0.0f, 0.0f, -1.0f, 1.0f);
        speed_loop.configure(0.25f, 0.05f, 0.0f, -1.0f, 1.0f, 6.0f);
    }

    void reset() {
        heading_outer.reset();
        yaw_inner.reset();
        speed_loop.reset();
    }

    Levers step(const Situation& now, const Bugs& want, float dt) {
        const float wanted_yaw = heading_outer.step(angle_error(now.heading, want.heading),
                                                    now.heading, dt);
        if (yaw_inner.saturated) {
            heading_outer.saturated = true;
        }
        Levers out;
        // A car steers on either stick's horizontal axis; this game reads roll + rudder.
        out.rudder = yaw_inner.step(wanted_yaw - now.yaw_rate, now.yaw_rate, dt);
        const float drive = speed_loop.step(want.airspeed - now.forward_speed,
                                            now.forward_speed, dt);
        out.throttle = drive > 0.0f ? drive : 0.0f;
        out.brake = drive < 0.0f ? -drive : 0.0f;
        return out;
    }
};

/// A HULL. The same two loops as a car with the steering on the rudder instead, and a
/// gentler yaw limit because a boat that is asked to turn harder than its keel can hold
/// stops tracking and starts sliding.
struct BoatMixer {
    float max_yaw_rate = 0.5f;

    Pid heading_outer;
    Pid yaw_inner;
    Pid speed_loop;

    BoatMixer() {
        heading_outer.configure(1.0f, 0.0f, 0.0f, -max_yaw_rate, max_yaw_rate);
        yaw_inner.configure(1.4f, 0.0f, 0.0f, -1.0f, 1.0f);
        speed_loop.configure(0.20f, 0.04f, 0.0f, -1.0f, 1.0f, 6.0f);
    }

    void reset() {
        heading_outer.reset();
        yaw_inner.reset();
        speed_loop.reset();
    }

    Levers step(const Situation& now, const Bugs& want, float dt) {
        const float wanted_yaw = heading_outer.step(angle_error(now.heading, want.heading),
                                                    now.heading, dt);
        if (yaw_inner.saturated) {
            heading_outer.saturated = true;
        }
        Levers out;
        out.rudder = yaw_inner.step(wanted_yaw - now.yaw_rate, now.yaw_rate, dt);
        const float drive = speed_loop.step(want.airspeed - now.forward_speed,
                                            now.forward_speed, dt);
        out.throttle = drive > 0.0f ? drive : 0.0f;
        out.brake = drive < 0.0f ? -drive : 0.0f;
        return out;
    }
};

/// A SHIP'S HELMSMAN: the heading to a turn rate, the turn rate to the wheel. The boat's two
/// loops with no speed loop, because nothing on a ship under sail is a throttle -- the sails
/// are trimmed to the wind, not to a speed -- and far slower: a two-hundred-tonne hull asked
/// for the half radian a second a launch turns at would have its helm hard over on every
/// heading change and overshoot every one of them.
///
/// Its gains are the rig's (`Rig::helm_*`), handed in each tick, so they tune with the rest of
/// a ship's numbers and need no rebuild.
struct SailMixer {
    Pid heading_outer;
    Pid yaw_inner;

    void configure(float heading_gain, float rate_gain, float most_turn) {
        heading_outer.configure(heading_gain, 0.0f, 0.0f, -most_turn, most_turn);
        yaw_inner.configure(rate_gain, 0.0f, 0.0f, -1.0f, 1.0f);
    }

    void reset() {
        heading_outer.reset();
        yaw_inner.reset();
    }

    float step(const Situation& now, float heading, float dt) {
        const float wanted_yaw = heading_outer.step(angle_error(now.heading, heading),
                                                    now.heading, dt);
        return yaw_inner.step(wanted_yaw - now.yaw_rate, now.yaw_rate, dt);
    }
};

}  // namespace ai
}  // namespace cockpit
}  // namespace ashiato_gd

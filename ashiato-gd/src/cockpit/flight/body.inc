// THE BODY'S OWN NUMBERS, AND THE ONE PLACE FORCES REACH BOX3D (lane/flightcore, step 1).
//
// An INCLUDE FRAGMENT, not a header: it is pasted inside `CockpitWorld` in cockpit_world.cpp, where Box3D's types and
// the class's own members are in scope. The pure blocks (`air.hpp`, `hull.hpp`, `lifting_surfaces.hpp`,
// `rotor_disc.hpp`) know no Box3D at all, so a prototype can include them; everything that does know Box3D is here,
// which is the line between the two.
//
// WHY IT EXISTS. "The inertia about this axis" -- a world inverse-inertia read and `a . (I^-1 a)`, guarded against a
// body that cannot turn -- was typed six times: in `fly_on_surfaces`, `steer_on_the_ground`, `steer_on_the_water`,
// `sail_ship`, `hold_the_turn` and `command_rate`. Each read Box3D again for a number that does not change within a
// tick. One helper, and later one read a tick handed to whatever needs it.
//
// THE EXPRESSIONS ARE UNCHANGED, to the order of their operations: step 1 moves code and moves nothing else, and
// `tests/flight_fingerprint.gd` prints every kind's motion bit for bit to prove it.

/// THE INERTIA A BODY HAS ABOUT ONE AXIS, kg m^2: the inverse of the angular acceleration a newton-metre about it
/// buys, `a . (I^-1 a)`. Zero for a body Box3D will not turn, which is what every caller's guard already says.
static float inertia_about(const b3Matrix3& inverse, const b3Vec3& axis) {
    const float response = dot3(axis, b3MulMV(inverse, axis));
    return response > 1e-9f ? 1.0f / response : 0.0f;
}

/// The same, asked of a body. Kept beside it for the callers that have no reason to hold the matrix themselves.
static float inertia_about(b3BodyId body, const b3Vec3& axis) {
    return inertia_about(b3Body_GetWorldInverseRotationalInertia(body), axis);
}

/// EVERY FORCE AND TORQUE A FLIGHT MODEL MAKES, SUMMED IN ONE PLACE, and handed to Box3D as one of each.
///
/// `fly_on_surfaces` already does this and it is why the surfaces cost what they do: fifteen Box3D calls an aircraft
/// became three (`research/flight_model_plan.md`, "Performance and determinism"). The lumped wing still makes eight,
/// and every model that moves onto the blocks gets this instead.
///
/// SUMMED IN A FIXED ORDER, which is a rollback decision: a replayed tick adds the same numbers in the same order and
/// so computes the same bits.
struct Loads {
    b3Vec3 force{0.0f, 0.0f, 0.0f};
    b3Vec3 torque{0.0f, 0.0f, 0.0f};

    void push(const b3Vec3& f) { force = added(force, f); }
    void twist(const b3Vec3& t) { torque = added(torque, t); }
    /// A force somewhere other than the centre of mass: the torque is the arm crossed into it, and the force still
    /// acts. `arm` is from the centre of mass, in the world's frame.
    void push_at(const b3Vec3& f, const b3Vec3& arm) {
        force = added(force, f);
        torque = added(torque, cross(arm, f));
    }
};

/// AND THE ONE PLACE THEY LEAVE: two calls, whatever the model did.
static void apply(b3BodyId body, const Loads& loads) {
    b3Body_ApplyForceToCenter(body, loads.force, true);
    b3Body_ApplyTorque(body, loads.torque, true);
}

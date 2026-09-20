// Box3D, stepped by us rather than by Godot.
//
// This is the piece that makes "Box3D does the sim, ashiato does the rewind" possible.
// The godot-box3d addon installs Box3D as a PhysicsServer3D backend, which means GODOT
// owns the step: once per physics frame, forward only, no way back. Prediction needs
// exactly the opposite -- restore a past state and re-step N times inside one frame.
//
// Box3D's own C API is manually stepped and documented as deterministic, so owning the
// world here gives ashiato the rewind. The trade is stated honestly in rewind_error():
// the public API can restore a body's transform and velocities but NOT the solver's
// warm-start/contact state, so a rewind through active contact is very close rather
// than bit-exact. Measuring that is the point of the conformance test, not guessing it.

#include <cmath>
#include <cstdint>
#include <unordered_map>
#include <vector>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/quaternion.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include "box3d/box3d.h"
#include "../core/from_godot.hpp"

using namespace godot;

namespace ashiato_gd {

// The state a rollback has to put back. Everything the public Box3D API lets us
// restore for a body; see the file header for what it cannot.
struct BodySnapshot {
    b3Pos position{};
    b3Quat rotation{};
    b3Vec3 linear{};
    b3Vec3 angular{};
};

class Box3DWorld : public RefCounted {
    GDCLASS(Box3DWorld, RefCounted)

public:
    Box3DWorld() = default;

    ~Box3DWorld() override {
        destroy_world();
    }

    // sub_steps 4 at a fixed 1/60 is what Box3D's own docs recommend; both are fixed
    // rather than frame-derived, because a rollback replays steps and a variable dt
    // would make the replay a different simulation.
    void create(const Vector3& gravity) {
        destroy_world();
        b3WorldDef def = b3DefaultWorldDef();
        def.gravity = b3_vec(gravity);
        world_ = b3CreateWorld(&def);
        alive_ = true;
    }

    bool is_valid() const {
        return alive_;
    }

    void destroy_world() {
        if (alive_) {
            b3DestroyWorld(world_);
            alive_ = false;
            bodies_.clear();
            next_handle_ = 1;
        }
    }

    // Returns a stable integer handle. Box3D ids are structs, and handing raw ids to
    // GDScript would leak their layout; a handle also survives being stored in a
    // component field.
    int64_t add_box(const Vector3& position, const Vector3& half_extents, float mass,
                    bool is_static) {
        if (!alive_) {
            return 0;
        }
        b3BodyDef body_def = b3DefaultBodyDef();
        body_def.type = is_static ? b3_staticBody : b3_dynamicBody;
        body_def.position = b3_pos(position);
        // Sleeping is disabled for every body this owns: a body that falls asleep stops
        // integrating, and a rollback that re-steps it would then produce a different
        // trajectory than the original run. Determinism beats the CPU saving here.
        body_def.enableSleep = false;

        const b3BodyId body = b3CreateBody(world_, &body_def);
        // A box is a hull in Box3D; b3BoxHull carries its own base to hand to
        // b3CreateHullShape, and must NOT be destroyed (see b3MakeBoxHull's docs).
        b3BoxHull box = b3MakeBoxHull(half_extents.x, half_extents.y, half_extents.z);
        b3ShapeDef shape_def = b3DefaultShapeDef();
        if (!is_static && mass > 0.0f) {
            shape_def.density = mass / (8.0f * half_extents.x * half_extents.y * half_extents.z);
        }
        b3CreateHullShape(body, &shape_def, &box.base);

        const int64_t handle = next_handle_++;
        bodies_[handle] = body;
        return handle;
    }

    void step(float dt, int sub_steps) {
        if (alive_) {
            b3World_Step(world_, dt, sub_steps);
        }
    }

    // ---- state, which is what ashiato stores per frame ----

    Dictionary get_state(int64_t handle) const {
        Dictionary out;
        const b3BodyId* body = find(handle);
        if (body == nullptr) {
            return out;
        }
        const b3WorldTransform xform = b3Body_GetTransform(*body);
        const b3Vec3 linear = b3Body_GetLinearVelocity(*body);
        const b3Vec3 angular = b3Body_GetAngularVelocity(*body);

        out["position"] = Vector3(xform.p.x, xform.p.y, xform.p.z);
        // b3Quat stores its vector part as a b3Vec3 plus a scalar, so it does not map
        // field-for-field onto Godot's Quaternion(x, y, z, w).
        out["rotation"] = Quaternion(xform.q.v.x, xform.q.v.y, xform.q.v.z, xform.q.s);
        out["linear_velocity"] = Vector3(linear.x, linear.y, linear.z);
        out["angular_velocity"] = Vector3(angular.x, angular.y, angular.z);
        return out;
    }

    void set_state(int64_t handle, const Dictionary& state) {
        const b3BodyId* body = find(handle);
        if (body == nullptr) {
            return;
        }
        const Vector3 position = state.get("position", Vector3());
        const Quaternion rotation = state.get("rotation", Quaternion());
        const Vector3 linear = state.get("linear_velocity", Vector3());
        const Vector3 angular = state.get("angular_velocity", Vector3());

        b3Body_SetTransform(*body,
                            b3_pos(position),
                            b3_quat(rotation));
        b3Body_SetLinearVelocity(*body, b3_vec(linear));
        b3Body_SetAngularVelocity(*body, b3_vec(angular));
    }

    void apply_force(int64_t handle, const Vector3& force) {
        const b3BodyId* body = find(handle);
        if (body != nullptr) {
            b3Body_ApplyForceToCenter(*body, b3_vec(force), true);
        }
    }

    void apply_torque(int64_t handle, const Vector3& torque) {
        const b3BodyId* body = find(handle);
        if (body != nullptr) {
            b3Body_ApplyTorque(*body, b3_vec(torque), true);
        }
    }

    Vector3 get_position(int64_t handle) const {
        const b3BodyId* body = find(handle);
        if (body == nullptr) {
            return Vector3();
        }
        const b3Pos p = b3Body_GetPosition(*body);
        return Vector3(p.x, p.y, p.z);
    }

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("create", "gravity"), &Box3DWorld::create);
        ClassDB::bind_method(D_METHOD("is_valid"), &Box3DWorld::is_valid);
        ClassDB::bind_method(D_METHOD("destroy_world"), &Box3DWorld::destroy_world);
        ClassDB::bind_method(
            D_METHOD("add_box", "position", "half_extents", "mass", "is_static"),
            &Box3DWorld::add_box);
        ClassDB::bind_method(D_METHOD("step", "dt", "sub_steps"), &Box3DWorld::step);
        ClassDB::bind_method(D_METHOD("get_state", "handle"), &Box3DWorld::get_state);
        ClassDB::bind_method(D_METHOD("set_state", "handle", "state"), &Box3DWorld::set_state);
        ClassDB::bind_method(D_METHOD("apply_force", "handle", "force"),
                             &Box3DWorld::apply_force);
        ClassDB::bind_method(D_METHOD("apply_torque", "handle", "torque"),
                             &Box3DWorld::apply_torque);
        ClassDB::bind_method(D_METHOD("get_position", "handle"), &Box3DWorld::get_position);
    }

private:
    const b3BodyId* find(int64_t handle) const {
        const auto found = bodies_.find(handle);
        return found == bodies_.end() ? nullptr : &found->second;
    }

    b3WorldId world_{};
    bool alive_ = false;
    std::unordered_map<int64_t, b3BodyId> bodies_;
    int64_t next_handle_ = 1;
};

void register_physics_classes() {
    GDREGISTER_CLASS(Box3DWorld);
}

}  // namespace ashiato_gd

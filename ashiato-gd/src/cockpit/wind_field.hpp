#pragma once

/// ## THE WIND OVER THE WORLD, AS A FUNCTION OF THE FRAME.
///
/// One field for the whole world: a direction the air comes FROM and a speed, both
/// wandering slowly between limits, and nothing else about it is chosen. It is the
/// authority. The simulation asks it, a sail asks it, and one day the sky and the clouds
/// will ask it rather than leaning on a constant of their own.
///
/// **IT IS A FUNCTION OF THE FRAME NUMBER AND A SEED, AND OF NOTHING ELSE.** Two peers told the
/// same weather compute the same wind for the same frame to the bit, and a resimulated tick
/// computes the wind its original did, because a frame survives a rewind and a free-running
/// clock does not. The standing swell (`swell_height`) does not travel for exactly that
/// reason; the wind can move because the frame is in hand wherever it is asked.
///
/// **Slowly, and in two sines apiece.** Speed and direction are each the sum of two sines
/// with periods of minutes that share no common multiple a session will reach. The
/// phases are hashed from the seed. One sine is a metronome anybody standing on a deck
/// for ten minutes would notice. A noise field was rejected too: noise needs a lattice
/// and an interpolant, is harder to bound, and the bound is the thing a test checks.
/// Two sines weighted 0.7 and 0.3 can never leave [-1, 1], so the speed never leaves
/// [`low`, `high`] and the direction never leaves `from` ± `veer`.
///
/// **A STEADY WIND IS THE SAME FIELD** with `low` equal to `high` and no veer.
/// `CockpitWorld::set_wind` makes one of those, so a world told a wind the old way flies
/// exactly as it did.
///
/// Where the air GOES is the vector, and where it comes FROM is the angle, because that
/// is how a sailor names a wind ("a westerly comes from the west") and how a person
/// typing a weather into a table thinks of it. Compass angles are the game's: 0 along −Z
/// and increasing to the right, the same as `Situation::heading`.

#include <cmath>
#include <cstdint>

namespace ashiato_gd {
namespace cockpit {

struct WindField {
    /// Compass angle the wind comes FROM, in radians.
    float from = 0.0f;
    /// The speed wanders between these, in metres a second.
    float low = 0.0f;
    float high = 0.0f;
    /// How far the direction wanders either side of `from`, in radians.
    float veer = 0.0f;
    /// Hashed into the phases, so two worlds with different seeds have different afternoons.
    std::uint32_t seed = 1u;

    /// THE PERIODS, in seconds. Seven minutes and three, ten and four: long enough that the
    /// wind a ship tacks against is the wind it tacked against a minute ago, short enough
    /// that a session sees it change.
    static constexpr double kSpeedSlow = 431.0;
    static constexpr double kSpeedQuick = 173.0;
    static constexpr double kTurnSlow = 617.0;
    static constexpr double kTurnQuick = 241.0;

    /// A wind that does not change: `air` is where the air goes, flat.
    static WindField steady(float air_x, float air_z) {
        WindField field;
        const float speed = std::sqrt(air_x * air_x + air_z * air_z);
        field.low = speed;
        field.high = speed;
        // FROM, so the opposite of where it goes: air moving along +X comes from -X.
        field.from = speed > 0.0f ? std::atan2(-air_x, air_z) : 0.0f;
        return field;
    }

    bool is_still() const {
        return high <= 0.0f;
    }

    /// Speed and direction at `seconds` into the session: the speed, and the angle it comes from.
    void at(double seconds, float& speed, float& coming_from) const {
        const double tau = 6.283185307179586;
        const double wander_speed = 0.7 * std::sin(tau * seconds / kSpeedSlow + phase(1u))
            + 0.3 * std::sin(tau * seconds / kSpeedQuick + phase(2u));
        const double wander_turn = 0.7 * std::sin(tau * seconds / kTurnSlow + phase(3u))
            + 0.3 * std::sin(tau * seconds / kTurnQuick + phase(4u));
        const double middle = 0.5 * (static_cast<double>(low) + static_cast<double>(high));
        const double half = 0.5 * (static_cast<double>(high) - static_cast<double>(low));
        speed = static_cast<float>(middle + half * wander_speed);
        coming_from = static_cast<float>(static_cast<double>(from)
                                         + static_cast<double>(veer) * wander_turn);
    }

    /// Where the air is going at `seconds`, in metres a second, flat: (x, z).
    void air_at(double seconds, float& x, float& z) const {
        float speed = 0.0f;
        float coming_from = 0.0f;
        at(seconds, speed, coming_from);
        // A compass angle h points along (sin h, 0, -cos h); the air goes the other way.
        x = -std::sin(coming_from) * speed;
        z = std::cos(coming_from) * speed;
    }

    /// A phase in [0, tau) for one of the four sines, from the seed. SplitMix64's finaliser:
    /// no table, no state, and the same answer on every compiler.
    double phase(std::uint32_t which) const {
        std::uint64_t z = (static_cast<std::uint64_t>(seed) << 8u) + which + 0x9E3779B97F4A7C15ull;
        z = (z ^ (z >> 30u)) * 0xBF58476D1CE4E5B9ull;
        z = (z ^ (z >> 27u)) * 0x94D049BB133111EBull;
        z = z ^ (z >> 31u);
        return static_cast<double>(z >> 11u) / 9007199254740992.0 * 6.283185307179586;
    }
};

}  // namespace cockpit
}  // namespace ashiato_gd

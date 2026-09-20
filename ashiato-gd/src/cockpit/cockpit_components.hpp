#pragma once
// The networked vocabulary for a game where every player is flying something.
//
// Self-contained on purpose: it shares no header with src/vr/ or src/driving/, so those
// can be changed or deleted without touching this. The quantiser helpers below are a
// deliberate second copy for that reason.
//
// ---------------------------------------------------------------------------------
// THE ONE DECISION EVERYTHING ELSE FOLLOWS FROM: A PILOT HAS NO WORLD POSE.
// ---------------------------------------------------------------------------------
//
// A pilot's head and hands are replicated as offsets inside their SEAT, and never as a
// position in the world. Nothing anywhere composes them into one for the wire.
//
// That is not a saving. It is the property that makes a cockpit feel solid at any speed:
//
//   - A hand held still has a CONSTANT seat-local pose whether the aircraft is parked or
//     doing 200 knots, so there is nothing left for the vehicle's motion to add jitter to.
//     The renderer draws hands as children of the vehicle, so a still hand is still.
//   - There is no second pose that could disagree with the vehicle's. A pilot cannot
//     drift out of their seat, arrive a frame late, or be published somewhere the
//     aircraft is not, because none of those states can be written down.
//   - The vehicle's pose is then the ONLY thing whose smoothness matters, which reduces
//     the whole problem to interpolating one transform per vehicle.
//
// Everything below is arranged to keep that true.

#include <atomic>
#include <array>
#include <cmath>
#include <cstdint>
#include <vector>

#include "ashiato/sync/sync.hpp"
#include "cockpit/ground_core.hpp"

namespace ashiato_gd::cockpit {

// ---- wire helpers ------------------------------------------------------------------

namespace wire {

using ashiato::sync::serialization::QuantizedFloatConfig;
using ashiato::sync::serialization::read_quantized_float;
using ashiato::sync::serialization::serialize_quantized_float;

// THE SIZE OF THE WORLD, and it is a hard edge rather than a soft one: a vehicle that
// leaves this box does not fly off into the distance, it is clamped on the wire and every
// other machine watches it stop at the boundary while its own pilot flies on.
//
// A 64 km box at 1 cm, from under the deepest ground to 41,700 m. Widened three times: 2 km to 8, 8 to 32, and for the
// terrain world -- 64 km, ranges to 3,000 m, and flying to the 20 km the user asked for -- to +-32,768 m, 23 bits an
// axis, and 41,900 m of height, 22 bits: one bit an axis and four for the height, six a position, against a wire that
// spends a hundred and fifty on each vehicle. Before it, `tests/far_out.gd` drew a remote craft 24 km out 7.4 km from
// the server's path and one at 2,500 m 573 m off, and rolled a client's own aeroplane 24 km out back on 360 ticks of 360.
//
// READ FROM THE GROUND'S OWN BOUNDS, never typed beside them (`ground_core.hpp`): the edge is the world's, and the floor
// is the deepest ground less room for a hull resting on it. The floor was a typed -100 m with the sea's floor at -150,
// and the rounds' and missiles' spend limits were the old +-16,000 m and -120 to 1,900 m typed beside the old range:
// every round that fell through the floor was recorded 20 m under it (crowd_sight, 4,051 clamps).
//
// PAST THE EDGE A POSITION IS STILL CLAMPED, and sync's `quantize_float` says nothing, so `put_position` counts every
// clamped coordinate and `CockpitWorld` reports them as an error that names the first one.
inline constexpr float kEdgeMetres = static_cast<float>(ashiato_gd::ground::kWorldEdgeMetres);
/// How far under the deepest ground the wire still carries a position, metres: a hull resting on the sea's floor. A
/// round or missile that goes under the floor is recorded where it crossed it, so nothing else needs the room.
inline constexpr float kUnderTheSeabedMetres = 50.0f;
/// The height the wire spans, metres: what 22 bits hold at 1 cm (4,194,303 steps), rounded down to 100 m.
inline constexpr float kHeightSpanMetres = 41900.0f;
inline constexpr float kFloorMetres =
    -static_cast<float>(ashiato_gd::ground::kSeabedMetres) - kUnderTheSeabedMetres;
inline constexpr QuantizedFloatConfig ground{-kEdgeMetres, kEdgeMetres, 0.01f};
inline constexpr QuantizedFloatConfig height{kFloorMetres, kFloorMetres + kHeightSpanMetres, 0.01f};

/// Whether a point is inside everything the wire carries: the world's edge on both axes, and its floor and ceiling.
inline bool inside_the_wire(float x, float y, float z) {
    return x >= ground.min && x <= ground.max && z >= ground.min && z <= ground.max && y >= height.min
        && y <= height.max;
}

/// EVERY POSITION COORDINATE THE WIRE HAS CLAMPED, in this process and for every world in it: counted where a position is
/// written, on whatever thread sync serialises on, and read by `CockpitWorld` after its server's tick.
inline std::atomic<std::uint64_t> clamped_positions{0};

/// One coordinate onto the wire, a clamp counted: a value outside its range, or not a number.
inline void put_coordinate(ashiato::BitBuffer& out, float value, QuantizedFloatConfig config) {
    if (!(value >= config.min && value <= config.max)) {
        clamped_positions.fetch_add(1, std::memory_order_relaxed);
    }
    serialize_quantized_float(out, value, config);
}

/// A POSITION ONTO THE WIRE: `ground`, `height`, `ground`, every clamp counted. Every position on the wire goes this way.
inline void put_position(ashiato::BitBuffer& out, float x, float y, float z) {
    put_coordinate(out, x, ground);
    put_coordinate(out, y, height);
    put_coordinate(out, z, ground);
}

/// A value as the wire would carry it -- quantised against its range and read back -- a clamp counted as `put_coordinate`
/// counts one. For the suites, which ask the wire about its own extremes.
inline float through_the_wire(float value, QuantizedFloatConfig config) {
    if (!(value >= config.min && value <= config.max)) {
        clamped_positions.fetch_add(1, std::memory_order_relaxed);
    }
    return ashiato::sync::serialization::dequantize_float(
        ashiato::sync::serialization::quantize_float(value, config), config);
}
// 400 m/s, which is past anything in this game with room to dive. It was 200 and that
// was fine until the aeroplane got four times the thrust: its level top speed is now 165,
// a dive would have gone straight through the old ceiling, and a velocity that does not
// fit is not an error anybody sees -- it is silently clamped, so every other machine
// watches the aircraft fly slower than its own pilot does. One more bit per axis.
inline constexpr QuantizedFloatConfig speed{-400.0f, 400.0f, 0.01f};
// A SHELL LEAVES THE BARREL AT FOUR TIMES THE WORLD'S SPEED LIMIT.
//
// `speed` above stops at 400 m/s, which is past anything in this game that flies; a 120 mm
// sabot round leaves at 1700. A muzzle velocity quantised against `speed` would be clamped
// on the way to the wire and every machine but the shooter's would watch the round crawl.
// Its own config, and coarse with it: a quarter of a metre a second is nothing to a shell,
// where a centimetre a second matters to an aeroplane holding station.
inline constexpr QuantizedFloatConfig muzzle{-1800.0f, 1800.0f, 0.25f};
// 20 rad/s is over three rotations a second. An airframe doing more than that has already
// broken up.
inline constexpr QuantizedFloatConfig spin{-20.0f, 20.0f, 0.005f};
/// A LAID GUN'S TWO ANGLES, radians, to two hundredths of a milliradian: twelve centimetres of fall of shot at six
/// kilometres. `GunnerState` carries a big gun's aim at this, and the simulation LAYS it at this too (`lay_gun`), so the
/// machine predicting it and the machine deciding it integrate the same numbers rather than two that differ by the
/// quantiser. NOT half a milliradian, which was the first figure: a turret trains 0.07 rad/s, which is 0.0006 rad a tick
/// at FULL stick, and a quarter stick rounded to no movement at all -- a gun that could not be laid slowly.
inline constexpr QuantizedFloatConfig aim{-3.2f, 3.2f, 0.00002f};
// Head and hands inside a seat. Arm's reach is about a metre; 1.5 m is generous, and 2 mm
// is finer than a controller reports.
inline constexpr QuantizedFloatConfig reach{-1.5f, 1.5f, 0.002f};
// A stick axis. 1/128 is far finer than anyone can hold a thumbstick.
inline constexpr QuantizedFloatConfig axis{-1.0f, 1.0f, 1.0f / 128.0f};
/// How far round the railway, in metres. A loop around this island is tens of kilometres
/// and a centimetre is far finer than anybody can see a train from.
inline constexpr QuantizedFloatConfig along_rail{0.0f, 80000.0f, 0.01f};
/// How long a missile has been flying, to a sixty-fourth of a second: finer than any exhaust
/// flicker and coarse enough to be twelve bits. A missile lives for tens of seconds; one that
/// outlives the ceiling is ended by the server before it gets there -- see `fly_missiles`.
inline constexpr QuantizedFloatConfig missile_age{0.0f, 64.0f, 1.0f / 64.0f};

/// Where a turret is pointing, in the vehicle's own frame. Coarser than a pose because
/// nobody's head is bolted to it: a fifth of a degree is far finer than anyone can aim.
inline constexpr QuantizedFloatConfig bearing{-3.15f, 3.15f, 0.003f};
inline constexpr QuantizedFloatConfig elevation{-0.7f, 1.3f, 0.003f};
// A trigger or a grip: one-sided.
inline constexpr QuantizedFloatConfig unit{0.0f, 1.0f, 1.0f / 64.0f};

// Smallest-three quaternion. The largest component is dropped and rebuilt from unit norm,
// which is what makes an orientation 32 bits instead of four floats. The remaining three
// are each within +/- 1/sqrt(2) -- that is forced, because the one dropped was the
// largest -- so the range is not a guess and clamping cannot silently lose a rotation.
/// A quaternion component, and the precision here is the ATTITUDE OF THE WHOLE WORLD.
///
/// It was 0.0014, which is about a twelfth of a degree of rotation -- and that sounds fine
/// until you notice what it is a floor UNDER: the rollback threshold. A client cannot
/// usefully be told "correct yourself if you are more than a fifth of a degree out" while
/// the number it is comparing against is itself a twelfth of a degree of noise, so the
/// threshold had to stay coarse, and a coarse threshold means corrections arrive large.
/// A large attitude correction rotates everything the pilot can see.
///
/// 0.0002 is about a hundredth of a degree, for nine more bits per vehicle per update.
/// That is what buys the tight rollback threshold below it.
inline constexpr QuantizedFloatConfig quat_part{-0.70710678f, 0.70710678f, 0.0002f};

struct Quat {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
    float w = 1.0f;
};

inline Quat normalized(Quat q) {
    const float len = std::sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w);
    // A zero quaternion is not a rotation, and decoding one produces NaN that then spreads
    // through every pose derived from it.
    if (!(len > 1e-6f)) {
        return Quat{0.0f, 0.0f, 0.0f, 1.0f};
    }
    return Quat{q.x / len, q.y / len, q.z / len, q.w / len};
}

inline void write_quat(ashiato::BitBuffer& out, const Quat& value) {
    const Quat q = normalized(value);
    const float c[4] = {q.x, q.y, q.z, q.w};
    int largest = 0;
    for (int i = 1; i < 4; ++i) {
        if (std::fabs(c[i]) > std::fabs(c[largest])) {
            largest = i;
        }
    }
    // q and -q are the same rotation, so flipping the whole thing to make the dropped
    // component positive removes its sign from the wire and lets the largest be rebuilt
    // as a plain positive square root.
    const float sign = c[largest] < 0.0f ? -1.0f : 1.0f;
    out.write_unsigned_bits(static_cast<std::uint32_t>(largest), 2);
    for (int i = 0; i < 4; ++i) {
        if (i != largest) {
            serialize_quantized_float(out, c[i] * sign, quat_part);
        }
    }
}

inline bool read_quat(ashiato::BitBuffer& in, Quat& out) {
    if (in.remaining_bits() < 2) {
        return false;
    }
    const int largest = static_cast<int>(in.read_unsigned_bits(2));
    float c[4] = {0.0f, 0.0f, 0.0f, 0.0f};
    float sum = 0.0f;
    for (int i = 0; i < 4; ++i) {
        if (i == largest) {
            continue;
        }
        if (!read_quantized_float(in, quat_part, c[i])) {
            return false;
        }
        sum += c[i] * c[i];
    }
    // fmax before the root: quantisation can push the sum a hair past 1, and sqrt of a
    // negative is a NaN that would be normalised into every pose downstream.
    c[largest] = std::sqrt(std::fmax(0.0f, 1.0f - sum));
    out = Quat{c[0], c[1], c[2], c[3]};
    return true;
}

inline float dot(const Quat& a, const Quat& b) {
    return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
}

/// Shortest-arc interpolation, falling back to a normalised lerp where the slerp formula
/// divides by a sine approaching zero.
inline Quat slerp(const Quat& from, Quat to, float alpha) {
    float cos_theta = dot(from, to);
    // Through the short way round, or a pose crossing the seam between q and -q spins the
    // long way in a single frame.
    if (cos_theta < 0.0f) {
        to = Quat{-to.x, -to.y, -to.z, -to.w};
        cos_theta = -cos_theta;
    }
    if (cos_theta > 0.9995f) {
        return normalized(Quat{from.x + (to.x - from.x) * alpha,
                               from.y + (to.y - from.y) * alpha,
                               from.z + (to.z - from.z) * alpha,
                               from.w + (to.w - from.w) * alpha});
    }
    const float theta = std::acos(std::fmin(1.0f, cos_theta));
    const float sin_theta = std::sin(theta);
    const float a = std::sin((1.0f - alpha) * theta) / sin_theta;
    const float b = std::sin(alpha * theta) / sin_theta;
    return normalized(Quat{from.x * a + to.x * b, from.y * a + to.y * b,
                           from.z * a + to.z * b, from.w * a + to.w * b});
}

inline Quat multiply(const Quat& a, const Quat& b) {
    return Quat{a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
                a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
                a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
                a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z};
}

inline Quat conjugate(const Quat& q) {
    return Quat{-q.x, -q.y, -q.z, q.w};
}

inline Quat identity() {
    return Quat{0.0f, 0.0f, 0.0f, 1.0f};
}

inline float lerp(float a, float b, float t) {
    return a + (b - a) * t;
}

/// The angle between two rotations, in radians. |dot| because q and -q are the same
/// rotation and a sign flip is not a disagreement.
inline float angle_between(const Quat& a, const Quat& b) {
    const float d = std::fabs(dot(normalized(a), normalized(b)));
    return 2.0f * std::acos(std::fmin(1.0f, d));
}

}  // namespace wire

// ---- constants shared with the wire --------------------------------------------------

// ---- SEATS: every width here is the one place it is said ------------------------------------
//
// Asked on 2026-09-18, "should a craft be able to have more than 4 seats?": "yes, no max." A seat was two bits on the
// wire, and every craft carried four occupant bytes and four seats' hands whether it had one seat or four
// (`kMaxSeats`). Now a seat is a sixteen-bit number, and what a craft keeps and sends is WHO IS ABOARD -- see `Seats`
// and `CrewControls` -- so a craft may be built with as many seats as the number can name, and a seat nobody is in
// costs nothing. `tests/many_seats.gd` holds that changing a width here does what it says.

/// HOW WIDE A SEAT NUMBER IS, in memory (`SeatId`) and in the wire's wide form. Sixteen bits.
inline constexpr unsigned kSeatBits = 16;
using SeatId = std::uint16_t;
static_assert(kSeatBits <= 16, "SeatId is a uint16_t; widen its type with this");
/// THE LARGEST NUMBER THE FIELD HOLDS, WHICH IS NO SEAT: "any free seat" on a JOIN (`kAnySeat`), "nobody's hands" on
/// the linkage (`kNobodyHandsOn`). Derived, never typed: both were 7, the top of a three-bit field, and `hands_on` was
/// once 255 on the server and 7 off the wire because the two were typed apart (lane/guns, 2026-09-15). Both travel as
/// ONE BIT on the wire (`write_seat_or_none`), which is two fewer than they did.
inline constexpr SeatId kNoSeat = static_cast<SeatId>((1u << kSeatBits) - 1u);
/// A SEAT NUMBER NO CRAFT HAS, one below the sentinel: what a JOIN too wide for the wire is sent as, so the server
/// refuses it out loud ("no_such_seat") rather than reading it as some other seat.
inline constexpr SeatId kUnnamedSeat = static_cast<SeatId>(kNoSeat - 1u);
/// HOW MANY SEATS A CRAFT MAY BE BUILT WITH: every number below `kUnnamedSeat`, so 65,534.
inline constexpr std::size_t kMostSeats = kUnnamedSeat;
/// THE SHORT FORM A LOW SEAT TRAVELS IN, as a low command channel does: one form bit and then `kShortSeatBits` or
/// `kSeatBits`. Every seat of every craft built before 2026-09-18 is below four, so a seat there costs one bit more
/// than the two-bit wire did, and a seat past it seventeen.
inline constexpr unsigned kShortSeatBits = 2;
inline constexpr std::uint32_t kFirstLongSeat = 1u << kShortSeatBits;
static_assert(kFirstLongSeat < kUnnamedSeat, "the wide form must name more than the short one");
/// WHAT A SEAT NUMBER COSTS ON THE WIRE, in bits.
constexpr unsigned seat_bits(std::uint32_t seat) {
    return 1u + (seat < kFirstLongSeat ? kShortSeatBits : kSeatBits);
}

/// HOW MANY PEOPLE ONE CRAFT HOLDS AT ONCE -- which is not how many SEATS it has. A craft of any number of seats is
/// boarded by the players in the session, and a session holds `Net.MAX_PLAYERS` of them, so no craft can ever have more
/// aboard than that. `Seats` and `CrewControls` keep one entry per person aboard, up to this, which is what lets a
/// 64-seat craft cost what its crew costs: the wire writes a count and then only the people. SIXTY-FOUR, the player cap
/// since 2026-09-18 ("let's make the max 64 for now, i want to see how things break down at higher loads"); it was
/// sixteen for a cap of eight. Net refuses to host more players than this (`Net.host_refusal`, `tests/many_seats.gd`).
/// It costs memory, not wire: a Seats is 4 bytes a person here, 258 on every craft, and a CrewControls 16 a person.
inline constexpr std::size_t kMostAboard = 64;
/// The bits a count of people aboard takes on the wire: enough for 0 to `kMostAboard`.
constexpr unsigned bits_to_count(std::size_t most) {
    unsigned bits = 0;
    while ((std::size_t{1} << bits) <= most) {
        ++bits;
    }
    return bits;
}
inline constexpr unsigned kAboardCountBits = bits_to_count(kMostAboard);
static_assert(kMostAboard < (std::size_t{1} << kAboardCountBits), "the count must fit its bits");

/// NOBODY'S HANDS ON THE CONTROLS: `CrewControls::hands_on` when no seat is moving anything. The sentinel; see above.
inline constexpr SeatId kNobodyHandsOn = kNoSeat;

/// A SEAT ON THE WIRE: the form bit, then the short or the wide number. Every seat field is written through these four,
/// so a width changed above is changed everywhere.
inline void write_seat(ashiato::BitBuffer& out, std::uint32_t seat) {
    const bool wide = seat >= kFirstLongSeat;
    out.write_unsigned_bits(wide ? 1u : 0u, 1);
    out.write_unsigned_bits(seat, wide ? kSeatBits : kShortSeatBits);
}

inline bool read_seat(ashiato::BitBuffer& in, SeatId& seat) {
    if (in.remaining_bits() < 1) {
        return false;
    }
    const unsigned bits = in.read_unsigned_bits(1) != 0 ? kSeatBits : kShortSeatBits;
    if (in.remaining_bits() < bits) {
        return false;
    }
    seat = static_cast<SeatId>(in.read_unsigned_bits(bits));
    // A WIDE FORM CARRYING A LOW SEAT is a packet no honest sender writes; refused, so one seat has one spelling, as a
    // command's channel does.
    return bits == kShortSeatBits || seat >= kFirstLongSeat;
}

/// A SEAT OR THE SENTINEL, which is one bit: "any free seat" and "nobody's hands" are the usual value of the fields
/// that carry them, so they cost less than a seat does.
inline void write_seat_or_none(ashiato::BitBuffer& out, SeatId seat) {
    out.write_unsigned_bits(seat == kNoSeat ? 1u : 0u, 1);
    if (seat != kNoSeat) {
        write_seat(out, seat);
    }
}

inline bool read_seat_or_none(ashiato::BitBuffer& in, SeatId& seat) {
    if (in.remaining_bits() < 1) {
        return false;
    }
    if (in.read_unsigned_bits(1) != 0) {
        seat = kNoSeat;
        return true;
    }
    return read_seat(in, seat);
}
/// sync's own "no client", repeated here because it is a WIRE value in Seats and has to
/// keep its width whatever sync does.
inline constexpr std::uint8_t kNoOccupant = 255;

// ---- A CRAFT KIND'S WIDTH: every number here is the one place it is said -------------------
//
// Asked for on 2026-09-18: "let's make it so we can have more kinds, i'd like to have lots of vehicle kinds", and
// "we could have many vehicles in the future, so let's make sure it's easy to expand the count". The kind was FIVE
// bits in two places -- `VehicleKind` down to every peer and `kind_wanted` up on every input frame -- with 31 typed as
// "no kind in particular" in three files, and 29 of the 31 kinds used. Each number below is changed here and nowhere
// else: the codec, `kNoKindWanted`, the server's bounds, `kind_limits()` and through it `Sim.NO_KIND` and every test.
// `tests/many_kinds.gd` holds that changing one does what it says.

/// HOW WIDE A KIND'S NUMBER IS: sixteen bits, 65,535 kinds and the sentinel. A kind is held as a `KindId` everywhere
/// it is kept -- the component, the input frame, the server's arguments -- so widening past sixteen is the type too.
inline constexpr unsigned kKindIdBits = 16;
using KindId = std::uint16_t;
static_assert(kKindIdBits <= 16, "a kind is a KindId (uint16_t); widen the type with this");
/// "NO KIND IN PARTICULAR", the next-craft button's request: the top of the width, derived from it and not typed.
/// It was 15 while the kind was four bits and 31 while it was five, and each time it was the next vehicle's number.
inline constexpr std::uint32_t kNoKind = (1u << kKindIdBits) - 1u;

/// THE SHORT FORM A LOW KIND TRAVELS IN, which is the five-bit field it always had: codes below `kShortKinds` ARE the
/// kind, `kKindCodeWide` says the full `kKindIdBits` follow, and `kKindCodeNone` is `kNoKind`. So every kind to 29 --
/// all of them in 2026-09 and the CB90 -- costs exactly what it did, the input frame did not grow by a bit, and a
/// kind from 30 up costs `kShortKindBits + kKindIdBits` only in a record that carries it. (Busbits chose a form bit
/// for channels; here the escape lives inside the field so today's frames stay the size they were.)
inline constexpr unsigned kShortKindBits = 5;
inline constexpr std::uint32_t kKindCodeNone = (1u << kShortKindBits) - 1u;
inline constexpr std::uint32_t kKindCodeWide = kKindCodeNone - 1u;
inline constexpr std::uint32_t kShortKinds = kKindCodeWide;
static_assert(kShortKinds < kNoKind, "the wide form must name more than the short one");

/// WHAT A KIND COSTS ON THE WIRE, in bits.
constexpr unsigned kind_wire_bits(std::uint32_t kind) {
    return kShortKindBits + (kind < kShortKinds || kind >= kNoKind ? 0u : kKindIdBits);
}

/// ONE KIND ONTO THE WIRE. A number past the width is written as `kNoKind` -- "none" is never somebody else's
/// craft -- which the server's own bounds never let reach here; it is the codec's floor, not a policy.
inline void write_kind(ashiato::BitBuffer& out, std::uint32_t kind) {
    if (kind >= kNoKind) {
        out.write_unsigned_bits(kKindCodeNone, kShortKindBits);
    } else if (kind < kShortKinds) {
        out.write_unsigned_bits(kind, kShortKindBits);
    } else {
        out.write_unsigned_bits(kKindCodeWide, kShortKindBits);
        out.write_unsigned_bits(kind, kKindIdBits);
    }
}

/// ONE KIND OFF THE WIRE, guarding its own length, since it knows it only after the first five bits. A wide form
/// carrying a number the short form has a spelling for is a packet no honest sender writes, and is refused, so one
/// kind has one spelling.
inline bool read_kind(ashiato::BitBuffer& in, KindId& out) {
    if (in.remaining_bits() < kShortKindBits) return false;
    const std::uint32_t code = in.read_unsigned_bits(kShortKindBits);
    if (code == kKindCodeNone) {
        out = static_cast<KindId>(kNoKind);
        return true;
    }
    if (code < kShortKinds) {
        out = static_cast<KindId>(code);
        return true;
    }
    if (in.remaining_bits() < kKindIdBits) return false;
    const std::uint32_t wide = in.read_unsigned_bits(kKindIdBits);
    out = static_cast<KindId>(wide);
    return wide >= kShortKinds && wide < kNoKind;
}

// ---- THE COMMAND BUS'S WIDTHS: every number here is the one place it is said ----------------
//
// Asked for on 2026-09-18: "There could easily be 255 or 512 devices in a single vehicle ... Let's make sure we can
// support a large amount > 256 and we can configure more if we get there." A DEVICE is not a channel -- any number
// of switches, keys and per-seat copies may work one channel (`DeviceSignalRouter`) -- but every INDEPENDENT value a
// crew shares is one, and there were 32 of them, five bits on the wire, seventeen used. Each width below is changed
// here and nowhere else: the serializers, `send_command`, the server's bounds, `bus_limits()` and through it every
// GDScript table and test read these. `tests/many_devices.gd` holds that changing one does what it says.

/// HOW WIDE A COMMAND'S CHANNEL MAY BE ON THE WIRE, and so how many channels a bus can name: `kCommandChannels`.
/// Sixteen bits, 65,536 channels. A mask used to turn channel 33 into channel 1, the flaps, with nothing to say so;
/// `send_command` refuses a channel past the top instead (busbits, 2026-09-18). Widening this past 16 changes the
/// type of `ControlInput::command_channel` too, which the assert below says.
inline constexpr unsigned kCommandChannelBits = 16;
inline constexpr std::uint32_t kCommandChannels = 1u << kCommandChannelBits;
static_assert(kCommandChannelBits <= 16, "command_channel is a uint16_t; widen its type with this");
/// THE SHORT FORM A LOW CHANNEL TRAVELS IN. A command's channel is written as one bit and then either
/// `kShortChannelBits` or `kCommandChannelBits`: every named channel -- throttle, gear, sweep, the seventeen the
/// simulation knows by name -- is below 32, so a craft working only those pays ONE bit more than the five-bit wire
/// did, and only on the frames carrying a command. The generic channels a craft is fitted with start here.
inline constexpr unsigned kShortChannelBits = 5;
inline constexpr std::uint32_t kFirstGenericChannel = 1u << kShortChannelBits;
static_assert(kFirstGenericChannel < kCommandChannels, "the wide form must name more than the short one");
/// WHAT A COMMAND'S CHANNEL COSTS ON THE WIRE, in bits: the form bit, then the short or the wide number.
constexpr unsigned command_channel_bits(std::uint32_t channel) {
    return 1u + (channel < kFirstGenericChannel ? kShortChannelBits : kCommandChannelBits);
}

/// HOW WIDE THE COMMAND SEQUENCE IS: how many commands may go unseen by the server before a wrap makes the newest
/// read as one it has already acted on. It was two bits until 2026-09-17 (four skipped read as no change and the RIO's
/// let-go sweep was lost), then eight, and is sixteen at the user's asking: 65,536 commands, thirty-six minutes of a
/// lever dragged at the thirty commands a second one client can send, with not one frame of it reaching the server. The server compares with `!=`, so only an
/// exact multiple of this is ever mistaken; `tests/command_burst.gd` holds 256 and goes red at eight bits.
inline constexpr unsigned kCommandSeqBits = 16;
static_assert(kCommandSeqBits <= 16, "command_seq is a uint16_t; widen its type with this");
inline constexpr std::uint32_t kCommandSeqMask = (1u << kCommandSeqBits) - 1u;

/// HOW WIDE ONE VALUE ON THE BUS IS: a command's value, and every value a generic channel holds on a `BusPage`.
/// Eight bits, 0 to 255 -- a switch is 1, a four-notch gate 3, a lever 255. WIDENING IT COSTS on every page record,
/// 32 of these at worst, and on every frame carrying a command; and past 8 the uint8_t fields that hold them widen too,
/// which is what the assert is for.
inline constexpr unsigned kGenericValueBits = 8;
static_assert(kGenericValueBits <= 8, "bus values are uint8_t; widen their type with this");
inline constexpr std::uint32_t kGenericValueMax = (1u << kGenericValueBits) - 1u;

/// HOW MANY GENERIC CHANNELS ONE `BusPage` HOLDS. A page is an entity sent whole when any of its values changes, so
/// this is the grain of the wire: 32 is the room controls' page too, and the page number takes what is left of the
/// channel's width.
inline constexpr unsigned kPageChannelBits = 5;
inline constexpr std::size_t kPageChannels = std::size_t{1} << kPageChannelBits;
inline constexpr unsigned kPageBits = kCommandChannelBits - kPageChannelBits;

/// "ANY FREE SEAT OF THEIRS", as `ControlInput::join_seat` says it: the first free one, from the front. The sentinel;
/// see `kNoSeat`. GDScript says it as -1 (`Sim.ANY_SEAT`).
inline constexpr SeatId kAnySeat = kNoSeat;

/// WHAT THE SERVER SAID TO A JOIN, on the asker's own cabin (`CabinOwner::answer`). Four bits. 0 is
/// "nothing said yet", which is what a cabin that has never been answered carries. Named for the
/// game in `CockpitWorld::join_why_name`, and those names are what the clipboard turns into words.
inline constexpr std::uint8_t kJoinNothingYet = 0;
inline constexpr std::uint8_t kJoinJoined = 1;
/// The seat asked for has somebody in it -- including somebody who asked for it on the same tick with
/// a lower client id.
inline constexpr std::uint8_t kJoinSeatTaken = 2;
/// Any free seat was asked for and there is none.
inline constexpr std::uint8_t kJoinFull = 3;
/// The player named is not flying anything, has left, or never was.
inline constexpr std::uint8_t kJoinGone = 4;
/// The asker is already in that seat, or asked for any seat of the craft it is already in.
inline constexpr std::uint8_t kJoinAlreadyThere = 5;
/// That craft has fewer seats than the one asked for.
inline constexpr std::uint8_t kJoinNoSuchSeat = 6;
/// That craft is one nobody may board (`Shape::pilotable`). The last value the three bits on the wire hold.
inline constexpr std::uint8_t kJoinNotBoardable = 7;
/// A CRAFT-page answer shares the cabin's four-bit answer field with JOIN. Only one menu
/// request may be pending, so these cannot be mistaken for a concurrent seat answer.
inline constexpr std::uint8_t kKindMoved = 8;
inline constexpr std::uint8_t kKindNoIssuePlace = 9;
/// Seat 0 is the one with the controls. A passenger's stick does nothing, which is also
/// why only the pilot's machine predicts the vehicle.
inline constexpr std::uint8_t kPilotSeat = 0;

// ---- what the pilot is asking for ----------------------------------------------------

/// Everything one player is doing this tick: four control axes and three tracked poses.
///
/// Sent client -> server by sync itself once designated with set_client_input_component,
/// which frame-stamps it, buffers it and REPLAYS IT DURING ROLLBACK. That last property is
/// why the tracked poses travel here rather than as their own message: a head pose comes
/// from outside the simulation and cannot be predicted, so it has to be replayed exactly
/// as a thumbstick is when the client rewinds.
///
/// Deliberately ABSENT from every archetype. Replicating input back to its owner makes the
/// server echo each client its own controls a round trip late, and the echo lands on the
/// predicted vehicle and overwrites the live stick it should be predicting with.
struct ControlInput {
    /// 0 to 1. Aircraft do not have negative thrust.
    float throttle = 0.0f;
    /// -1 nose down to +1 nose up.
    float pitch = 0.0f;
    /// -1 left wing down to +1 right wing down.
    float roll = 0.0f;
    /// -1 nose left to +1 nose right.
    float rudder = 0.0f;
    /// Airbrake, wheel brake, reverse thrust -- whatever the vehicle has. 0 to 1.
    float brake = 0.0f;
    /// HOW HARD THE TRIGGER IS PULLED, 0 to 1, and not whether it is.
    ///
    /// It was a BIT -- `kButtonFire`, set when a controller's trigger passed half travel --
    /// and a bit is the wrong shape for a trigger. The hardware reports an axis, every
    /// finger that has ever been on one expects the first half of the travel to mean
    /// something, and throwing that away turned the one analogue input a hand controller
    /// has into a switch.
    ///
    /// The bit is still sent beside it and still means "firing at all", because the server
    /// edge-detects THAT to count rounds -- an input frame is replayed during a rollback
    /// and a magazine per replay is the bug the bit exists to prevent. What the axis adds
    /// is how hard, which a gun with a rate of fire can spend.
    float trigger = 0.0f;

    // Tracked, in the SEAT's frame. Never a world pose; see the header.
    float head_x = 0.0f;
    float head_y = 0.0f;
    float head_z = 0.0f;
    wire::Quat head_rot{};
    float left_x = -0.25f;
    float left_y = -0.35f;
    float left_z = -0.30f;
    wire::Quat left_rot{};
    float right_x = 0.25f;
    float right_y = -0.35f;
    float right_z = -0.30f;
    wire::Quat right_rot{};

    /// How closed each hand is, for drawing fingers.
    float grip_left = 0.0f;
    float grip_right = 0.0f;

    /// WHICH KIND OF CRAFT to go and find, or `kNoKind` for "the next one, whatever it is".
    ///
    /// A `KindId`, written by `write_kind`: five bits for every kind to 29 and for `kNoKind`, twenty-one for one past
    /// them (lane/kinds, 2026-09-18). Beside the buttons rather than a command on the bus: the bus is the
    /// CRAFT's, gated on what the craft you are in is fitted with, and "take me to a
    /// helicopter" is not something the aeroplane you are leaving has an opinion about.
    /// Edge-detected on the server with the buttons, for the same reason they are.
    ///
    /// It was four bits and the sentinel was 15, which is fine while there are sixteen
    /// kinds and is the GUNSHIP the moment there are seventeen: `switch_kind` reads
    /// anything below `kKindCount` as a kind somebody named. Both halves widened together, and
    /// the sentinel is now the top of the width, derived rather than typed.
    KindId kind_wanted = static_cast<KindId>(kNoKind);

    /// Bit 0 seat change, bit 1 use, bit 2 menu, bit 3 next kind, bit 4 FIRE, bit 5 JOIN,
    /// bit 6 LOCK, bit 7 LAUNCH. Edge detection is the SERVER's job: an input frame is
    /// replayed during rollback, so a "just pressed" computed on the client fires again on
    /// every replay of the frame that pressed it.
    ///
    /// EIGHT BITS ON THE WIRE, the whole byte, and the count matters. It was four, which was
    /// every button there was until a trigger arrived -- and a fifth bit written into a
    /// four-bit field is not an error anybody sees. It is silently dropped on the way out,
    /// so the gun worked when a test fired it on the server and did nothing at all when a
    /// player pulled the trigger. It went to six for that, and to eight for a missile's lock
    /// and launch, and it went the same way the second time: `lock_and_launch_reach_the_server`
    /// in cockpit_loopback was run against the six-bit field first and read "sent 192, the
    /// server's simulation saw 0". Two more bits per input frame, client to server only.
    std::uint8_t buttons = 0;

    /// WHICH PLAYER TO JOIN, by client id, or 255 for nobody.
    ///
    /// Beside `kind_wanted` and for the same reason: the seat buttons BROWSE -- they walk
    /// the world in entity order, which is the right control for somebody looking for
    /// something to fly and no way at all to say "that one, where my friend is". Entity ids
    /// are per-world and cannot go on a wire; a client id is eight bits and already means
    /// the same thing on every machine.
    ///
    /// On the input frame rather than down a reliable side channel, which is the rule this
    /// whole component is built on: an input frame is the only thing here that survives a
    /// rollback correctly.
    std::uint8_t join_wanted = 255;

    /// WHICH OF THAT PLAYER'S SEATS, any a craft may have, or `kAnySeat` for the first free one.
    ///
    /// The CREW page lists every seat of every crewed craft and puts a JOIN on each free one, so a
    /// press names a seat as well as a person. A craft is named BY a person in it, because client ids
    /// mean the same thing on every machine and entity ids do not. A seat in the short or wide form, or one bit for
    /// any, client to server only (`write_seat_or_none`). The server checks it against the craft; a seat the craft
    /// does not have is refused ("no_such_seat"), not clamped.
    SeatId join_seat = kAnySeat;

    /// A MENU PRESS'S NUMBER: bumped by one for every JOIN or craft pressed on the clipboard, mod 8, and on EVERY frame.
    ///
    /// A button edge was how a menu press reached the server, and an edge is a single moment: the server applies the
    /// newest input frame due and skips older ones that arrive together, and repeats the last one while none arrives,
    /// so the frame that rose, or the frame that fell before a second press, could go unseen and the press with it --
    /// tests/crew_peers.gd's joiner pressed JOIN and was never answered. A number that stays on every frame is seen by
    /// whichever frame is applied next, however many were skipped or late. The server acts when it CHANGES, per client,
    /// as it does the command sequence, and `join_wanted`/`join_seat` or `kind_wanted` ride beside it until answered.
    /// Three bits, client to server only.
    std::uint8_t menu_request = 0;

    /// ONE COMMAND, riding on the input frame.
    ///
    /// This is how a seat reaches the command bus, and it goes here rather than down a
    /// reliable side channel for a reason worth stating: an input frame is the only thing
    /// in this game that already survives a rollback correctly. Sync keeps it, replays it,
    /// and the server already edge-detects the buttons on it. A separate reliable message
    /// would arrive on a frame nobody was resimulating and land in a different order on a
    /// replay.
    ///
    /// The sequence number is what makes it a command rather than a level: holding a
    /// switch does not send it a hundred and twenty times a second, and a replayed frame
    /// does not apply it twice.
    ///
    /// EIGHT BITS, NOT TWO (2026-09-17). The server takes only the newest input frame due and
    /// skips older ones that came late alongside it, so a joiner whose frames arrive in a burst
    /// has the middle of a dragged lever's commands skipped -- harmless, the newest frame carries
    /// the latest value -- unless the sequence has wrapped. At two bits, four commands skipped
    /// read as no change at all, and the value the hand let go at was lost for good: the RIO's
    /// sweep handle in `sweep_peers`, red once the puff clouds made both machines heavier.
    /// `tests/command_burst.gd` holds a client's packets through 1-5 and 8 commands; 4 and 8
    /// were red. It now takes 256 skipped commands, over a second of a lever being dragged with
    /// not one frame of it reaching the server.
    ///
    /// SIXTEEN BITS OF CHANNEL AND SIXTEEN OF SEQUENCE (busbits, 2026-09-18): see `kCommandChannelBits` and
    /// `kCommandSeqBits`. A low channel still travels in six bits, so the only cost to a craft that works none of the
    /// generic channels is one bit of channel and eight of sequence on the frames carrying a command.
    std::uint16_t command_channel = 0;
    std::uint8_t command_value = 0;
    std::uint16_t command_seq = 0;

    /// ONE WORLD-MOUNTED ROOM CONTROL.  This is deliberately a separate record from the
    /// craft bus: it names a room-local endpoint, and only lives on frames while a request
    /// is being repeated over the lossy input path.  The server sequence-gates it by
    /// client, exactly as it does a craft command, so rollback and duplicate packets do
    /// not reapply a switch.
    bool room_active = false;
    std::uint8_t room_id = 0;
    std::uint16_t room_endpoint = 0;
    std::uint8_t room_value = 0;
    std::uint16_t room_revision = 0;
    std::uint16_t room_seq = 0;
};

/// One fixed 32-value page of a world-control bank.  A page is an entity rather than a
/// field on every vehicle: sync sends a changed page once, and a late join receives its
/// ordinary replicated baseline.  The final page carries `count` live values and zeros
/// in the remainder; receivers validate that count before exposing it to GDScript.
struct RoomControlPage {
    std::uint8_t room_id = 0;
    std::uint8_t page = 0;
    std::uint8_t count = 0;
    std::uint16_t revision = 0;
    std::uint16_t generation = 0;
    std::array<std::uint8_t, 32> values{};
};

/// THIRTY-TWO OF A CRAFT'S GENERIC CHANNELS: the bus past the named ones (busbits, 2026-09-18).
///
/// A craft may be fitted with any number of channels from `kFirstGenericChannel` up to `kCommandChannels`, each a
/// value 0 to its range that a crew shares -- a fuel pump, a breaker, a page on the third display at the second
/// station. The simulation reads none of them. Their values live here, 32 to a page, and a page is an ENTITY for the
/// same reason a room's is: sync sends one when it changes, and a late joiner gets it as a baseline like anything else.
/// A PAGE EXISTS ONLY ONCE A VALUE ON IT IS NOT ZERO, so a craft with five hundred switches all off costs the wire
/// nothing, and a missing page reads as zeros.
///
/// TWO AUDIENCES, the same two the fixed bus has. `client == kNoOccupant` is a CRAFT page: sent to everybody, as
/// `CraftSystems` is, at the craft's own priority -- what somebody outside can see. Otherwise it is ONE CREW MEMBER'S
/// copy of a CREW page, sent to that client alone and retired with their cabin, as `CabinSystems` is: what only the
/// crew can see. The server's own copy of the crew's values is not a page at all (`CockpitWorld::crew_values_`).
struct BusPage {
    ashiato::sync::EntityReference vehicle{};
    std::uint8_t client = kNoOccupant;
    /// Which 32: channels `page * kPageChannels` to `page * kPageChannels + 31`.
    std::uint16_t page = 0;
    std::array<std::uint8_t, kPageChannels> values{};
};

// ---- what the world contains ---------------------------------------------------------

/// Where a vehicle is and how it is moving. The whole simulation result, and the only
/// thing in this game whose smoothness the renderer has to work at.
///
/// Full quaternion, not a heading: an aircraft that cannot bank is not an aircraft with
/// the roll left out, it is an object the wire format has made impossible.
struct VehicleState {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
    wire::Quat rot{};
    float vx = 0.0f;
    float vy = 0.0f;
    float vz = 0.0f;
    float wx = 0.0f;
    float wy = 0.0f;
    float wz = 0.0f;
};

/// THE COMMAND BUS, and it is TWO components rather than one because the split it makes
/// is the one that actually matters.
///
/// A crew shares more than a stick. Gear, flaps, a throttle lever, which weapon is
/// selected, which radio channel, what is on a display -- all of it has to reach everyone
/// aboard, and none of it belongs in ControlInput, which is one pilot's momentary demand
/// and is deliberately never replicated to anybody.
///
/// So both of these live on the VEHICLE and are replicated to all of it. What separates
/// them is whether the SIMULATION reads them:
///
///   Craft   -- gear, flaps, throttle. The physics reads these, so a client predicting
///              this vehicle must predict them too, and a disagreement is worth a
///              rollback like any other piece of state that moves the aeroplane.
///
///   Systems -- weapon selection, lights, the radio, a display page. Nothing outside the
///              cockpit can tell, so resimulating the world because one changed would be
///              paying a physics price for a switch.
///
/// That is the whole reason for two components: `should_roll_back` cannot be answered
/// differently for two halves of one.
///
/// WHAT THE CHANNELS MEAN IS PER KIND. A helicopter has no flaps and an aeroplane has no
/// collective, so the slots are named by a SCHEMA the game asks for -- see
/// CockpitWorld::craft_schema -- rather than by the wire, which only carries numbers.
struct CraftControls {
    /// The lever, 0 to 1, latched. Not the same thing as a pilot's trigger: it is where
    /// the lever IS, which is why a copilot can see it move.
    float throttle = 0.0f;
    /// 0 to 1. More lift, more drag, a lower stall. Kinds without flaps ignore it.
    float flaps = 0.0f;
    /// Nose trim, -1 to 1.
    float trim = 0.0f;
    /// WHERE THE NACELLES ARE POINTING on a tiltrotor: 0 straight ahead and flying like an
    /// aeroplane, 1 straight up and hovering like a helicopter. Anything else ignores it.
    ///
    /// Here rather than on the input frame because it is a CONFIGURATION, exactly like the
    /// flaps and the gear beside it: it stays where it is put, the physics reads it, and
    /// both pilots have to be able to see it. A tiltrotor whose nacelles were a momentary
    /// demand would fall out of the sky the instant a packet went missing.
    float tilt = 0.0f;
    /// Bit 0 gear down, bit 1 spoilers. Bits 2 up are per kind.
    std::uint8_t switches = 0;
};

/// A TRAIN IS A 1D PROBLEM WEARING A 3D COSTUME.
///
/// Straight out of `../previous_projects/august-15-train`, which put it better than I
/// would have: a train owns one scalar position along the railway and one scalar speed,
/// and everything else -- where it is, which way it is facing, how it leans -- is read back
/// off the track from those two numbers.
///
/// So this is what goes on the wire, and it is thirty-odd bits instead of a hundred and
/// sixty. The pose is not replicated at all: every peer builds the same railway from the
/// same data, so every peer can work out where the train is from how far along it has got.
struct RailCar {
    /// Metres along the track, wrapping at its length.
    float distance = 0.0f;
    /// Metres per second along it. Negative is backwards, which a train may do.
    float speed = 0.0f;
    std::uint8_t track = 0;
};

/// WHERE EVERY SEAT'S HANDS ARE, on the controls in front of them.
///
/// A crew of two flying one aeroplane needs to see each other's levers move, and neither
/// of them can: nobody receives anybody else's input, by design. So the server -- which
/// receives all of it -- publishes each seat's control POSITIONS here, and everyone aboard
/// reads them off the wire.
///
/// This is not the same thing as the input. The input is one client's demand, is never
/// replicated, and exists to be merged. This is the state of the physical controls in a
/// shared cockpit, and its whole purpose is to be looked at.
///
/// ONLY THE CREW RECEIVE IT, AND THEY RECEIVE IT AT ONCE. It lives on each crew member's
/// CABIN -- see CabinOwner -- and not on the vehicle, Step, on an entity every crew machine
/// holds in sync's Snap mode.
///
/// It was on the vehicle, withheld from outsiders by a component mask, Interpolate, and
/// rolled back on the pilot's machine: nothing in the simulation reads it (`drive_vehicle`
/// builds its own Linkage from ControlInput), but on a PREDICTED entity an authoritative
/// value only arrives on a rollback, so the copilot's hands reached the pilot as a
/// resimulation of the world. And the copilot, who does not predict, drew them through the
/// interpolation buffer: three frames after they landed over a one-tick link
/// (`addon/tests/crew_cabin`, 2c774b5). A cabin nobody predicts and everybody aboard snaps
/// has neither cost, and a mask that opens and closes on a live entity -- which needed a
/// sync patch and never took anything away from somebody who left -- is not needed at all.
///
/// ONE ENTRY PER PERSON ABOARD, NOT PER SEAT (lane/seats, 2026-09-18). It was three floats for each of four seats on
/// every crew member's cabin, 92 bits a record whoever was aboard; a 64-seat craft that way is 1.5 KB a record, sent to
/// every member each tick a hand moves. A seat with nobody in it has no hands, so it is not kept: `of(seat)` answers
/// nothing and a reader draws it at rest. Every field is written, never left to padding, because sync compares
/// components byte for byte.
struct SeatHands {
    SeatId seat = kNoSeat;
    std::uint16_t spare = 0;
    float throttle = 0.0f;
    float stick_x = 0.0f;
    float stick_y = 0.0f;
};

struct CrewControls {
    /// How many of `hands` are in use, in SEAT ORDER; the rest are `SeatHands{}`.
    std::uint8_t count = 0;
    std::uint8_t spare = 0;
    /// Which seat is actually moving anything, or `kNobodyHandsOn`. The pilot wins ties,
    /// because when two people are flying it is the pilot who is flying.
    SeatId hands_on = kNobodyHandsOn;
    /// Per person aboard: what THAT seat is asking for. Where its own hands are.
    SeatHands hands[kMostAboard]{};

    /// That seat's hands, or nullptr for a seat nobody is in.
    const SeatHands* of(std::uint32_t seat) const {
        for (std::size_t i = 0; i < count; ++i) {
            if (hands[i].seat == seat) {
                return &hands[i];
            }
        }
        return nullptr;
    }

    /// Put a seat's hands, in seat order. False, and nothing changed, when `kMostAboard` are already kept.
    bool set(SeatId seat, float throttle, float stick_x, float stick_y) {
        std::size_t at = 0;
        while (at < count && hands[at].seat < seat) {
            ++at;
        }
        if (at >= count || hands[at].seat != seat) {
            if (count >= kMostAboard) {
                return false;
            }
            for (std::size_t i = count; i > at; --i) {
                hands[i] = hands[i - 1];
            }
            ++count;
        }
        hands[at] = SeatHands{seat, 0, throttle, stick_x, stick_y};
        return true;
    }

    /// THE LINKAGE: where the controls actually ARE.
    ///
    /// Two yokes on one linkage have ONE position, not two. So this is the merged demand
    /// -- the same value the aeroplane is flown from -- and every control connected to the
    /// linkage shows it. That is what lets a copilot sit with their hands in their lap and
    /// watch the yoke in front of them move with the pilot's.
    ///
    /// It is deliberately the FLYING value rather than the pilot's alone. Showing one
    /// seat's input while the aeroplane obeys the average would mean the yokes lie about
    /// what the aircraft is doing, which is the one thing a control position is for.
    /// With one pair of hands on it -- the usual case -- the two are identical anyway.
    float linked_throttle = 0.0f;
    float linked_x = 0.0f;
    float linked_y = 0.0f;
    /// Rudder, which on this stick comes from TWISTING it. It is on the linkage with the
    /// other axes and not folded into `linked_x`, because it is a third thing the aeroplane
    /// does and the only instrument showing it reads this.
    float linked_rudder = 0.0f;
};

/// The half the SIMULATION never reads. Never rolls back; see CraftControls.
///
/// The turret lives here, and it took a bug to work out why. It was in VehicleState, which
/// is PREDICTED -- and a client flying the aeroplane predicts that state from the pilot's
/// stick, the only input it has. It does not have the gunner's. So the barrel sat still on
/// the pilot's machine and swung on everyone else's, and nothing corrected it, because
/// VehicleState deliberately does not rewind the world over a turret.
///
/// The rule underneath is the one this whole project runs on: PREDICT ONLY WHAT YOU HAVE
/// THE INPUT FOR. A turret aimed by somebody else is not that, so it is not predicted -- it
/// is received, like the route and the switches beside it.
/// How many independently aimed mounts a craft may carry.
///
/// THREE, because the gunship has three guns and three gunners, and each of them is
/// pointing at something different. It was two, which was one per gunner on a boat with a
/// gun at each end -- and the cost of the third is eleven bits on a Step component that is
/// only sent when a gunner moves, which is nothing.
constexpr std::size_t kMaxTurrets = 3;

struct CraftSystems {
    /// WHERE EACH MOUNT IS POINTING, in the vehicle's own frame.
    ///
    /// Two of them, and one per gunner rather than one per craft: a boat with a gun forward
    /// and a gun aft has two people looking at two different things, and a single shared
    /// mount would have them fighting over it every tick with nothing sensible to average.
    /// Turret stations take mounts in seat order.
    float turret_yaw[kMaxTurrets] = {0.0f, 0.0f, 0.0f};
    float turret_pitch[kMaxTurrets] = {0.0f, 0.0f, 0.0f};
    /// The latching switches somebody OUTSIDE the craft can see: `kOutsideFlags`, the lights. The
    /// selectors and the rest of the switches -- weapon, radio, display, mode, the master arm, the
    /// crew lamp -- are the crew's, and live on CabinSystems, which only the crew are sent.
    std::uint16_t flags = 0;
    /// HOW MUCH IS IN THE TANK, 0 empty and 255 full. Meaningless on anything without one.
    ///
    /// ONE BYTE, TWO MEANINGS, never both on one craft: THE GUN COUNT ON A JET, THE FUEL/WATER LOAD ON A TANKER. On a
    /// craft whose weapon-selector gun keeps a count (`Gun::rounds`: the F/A-18F, F-14D and F-16, lane/jetarms,
    /// 2026-09-18) it is the share of the drum left, rounded up so 0 is empty everywhere at once (`publish_drum`); on a
    /// tanker it is the water. `work_the_tanks` writes it only on a kind `has_a_tank`, and `publish_drum` only on a kind
    /// whose selector gun has `rounds`; tests/jet_arms.gd holds a tanker's load where it was while the jets fire.
    ///
    /// HERE AND NOT ON CraftControls, and the line between the two is what it weighs. This
    /// half of the bus is the one with no physics in it: six tonnes of water does not
    /// change how the aeroplane flies today -- see `drop_water` -- so the tank is a GAUGE,
    /// and a gauge belongs beside the switches and the selectors.
    ///
    /// Eight bits, which is finer than any gauge anybody reads and coarse enough that a
    /// twelve-second drop is 255 steps rather than a float nobody can see the end of.
    std::uint8_t load = 255;
    /// WHICH MISSILE RAILS STILL CARRY A MISSILE, a bit a rail, numbered as the loadout numbers
    /// them. A gauge beside the tank for the same reason the tank is here: the crew and anybody
    /// outside have to see a rail go empty, and nothing about it moves the aeroplane.
    std::uint8_t stores = 0;
    /// THE WING SWEEP, on a swing-wing aeroplane: where the crew's handles ask for (`sweep_command`, set by any seat
    /// through `Channel::Sweep`) and where the wings actually are (`sweep`, walked toward the command by the server at
    /// `kSweepDegreesPerSecond`). 0 is 20 degrees spread and 255 is 75 overswept. BOTH on the wire: the handles show
    /// the command and the wings show where they are, and a wing that snapped to the command would be a lie for the
    /// four and a half seconds it takes to get there. Zero on every craft without the channel, and never written.
    std::uint8_t sweep_command = 0;
    std::uint8_t sweep = 0;
    /// THE WEAPONS BAYS' DOORS, open or shut: bit 0 the starboard bay, bit 1 the port (the F-35B, lane/lightning). The
    /// SERVER opens a bay when a missile in it is launched and ejects the missile once the doors have had time to open,
    /// so the doors are open before the missile moves on every machine; each machine eases its drawn doors toward this
    /// bit. Outside and replicated, beside the rails it is the doors of: everybody in sight sees a bay open.
    std::uint8_t bays = 0;
};

/// WHERE THIS VEHICLE IS GOING, if anything is taking it anywhere.
///
/// A separate component from VehicleState, and the reason is entirely about the wire:
/// VehicleState changes every tick and is sent every tick, while a route changes once a
/// leg -- perhaps twice a minute. As a Step component it is sent when it CHANGES and costs
/// nothing in between, where the same three numbers folded into VehicleState would be
/// sixty-two more bits per vehicle per tick, for a value that had not moved.
///
/// Replicated rather than asked of the server, because entity ids are per-world: a client
/// cannot ask "where is the aeroplane I am sitting in going" without a mapping that does
/// not exist. This way the answer arrives with the aeroplane.
struct Route {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
    /// Nothing is taking this vehicle anywhere: it is being flown, or has no autopilot.
    bool active = false;
};

/// WHAT A SHIP'S SAILS ARE DOING, for every machine that draws one: the fore and main levers, how much sail is set, how
/// full each sail group is, and where the apparent wind comes from off the bow and how hard.
///
/// THE SERVER'S `sail_ship` REPORT, published after the job (`publish_rigging`), and nothing reads it back into the
/// physics. A machine that is only watching a ship does not know the wind -- it never simulates the ship -- so without
/// this it could not tell a full sail from a slack one or which way the flag should stream.
///
/// ON THE SHIP ARCHETYPE ONLY, so no craft without sails carries it or pays for its first send. And a STEP component
/// written only when a field moves by more than its step: a ship holding a course in a steady wind sends nothing.
struct Rigging {
    /// The levers, times 127.
    std::int8_t fore = 0;
    std::int8_t main = 0;
    /// How much sail is set, 0 to 255.
    std::uint8_t set = 0;
    /// How full each sail group is, 0 to 255: fore square, main square, jib, spanker.
    std::uint8_t fill[4] = {0, 0, 0, 0};
    /// The apparent wind's angle off the bow, a turn in 256, positive to starboard.
    std::uint8_t apparent = 0;
    /// And its speed, in whole metres a second, to 63.
    std::uint8_t breeze = 0;
};

/// WHAT A ROUND IN THE AIR IS: where it left, how fast, and -- once it is over -- where it
/// stopped and on what.
///
/// ---------------------------------------------------------------------------------
/// A SHOT IS A BIRTH RECORD, NOT A MOVING THING ON THE WIRE
/// ---------------------------------------------------------------------------------
///
/// This is `RigState` and `RailCar` for a third time. A trailer is one angle off the cab
/// and a train is one distance along a railway, both because a thing whose whole future is
/// determined by something else must not carry a second copy of itself that could disagree.
/// A shell's whole future is its muzzle state, so that is what is sent -- ONCE -- and every
/// machine draws the same flight from it.
///
/// The alternative costs what it sounds like. A 120 mm round is in the air for about two
/// seconds, which at 120 Hz is 240 ticks; as a replicated pose that is three kilobytes a
/// shell, and a 25 mm cannon at 1800 rounds a minute would have ninety of them up at once.
/// As a birth record it is one packet at the muzzle and one at the impact.
///
/// So it is a STEP component: nothing at all is sent between those two moments.
///
/// THE SERVER IS THE ONLY MACHINE THAT INTEGRATES IT. There is nothing here for a client to
/// predict -- a shell does not answer anybody's stick -- so the flight is worked out once,
/// where the ray cast can be trusted, and the clients draw it. `surface` is what says which
/// of the two states this record is in.
struct ShotState {
    /// The muzzle: where the round started and how fast it left.
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
    float vx = 0.0f;
    float vy = 0.0f;
    float vz = 0.0f;
    /// Which round this is. The renderer reads it for the tracer and the explosion, and
    /// the simulation reads it for the drag.
    std::uint8_t ammo = 0;
    /// STILL IN THE AIR while this is kSurfaceFlying, and what it hit once it is not. The
    /// one field that says which half of this component's life it is in.
    std::uint8_t surface = 0;
    /// Where it stopped. Meaningless while it is flying, and not sent as a separate
    /// component because a Step component that changes is sent whole anyway.
    float ix = 0.0f;
    float iy = 0.0f;
    float iz = 0.0f;
    /// WHO FIRED IT: the client whose trigger it was, or `kNoOccupant` for a round nobody's
    /// finger fired (a test, the AI, `fire_gun`). And WHICH OF THAT CRAFT'S MOUNTS.
    ///
    /// What they buy is the gunner's hand feeling every round their own gun fires. Without
    /// them a round's birth record named nothing, so a machine could not tell its own cannon
    /// from a gunship four kilometres away, and the kick came once per PULL -- which on a
    /// door gun firing eleven a second is exactly a gun that feels like it fired once. Ten
    /// bits a round, sent once, with the birth record they describe.
    std::uint8_t shooter = kNoOccupant;
    std::uint8_t mount = 0;
    /// WHICH OF ITS GUNNER'S SHELLS THIS IS, for a gun whose fire is predicted (`Gun::predicted`): the number the gunner's
    /// `GunnerState::shells` counted to when it fired, and the number the predicted `ShellCue` carried. It is what the
    /// renderer hands a drawn shell over to the server's by -- see `ShotYard` -- and 0 for every other round.
    std::uint8_t shell = 0;
};

/// What a round stopped on. The renderer picks an explosion from this and the ammunition
/// together: the same shell throws a dust ring off a field, a column off water and sparks
/// off armour.
inline constexpr std::uint8_t kSurfaceFlying = 0;
inline constexpr std::uint8_t kSurfaceGround = 1;
inline constexpr std::uint8_t kSurfaceWater = 2;
inline constexpr std::uint8_t kSurfaceArmour = 3;
/// Ran out of life without hitting anything -- fired at the sky, or past the edge of the
/// world. It still has to be retired, and it must not explode.
inline constexpr std::uint8_t kSurfaceSpent = 4;
/// A MISSILE BURST BESIDE ITS TARGET: the proximity fuse, in the air, on nothing. Three bits
/// hold eight surfaces, so this costs nothing on the wire; shells never use it.
inline constexpr std::uint8_t kSurfaceFused = 5;

/// SOMETHING THAT HAPPENED ON A CRAFT, AT A FRAME, ONCE.
///
/// The first CUE in this game, and the difference between a cue and everything else on the
/// wire is worth stating plainly: a replicated component is a FACT THAT PERSISTS -- where a
/// vehicle is, how full a tank is, whether a fire is out -- and a cue is a MOMENT. It is
/// stamped with the frame it happened on, it is delivered once, and a machine that was not
/// connected at that frame never hears about it.
///
/// That makes the choice between them a question about what has to survive: if the END
/// STATE matters, it belongs in a component, because a client that joins afterwards has to
/// see it. The tank doors are a bus bit and the tank level is a byte, for exactly that
/// reason -- somebody arriving mid-drop must see open doors and a half-empty tank. What a
/// component CANNOT say is "and it happened just now, at this moment", which is what an
/// effect, a sound or a one-shot animation is started from.
///
/// ONE CUE TYPE WITH AN EVENT NUMBER IN IT, rather than a type per event. Registering a cue
/// costs a traits specialisation, a serialiser and a line in `start`; a new EVENT costs a
/// constant. The next thing that wants a moment on the wire should not have to think about
/// any of the above.
struct CraftCue {
    /// Which moment this is -- see kCue* below.
    std::uint8_t what = 0;
    /// One byte of detail, whose meaning is the event's own. For a water release it is how
    /// full the tank was when the doors opened, which is how big the first gush is.
    std::uint8_t value = 0;
};

/// THE DOORS OPENED AND SIX TONNES STARTED LEAVING. The event, as opposed to the doors
/// being open, which is a bit on the bus and stays true for the next five seconds.
inline constexpr std::uint8_t kCueWaterRelease = 0;
/// A MISSILE LEFT A RAIL. On the launching vehicle; the value is the rail in the low four bits
/// and the missile row in the high four, which is what the smoke puff is started from.
inline constexpr std::uint8_t kCueMissileLaunch = 1;
/// A MISSILE ENDED. On the missile itself; the value is the surface it ended on -- see
/// MissileState::surface -- which is what picks the burst.
inline constexpr std::uint8_t kCueMissileEnd = 2;
/// A CRAFT WAS DESTROYED, this frame: the fireball and the pieces are started from it. On the craft; the value is the
/// `kHullCause*`. The wreck itself is a fact on `Hull`, so a machine that joins later draws the wreck without the bang.
inline constexpr std::uint8_t kCueDestroyed = 3;

/// A CUE THAT HAS BEEN PLAYED, waiting for the renderer to be told about it.
///
/// LOCAL, and never replicated: this is the far end of the wire rather than something on
/// it. The cue runtime calls `SyncCueTraits<CraftCue>::play` on whichever machine is
/// drawing, and that has a registry and an entity and nothing else -- no pointer to the
/// game, no way to reach a renderer. So it writes here, and the game drains it once a tick.
///
/// A SINGLETON, because the alternative is a component on every craft that has ever done
/// anything, and because the renderer wants the list rather than a search.
struct PlayedCue {
    std::uint64_t entity = 0;
    std::uint8_t what = 0;
    std::uint8_t value = 0;
    /// How late this machine is playing it, in seconds -- the difference between the frame
    /// it happened on and the frame this machine is drawing. An effect that lasts a second
    /// and arrives a quarter of a second late should start a quarter of the way in.
    float late = 0.0f;
    /// The frame it happened on. Every peer gets the same number, which is what makes an
    /// animation started from a cue run in step on all of them.
    std::uint32_t frame = 0;
};

struct CueLog {
    std::vector<PlayedCue> played;
};

/// A FIRE ON THE GROUND: where it is and how hard it is burning.
///
/// REPLICATED, WHERE THE SCENERY IS NOT, and the difference is the whole reason this is a
/// component at all. A mountain is built identically on every peer from the same generator
/// and never mentioned again -- see the note at the top of Terrain -- because it never
/// changes. A fire changes: it grows, it is put out, and whether it is out is the one fact
/// the whole exercise turns on. Two peers with different ideas about that are two peers
/// playing different games.
///
/// A Step component, and a cheap one: a fire that nobody is dropping on changes by a
/// fraction of a per cent a second, which crosses the quantiser about once a second.
struct FireState {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
    /// 0 out, 1 burning as hard as it does. Everything anybody can see about a fire is
    /// derived from this: how wide it is, how high the flames stand, how much smoke.
    float strength = 1.0f;
};

/// WHAT ONE SEAT'S SEEKER IS DOING: which missile it is working for, whether it has hold of
/// anything, what, and whether a launch would be accepted.
///
/// ITS OWN ENTITY, AND NOT A COMPONENT ON THE VEHICLE, and the reason is the trap written up on
/// CraftSystems: the vehicle is PREDICTED on its pilot's machine, and on a predicted entity an
/// authoritative value only ever arrives on a rollback. A lock changes whenever its progress
/// ticks up, so on the vehicle it would roll the pilot's whole world back every tick of a lock.
/// Nobody predicts this entity -- it carries neither a PilotOwner nor Seats -- so it is simply
/// received.
///
/// WHOSE IT IS IS A CLIENT ID, the one number that means the same thing on every machine. The
/// vehicle and the seat are found through that vehicle's Seats, exactly as a pilot's are.
///
/// THE TARGET IS AN ENTITY REFERENCE, which sync maps to the receiving machine's own entity id.
/// Bearing and range are NOT sent: each machine works them out from where the target is
/// DRAWN, so the diamond on the sight sits on the aircraft the pilot can see rather than on a
/// bearing a round trip old -- and there is no second copy of where the target is.
struct SeekerState {
    std::uint8_t client = kNoOccupant;
    /// Which row of the missile table, four bits.
    std::uint8_t type = 0;
    /// kSeeker*, three bits.
    std::uint8_t phase = 0;
    /// kWhy*, three bits. Zero -- kWhyReady -- is the only value a launch is accepted on.
    std::uint8_t why = 0;
    /// 0 to 1 of the row's lock time.
    float progress = 0.0f;
    ashiato::sync::EntityReference target{};
};

inline constexpr std::uint8_t kSeekerNone = 0;
inline constexpr std::uint8_t kSeekerSearching = 1;
inline constexpr std::uint8_t kSeekerLocking = 2;
inline constexpr std::uint8_t kSeekerLocked = 3;
inline constexpr std::uint8_t kSeekerLost = 4;

inline constexpr std::uint8_t kWhyReady = 0;
inline constexpr std::uint8_t kWhyNotALaunchSeat = 1;
inline constexpr std::uint8_t kWhyNoMissile = 2;
inline constexpr std::uint8_t kWhyNotArmed = 3;
inline constexpr std::uint8_t kWhyNoLock = 4;
inline constexpr std::uint8_t kWhyEmpty = 5;
inline constexpr std::uint8_t kWhyReloading = 6;

/// A GUIDED MISSILE IN THE AIR: where it is, how it is moving, how long it has flown, and --
/// once it is over -- what it ended on.
///
/// NOT A BIRTH RECORD, and that is the difference from ShotState that everything else follows.
/// A shell's whole future is its muzzle state, so it is sent twice and drawn from. A guided
/// missile's future depends on its target, and the target moves on somebody else's stick, so
/// no machine but the server can work out where the missile goes. Its pose is sent every tick
/// it flies, Interpolate, like a vehicle's.
///
/// Like a shell in every other way: ONLY THE SERVER FLIES IT, outside every job, and nobody
/// predicts it. What a client needs beyond the pose is carried or derived, never duplicated --
/// the motor and how much burn is left come from `age` and the missile's row, and which way it
/// points is where it is going.
struct MissileState {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
    float vx = 0.0f;
    float vy = 0.0f;
    float vz = 0.0f;
    /// Seconds since it left the rail.
    float age = 0.0f;
    /// Which row of the missile table, four bits.
    std::uint8_t type = 0;
    /// Which rail it left, three bits. On the cue as well, but a cue can be missed and a
    /// component cannot: a machine that joins mid-flight still starts the contrail at the rail.
    std::uint8_t pylon = 0;
    /// kSurface*, three bits: kSurfaceFlying while it flies, and what it ended on after.
    std::uint8_t surface = 0;
    /// Who launched it, by client id, kNoOccupant for a launch that was not a player's.
    std::uint8_t client = kNoOccupant;
    /// Whether its seeker has hold of something this tick.
    bool guided = false;
    /// EJECTED FROM A BAY rather than fired off a rail: it falls clear of its aeroplane unlit, and its motor lights
    /// `kEjectIgniteSeconds` after it leaves (the F-35B's AMRAAMs, lane/lightning). One bit, so every machine lights the
    /// plume on the same tick from the replicated age, as it always has.
    bool ejected = false;
    /// WHAT IT ENDED ON, once it has: the vehicle it burst beside or flew into, and nothing for
    /// the ground, the sea or the sky. An entity reference, mapped by sync to each receiving
    /// machine's own id, for the reason SeekerState's target is one.
    ashiato::sync::EntityReference hit{};
};

/// HOW MUCH OF A CRAFT IS LEFT, AND WHAT HAPPENED TO IT (lane/combat, 2026-09-18).
///
/// Asked for on 2026-09-18: "I'd like there to be "hit points" on craft ... their guns can damage the plane (causing
/// smoke to trail behind it), Finally after taking enough damage, it should explode into pieces ... planes that hit the
/// ground or water (that are not planeboats) should explode too".
///
/// THE SERVER WRITES IT AND NOBODY ELSE EVER DOES. Damage comes from rounds and missiles, which only the server flies,
/// and from impacts, which only the server judges (`judge_impacts`), so no client has the input that moves it and no
/// client predicts it. On the VEHICLE, Step, sent when it changes -- a craft nobody is shooting sends nothing.
///
/// AND IT ROLLS BACK ON ANY CHANGE, which is CraftSystems' lesson: on a predicted craft -- the pilot's own -- an
/// authoritative value only arrives on a rollback, so a pilot whose own aeroplane was hit would never see it smoke.
/// Hits are a few a second at the most, and a resimulation costs 0.06 ms a tick over ten. A KILL CANNOT FLAP: no client
/// writes this, and `destroyed` is never cleared, so the only value a rollback can restore is the server's.
///
/// NOT ON VehicleState, where WHAT IS NOT HERE YET once proposed a byte of health: that is predicted and sent every
/// tick, and this changes a few times in a craft's life.
struct Hull {
    /// What is left, 255 whole and 0 nothing, as a share of the kind's hit points (`hull_of`). The server holds the
    /// points to better than a byte between hits; see `hull_points_`.
    std::uint8_t left = 255;
    /// Destroyed: frozen where it died, drawn as wreckage, never flown again. Never cleared.
    bool destroyed = false;
    /// kHullCause*, three bits: what did the last damage, and so what killed it.
    std::uint8_t cause = 0;
    /// Which round (kAmmo*) or which missile row, four bits, for a gun or a missile; 0 otherwise.
    std::uint8_t weapon = 0;
    /// The client whose finger it was, or kNoOccupant for the AI, a test, or the ground.
    std::uint8_t by = kNoOccupant;
    /// What kind of craft it came from, or kNoKind: "shot down by an Apache" names a gun nobody's finger fired.
    KindId by_kind = static_cast<KindId>(kNoKind);
    /// How fast it was going when it hit something, metres a second, for "hit the water at 140 knots". 0 for a shot.
    std::uint8_t speed = 0;
};

inline constexpr std::uint8_t kHullCauseNone = 0;
inline constexpr std::uint8_t kHullCauseGun = 1;
inline constexpr std::uint8_t kHullCauseMissile = 2;
inline constexpr std::uint8_t kHullCauseGround = 3;
inline constexpr std::uint8_t kHullCauseWater = 4;
inline constexpr std::uint8_t kHullCauseCollision = 5;
inline constexpr std::uint8_t kHullCauseCount = 6;

/// Which vehicle this is, and therefore which handling and which shape every machine must
/// simulate it with. Replicated because the archetype is sync's business and the game
/// layer never sees it.
struct VehicleKind {
    /// A `KindId`, on the wire by `write_kind`: see `kKindIdBits`.
    KindId kind = 0;
};

/// Who is aboard, by seat.
///
/// THE SEAT MAP LIVES ON THE VEHICLE, not as a vehicle reference on the pilot. One client
/// id per seat makes a double occupancy UNREPRESENTABLE: writing a second player into
/// seat 0 removes the first, in one field, on the authoritative machine, in one place. It
/// also avoids entity references on the wire entirely.
///
/// ONE ENTRY PER PERSON ABOARD, IN SEAT ORDER, and not one byte per seat (lane/seats, 2026-09-18). It was four occupant
/// bytes, which a craft of sixty-four seats cannot be, and which every unmanned craft in the sky sent anyway. The rule
/// above survives the change: `put` is the only writer and it REPLACES whoever is in the seat, so two people in one seat
/// still cannot be written; on the wire each seat is written as its distance past the one before, so they cannot be
/// sent either, and `deserialize` refuses a list that names a client twice. Every field is written, never left to
/// padding, because sync compares components byte for byte.
struct Aboard {
    SeatId seat = kNoSeat;
    std::uint8_t client = kNoOccupant;
    std::uint8_t spare = 0;
};

struct Seats {
    /// How many of `aboard` are in use; the rest are `Aboard{}`.
    std::uint8_t count = 0;
    std::uint8_t spare = 0;
    Aboard aboard[kMostAboard]{};

    /// Who is in that seat, or kNoOccupant.
    std::uint8_t occupant(std::uint32_t seat) const {
        for (std::size_t i = 0; i < count; ++i) {
            if (aboard[i].seat == seat) {
                return aboard[i].client;
            }
        }
        return kNoOccupant;
    }

    bool empty() const {
        return count == 0;
    }

    /// PUT `client` IN `seat`, replacing whoever was in it; kNoOccupant empties it. False, and nothing changed, only when
    /// the seat is empty and `kMostAboard` are already aboard -- which the session's player cap keeps from happening.
    bool put(SeatId seat, std::uint8_t client) {
        std::size_t at = 0;
        while (at < count && aboard[at].seat < seat) {
            ++at;
        }
        const bool there = at < count && aboard[at].seat == seat;
        if (client == kNoOccupant) {
            if (there) {
                for (std::size_t i = at; i + 1 < count; ++i) {
                    aboard[i] = aboard[i + 1];
                }
                --count;
                aboard[count] = Aboard{};
            }
            return true;
        }
        if (there) {
            aboard[at].client = client;
            return true;
        }
        if (count >= kMostAboard) {
            return false;
        }
        for (std::size_t i = count; i > at; --i) {
            aboard[i] = aboard[i - 1];
        }
        aboard[at] = Aboard{seat, client, 0};
        ++count;
        return true;
    }
};

/// A player, as everybody else sees them: three poses inside a seat and nothing else.
///
/// There is no position field here and there is not going to be one. Where this pilot is
/// in the world is a question about their VEHICLE, and it is answered by looking at the
/// vehicle.
struct PilotState {
    float head_x = 0.0f;
    float head_y = 0.0f;
    float head_z = 0.0f;
    wire::Quat head_rot{};
    float left_x = -0.25f;
    float left_y = -0.35f;
    float left_z = -0.30f;
    wire::Quat left_rot{};
    float right_x = 0.25f;
    float right_y = -0.35f;
    float right_z = -0.30f;
    wire::Quat right_rot{};
    float grip_left = 0.0f;
    float grip_right = 0.0f;
    /// Which seat of whichever vehicle holds this pilot's client id. Carried so the
    /// renderer does not have to scan for it every frame; the vehicle's Seats is still the
    /// authority, and disagreement means the pilot is mid-transfer. `write_seat` on the wire.
    SeatId seat = kPilotSeat;
};

/// Whose pilot this is, in OUR vocabulary.
///
/// sync::NetworkOwner records the same fact but has no SyncComponentTraits and therefore
/// no wire format; putting it in an archetype crashes on the first serialize. The client
/// still has to know which pilot is its own in order to predict it.
/// A GUNNER AT A GUN WHOSE FIRE IS PREDICTED: where they have laid it, how many shells they have fired, and when it is
/// loaded again. ON THE PILOT ENTITY, which is the one thing a turret gunner's machine predicts -- the ship is somebody
/// else's -- so ashiato rolls this back and replays it with the gunner's own input like any predicted state. Sent to
/// its owner only: nobody else draws from it (the mount everybody sees is `CraftSystems`, which the server copies from
/// here), and a gunner's reload is nobody else's business.
///
/// Plan item 22: "projectiles must be synced and predicted by ashiato." The shell count is what makes a resimulation
/// unable to fire twice or lose one: a replayed frame finds the count where the rollback put it and fires the SAME
/// numbered shell again, which the cue runtime recognises as already played.
///
/// WHAT IT COSTS ON THE WIRE, on EVERY pilot, measured off the server's own trace (2026-09-16, a client over a 4-tick
/// link, the same probe against the library before this component and after it). A pilot FLYING a plane: 33.44 bytes a
/// tick of everything that client was sent, before and after -- nothing a tick, because a Step component that does not
/// change is not sent. What it does cost a non-gunner is its first record: ten records of about ten bytes in the second
/// after spawning, while the record is unacknowledged, and then nothing. A gunner LAYING a turret: 49.88 bytes a tick
/// against 40.47, the difference being this component (9.45) re-sent as the aim moves; at rest, 26.81 against 26.17.
/// So it stays on every pilot rather than being added on boarding a predicted seat and removed on leaving: a
/// non-gunner pays no bytes a tick, and `tests/shell_prediction.gd` holds that.
struct GunnerState {
    /// Which mount of the craft this gunner has laid, or `kNoMount` when they are not at a predicted gun.
    std::uint8_t mount = 7;
    std::uint8_t shells = 0;
    /// The frame from which the gun may fire again. A FRAME, not a time: a rolled-back reload is exactly the frame the
    /// replay reaches, and a clock in seconds would be one more thing that is not rolled back (`gun_ready_` is not).
    std::uint32_t loaded_frame = 0;
    float aim_yaw = 0.0f;
    float aim_pitch = 0.0f;
};

/// Nobody's mount, in GunnerState's three bits.
inline constexpr std::uint8_t kNoMount = 7;

/// A PREDICTED SHELL LEFT A GUN: the moment, as a cue on the gunner's pilot entity, with where it left and how fast so the
/// gunner's own machine draws it that tick. Two cues are the same shell when their mount and shell number agree -- the
/// muzzle a client worked out and the one the server did are allowed to differ, by the distance a ship moves while a
/// packet crosses, and that is the handover's to blend (see `ShotYard`).
struct ShellCue {
    std::uint8_t mount = 0;
    std::uint8_t shell = 0;
    /// Which round, so the machine drawing it before the server's record arrives draws the right tracer and flies it
    /// with the right drag. Four bits, as `ShotState::ammo`.
    std::uint8_t ammo = 0;
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
    float vx = 0.0f;
    float vy = 0.0f;
    float vz = 0.0f;
};

/// ONE SHELL CUE THIS MACHINE PLAYED -- or took back, `withdrawn` -- waiting for the renderer. See `CueLog`, whose reasons
/// it shares: a static trait has a registry and nothing else.
struct PlayedShell {
    std::uint64_t entity = 0;
    ShellCue cue{};
    float late = 0.0f;
    std::uint32_t frame = 0;
    bool withdrawn = false;
};

struct ShellLog {
    std::vector<PlayedShell> played;
};

struct PilotOwner {
    std::uint32_t client = 0;
    /// THE GODOT PEER THAT CLIENT CAME IN ON, or 0 while the server has not been told. Only the server
    /// knows the pair -- sync hands out client ids and tells the server which peer each arrived on -- so
    /// it is written here and every machine reads the whole map off the pilots it already receives. It
    /// was a reliable Godot RPC each machine sent once as it arrived, so a later joiner never heard the
    /// host's (cockpit-steam, 2026-09-14). See CockpitWorld::client_of_peer.
    std::uint32_t peer = 0;
};

/// WHICH OF A CRAFT'S LATCHING SWITCHES SOMEBODY OUTSIDE IT CAN SEE: bit 0, the lights, and bits 2 and
/// 3 kept for the next outside switch, so it is a constant and not a format change; the four low bits
/// go on the wire. Everything else a switch latches is the crew's: bit 1 the master arm (and the
/// per-kind switch that has always shared it), bit 8 the crew lamp.
///
/// NOT 0x000F: that took bit 1 with it, and the master arm would have gone to every machine on the
/// craft's own record. The static_assert beside `kMasterArmBit` in cockpit_world.cpp stopped the first
/// build of this (2026-09-14).
// 0x0070 ADDED FOR THE FIREBOAT'S THREE MONITORS (bits 4, 5, 6): whether each is pumping. OUTSIDE, because a
// hundred tonnes of water an hour leaving a boat is the most visible thing about her -- every machine already
// has the aim, so one bit a monitor is the whole of what the wire carries about a stream (lane/fireboat).
inline constexpr std::uint16_t kOutsideFlags = 0x007Du;
inline constexpr std::uint16_t kCrewFlags = 0x0102u;

/// HOW MANY BITS A FLAG MASK NEEDS, so a serializer never has to be told twice.
///
/// THIS EXISTS BECAUSE OF A BUG THAT COST AN AFTERNOON AND COULD NOT BE SEEN (lane/fireboat, 2026-09-20).
/// `CraftSystems`' serializer wrote `flags & kOutsideFlags` in a hard-coded FOUR BITS, which was exactly right while
/// the mask was 0x000D. Widening the mask to carry three more outside switches compiled, asserted, replicated and
/// drew -- and the three new bits were silently dropped on the way to the wire, so the boat pumped on the server and
/// every client saw her monitors shut. Nothing was red. The picture was simply empty.
///
/// The mask and the width were two copies of one fact. Now there is one.
inline constexpr int bits_for_flags(std::uint16_t mask) {
    int bits = 0;
    while ((mask >> bits) != 0u) {
        ++bits;
    }
    return bits;
}
inline constexpr int kOutsideFlagBits = bits_for_flags(kOutsideFlags);
static_assert((kOutsideFlags >> kOutsideFlagBits) == 0u
                  && (kOutsideFlagBits == 0 || (kOutsideFlags >> (kOutsideFlagBits - 1)) != 0u),
              "the outside flags must fit their own width exactly");

/// ONE CREW MEMBER'S VIEW INTO ONE COCKPIT: whose it is, which craft, and which seat.
///
/// AN ENTITY PER CREW MEMBER, SENT TO THAT MEMBER AND NOBODY ELSE. Everything a crew shares that
/// nobody outside can perceive -- where each seat's levers are, which weapon, which radio channel,
/// the master arm -- rides on a Cabin entity the server makes for each occupant of each seat and
/// retires when they leave the craft. The prioritizer in CockpitWorld::start sends a cabin to its
/// `client` and returns zero for everybody else, and sync skips an entity whose priority is zero or less
/// (client_update_scheduler.cpp, send_client) before it is ever serialised or given a network id,
/// so an outsider is never told a cabin exists -- nor sent its removal.
///
/// Why one per member and not one per craft: a cabin's audience never changes while it lives. One
/// entity per craft would change audience every time somebody boarded or left, which is a mask or a
/// relevance opening and closing on a live entity -- sync only asks about an entity when it is
/// dirty, a closed one keeps its stale copy on the client, and the opening needed a patch.
///
/// SNAPPED, NOT INTERPOLATED OR PREDICTED: every client holds a Cabin in ReplicationClientMode::Snap
/// (the mode selector in CockpitWorld::start), which applies a record in the client's tick the moment
/// its packet is processed and erases a destroyed one at once (update_runtime.cpp, apply_snap_upsert
/// and apply_snap_destroy).
///
/// Every field here is written by the server alone; see `publish_cabins`.
struct CabinOwner {
    /// The one client this cabin is sent to.
    std::uint8_t client = kNoOccupant;
    /// Which seat of the craft they are in. `write_seat` on the wire: any seat a craft may have.
    SeatId seat = 0;
    /// HOW MANY TIMES THE SERVER HAS ANSWERED THIS MEMBER'S JOIN, mod 16 and never 0 once it has, and
    /// what it said last (`kJoin*`). Four bits each. On the cabin because the cabin is the one thing
    /// sent to that member and nobody else, and snapped: a refusal is nobody else's business, and a
    /// refused player should read it on the tick it lands. The server keeps the pair per CLIENT, not
    /// per cabin, so a player who joins takes the answer "joined" onto the new craft's cabin with them.
    std::uint8_t answer_count = 0;
    std::uint8_t answer = kJoinNothingYet;
    /// Which craft, mapped by sync to each receiving machine's own entity. Resolved again when it is
    /// read, because a cabin can land before the craft it names has been made on that machine.
    ashiato::sync::EntityReference vehicle{};
};

/// THE CREW'S HALF OF THE COMMAND BUS: the switches nobody outside a cockpit can see.
///
/// It was on CraftSystems, on the vehicle, which went to everybody: a radio channel changed in one
/// aeroplane was written onto the wire to every machine in the session (30 records to an outsider
/// in `crew_cabin`'s window on 2c774b5), and on the pilot's predicting machine a gunner's selector
/// arrived as a rollback of the world.
struct CabinSystems {
    /// Per-kind selectors: weapon, radio channel, display page, mode.
    std::uint8_t selector[4] = {0, 0, 0, 0};
    /// `kCrewFlags` only: the master arm and the crew lamp.
    std::uint16_t flags = 0;
};

/// THE SERVER'S ONE COPY OF A CRAFT'S CREW SWITCHES, on the vehicle, and never on the wire.
///
/// A plain registry component and NOT a sync component, on purpose: sync marks an entity's replicated
/// slot dirty for any sync-registered component that changes on it, archetype or not
/// (dirty_slots.hpp, each_dirty_replicated_slot), and a dirty entity costs a record. `apply_command`
/// writes this; `publish_cabins` copies it into every cabin aboard.
struct CrewSwitches {
    CabinSystems switches{};
};

}  // namespace ashiato_gd::cockpit

namespace ashiato {

/// ONE LOG PER WORLD, not one per craft -- see CueLog.
///
/// UP HERE, BEFORE ANYTHING READS IT. A singleton is `registry.write<T>()` with no entity,
/// and that overload only exists if this specialisation has already been seen: declared
/// after the cue traits below, it compiles as an ordinary per-entity component with no
/// entity to write to, which the compiler reports as a missing overload a hundred lines
/// from the actual mistake.
template <>
struct is_singleton_component<ashiato_gd::cockpit::CueLog> : std::true_type {};
/// And the predicted shells' log, for the same reason.
template <>
struct is_singleton_component<ashiato_gd::cockpit::ShellLog> : std::true_type {};

}  // namespace ashiato

namespace ashiato::sync {

// A namespace alias, not a member typedef: an alias is illegal inside a class body, and
// every trait below wants the same quantisers and maths.
namespace cw = ashiato_gd::cockpit::wire;

/// WHAT A CLIENT WILL DECODE, which is what the server has to compare.
///
/// sync decides whether a component changed by comparing QUANTIZED bytes against the client's baseline (server.cpp,
/// a memcmp per component), and a component that compares equal costs one bit instead of its payload. Every trait
/// here used to quantize with `out = value`, the raw floats, so a parked aeroplane whose body settles by a micrometre,
/// a turret clamped back to the angle it already had and a throttle one float away from itself all "changed" on
/// every tick and went out in full. In the flight level the 24 parked craft cost 555 of the 1,847 bytes a tick one
/// client was owed against a budget of 1,024 (`cockpit/tests/wire_budget`), and a joined machine drew every craft
/// holding and leaping because the rest waited seven to ten ticks for a slot.
///
/// Through the trait's own serialize and deserialize, so there is no second copy of any precision: widen a field on
/// the wire and this follows. The client receives exactly what it did before -- it always decoded these same bits.
/// Not for a trait that carries an entity reference, which needs sync's reference context to write at all.
///
/// AND ONLY WHEN IT WRITES THE SAME BITS AGAIN. Decoding and re-encoding is not always the identity: a smallest-three
/// quaternion drops its largest component and rebuilds it from the other three, and when two components tie -- an
/// aeroplane heading due east is (0, -0.7071, 0, 0.7071) -- the rebuilt one can come back a step smaller, so the
/// re-encode drops the OTHER one. Same rotation, different bits. `crowd_sight`, whose autopilots all fly one heading,
/// caught 52,511 of 291,600 components writing different bits that way before this guard. So the decoded value is
/// kept only if it re-encodes to exactly what the raw value encoded to, and otherwise the raw value is, which is what
/// went on the wire before: a client never receives a different bit.
template <typename T>
inline void quantize_through_the_wire(const T& value, T& out) {
    thread_local ashiato::BitBuffer written;
    thread_local ashiato::BitBuffer again;
    written.clear();
    again.clear();
    ashiato::ComponentSerializationContext context{};
    SyncComponentTraits<T>::serialize(nullptr, value, written, context);
    written.reset_read();
    // A field the wire does not carry keeps its value; deserialize overwrites the ones it does.
    out = value;
    if (!SyncComponentTraits<T>::deserialize(written, nullptr, out, context)) {
        out = value;
        return;
    }
    SyncComponentTraits<T>::serialize(nullptr, out, again, context);
    if (again.bit_size() != written.bit_size() || again.bytes() != written.bytes()) {
        out = value;
    }
}

// ---- ControlInput --------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::ControlInput> {
    using Quantized = ashiato_gd::cockpit::ControlInput;

    static void quantize(const ashiato_gd::cockpit::ControlInput& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::cockpit::ControlInput dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized* previous,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        if (previous != nullptr) {
            serialize_delta(*previous, current, out);
            return;
        }
        cw::serialize_quantized_float(out, current.throttle, cw::unit);
        cw::serialize_quantized_float(out, current.pitch, cw::axis);
        cw::serialize_quantized_float(out, current.roll, cw::axis);
        cw::serialize_quantized_float(out, current.rudder, cw::axis);
        cw::serialize_quantized_float(out, current.brake, cw::unit);
        cw::serialize_quantized_float(out, current.trigger, cw::unit);
        cw::serialize_quantized_float(out, current.head_x, cw::reach);
        cw::serialize_quantized_float(out, current.head_y, cw::reach);
        cw::serialize_quantized_float(out, current.head_z, cw::reach);
        cw::write_quat(out, current.head_rot);
        cw::serialize_quantized_float(out, current.left_x, cw::reach);
        cw::serialize_quantized_float(out, current.left_y, cw::reach);
        cw::serialize_quantized_float(out, current.left_z, cw::reach);
        cw::write_quat(out, current.left_rot);
        cw::serialize_quantized_float(out, current.right_x, cw::reach);
        cw::serialize_quantized_float(out, current.right_y, cw::reach);
        cw::serialize_quantized_float(out, current.right_z, cw::reach);
        cw::write_quat(out, current.right_rot);
        cw::serialize_quantized_float(out, current.grip_left, cw::unit);
        cw::serialize_quantized_float(out, current.grip_right, cw::unit);
        out.write_unsigned_bits(current.buttons, 8);
        ashiato_gd::cockpit::write_kind(out, current.kind_wanted);
        out.write_unsigned_bits(current.join_wanted, 8);
        ashiato_gd::cockpit::write_seat_or_none(out, current.join_seat);
        out.write_unsigned_bits(current.menu_request & 0x7u, 3);
        write_command(out, current);
        out.write_unsigned_bits(current.room_active ? 1u : 0u, 1);
        if (current.room_active) {
            out.write_unsigned_bits(current.room_id & 0x1u, 1);
            out.write_unsigned_bits(current.room_endpoint & 0x1FFu, 9);
            out.write_unsigned_bits(current.room_value, 8);
            out.write_unsigned_bits(current.room_revision, 16);
            out.write_unsigned_bits(current.room_seq, 16);
        }
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized* previous,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        if (previous != nullptr) {
            return deserialize_delta(in, *previous, out);
        }
        if (!cw::read_quantized_float(in, cw::unit, out.throttle)
            || !cw::read_quantized_float(in, cw::axis, out.pitch)
            || !cw::read_quantized_float(in, cw::axis, out.roll)
            || !cw::read_quantized_float(in, cw::axis, out.rudder)
            || !cw::read_quantized_float(in, cw::unit, out.brake)
            || !cw::read_quantized_float(in, cw::unit, out.trigger)
            || !cw::read_quantized_float(in, cw::reach, out.head_x)
            || !cw::read_quantized_float(in, cw::reach, out.head_y)
            || !cw::read_quantized_float(in, cw::reach, out.head_z)
            || !cw::read_quat(in, out.head_rot)
            || !cw::read_quantized_float(in, cw::reach, out.left_x)
            || !cw::read_quantized_float(in, cw::reach, out.left_y)
            || !cw::read_quantized_float(in, cw::reach, out.left_z)
            || !cw::read_quat(in, out.left_rot)
            || !cw::read_quantized_float(in, cw::reach, out.right_x)
            || !cw::read_quantized_float(in, cw::reach, out.right_y)
            || !cw::read_quantized_float(in, cw::reach, out.right_z)
            || !cw::read_quat(in, out.right_rot)
            || !cw::read_quantized_float(in, cw::unit, out.grip_left)
            || !cw::read_quantized_float(in, cw::unit, out.grip_right)) {
            return false;
        }
        // THIRTY-SIX, WHICH IS WHAT THE SIX READS BELOW ACTUALLY TAKE. It said 18 while
        // they took 23, which is a guard that lets a truncated packet through to be read
        // past the end of -- and the fix is to count them rather than to keep a number
        // beside them that has to be remembered. It is written as the same sum, in the
        // same order, so that widening a field is a change here beside the read and not a
        // total somewhere else: `kind_wanted` went from four bits to five with the
        // seventeenth vehicle, and `buttons` from six to eight with lock and launch.
        //
        // THE COMMAND IS COUNTED BY `read_command`, which knows its own length only after its first bit: a channel
        // is six bits or seventeen (busbits, 2026-09-18). So the guard here covers the five fields before it, and
        // the room flag after it is guarded where it is read.
        //
        // AND THE KIND BY `read_kind`, for the same reason: five bits or twenty-one (lane/kinds, 2026-09-18). The
        // guard counts its short form, and the wide one is guarded where it is read -- after which the three
        // fields behind it are counted again, since sixteen bits of this packet have gone.
        // AND THE JOIN SEAT BY `read_seat_or_none`: one bit, four or nineteen (lane/seats, 2026-09-18). The guards
        // count its shortest form, one bit, and the rest is guarded where it is read.
        if (in.remaining_bits() < 8 + ashiato_gd::cockpit::kShortKindBits + 8 + 1 + 3) {
            return false;
        }
        out.buttons = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        if (!ashiato_gd::cockpit::read_kind(in, out.kind_wanted) || in.remaining_bits() < 8 + 1 + 3) {
            return false;
        }
        out.join_wanted = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        if (!ashiato_gd::cockpit::read_seat_or_none(in, out.join_seat) || in.remaining_bits() < 3) {
            return false;
        }
        out.menu_request = static_cast<std::uint8_t>(in.read_unsigned_bits(3));
        if (!read_command(in, out) || in.remaining_bits() < 1) {
            return false;
        }
        out.room_active = in.read_unsigned_bits(1) != 0;
        if (out.room_active) {
            if (in.remaining_bits() < 1 + 9 + 8 + 16 + 16) return false;
            out.room_id = static_cast<std::uint8_t>(in.read_unsigned_bits(1));
            out.room_endpoint = static_cast<std::uint16_t>(in.read_unsigned_bits(9));
            out.room_value = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
            out.room_revision = static_cast<std::uint16_t>(in.read_unsigned_bits(16));
            out.room_seq = static_cast<std::uint16_t>(in.read_unsigned_bits(16));
        }
        return true;
    }

    /// INPUT DELTAS ARE RELATIVE TO SYNC'S ACKNOWLEDGED BASELINE for the first
    /// frame in every packet, then to the preceding frame in that packet. A lost
    /// packet therefore cannot poison a later one. Twenty-one groups keep the mask
    /// small while letting the six controls, three tracked poses, command and room
    /// request change independently. Even when every tracked pose changes, the
    /// unchanged request fields save more than this 21-bit mask costs.
    static constexpr std::size_t delta_field_count = 21;

    /// ONE COMMAND: its channel in the short or the wide form (`command_channel_bits`), its value and its sequence,
    /// all at the widths `cockpit_components.hpp` names at the top and nowhere else.
    static void write_command(ashiato::BitBuffer& out, const Quantized& current) {
        namespace ck = ashiato_gd::cockpit;
        const std::uint32_t channel = current.command_channel & (ck::kCommandChannels - 1u);
        const bool wide = channel >= ck::kFirstGenericChannel;
        out.write_unsigned_bits(wide ? 1u : 0u, 1);
        out.write_unsigned_bits(channel, wide ? ck::kCommandChannelBits : ck::kShortChannelBits);
        out.write_unsigned_bits(current.command_value & ck::kGenericValueMax, ck::kGenericValueBits);
        out.write_unsigned_bits(current.command_seq & ck::kCommandSeqMask, ck::kCommandSeqBits);
    }

    static bool read_command(ashiato::BitBuffer& in, Quantized& out) {
        namespace ck = ashiato_gd::cockpit;
        if (in.remaining_bits() < 1) return false;
        const bool wide = in.read_unsigned_bits(1) != 0;
        const unsigned channel_bits = wide ? ck::kCommandChannelBits : ck::kShortChannelBits;
        if (in.remaining_bits() < channel_bits + ck::kGenericValueBits + ck::kCommandSeqBits) return false;
        out.command_channel = static_cast<std::uint16_t>(in.read_unsigned_bits(channel_bits));
        out.command_value = static_cast<std::uint8_t>(in.read_unsigned_bits(ck::kGenericValueBits));
        out.command_seq = static_cast<std::uint16_t>(in.read_unsigned_bits(ck::kCommandSeqBits));
        // A WIDE FORM CARRYING A LOW NUMBER is a packet no honest sender writes; refused, so one channel has one
        // spelling on the wire.
        return !wide || out.command_channel >= ck::kFirstGenericChannel;
    }

    static bool same_float(float a, float b, cw::QuantizedFloatConfig config) {
        return ashiato::sync::serialization::quantize_float(a, config)
            == ashiato::sync::serialization::quantize_float(b, config);
    }

    static std::array<std::uint64_t, 4> quat_code(const cw::Quat& value) {
        const cw::Quat q = cw::normalized(value);
        const float components[4] = {q.x, q.y, q.z, q.w};
        int largest = 0;
        for (int i = 1; i < 4; ++i) {
            if (std::fabs(components[i]) > std::fabs(components[largest])) largest = i;
        }
        const float sign = components[largest] < 0.0f ? -1.0f : 1.0f;
        std::array<std::uint64_t, 4> code{static_cast<std::uint64_t>(largest), 0U, 0U, 0U};
        std::size_t at = 1;
        for (int i = 0; i < 4; ++i) {
            if (i != largest) {
                code[at++] = ashiato::sync::serialization::quantize_float(
                    components[i] * sign, cw::quat_part);
            }
        }
        return code;
    }

    static bool same_quat(const cw::Quat& a, const cw::Quat& b) {
        return quat_code(a) == quat_code(b);
    }

    static void serialize_delta(
        const Quantized& previous,
        const Quantized& current,
        ashiato::BitBuffer& out) {
        const std::array<bool, delta_field_count> changed = {
            !same_float(previous.throttle, current.throttle, cw::unit),
            !same_float(previous.pitch, current.pitch, cw::axis),
            !same_float(previous.roll, current.roll, cw::axis),
            !same_float(previous.rudder, current.rudder, cw::axis),
            !same_float(previous.brake, current.brake, cw::unit),
            !same_float(previous.trigger, current.trigger, cw::unit),
            !same_float(previous.head_x, current.head_x, cw::reach)
                || !same_float(previous.head_y, current.head_y, cw::reach)
                || !same_float(previous.head_z, current.head_z, cw::reach),
            !same_quat(previous.head_rot, current.head_rot),
            !same_float(previous.left_x, current.left_x, cw::reach)
                || !same_float(previous.left_y, current.left_y, cw::reach)
                || !same_float(previous.left_z, current.left_z, cw::reach),
            !same_quat(previous.left_rot, current.left_rot),
            !same_float(previous.right_x, current.right_x, cw::reach)
                || !same_float(previous.right_y, current.right_y, cw::reach)
                || !same_float(previous.right_z, current.right_z, cw::reach),
            !same_quat(previous.right_rot, current.right_rot),
            !same_float(previous.grip_left, current.grip_left, cw::unit),
            !same_float(previous.grip_right, current.grip_right, cw::unit),
            previous.buttons != current.buttons,
            previous.kind_wanted != current.kind_wanted,
            previous.join_wanted != current.join_wanted,
            previous.join_seat != current.join_seat,
            previous.menu_request != current.menu_request,
            previous.command_channel != current.command_channel
                || previous.command_value != current.command_value
                || previous.command_seq != current.command_seq,
            previous.room_active != current.room_active
                || previous.room_id != current.room_id
                || previous.room_endpoint != current.room_endpoint
                || previous.room_value != current.room_value
                || previous.room_revision != current.room_revision
                || previous.room_seq != current.room_seq,
        };
        for (const bool value : changed) out.write_unsigned_bits(value ? 1U : 0U, 1);
        if (changed[0]) cw::serialize_quantized_float(out, current.throttle, cw::unit);
        if (changed[1]) cw::serialize_quantized_float(out, current.pitch, cw::axis);
        if (changed[2]) cw::serialize_quantized_float(out, current.roll, cw::axis);
        if (changed[3]) cw::serialize_quantized_float(out, current.rudder, cw::axis);
        if (changed[4]) cw::serialize_quantized_float(out, current.brake, cw::unit);
        if (changed[5]) cw::serialize_quantized_float(out, current.trigger, cw::unit);
        if (changed[6]) {
            cw::serialize_quantized_float(out, current.head_x, cw::reach);
            cw::serialize_quantized_float(out, current.head_y, cw::reach);
            cw::serialize_quantized_float(out, current.head_z, cw::reach);
        }
        if (changed[7]) cw::write_quat(out, current.head_rot);
        if (changed[8]) {
            cw::serialize_quantized_float(out, current.left_x, cw::reach);
            cw::serialize_quantized_float(out, current.left_y, cw::reach);
            cw::serialize_quantized_float(out, current.left_z, cw::reach);
        }
        if (changed[9]) cw::write_quat(out, current.left_rot);
        if (changed[10]) {
            cw::serialize_quantized_float(out, current.right_x, cw::reach);
            cw::serialize_quantized_float(out, current.right_y, cw::reach);
            cw::serialize_quantized_float(out, current.right_z, cw::reach);
        }
        if (changed[11]) cw::write_quat(out, current.right_rot);
        if (changed[12]) cw::serialize_quantized_float(out, current.grip_left, cw::unit);
        if (changed[13]) cw::serialize_quantized_float(out, current.grip_right, cw::unit);
        if (changed[14]) out.write_unsigned_bits(current.buttons, 8);
        if (changed[15]) ashiato_gd::cockpit::write_kind(out, current.kind_wanted);
        if (changed[16]) out.write_unsigned_bits(current.join_wanted, 8);
        if (changed[17]) ashiato_gd::cockpit::write_seat_or_none(out, current.join_seat);
        if (changed[18]) out.write_unsigned_bits(current.menu_request & 0x7u, 3);
        if (changed[19]) {
            write_command(out, current);
        }
        if (changed[20]) {
            out.write_unsigned_bits(current.room_active ? 1u : 0u, 1);
            if (current.room_active) {
                out.write_unsigned_bits(current.room_id & 0x1u, 1);
                out.write_unsigned_bits(current.room_endpoint & 0x1FFu, 9);
                out.write_unsigned_bits(current.room_value, 8);
                out.write_unsigned_bits(current.room_revision, 16);
                out.write_unsigned_bits(current.room_seq, 16);
            }
        }
    }

    static bool deserialize_delta(
        ashiato::BitBuffer& in,
        const Quantized& previous,
        Quantized& out) {
        if (in.remaining_bits() < delta_field_count) return false;
        std::array<bool, delta_field_count> changed{};
        for (bool& value : changed) value = in.read_unsigned_bits(1) != 0;
        out = previous;
        if (changed[0] && !cw::read_quantized_float(in, cw::unit, out.throttle)) return false;
        if (changed[1] && !cw::read_quantized_float(in, cw::axis, out.pitch)) return false;
        if (changed[2] && !cw::read_quantized_float(in, cw::axis, out.roll)) return false;
        if (changed[3] && !cw::read_quantized_float(in, cw::axis, out.rudder)) return false;
        if (changed[4] && !cw::read_quantized_float(in, cw::unit, out.brake)) return false;
        if (changed[5] && !cw::read_quantized_float(in, cw::unit, out.trigger)) return false;
        if (changed[6] && (!cw::read_quantized_float(in, cw::reach, out.head_x)
            || !cw::read_quantized_float(in, cw::reach, out.head_y)
            || !cw::read_quantized_float(in, cw::reach, out.head_z))) return false;
        if (changed[7] && !cw::read_quat(in, out.head_rot)) return false;
        if (changed[8] && (!cw::read_quantized_float(in, cw::reach, out.left_x)
            || !cw::read_quantized_float(in, cw::reach, out.left_y)
            || !cw::read_quantized_float(in, cw::reach, out.left_z))) return false;
        if (changed[9] && !cw::read_quat(in, out.left_rot)) return false;
        if (changed[10] && (!cw::read_quantized_float(in, cw::reach, out.right_x)
            || !cw::read_quantized_float(in, cw::reach, out.right_y)
            || !cw::read_quantized_float(in, cw::reach, out.right_z))) return false;
        if (changed[11] && !cw::read_quat(in, out.right_rot)) return false;
        if (changed[12] && !cw::read_quantized_float(in, cw::unit, out.grip_left)) return false;
        if (changed[13] && !cw::read_quantized_float(in, cw::unit, out.grip_right)) return false;
        if (changed[14]) {
            if (in.remaining_bits() < 8) return false;
            out.buttons = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        }
        if (changed[15] && !ashiato_gd::cockpit::read_kind(in, out.kind_wanted)) return false;
        if (changed[16]) {
            if (in.remaining_bits() < 8) return false;
            out.join_wanted = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        }
        if (changed[17] && !ashiato_gd::cockpit::read_seat_or_none(in, out.join_seat)) return false;
        if (changed[18]) {
            if (in.remaining_bits() < 3) return false;
            out.menu_request = static_cast<std::uint8_t>(in.read_unsigned_bits(3));
        }
        if (changed[19] && !read_command(in, out)) return false;
        if (changed[20]) {
            if (in.remaining_bits() < 1) return false;
            out.room_active = in.read_unsigned_bits(1) != 0;
            if (out.room_active) {
                if (in.remaining_bits() < 1 + 9 + 8 + 16 + 16) return false;
                out.room_id = static_cast<std::uint8_t>(in.read_unsigned_bits(1));
                out.room_endpoint = static_cast<std::uint16_t>(in.read_unsigned_bits(9));
                out.room_value = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
                out.room_revision = static_cast<std::uint16_t>(in.read_unsigned_bits(16));
                out.room_seq = static_cast<std::uint16_t>(in.read_unsigned_bits(16));
            }
        }
        return true;
    }

    // Required even though this is never in an archetype: sync wants a full trait set for
    // any registered component, and its absence crashes on the first prediction rather
    // than saying anything. Input is authoritative from whoever moved the stick, so a
    // difference is never worth a rollback on its own.
    static bool should_roll_back(const Quantized&, const Quantized&) {
        return false;
    }
};

// ---- RoomControlPage ---------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::RoomControlPage> {
    using Quantized = ashiato_gd::cockpit::RoomControlPage;
    static void quantize(const Quantized& value, Quantized& out) { out = value; }
    static Quantized dequantize(const Quantized& value) { return value; }
    static void serialize(const Quantized*, const Quantized& current, ashiato::BitBuffer& out,
                          ashiato::ComponentSerializationContext&) {
        out.write_unsigned_bits(current.room_id & 0x1u, 1);
        out.write_unsigned_bits(current.page & 0x0Fu, 4);
        out.write_unsigned_bits((current.count - 1u) & 0x1Fu, 5);
        out.write_unsigned_bits(current.revision, 16);
        out.write_unsigned_bits(current.generation, 16);
        for (const std::uint8_t value : current.values) out.write_unsigned_bits(value, 8);
    }
    static bool deserialize(ashiato::BitBuffer& in, const Quantized*, Quantized& out,
                            ashiato::ComponentSerializationContext&) {
        constexpr std::size_t kBits = 1 + 4 + 5 + 16 + 16 + 32 * 8;
        if (in.remaining_bits() < kBits) return false;
        out.room_id = static_cast<std::uint8_t>(in.read_unsigned_bits(1));
        out.page = static_cast<std::uint8_t>(in.read_unsigned_bits(4));
        out.count = static_cast<std::uint8_t>(in.read_unsigned_bits(5) + 1u);
        out.revision = static_cast<std::uint16_t>(in.read_unsigned_bits(16));
        out.generation = static_cast<std::uint16_t>(in.read_unsigned_bits(16));
        for (std::uint8_t& value : out.values) value = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        return out.count > 0 && out.count <= 32;
    }
    static bool should_roll_back(const Quantized&, const Quantized&) { return false; }
};

// ---- BusPage -----------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::BusPage> {
    using Quantized = ashiato_gd::cockpit::BusPage;
    /// THE CRAFT IS AN ENTITY REFERENCE, mapped through sync's reference context as CabinOwner's is.
    static constexpr bool references_entities = true;

    static void quantize(const Quantized& value, Quantized& out) { out = value; }
    static Quantized dequantize(const Quantized& value) { return value; }

    /// SPARSE: which of the 32 are not zero, as a mask, and then only those values. A page is written whole whenever
    /// anything on it changes, and most switches on a panel are off, so one switch thrown on a page costs its 32-bit
    /// mask and eight bits rather than 256. At worst, every value set, it is 32 bits dearer than writing all 32.
    static void serialize(const Quantized*, const Quantized& current, ashiato::BitBuffer& out,
                          ashiato::ComponentSerializationContext& context) {
        namespace ck = ashiato_gd::cockpit;
        out.write_unsigned_bits(current.client, 8);
        out.write_unsigned_bits(current.page & ((1u << ck::kPageBits) - 1u), ck::kPageBits);
        std::uint64_t mask = 0;
        for (std::size_t i = 0; i < ck::kPageChannels; ++i) {
            if (current.values[i] != 0) mask |= std::uint64_t{1} << i;
        }
        out.write_unsigned_bits(mask, static_cast<unsigned>(ck::kPageChannels));
        for (std::size_t i = 0; i < ck::kPageChannels; ++i) {
            if (current.values[i] != 0) out.write_unsigned_bits(current.values[i] & ck::kGenericValueMax, ck::kGenericValueBits);
        }
        // NO CONTEXT, NO CRAFT, rather than a null dereference; see CabinOwner.
        if (context.userContext == nullptr) {
            out.write_bool(false);
            return;
        }
        EntityReferenceContext& references = *static_cast<EntityReferenceContext*>(context.userContext);
        (void)write_entity_reference(out, current.vehicle.entity, references);
    }

    static bool deserialize(ashiato::BitBuffer& in, const Quantized*, Quantized& out,
                            ashiato::ComponentSerializationContext& context) {
        namespace ck = ashiato_gd::cockpit;
        if (in.remaining_bits() < 8 + ck::kPageBits + ck::kPageChannels) return false;
        out.client = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        out.page = static_cast<std::uint16_t>(in.read_unsigned_bits(ck::kPageBits));
        const std::uint64_t mask = in.read_unsigned_bits(static_cast<unsigned>(ck::kPageChannels));
        for (std::size_t i = 0; i < ck::kPageChannels; ++i) {
            out.values[i] = 0;
            if ((mask & (std::uint64_t{1} << i)) == 0) continue;
            if (in.remaining_bits() < ck::kGenericValueBits) return false;
            out.values[i] = static_cast<std::uint8_t>(in.read_unsigned_bits(ck::kGenericValueBits));
        }
        if (context.userContext == nullptr) return false;
        EntityReferenceContext& references = *static_cast<EntityReferenceContext*>(context.userContext);
        return read_entity_reference(in, references, out.vehicle);
    }

    /// NEVER. Nobody predicts a page; it snaps, as a cabin does.
    static bool should_roll_back(const Quantized&, const Quantized&) { return false; }
    static Quantized interpolate(const Quantized& from, const Quantized&, float) { return from; }
};

// ---- VehicleState --------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::VehicleState> {
    using Quantized = ashiato_gd::cockpit::VehicleState;

    static void quantize(const ashiato_gd::cockpit::VehicleState& value, Quantized& out) {
        quantize_through_the_wire(value, out);
    }

    static ashiato_gd::cockpit::VehicleState dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        cw::put_position(out, current.x, current.y, current.z);
        cw::write_quat(out, current.rot);
        cw::serialize_quantized_float(out, current.vx, cw::speed);
        cw::serialize_quantized_float(out, current.vy, cw::speed);
        cw::serialize_quantized_float(out, current.vz, cw::speed);
        cw::serialize_quantized_float(out, current.wx, cw::spin);
        cw::serialize_quantized_float(out, current.wy, cw::spin);
        cw::serialize_quantized_float(out, current.wz, cw::spin);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        return cw::read_quantized_float(in, cw::ground, out.x)
            && cw::read_quantized_float(in, cw::height, out.y)
            && cw::read_quantized_float(in, cw::ground, out.z)
            && cw::read_quat(in, out.rot)
            && cw::read_quantized_float(in, cw::speed, out.vx)
            && cw::read_quantized_float(in, cw::speed, out.vy)
            && cw::read_quantized_float(in, cw::speed, out.vz)
            && cw::read_quantized_float(in, cw::spin, out.wx)
            && cw::read_quantized_float(in, cw::spin, out.wy)
            && cw::read_quantized_float(in, cw::spin, out.wz);
    }

    /// How wrong the prediction has to be before it is worth rewinding for.
    ///
    /// Tight, because the player's own head is bolted to this: the whole cockpit moves
    /// when it is corrected, and a correction the eye can see is the world lurching rather
    /// than an object shifting. What makes that affordable is that the correction is then
    /// BLENDED OUT visually rather than snapped -- see the visual offset in
    /// cockpit_world.cpp -- so a tight threshold costs resimulation, not comfort.
    ///
    /// THE ANGLE IS THE ONE THAT MATTERS, and it was far too loose. At 0.05 rad the client
    /// was allowed to drift three degrees of attitude before anything corrected it, and
    /// then the whole world rotated three degrees over the blend -- several times a
    /// second, at a rate an aeroplane's own pitch change is a small fraction of. Measured,
    /// a single tick's drawn rotation could be eight times what the aircraft's angular
    /// velocity accounted for.
    ///
    /// It could not simply be tightened: at the old quantisation it would have been a
    /// threshold below the noise, and the client would have rolled back on rounding. The
    /// finer `quat_part` above is what makes this number possible.
    ///
    /// Resimulation is what pays for both, and it is cheap: 0.06 ms a tick with the whole
    /// world loaded, worst span ten ticks.
    static constexpr float rollback_position = 0.04f;   // metres, 4x the position grid
    static constexpr float rollback_angle = 0.004f;     // radians, about a fifth of a degree

    static bool should_roll_back(const Quantized& predicted, const Quantized& authoritative) {
        const float dx = predicted.x - authoritative.x;
        const float dy = predicted.y - authoritative.y;
        const float dz = predicted.z - authoritative.z;
        if ((dx * dx + dy * dy + dz * dz) > (rollback_position * rollback_position)) {
            return true;
        }
        return cw::angle_between(predicted.rot, authoritative.rot) > rollback_angle;
    }

    static Quantized interpolate(const Quantized& from, const Quantized& to, float alpha) {
        Quantized out;
        out.x = cw::lerp(from.x, to.x, alpha);
        out.y = cw::lerp(from.y, to.y, alpha);
        out.z = cw::lerp(from.z, to.z, alpha);
        out.rot = cw::slerp(from.rot, to.rot, alpha);
        out.vx = cw::lerp(from.vx, to.vx, alpha);
        out.vy = cw::lerp(from.vy, to.vy, alpha);
        out.vz = cw::lerp(from.vz, to.vz, alpha);
        out.wx = cw::lerp(from.wx, to.wx, alpha);
        out.wy = cw::lerp(from.wy, to.wy, alpha);
        out.wz = cw::lerp(from.wz, to.wz, alpha);
        return out;
    }
};

// ---- CraftControls --------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::CraftControls> {
    using Quantized = ashiato_gd::cockpit::CraftControls;

    static void quantize(const ashiato_gd::cockpit::CraftControls& value, Quantized& out) {
        quantize_through_the_wire(value, out);
    }

    static ashiato_gd::cockpit::CraftControls dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        cw::serialize_quantized_float(out, current.throttle, cw::unit);
        cw::serialize_quantized_float(out, current.flaps, cw::unit);
        cw::serialize_quantized_float(out, current.trim, cw::axis);
        cw::serialize_quantized_float(out, current.tilt, cw::unit);
        out.write_unsigned_bits(current.switches, 8);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        if (!cw::read_quantized_float(in, cw::unit, out.throttle)
            || !cw::read_quantized_float(in, cw::unit, out.flaps)
            || !cw::read_quantized_float(in, cw::axis, out.trim)
            || !cw::read_quantized_float(in, cw::unit, out.tilt)) {
            return false;
        }
        if (in.remaining_bits() < 8) {
            return false;
        }
        out.switches = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        return true;
    }

    /// THE PHYSICS READS THIS, so a client that predicted the wrong flap setting has been
    /// predicting the wrong aeroplane. Worth a rollback, and the threshold is tight
    /// because the difference between gear up and gear down is not a rounding error.
    static bool should_roll_back(const Quantized& predicted, const Quantized& authority) {
        return predicted.switches != authority.switches
            || std::fabs(predicted.throttle - authority.throttle) > 0.06f
            || std::fabs(predicted.flaps - authority.flaps) > 0.06f
            || std::fabs(predicted.trim - authority.trim) > 0.06f
            // TIGHTER than the rest, because on a tiltrotor this one IS the aeroplane:
            // a tenth of the travel is the difference between thrust along the nose and
            // thrust holding the weight up.
            || std::fabs(predicted.tilt - authority.tilt) > 0.03f;
    }

    /// A lever does not slide between two settings on its way to being read; it is where
    /// it is. Step, like the rest of the discrete state on a vehicle.
    static Quantized interpolate(const Quantized& from, const Quantized&, float) {
        return from;
    }
};

// ---- CraftSystems ---------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::CraftSystems> {
    using Quantized = ashiato_gd::cockpit::CraftSystems;

    static void quantize(const ashiato_gd::cockpit::CraftSystems& value, Quantized& out) {
        quantize_through_the_wire(value, out);
    }

    static ashiato_gd::cockpit::CraftSystems dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        for (std::size_t i = 0; i < ashiato_gd::cockpit::kMaxTurrets; ++i) {
            cw::serialize_quantized_float(out, current.turret_yaw[i], cw::bearing);
            cw::serialize_quantized_float(out, current.turret_pitch[i], cw::elevation);
        }
        // THE OUTSIDE SWITCHES, AS MANY BITS AS THE MASK NEEDS; the selectors and the crew's switches are on
        // CabinSystems. Written masked, so a crew bit set here by mistake cannot reach the wire -- and written
        // `kOutsideFlagBits` wide rather than a typed 4, because the two went out of step the first time the mask
        // grew and the new switches vanished on the wire with nothing red to say so (lane/fireboat).
        out.write_unsigned_bits(current.flags & ashiato_gd::cockpit::kOutsideFlags,
                                ashiato_gd::cockpit::kOutsideFlagBits);
        out.write_unsigned_bits(current.load, 8);
        out.write_unsigned_bits(current.stores, 8);
        out.write_unsigned_bits(current.sweep_command, 8);
        out.write_unsigned_bits(current.sweep, 8);
        out.write_unsigned_bits(current.bays & 0x3u, 2);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        bool ok = true;
        for (std::size_t i = 0; i < ashiato_gd::cockpit::kMaxTurrets && ok; ++i) {
            ok = cw::read_quantized_float(in, cw::bearing, out.turret_yaw[i])
                && cw::read_quantized_float(in, cw::elevation, out.turret_pitch[i]);
        }
        if (!ok) {
            return false;
        }
        if (in.remaining_bits() < ashiato_gd::cockpit::kOutsideFlagBits + 8 + 8 + 8 + 8 + 2) {
            return false;
        }
        out.flags = static_cast<std::uint16_t>(
            in.read_unsigned_bits(ashiato_gd::cockpit::kOutsideFlagBits));
        out.load = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        out.stores = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        out.sweep_command = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        out.sweep = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        out.bays = static_cast<std::uint8_t>(in.read_unsigned_bits(2));
        return true;
    }

    /// YES, AND THE REASON IS NOT WHAT IT LOOKS LIKE.
    ///
    /// None of this is physics, so the obvious answer is "never rewind for it" -- and that
    /// was the first answer, and it was wrong in a way that took a failing test to see.
    ///
    /// On a PREDICTED entity, an authoritative value only ever arrives ON A ROLLBACK.
    /// Between rollbacks the local simulation owns the state, which is the whole point of
    /// prediction. So anything on a predicted vehicle that this machine CANNOT COMPUTE
    /// FOR ITSELF -- because it does not have the input that drives it -- never arrives at
    /// all unless something rewinds. The pilot of an aeroplane saw their own gunner's
    /// turret sitting dead ahead while it swung for everybody else.
    ///
    /// What makes this affordable is the other half of the correction machinery: a
    /// rollback moves the PICTURE by the size of the disagreement, and a turret
    /// disagreement moves the position and attitude by nothing at all. So it costs
    /// resimulation and not comfort -- measured at 0.06 ms a tick over a span of ten.
    ///
    /// The threshold is coarse on purpose. A gunner slewing at full rate crosses it a
    /// couple of times a second, which is the price of the pilot being able to see it.
    static bool should_roll_back(const Quantized& predicted, const Quantized& authority) {
        if (predicted.flags != authority.flags) {
            return true;
        }
        for (std::size_t i = 0; i < ashiato_gd::cockpit::kMaxTurrets; ++i) {
            if (std::fabs(short_way(predicted.turret_yaw[i], authority.turret_yaw[i]))
                    > 0.15f
                || std::fabs(predicted.turret_pitch[i] - authority.turret_pitch[i])
                    > 0.15f) {
                return true;
            }
        }
        // THE RAILS, ON ANY DIFFERENCE. The pilot's own machine predicts this vehicle and
        // cannot launch a missile, so an emptied rail only ever reaches it on a rollback -- and
        // a launch is a once-a-second event at the very most, so the rollback is cheap.
        if (predicted.stores != authority.stores) {
            return true;
        }
        // THE SWEEP HANDLES, ON ANY DIFFERENCE: the RIO's command reaches the pilot's predicting machine on a rollback
        // or not at all, and it changes only while a hand is on a handle. THE WINGS THEMSELVES, COARSELY, as the tank:
        // the server walks them a fifth of a degree a step, and rolling the world back for every step of a 4.6 s
        // sweep would resimulate for a difference nobody can see. Eight steps is 1.7 degrees; the view eases between.
        if (predicted.sweep_command != authority.sweep_command) {
            return true;
        }
        // THE BAYS, ON ANY DIFFERENCE, for the rails' reason: only the server opens one, twice a launch at most.
        if (predicted.bays != authority.bays) {
            return true;
        }
        if ((predicted.sweep > authority.sweep ? predicted.sweep - authority.sweep : authority.sweep - predicted.sweep) > 8) {
            return true;
        }
        // THE TANK, COARSELY, for the same reason as the turret above it. A client flying
        // its own water bomber drains and fills the tank for itself -- the rule is the
        // doors, the dt and nothing else -- so the two agree to within a tick, and rolling
        // the world back over one step of a gauge would resimulate on every tick of a
        // twelve-second drop for a difference nobody can see.
        return predicted.load > authority.load
            ? predicted.load - authority.load > 8
            : authority.load - predicted.load > 8;
    }

    /// The SHORT way round on the traverse: a barrel swinging past due aft crosses from
    /// +pi to -pi, and a straight lerp would send it all the way back the other way.
    static float short_way(float from, float to) {
        float sweep = to - from;
        while (sweep > 3.14159274f) {
            sweep -= 6.28318548f;
        }
        while (sweep < -3.14159274f) {
            sweep += 6.28318548f;
        }
        return sweep;
    }

    static Quantized interpolate(const Quantized& from, const Quantized& to, float alpha) {
        Quantized out = from;
        for (std::size_t i = 0; i < ashiato_gd::cockpit::kMaxTurrets; ++i) {
            out.turret_yaw[i] = from.turret_yaw[i]
                + short_way(from.turret_yaw[i], to.turret_yaw[i]) * alpha;
            out.turret_pitch[i] = cw::lerp(from.turret_pitch[i], to.turret_pitch[i],
                                           alpha);
        }
        return out;
    }
};

// ---- RailCar --------------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::RailCar> {
    using Quantized = ashiato_gd::cockpit::RailCar;

    static void quantize(const ashiato_gd::cockpit::RailCar& value, Quantized& out) {
        quantize_through_the_wire(value, out);
    }

    static ashiato_gd::cockpit::RailCar dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        cw::serialize_quantized_float(out, current.distance, cw::along_rail);
        cw::serialize_quantized_float(out, current.speed, cw::speed);
        out.write_unsigned_bits(current.track & 0x3u, 2);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        if (!cw::read_quantized_float(in, cw::along_rail, out.distance)
            || !cw::read_quantized_float(in, cw::speed, out.speed)) {
            return false;
        }
        if (in.remaining_bits() < 2) {
            return false;
        }
        out.track = static_cast<std::uint8_t>(in.read_unsigned_bits(2));
        return true;
    }

    /// Tight, because the player's own head is bolted to this exactly as it is to a
    /// vehicle's pose -- and on a railway a metre of error is a metre of the whole world
    /// sliding past the window.
    static bool should_roll_back(const Quantized& predicted, const Quantized& authority) {
        return std::fabs(predicted.distance - authority.distance) > 0.25f
            || std::fabs(predicted.speed - authority.speed) > 0.5f;
    }

    static Quantized interpolate(const Quantized& from, const Quantized& to, float alpha) {
        Quantized out = from;
        // NOT through the wrap. A train crossing the end of the loop goes from 30 km to 0,
        // and interpolating that straight would send it back round the whole railway in
        // one frame.
        const float sweep = to.distance - from.distance;
        out.distance = std::fabs(sweep) > 1000.0f
            ? to.distance
            : from.distance + sweep * alpha;
        out.speed = cw::lerp(from.speed, to.speed, alpha);
        return out;
    }
};

// ---- CrewControls ---------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::CrewControls> {
    using Quantized = ashiato_gd::cockpit::CrewControls;

    static void quantize(const ashiato_gd::cockpit::CrewControls& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::cockpit::CrewControls dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        namespace ck = ashiato_gd::cockpit;
        // TWO FORMS, and the writer takes the smaller (lane/seats, 2026-09-18). The FOUR-SEAT form is the wire before
        // this lane, every seat's hands whether anybody is in it, and a craft whose crew all sit below seat four never
        // pays more than its one form bit over what it paid. The ABOARD form is a count and then, for each person
        // aboard, their seat's distance past the last one and their hands: what a lone pilot, or a crew in a craft
        // of sixty-four seats, costs.
        bool low = true;
        unsigned aboard_bits = ck::kAboardCountBits;
        std::uint32_t next = 0;
        for (std::size_t i = 0; i < current.count; ++i) {
            low = low && current.hands[i].seat < ck::kFirstLongSeat;
            aboard_bits += ck::seat_bits(current.hands[i].seat - next) + hands_bits();
            next = current.hands[i].seat + 1u;
        }
        const unsigned four_bits = static_cast<unsigned>(ck::kFirstLongSeat) * hands_bits();
        if (low && four_bits <= aboard_bits) {
            out.write_unsigned_bits(0u, 1);
            for (std::uint32_t seat = 0; seat < ck::kFirstLongSeat; ++seat) {
                const ck::SeatHands* hands = current.of(seat);
                write_hands(out, hands != nullptr ? *hands : ck::SeatHands{});
            }
        } else {
            out.write_unsigned_bits(1u, 1);
            out.write_unsigned_bits(current.count, ck::kAboardCountBits);
            next = 0;
            for (std::size_t i = 0; i < current.count; ++i) {
                ck::write_seat(out, current.hands[i].seat - next);
                write_hands(out, current.hands[i]);
                next = current.hands[i].seat + 1u;
            }
        }
        cw::serialize_quantized_float(out, current.linked_throttle, cw::unit);
        cw::serialize_quantized_float(out, current.linked_x, cw::axis);
        cw::serialize_quantized_float(out, current.linked_y, cw::axis);
        cw::serialize_quantized_float(out, current.linked_rudder, cw::axis);
        ck::write_seat_or_none(out, current.hands_on);
    }

    /// One seat's hands: measured from the quantisers rather than typed (see `hands_bits`).
    static void write_hands(ashiato::BitBuffer& out, const ashiato_gd::cockpit::SeatHands& hands) {
        cw::serialize_quantized_float(out, hands.throttle, cw::unit);
        cw::serialize_quantized_float(out, hands.stick_x, cw::axis);
        cw::serialize_quantized_float(out, hands.stick_y, cw::axis);
    }

    static bool read_hands(ashiato::BitBuffer& in, ashiato_gd::cockpit::SeatHands& hands) {
        return cw::read_quantized_float(in, cw::unit, hands.throttle)
            && cw::read_quantized_float(in, cw::axis, hands.stick_x)
            && cw::read_quantized_float(in, cw::axis, hands.stick_y);
    }

    /// WHAT ONE SEAT'S HANDS COST, asked of the quantisers by writing a seat at rest once.
    static unsigned hands_bits() {
        static const unsigned bits = [] {
            ashiato::BitBuffer scratch;
            write_hands(scratch, ashiato_gd::cockpit::SeatHands{});
            return static_cast<unsigned>(scratch.bit_size());
        }();
        return bits;
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        namespace ck = ashiato_gd::cockpit;
        if (in.remaining_bits() < 1) {
            return false;
        }
        out = ck::CrewControls{};
        if (in.read_unsigned_bits(1) == 0) {
            // The four-seat form: every seat below four, whoever is in it. A seat at rest is kept as one.
            for (std::uint32_t seat = 0; seat < ck::kFirstLongSeat; ++seat) {
                ck::SeatHands hands;
                if (!read_hands(in, hands)) {
                    return false;
                }
                out.set(static_cast<ck::SeatId>(seat), hands.throttle, hands.stick_x, hands.stick_y);
            }
        } else {
            if (in.remaining_bits() < ck::kAboardCountBits) {
                return false;
            }
            const std::size_t count = in.read_unsigned_bits(ck::kAboardCountBits);
            if (count > ck::kMostAboard) {
                return false;
            }
            std::uint32_t next = 0;
            for (std::size_t i = 0; i < count; ++i) {
                ck::SeatId gap = 0;
                ck::SeatHands hands;
                if (!ck::read_seat(in, gap) || !read_hands(in, hands)) {
                    return false;
                }
                const std::uint32_t seat = next + gap;
                if (seat >= ck::kMostSeats) {
                    return false;
                }
                out.set(static_cast<ck::SeatId>(seat), hands.throttle, hands.stick_x, hands.stick_y);
                next = seat + 1u;
            }
        }
        if (!cw::read_quantized_float(in, cw::unit, out.linked_throttle)
            || !cw::read_quantized_float(in, cw::axis, out.linked_x)
            || !cw::read_quantized_float(in, cw::axis, out.linked_y)
            || !cw::read_quantized_float(in, cw::axis, out.linked_rudder)) {
            return false;
        }
        return ck::read_seat_or_none(in, out.hands_on);
    }

    /// NEVER: it is on a cabin, and nobody predicts a cabin. See the note on the component.
    static bool should_roll_back(const Quantized&, const Quantized&) {
        return false;
    }

    static Quantized interpolate(const Quantized& from, const Quantized& to, float alpha) {
        // SEAT BY SEAT: a seat in `to` blends from the same seat in `from`, and from rest if nobody was in it.
        Quantized out = to;
        for (std::size_t i = 0; i < to.count; ++i) {
            const ashiato_gd::cockpit::SeatHands* was = from.of(to.hands[i].seat);
            const ashiato_gd::cockpit::SeatHands rest{};
            const ashiato_gd::cockpit::SeatHands& a = was != nullptr ? *was : rest;
            out.hands[i].throttle = cw::lerp(a.throttle, to.hands[i].throttle, alpha);
            out.hands[i].stick_x = cw::lerp(a.stick_x, to.hands[i].stick_x, alpha);
            out.hands[i].stick_y = cw::lerp(a.stick_y, to.hands[i].stick_y, alpha);
        }
        out.linked_throttle = cw::lerp(from.linked_throttle, to.linked_throttle, alpha);
        out.linked_x = cw::lerp(from.linked_x, to.linked_x, alpha);
        out.linked_y = cw::lerp(from.linked_y, to.linked_y, alpha);
        out.linked_rudder = cw::lerp(from.linked_rudder, to.linked_rudder, alpha);
        out.hands_on = from.hands_on;
        return out;
    }
};

// ---- Route ----------------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::Route> {
    using Quantized = ashiato_gd::cockpit::Route;

    static void quantize(const ashiato_gd::cockpit::Route& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::cockpit::Route dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        out.write_unsigned_bits(current.active ? 1u : 0u, 1);
        if (!current.active) {
            return;
        }
        cw::put_position(out, current.x, current.y, current.z);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        if (in.remaining_bits() < 1) {
            return false;
        }
        out.active = in.read_unsigned_bits(1) != 0u;
        if (!out.active) {
            out.x = out.y = out.z = 0.0f;
            return true;
        }
        return cw::read_quantized_float(in, cw::ground, out.x)
            && cw::read_quantized_float(in, cw::height, out.y)
            && cw::read_quantized_float(in, cw::ground, out.z);
    }

    /// A destination is not physics. Rewinding the world because an autopilot picked a
    /// different one would be paying a simulation price for a signpost.
    static bool should_roll_back(const Quantized&, const Quantized&) {
        return false;
    }

    /// Step, not interpolate: a waypoint does not slide from the old one to the new one,
    /// it is somewhere else now.
    static Quantized interpolate(const Quantized& from, const Quantized&, float) {
        return from;
    }
};

// ---- Rigging ---------------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::Rigging> {
    using Quantized = ashiato_gd::cockpit::Rigging;

    static void quantize(const ashiato_gd::cockpit::Rigging& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::cockpit::Rigging dequantize(const Quantized& value) {
        return value;
    }

    /// 8 + 8 + 8 + 4 x 8 + 8 + 6 = 70 bits, and only when something moved past its step.
    static constexpr std::size_t kBits = 8 + 8 + 8 + 4 * 8 + 8 + 6;

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        out.write_unsigned_bits(static_cast<std::uint8_t>(current.fore), 8);
        out.write_unsigned_bits(static_cast<std::uint8_t>(current.main), 8);
        out.write_unsigned_bits(current.set, 8);
        for (std::size_t i = 0; i < 4; ++i) {
            out.write_unsigned_bits(current.fill[i], 8);
        }
        out.write_unsigned_bits(current.apparent, 8);
        out.write_unsigned_bits(current.breeze & 0x3Fu, 6);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        if (in.remaining_bits() < kBits) {
            return false;
        }
        out.fore = static_cast<std::int8_t>(static_cast<std::uint8_t>(in.read_unsigned_bits(8)));
        out.main = static_cast<std::int8_t>(static_cast<std::uint8_t>(in.read_unsigned_bits(8)));
        out.set = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        for (std::size_t i = 0; i < 4; ++i) {
            out.fill[i] = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        }
        out.apparent = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        out.breeze = static_cast<std::uint8_t>(in.read_unsigned_bits(6));
        return true;
    }

    /// Nobody predicts a ship nobody may board, and a sail's shape is not physics: never a reason to rewind.
    static bool should_roll_back(const Quantized&, const Quantized&) {
        return false;
    }

    /// Step: a sail is as full as the last record said, and a yard where it was put.
    static Quantized interpolate(const Quantized& from, const Quantized&, float) {
        return from;
    }
};

// ---- CraftCue, which is not a component at all ------------------------------------------
//
// A cue has FOUR jobs rather than a component's six: put it on the wire, take it off, PLAY
// it, and un-play it if it turns out not to have happened. There is no interpolation and no
// rollback threshold, because a moment does not have a value between two frames.

template <>
struct SyncCueTraits<ashiato_gd::cockpit::CraftCue> {
    static void serialize(
        const ashiato_gd::cockpit::CraftCue& cue,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        out.write_unsigned_bits(cue.what, 8);
        out.write_unsigned_bits(cue.value, 8);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        ashiato_gd::cockpit::CraftCue& out,
        ashiato::ComponentSerializationContext&) {
        if (in.remaining_bits() < 16) {
            return false;
        }
        out.what = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        out.value = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        return true;
    }

    /// PLAYED ON WHICHEVER MACHINE IS DRAWING, which is where a cue's whole point is.
    ///
    /// It lands in the log rather than doing anything, because a static trait function has
    /// a registry and an entity and no way at all to reach a renderer. `late_seconds` is
    /// how far behind the frame this machine is drawing, and `frame` is the number every
    /// peer agrees on -- both are carried through so that an effect started from this can
    /// begin at the right point rather than at its beginning.
    static bool play(
        ashiato::Registry& registry,
        ashiato::Entity owner,
        const ashiato_gd::cockpit::CraftCue& cue,
        float late_seconds,
        SyncFrame frame) {
        ashiato_gd::cockpit::CueLog& log = registry.write<ashiato_gd::cockpit::CueLog>();
        // A CAP, because nothing guarantees anybody is draining this. A machine with no
        // renderer -- a dedicated server, a test -- would otherwise collect every moment
        // that has ever happened.
        if (log.played.size() >= 64) {
            log.played.erase(log.played.begin());
        }
        ashiato_gd::cockpit::PlayedCue played;
        played.entity = owner.value;
        played.what = cue.what;
        played.value = cue.value;
        played.late = late_seconds;
        played.frame = static_cast<std::uint32_t>(frame);
        log.played.push_back(played);
        return true;
    }

    /// WHETHER TWO OF THESE ARE THE SAME MOMENT, which is how a predicted cue is matched
    /// against the authoritative one that confirms it. Two releases from one aeroplane with
    /// the same tank level are the same event as far as this can tell, and the frame they
    /// are filed under is what actually tells them apart.
    static bool equals_cue(
        const ashiato_gd::cockpit::CraftCue& lhs,
        const ashiato_gd::cockpit::CraftCue& rhs) {
        return lhs.what == rhs.what && lhs.value == rhs.value;
    }

    /// AND UN-PLAYED, when a cue this machine predicted turns out not to have happened.
    ///
    /// Nothing in this game predicts one today -- only the server emits -- so this is the
    /// honest empty case rather than a missing one: take the most recent matching entry
    /// back out if it has not been drained yet, and shrug if it has. An effect that has
    /// already been drawn cannot be undrawn, which is the real reason a cue for something
    /// expensive should be emitted by the server rather than guessed at.
    static bool rollback(
        ashiato::Registry& registry,
        ashiato::Entity owner,
        const ashiato_gd::cockpit::CraftCue& cue) {
        ashiato_gd::cockpit::CueLog& log = registry.write<ashiato_gd::cockpit::CueLog>();
        for (auto it = log.played.rbegin(); it != log.played.rend(); ++it) {
            if (it->entity == owner.value && it->what == cue.what
                && it->value == cue.value) {
                log.played.erase(std::next(it).base());
                return true;
            }
        }
        return true;
    }
};

// ---- ShellCue ------------------------------------------------------------------------

template <>
struct SyncCueTraits<ashiato_gd::cockpit::ShellCue> {
    static void serialize(
        const ashiato_gd::cockpit::ShellCue& cue,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        out.write_unsigned_bits(cue.mount & 0x3u, 2);
        out.write_unsigned_bits(cue.shell, 8);
        out.write_unsigned_bits(cue.ammo & 0xFu, 4);
        cw::put_position(out, cue.x, cue.y, cue.z);
        cw::serialize_quantized_float(out, cue.vx, cw::muzzle);
        cw::serialize_quantized_float(out, cue.vy, cw::muzzle);
        cw::serialize_quantized_float(out, cue.vz, cw::muzzle);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        ashiato_gd::cockpit::ShellCue& out,
        ashiato::ComponentSerializationContext&) {
        if (in.remaining_bits() < 14) {
            return false;
        }
        out.mount = static_cast<std::uint8_t>(in.read_unsigned_bits(2));
        out.shell = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        out.ammo = static_cast<std::uint8_t>(in.read_unsigned_bits(4));
        return cw::read_quantized_float(in, cw::ground, out.x)
            && cw::read_quantized_float(in, cw::height, out.y)
            && cw::read_quantized_float(in, cw::ground, out.z)
            && cw::read_quantized_float(in, cw::muzzle, out.vx)
            && cw::read_quantized_float(in, cw::muzzle, out.vy)
            && cw::read_quantized_float(in, cw::muzzle, out.vz);
    }

    /// PLAYED INTO THE LOG, as a CraftCue is -- see its note -- and drained by `CockpitWorld::shell_cues`.
    static bool play(
        ashiato::Registry& registry,
        ashiato::Entity owner,
        const ashiato_gd::cockpit::ShellCue& cue,
        float late_seconds,
        SyncFrame frame) {
        ashiato_gd::cockpit::ShellLog& log = registry.write<ashiato_gd::cockpit::ShellLog>();
        if (log.played.size() >= 64) {
            log.played.erase(log.played.begin());
        }
        ashiato_gd::cockpit::PlayedShell played;
        played.entity = owner.value;
        played.cue = cue;
        played.late = late_seconds;
        played.frame = static_cast<std::uint32_t>(frame);
        log.played.push_back(played);
        return true;
    }

    /// THE SAME SHELL: the same mount and the same shell number. NOT the muzzle -- the gunner's machine works it out
    /// from a ship it is drawing a packet late and the server from the ship itself, so the two differ by however far
    /// the ship moved, and a cue that demanded they agree would withdraw every shell a moving ship fired.
    static bool equals_cue(
        const ashiato_gd::cockpit::ShellCue& lhs,
        const ashiato_gd::cockpit::ShellCue& rhs) {
        return lhs.mount == rhs.mount && lhs.shell == rhs.shell;
    }

    /// TAKEN BACK: the server's frame had no such shell (it refused the fire) or a replay did not fire it again. Logged
    /// as a WITHDRAWAL rather than erased, because the renderer has very likely drawn the shell already and has to be
    /// told to take it away.
    static bool rollback(
        ashiato::Registry& registry,
        ashiato::Entity owner,
        const ashiato_gd::cockpit::ShellCue& cue) {
        ashiato_gd::cockpit::ShellLog& log = registry.write<ashiato_gd::cockpit::ShellLog>();
        ashiato_gd::cockpit::PlayedShell taken;
        taken.entity = owner.value;
        taken.cue = cue;
        taken.withdrawn = true;
        log.played.push_back(taken);
        return true;
    }
};

// ---- GunnerState ---------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::GunnerState> {
    using Quantized = ashiato_gd::cockpit::GunnerState;

    static void quantize(const ashiato_gd::cockpit::GunnerState& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::cockpit::GunnerState dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        out.write_unsigned_bits(current.mount & 0x7u, 3);
        out.write_unsigned_bits(current.shells, 8);
        out.write_unsigned_bits(current.loaded_frame, 32);
        cw::serialize_quantized_float(out, current.aim_yaw, cw::aim);
        cw::serialize_quantized_float(out, current.aim_pitch, cw::aim);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        if (in.remaining_bits() < 43) {
            return false;
        }
        out.mount = static_cast<std::uint8_t>(in.read_unsigned_bits(3));
        out.shells = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        out.loaded_frame = static_cast<std::uint32_t>(in.read_unsigned_bits(32));
        return cw::read_quantized_float(in, cw::aim, out.aim_yaw)
            && cw::read_quantized_float(in, cw::aim, out.aim_pitch);
    }

    /// ANY DIFFERENCE. This is the state a gunner's machine predicts from its own stick and trigger, so a server that
    /// counted a different number of shells, loaded at another frame or laid the gun elsewhere is a prediction that was
    /// wrong, and replaying it is how it is put right. The angles are compared at their quantum: both machines lay the
    /// gun at it (`lay_gun`), so a real difference is at least one step.
    static bool should_roll_back(const Quantized& predicted, const Quantized& authoritative) {
        return predicted.mount != authoritative.mount || predicted.shells != authoritative.shells
            || predicted.loaded_frame != authoritative.loaded_frame
            || std::fabs(predicted.aim_yaw - authoritative.aim_yaw) > cw::aim.resolution * 0.5f
            || std::fabs(predicted.aim_pitch - authoritative.aim_pitch) > cw::aim.resolution * 0.5f;
    }

    static Quantized interpolate(const Quantized& from, const Quantized&, float) {
        return from;
    }
};

// ---- FireState -----------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::FireState> {
    using Quantized = ashiato_gd::cockpit::FireState;

    static void quantize(const ashiato_gd::cockpit::FireState& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::cockpit::FireState dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        cw::put_position(out, current.x, current.y, current.z);
        cw::serialize_quantized_float(out, current.strength, cw::unit);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        return cw::read_quantized_float(in, cw::ground, out.x)
            && cw::read_quantized_float(in, cw::height, out.y)
            && cw::read_quantized_float(in, cw::ground, out.z)
            && cw::read_quantized_float(in, cw::unit, out.strength);
    }

    /// NEVER, and for the reason the shell beside it gives: no client has any input that
    /// bears on a fire. It burns to the server's clock, water lands on it from a record
    /// the server wrote, and a rollback for a flame flickering is the world lurching for
    /// something nobody is flying.
    static bool should_roll_back(const Quantized&, const Quantized&) {
        return false;
    }

    /// STEP, not interpolate. A fire does not slide from one strength to another between
    /// packets: it is drawn from the last thing the server said, and the renderer's own
    /// flicker is what makes it look alive. See FireYard.
    static Quantized interpolate(const Quantized& from, const Quantized&, float) {
        return from;
    }
};

// ---- ShotState -----------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::ShotState> {
    using Quantized = ashiato_gd::cockpit::ShotState;

    static void quantize(const ashiato_gd::cockpit::ShotState& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::cockpit::ShotState dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        cw::put_position(out, current.x, current.y, current.z);
        cw::serialize_quantized_float(out, current.vx, cw::muzzle);
        cw::serialize_quantized_float(out, current.vy, cw::muzzle);
        cw::serialize_quantized_float(out, current.vz, cw::muzzle);
        out.write_unsigned_bits(current.ammo & 0xFu, 4);
        out.write_unsigned_bits(current.surface & 0x7u, 3);
        out.write_unsigned_bits(current.shooter, 8);
        out.write_unsigned_bits(current.mount & 0x3u, 2);
        out.write_unsigned_bits(current.shell, 8);
        cw::put_position(out, current.ix, current.iy, current.iz);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        if (!cw::read_quantized_float(in, cw::ground, out.x)
            || !cw::read_quantized_float(in, cw::height, out.y)
            || !cw::read_quantized_float(in, cw::ground, out.z)
            || !cw::read_quantized_float(in, cw::muzzle, out.vx)
            || !cw::read_quantized_float(in, cw::muzzle, out.vy)
            || !cw::read_quantized_float(in, cw::muzzle, out.vz)) {
            return false;
        }
        if (in.remaining_bits() < 25) {
            return false;
        }
        out.ammo = static_cast<std::uint8_t>(in.read_unsigned_bits(4));
        out.surface = static_cast<std::uint8_t>(in.read_unsigned_bits(3));
        out.shooter = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        out.mount = static_cast<std::uint8_t>(in.read_unsigned_bits(2));
        out.shell = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        return cw::read_quantized_float(in, cw::ground, out.ix)
            && cw::read_quantized_float(in, cw::height, out.iy)
            && cw::read_quantized_float(in, cw::ground, out.iz);
    }

    /// NEVER. A client does not predict a shell -- there is nothing of anybody's input in
    /// it -- so there is nothing here that a resimulation could put right, and a rollback
    /// for a round somebody else fired would be the world lurching for a tracer.
    static bool should_roll_back(const Quantized&, const Quantized&) {
        return false;
    }

    /// A birth record does not slide into another birth record. The round's position
    /// between the two ends of its life is worked out from the record, by whoever is
    /// drawing it, which is the whole design -- see the note on the component.
    static Quantized interpolate(const Quantized& from, const Quantized&, float) {
        return from;
    }
};

// ---- MissileState --------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::MissileState> {
    using Quantized = ashiato_gd::cockpit::MissileState;
    /// `hit` is an entity -- see SeekerState's traits.
    static constexpr bool references_entities = true;

    static void quantize(const ashiato_gd::cockpit::MissileState& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::cockpit::MissileState dequantize(const Quantized& value) {
        return value;
    }

    /// About 120 bits: a vehicle's position, a SHELL's velocity range -- a missile at burnout
    /// is well past the 400 m/s that `speed` holds, and a velocity that does not fit is
    /// clamped on the wire with nothing to say so -- twelve bits of age and nineteen of the
    /// rest, and one more for a missile that has not hit anything.
    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext& context) {
        cw::put_position(out, current.x, current.y, current.z);
        cw::serialize_quantized_float(out, current.vx, cw::muzzle);
        cw::serialize_quantized_float(out, current.vy, cw::muzzle);
        cw::serialize_quantized_float(out, current.vz, cw::muzzle);
        cw::serialize_quantized_float(out, current.age, cw::missile_age);
        out.write_unsigned_bits(current.type & 0xFu, 4);
        out.write_unsigned_bits(current.pylon & 0x7u, 3);
        out.write_unsigned_bits(current.surface & 0x7u, 3);
        out.write_unsigned_bits(current.client, 8);
        out.write_unsigned_bits(current.guided ? 1u : 0u, 1);
        out.write_unsigned_bits(current.ejected ? 1u : 0u, 1);
        if (context.userContext == nullptr) {
            out.write_bool(false);
            return;
        }
        EntityReferenceContext& references =
            *static_cast<EntityReferenceContext*>(context.userContext);
        (void)write_entity_reference(out, current.hit.entity, references);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext& context) {
        if (!cw::read_quantized_float(in, cw::ground, out.x)
            || !cw::read_quantized_float(in, cw::height, out.y)
            || !cw::read_quantized_float(in, cw::ground, out.z)
            || !cw::read_quantized_float(in, cw::muzzle, out.vx)
            || !cw::read_quantized_float(in, cw::muzzle, out.vy)
            || !cw::read_quantized_float(in, cw::muzzle, out.vz)
            || !cw::read_quantized_float(in, cw::missile_age, out.age)) {
            return false;
        }
        if (in.remaining_bits() < 4 + 3 + 3 + 8 + 1 + 1) {
            return false;
        }
        out.type = static_cast<std::uint8_t>(in.read_unsigned_bits(4));
        out.pylon = static_cast<std::uint8_t>(in.read_unsigned_bits(3));
        out.surface = static_cast<std::uint8_t>(in.read_unsigned_bits(3));
        out.client = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        out.guided = in.read_unsigned_bits(1) != 0u;
        out.ejected = in.read_unsigned_bits(1) != 0u;
        if (context.userContext == nullptr) {
            return false;
        }
        EntityReferenceContext& references =
            *static_cast<EntityReferenceContext*>(context.userContext);
        return read_entity_reference(in, references, out.hit);
    }

    /// NEVER: nobody predicts a missile, for the shell's reason.
    static bool should_roll_back(const Quantized&, const Quantized&) {
        return false;
    }

    /// The pose and the age slide between two ticks; what it is, which rail, whether it is
    /// guided and what it ended on do not.
    static Quantized interpolate(const Quantized& from, const Quantized& to, float alpha) {
        Quantized out = from;
        out.x = cw::lerp(from.x, to.x, alpha);
        out.y = cw::lerp(from.y, to.y, alpha);
        out.z = cw::lerp(from.z, to.z, alpha);
        out.vx = cw::lerp(from.vx, to.vx, alpha);
        out.vy = cw::lerp(from.vy, to.vy, alpha);
        out.vz = cw::lerp(from.vz, to.vz, alpha);
        out.age = cw::lerp(from.age, to.age, alpha);
        return out;
    }
};

// ---- Hull ------------------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::Hull> {
    using Quantized = ashiato_gd::cockpit::Hull;

    static void quantize(const ashiato_gd::cockpit::Hull& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::cockpit::Hull dequantize(const Quantized& value) {
        return value;
    }

    /// 8 + 1 + 3 + 4 + 8 + a kind (5, or 21 past kind 29) + 8: thirty-seven bits, sent when a craft is hit.
    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        out.write_unsigned_bits(current.left, 8);
        out.write_unsigned_bits(current.destroyed ? 1u : 0u, 1);
        out.write_unsigned_bits(current.cause & 0x7u, 3);
        out.write_unsigned_bits(current.weapon & 0xFu, 4);
        out.write_unsigned_bits(current.by, 8);
        ashiato_gd::cockpit::write_kind(out, current.by_kind);
        out.write_unsigned_bits(current.speed, 8);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        if (in.remaining_bits() < 8 + 1 + 3 + 4 + 8) {
            return false;
        }
        out.left = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        out.destroyed = in.read_unsigned_bits(1) != 0u;
        out.cause = static_cast<std::uint8_t>(in.read_unsigned_bits(3));
        out.weapon = static_cast<std::uint8_t>(in.read_unsigned_bits(4));
        out.by = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        if (!ashiato_gd::cockpit::read_kind(in, out.by_kind) || in.remaining_bits() < 8) {
            return false;
        }
        out.speed = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        return out.cause < ashiato_gd::cockpit::kHullCauseCount;
    }

    /// ON ANY CHANGE of what is left or of the kill. See Hull: this is the only way the pilot's own predicted craft
    /// ever learns it was hit, and nobody but the server ever writes it, so there is nothing to flap.
    static bool should_roll_back(const Quantized& predicted, const Quantized& authority) {
        return predicted.left != authority.left || predicted.destroyed != authority.destroyed;
    }

    /// Step: a hull is as damaged as the last record said, never halfway to the next.
    static Quantized interpolate(const Quantized& from, const Quantized&, float) {
        return from;
    }
};

// ---- SeekerState ---------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::SeekerState> {
    using Quantized = ashiato_gd::cockpit::SeekerState;
    /// THE TARGET IS AN ENTITY, and an entity id means nothing on another machine. This is
    /// what makes sync hand serialise and deserialise a reference context to map it through
    /// -- see sync's own examples/balls.cpp, which does the same with BallContact.
    static constexpr bool references_entities = true;

    static void quantize(const ashiato_gd::cockpit::SeekerState& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::cockpit::SeekerState dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext& context) {
        out.write_unsigned_bits(current.client, 8);
        out.write_unsigned_bits(current.type & 0xFu, 4);
        out.write_unsigned_bits(current.phase & 0x7u, 3);
        out.write_unsigned_bits(current.why & 0x7u, 3);
        cw::serialize_quantized_float(out, current.progress, cw::unit);
        // NO CONTEXT, NO TARGET, rather than a null dereference. With references_entities set
        // sync always supplies one; this is the difference between a missing diamond and a
        // crash if that ever stops being true.
        if (context.userContext == nullptr) {
            out.write_bool(false);
            return;
        }
        EntityReferenceContext& references =
            *static_cast<EntityReferenceContext*>(context.userContext);
        (void)write_entity_reference(out, current.target.entity, references);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext& context) {
        if (in.remaining_bits() < 8 + 4 + 3 + 3) {
            return false;
        }
        out.client = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        out.type = static_cast<std::uint8_t>(in.read_unsigned_bits(4));
        out.phase = static_cast<std::uint8_t>(in.read_unsigned_bits(3));
        out.why = static_cast<std::uint8_t>(in.read_unsigned_bits(3));
        if (!cw::read_quantized_float(in, cw::unit, out.progress)) {
            return false;
        }
        if (context.userContext == nullptr) {
            return false;
        }
        EntityReferenceContext& references =
            *static_cast<EntityReferenceContext*>(context.userContext);
        // MAPPED ON ARRIVAL: read_entity_reference fills `target.entity` with THIS machine's
        // entity when it already has it (ashiato-sync types.hpp, read_entity_reference), and
        // leaves it empty when it does not yet -- which is why lock_states() resolves the
        // reference again rather than trusting the field.
        return read_entity_reference(in, references, out.target);
    }

    /// NEVER. Nobody predicts a seeker; see the note on the component.
    static bool should_roll_back(const Quantized&, const Quantized&) {
        return false;
    }

    /// Step: a lock does not slide between two phases.
    static Quantized interpolate(const Quantized& from, const Quantized&, float) {
        return from;
    }
};

// ---- VehicleKind ---------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::VehicleKind> {
    using Quantized = ashiato_gd::cockpit::VehicleKind;

    static void quantize(const ashiato_gd::cockpit::VehicleKind& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::cockpit::VehicleKind dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        // FIVE BITS FOR EVERY KIND TO 29, TWENTY-ONE PAST THEM: `write_kind`. It was four bits until the water bomber
        // and five until lane/kinds (2026-09-18), each time written down here as what the next vehicle would cost.
        // A VehicleKind never changes, so it goes only in a full record and the wide form costs a craft once.
        ashiato_gd::cockpit::write_kind(out, current.kind);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        // `kNoKind` is not a craft; a record naming it is refused like any other malformed one.
        return ashiato_gd::cockpit::read_kind(in, out.kind) && out.kind != ashiato_gd::cockpit::kNoKind;
    }

    // A vehicle does not turn into a different vehicle in flight. If it did, the physics
    // body and the mesh would both have to be rebuilt, which is not something a
    // resimulation can do.
    static bool should_roll_back(const Quantized&, const Quantized&) {
        return false;
    }

    static Quantized interpolate(const Quantized& from, const Quantized&, float) {
        return from;
    }
};

// ---- Seats ---------------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::Seats> {
    using Quantized = ashiato_gd::cockpit::Seats;

    static void quantize(const ashiato_gd::cockpit::Seats& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::cockpit::Seats dequantize(const Quantized& value) {
        return value;
    }

    // Eight bits per client, which is exactly a sync ClientId including its 255 "nobody".
    // Packing it tighter would mean a second encoding of client ids to keep in step with
    // sync's, for bytes on a component that changes when somebody climbs in.
    //
    // TWO FORMS, the smaller written (lane/seats, 2026-09-18). The FOUR-SEAT form is the wire before this lane, four
    // occupant bytes, and a crew sitting below seat four never pays more than its form bit over it. The ABOARD form is
    // a count and, for each person, their seat's distance past the last one and their client: an empty craft -- nearly
    // every craft in the sky -- is six bits where it was thirty-two, and a seat far down a long cabin costs its wide
    // form only when somebody sits in it. A distance cannot name one seat twice.
    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        namespace ck = ashiato_gd::cockpit;
        bool low = true;
        unsigned aboard_bits = ck::kAboardCountBits;
        std::uint32_t next = 0;
        for (std::size_t i = 0; i < current.count; ++i) {
            low = low && current.aboard[i].seat < ck::kFirstLongSeat;
            aboard_bits += ck::seat_bits(current.aboard[i].seat - next) + 8u;
            next = current.aboard[i].seat + 1u;
        }
        if (low && 8u * ck::kFirstLongSeat <= aboard_bits) {
            out.write_unsigned_bits(0u, 1);
            for (std::uint32_t seat = 0; seat < ck::kFirstLongSeat; ++seat) {
                out.write_unsigned_bits(current.occupant(seat), 8);
            }
            return;
        }
        out.write_unsigned_bits(1u, 1);
        out.write_unsigned_bits(current.count, ck::kAboardCountBits);
        next = 0;
        for (std::size_t i = 0; i < current.count; ++i) {
            ck::write_seat(out, current.aboard[i].seat - next);
            out.write_unsigned_bits(current.aboard[i].client, 8);
            next = current.aboard[i].seat + 1u;
        }
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        namespace ck = ashiato_gd::cockpit;
        if (in.remaining_bits() < 1) {
            return false;
        }
        out = ck::Seats{};
        if (in.read_unsigned_bits(1) == 0) {
            if (in.remaining_bits() < 8 * ck::kFirstLongSeat) {
                return false;
            }
            for (std::uint32_t seat = 0; seat < ck::kFirstLongSeat; ++seat) {
                const auto client = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
                if (client != ck::kNoOccupant && !claim(out, static_cast<ck::SeatId>(seat), client)) {
                    return false;
                }
            }
            return true;
        }
        if (in.remaining_bits() < ck::kAboardCountBits) {
            return false;
        }
        const std::size_t count = in.read_unsigned_bits(ck::kAboardCountBits);
        if (count > ck::kMostAboard) {
            return false;
        }
        std::uint32_t next = 0;
        for (std::size_t i = 0; i < count; ++i) {
            ck::SeatId gap = 0;
            if (!ck::read_seat(in, gap) || in.remaining_bits() < 8) {
                return false;
            }
            const std::uint32_t seat = next + gap;
            const auto client = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
            if (seat >= ck::kMostSeats || client == ck::kNoOccupant
                || !claim(out, static_cast<ck::SeatId>(seat), client)) {
                return false;
            }
            next = seat + 1u;
        }
        return true;
    }

    /// A SEAT FOR A CLIENT NOT ALREADY ABOARD: a record naming one person in two seats is refused, not half-applied.
    static bool claim(ashiato_gd::cockpit::Seats& seats, ashiato_gd::cockpit::SeatId seat, std::uint8_t client) {
        for (std::size_t i = 0; i < seats.count; ++i) {
            if (seats.aboard[i].client == client) {
                return false;
            }
        }
        return seats.put(seat, client);
    }

    // TRUE on any difference, and this is what makes seats work at all.
    //
    // Who is aboard is never simulated by a client -- only the server decides it -- so a
    // predicted vehicle would otherwise leave somebody climbing in beside you sitting in
    // the incoming update, unapplied, until the aircraft happened to be corrected for an
    // unrelated reason. It costs one resimulation on an event that happens when a person
    // sits down.
    static bool should_roll_back(const Quantized& current, const Quantized& previous) {
        if (current.count != previous.count) {
            return true;
        }
        for (std::size_t i = 0; i < current.count; ++i) {
            if (current.aboard[i].seat != previous.aboard[i].seat
                || current.aboard[i].client != previous.aboard[i].client) {
                return true;
            }
        }
        return false;
    }

    // Step, not blend: nobody is half out of a seat.
    static Quantized interpolate(const Quantized& from, const Quantized&, float) {
        return from;
    }
};

// ---- PilotState ----------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::PilotState> {
    using Quantized = ashiato_gd::cockpit::PilotState;

    static void quantize(const ashiato_gd::cockpit::PilotState& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::cockpit::PilotState dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        cw::serialize_quantized_float(out, current.head_x, cw::reach);
        cw::serialize_quantized_float(out, current.head_y, cw::reach);
        cw::serialize_quantized_float(out, current.head_z, cw::reach);
        cw::write_quat(out, current.head_rot);
        cw::serialize_quantized_float(out, current.left_x, cw::reach);
        cw::serialize_quantized_float(out, current.left_y, cw::reach);
        cw::serialize_quantized_float(out, current.left_z, cw::reach);
        cw::write_quat(out, current.left_rot);
        cw::serialize_quantized_float(out, current.right_x, cw::reach);
        cw::serialize_quantized_float(out, current.right_y, cw::reach);
        cw::serialize_quantized_float(out, current.right_z, cw::reach);
        cw::write_quat(out, current.right_rot);
        cw::serialize_quantized_float(out, current.grip_left, cw::unit);
        cw::serialize_quantized_float(out, current.grip_right, cw::unit);
        ashiato_gd::cockpit::write_seat(out, current.seat);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        if (!cw::read_quantized_float(in, cw::reach, out.head_x)
            || !cw::read_quantized_float(in, cw::reach, out.head_y)
            || !cw::read_quantized_float(in, cw::reach, out.head_z)
            || !cw::read_quat(in, out.head_rot)
            || !cw::read_quantized_float(in, cw::reach, out.left_x)
            || !cw::read_quantized_float(in, cw::reach, out.left_y)
            || !cw::read_quantized_float(in, cw::reach, out.left_z)
            || !cw::read_quat(in, out.left_rot)
            || !cw::read_quantized_float(in, cw::reach, out.right_x)
            || !cw::read_quantized_float(in, cw::reach, out.right_y)
            || !cw::read_quantized_float(in, cw::reach, out.right_z)
            || !cw::read_quat(in, out.right_rot)
            || !cw::read_quantized_float(in, cw::unit, out.grip_left)
            || !cw::read_quantized_float(in, cw::unit, out.grip_right)) {
            return false;
        }
        return ashiato_gd::cockpit::read_seat(in, out.seat);
    }

    // Never. A tracked pose that disagrees with the server is not a prediction that was
    // wrong -- it is a later reading of the same head. Rewinding the world because
    // somebody moved their hand would be resimulating for nothing.
    static bool should_roll_back(const Quantized&, const Quantized&) {
        return false;
    }

    static Quantized interpolate(const Quantized& from, const Quantized& to, float alpha) {
        Quantized out = to;
        // Across a seat change these are measured in different frames, so blending them
        // would slide a pilot through the cockpit wall. Step instead; it is one frame.
        if (from.seat != to.seat) {
            return out;
        }
        out.head_x = cw::lerp(from.head_x, to.head_x, alpha);
        out.head_y = cw::lerp(from.head_y, to.head_y, alpha);
        out.head_z = cw::lerp(from.head_z, to.head_z, alpha);
        out.head_rot = cw::slerp(from.head_rot, to.head_rot, alpha);
        out.left_x = cw::lerp(from.left_x, to.left_x, alpha);
        out.left_y = cw::lerp(from.left_y, to.left_y, alpha);
        out.left_z = cw::lerp(from.left_z, to.left_z, alpha);
        out.left_rot = cw::slerp(from.left_rot, to.left_rot, alpha);
        out.right_x = cw::lerp(from.right_x, to.right_x, alpha);
        out.right_y = cw::lerp(from.right_y, to.right_y, alpha);
        out.right_z = cw::lerp(from.right_z, to.right_z, alpha);
        out.right_rot = cw::slerp(from.right_rot, to.right_rot, alpha);
        out.grip_left = cw::lerp(from.grip_left, to.grip_left, alpha);
        out.grip_right = cw::lerp(from.grip_right, to.grip_right, alpha);
        return out;
    }
};

// ---- PilotOwner ----------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::PilotOwner> {
    using Quantized = ashiato_gd::cockpit::PilotOwner;

    static void quantize(const ashiato_gd::cockpit::PilotOwner& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::cockpit::PilotOwner dequantize(const Quantized& value) {
        return value;
    }

    // 16 bits: a lobby will not hold 65k pilots, and ownership never changes often enough
    // for the width to matter. And the peer whole, 32 bits: a Godot peer id is a random
    // 32-bit number, and a truncated one names the wrong machine (LEARNINGS, PeerId).
    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        out.write_unsigned_bits(current.client & 0xFFFFu, 16);
        out.write_unsigned_bits(current.peer, 32);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        if (in.remaining_bits() < 16 + 32) {
            return false;
        }
        out.client = static_cast<std::uint32_t>(in.read_unsigned_bits(16));
        out.peer = static_cast<std::uint32_t>(in.read_unsigned_bits(32));
        return true;
    }

    static bool should_roll_back(const Quantized&, const Quantized&) {
        return false;
    }

    static Quantized interpolate(const Quantized& from, const Quantized&, float) {
        return from;
    }
};

// ---- CabinOwner ----------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::CabinOwner> {
    using Quantized = ashiato_gd::cockpit::CabinOwner;
    /// THE CRAFT IS AN ENTITY REFERENCE, mapped through sync's reference context like SeekerState's
    /// target -- and for that reason not quantized through the wire, which has no context to write one.
    static constexpr bool references_entities = true;

    static void quantize(const ashiato_gd::cockpit::CabinOwner& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::cockpit::CabinOwner dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext& context) {
        out.write_unsigned_bits(current.client, 8);
        ashiato_gd::cockpit::write_seat(out, current.seat);
        out.write_unsigned_bits(current.answer_count & 0xFu, 4);
        out.write_unsigned_bits(current.answer & 0xFu, 4);
        // NO CONTEXT, NO CRAFT, rather than a null dereference; see SeekerState.
        if (context.userContext == nullptr) {
            out.write_bool(false);
            return;
        }
        EntityReferenceContext& references =
            *static_cast<EntityReferenceContext*>(context.userContext);
        (void)write_entity_reference(out, current.vehicle.entity, references);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext& context) {
        if (in.remaining_bits() < 8) {
            return false;
        }
        out.client = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        if (!ashiato_gd::cockpit::read_seat(in, out.seat) || in.remaining_bits() < 4 + 4) {
            return false;
        }
        out.answer_count = static_cast<std::uint8_t>(in.read_unsigned_bits(4));
        out.answer = static_cast<std::uint8_t>(in.read_unsigned_bits(4));
        if (context.userContext == nullptr) {
            return false;
        }
        EntityReferenceContext& references =
            *static_cast<EntityReferenceContext*>(context.userContext);
        return read_entity_reference(in, references, out.vehicle);
    }

    /// NEVER. Nobody predicts a cabin.
    static bool should_roll_back(const Quantized&, const Quantized&) {
        return false;
    }

    static Quantized interpolate(const Quantized& from, const Quantized&, float) {
        return from;
    }
};

// ---- CabinSystems --------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::cockpit::CabinSystems> {
    using Quantized = ashiato_gd::cockpit::CabinSystems;

    static void quantize(const ashiato_gd::cockpit::CabinSystems& value, Quantized& out) {
        quantize_through_the_wire(value, out);
    }

    static ashiato_gd::cockpit::CabinSystems dequantize(const Quantized& value) {
        return value;
    }

    // The same widths CraftSystems carried them in: a byte a selector, and the switches masked to
    // the crew's, so an outside bit written here by mistake cannot travel on the crew's record.
    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        for (int i = 0; i < 4; ++i) {
            out.write_unsigned_bits(current.selector[i], 8);
        }
        out.write_unsigned_bits(current.flags & ashiato_gd::cockpit::kCrewFlags, 16);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        if (in.remaining_bits() < 4 * 8 + 16) {
            return false;
        }
        for (int i = 0; i < 4; ++i) {
            out.selector[i] = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        }
        out.flags = static_cast<std::uint16_t>(in.read_unsigned_bits(16));
        return true;
    }

    /// NEVER. Nobody predicts a cabin, and nothing a client simulates reads a switch.
    static bool should_roll_back(const Quantized&, const Quantized&) {
        return false;
    }

    static Quantized interpolate(const Quantized& from, const Quantized&, float) {
        return from;
    }
};

}  // namespace ashiato::sync


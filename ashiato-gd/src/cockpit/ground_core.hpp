#pragma once
/// THE GROUND AS A FUNCTION OF INTEGERS: a coast, mountain ranges, rolling land, valleys, lakes and flattened places
/// for towns and airfields, the same to the bit on every machine that runs this library.
///
/// WHY IT IS HERE. Static collision is not replicated (cockpit/agents.md, RULES 8): every peer builds the ground and
/// the simulation never mentions it again, so a peer whose hillside is a centimetre elsewhere predicts itself into
/// the server's. A world of 30 to 70 km at 16 m is sixteen million samples, which GDScript takes ten to seventeen
/// minutes over and this takes a quarter of a second (godotgames-drafts/2026-09-14/cockpit-terrain/report.md).
///
/// NO GODOT IN THIS FILE, and that is its whole reason to be apart from `ground_field.hpp`: the binding needs godot-cpp,
/// and a scratch program that measures a change to the function -- or proves one leaves a world bit for bit where it
/// was -- has to compile this without it. `ground_field.hpp` is the class GDScript sees; this is the ground.
///
/// NO FLOATING POINT IN THE HEIGHT. Perlin's gradient noise on lattices whose periods are powers of two metres, with
/// every fraction, fade and lerp in Q16 fixed point on int64, and every distance compared as a square. Integer
/// arithmetic cannot be contracted into a fused multiply-add or rounded by a libm, so the answer does not depend on
/// the compiler, the platform or the engine's precision. `>>` on a negative int64 is an arithmetic shift, which C++20
/// defines as floor; nothing here left-shifts or masks a negative number. `cockpit/tests/ground_field.gd` holds the
/// library to recorded hashes on both editors.
///
/// HEIGHTS ARE TICKS OF 1/32 m, exactly representable in a float32, and exactly the step of a Box3D height field whose
/// range is 65,535 steps of 1/32 m -- so the collision can hold the same numbers with no rounding between them.
///
/// THE WORLD IS THREE TUNED NUMBERS, required rather than defaulted here: its half-width, how tall its ranges stand,
/// and a seed. The game's values live in `cockpit/world/ground_tuning.gd` and nowhere else.
///
/// THREAD-SAFE TO READ. After construction every query is const over data that does not change, so the scenery's
/// worker threads may ask it while the main thread does.

#include <cstdint>
#include <unordered_map>
#include <vector>

namespace ashiato_gd {
namespace ground {

using i64 = std::int64_t;

/// Ticks in a metre. A height of 32 is 1 m.
inline constexpr i64 kTicksPerMetre = 32;
/// Below this in ticks, a water query found no water.
inline constexpr i64 kNoWater = -(i64(1) << 30);
/// THE DEEPEST THE GROUND GOES, metres under the sea: the open sea's floor, where the land fraction is clamped to -1.
/// Nothing in the function goes lower -- a lake's bed stops above -25 m, and towns and airfields stand on land -- so
/// the wire's height floor is read from this (`cockpit_components.hpp`, `wire::height`). Before, the wire's floor was a
/// typed -100 m, and a round into the open sea or a craft sunk to its bed clamped.
inline constexpr i64 kSeabedMetres = 150;
/// THE WORLD'S EDGE, metres from the origin on either axis: the most a tuned half-width may be (`GroundField`'s
/// `world_half`), and the wire's `ground` range, so nothing the ground puts in the world is past what the wire carries.
inline constexpr i64 kWorldEdgeMetres = 32768;

/// A RUNWAY END'S APPROACH, kept clear of the ground: from the end (x, z) on the centreline, out along `dir` (0 is +x,
/// 1 is +z, 2 is -x, 3 is -z) for `length` metres and `half_width` either side, no ground stands above its pad's level
/// plus one metre in 34 out (TERPS's 34:1 obstacle clearance surface). Outside that the cap rises one metre in
/// kCutSlope with the distance from it, sideways and past the far end, so a ridge across a final is cut as a valley
/// whose sides are no steeper than the ground was or 1 in 8, and never as a slot.
struct Funnel {
    i64 x = 0, z = 0;
    int dir = 0;
    i64 length = 0, half_width = 0;
};

/// AN AIRPORT'S GROUND, HANDED IN: a rectangle flattened at the mean of the ground over it, and the approaches off its
/// runway ends. Outside the rectangle the ground is held within one metre in kCutSlope of its level, a cutting or an
/// embankment no steeper than that; `margin` is how far towns and lakes keep off it. Its level is found by the function; the rest is the level's data
/// (cockpit/world/airfield.gd works it out from the airfield and air base files), so an airport is laid where its file
/// says and the ground makes room, rather than the ground's own strips being hunted for.
struct Pad {
    i64 x0 = 0, z0 = 0, x1 = 0, z1 = 0, margin = 0;
    std::vector<Funnel> funnels;
    /// Found by the function, in 1/1024 m on the tick grid, like a Strip's.
    i64 level = 0;
};

/// A WATERCOURSE THE LEVEL LAYS (lane/rivers, 2026-09-20): a centre line through whole metres with a river `width`
/// metres wide seated in it, and a corridor held clear either side. Optional and absent by default, so a world that
/// names none is bit for bit the world it was -- the same bargain `coast`, `sites_within` and `pads` were added on.
///
/// WHAT THIS CUTS AND WHAT IT DOES NOT. It seats the water: a bed `draught` metres under the surface across the
/// river's width, and a bank rising from the water's edge to the corridor's. It does NOT dig the canyon. The user
/// asked for canyons "200-300 metres deep ... and a high mountain on both sides", and a 250 m slot cut into ground
/// that stands 100 m above the sea would have its floor under the sea. So the DEPTH IS THE WALLS' JOB: the level lays
/// ranges either side through `MountainRange`, whose crests are worked out from the river's own level plus the depth
/// asked for (`cockpit/world/watercourse.gd`), and the depth from the rim to the water is that one number rather than
/// two numbers that have to agree.
///
/// THE WATER RUNS DOWNHILL AND NEVER UP. The level at each control point is the ground there, held to the lowest
/// reached so far along the line, so a river that crosses a rise does not climb it. Found by the function, in 1/1024 m
/// like a Strip's, so nothing types a water level beside a ground height.
struct River {
    /// The centre line, whole metres, two points or more.
    std::vector<i64> x, z;
    /// The water's width, metres.
    i64 width = 50;
    /// Half the corridor kept clear either side of the centre line, metres: the flyable floor of the canyon.
    i64 corridor = 125;
    /// How deep the water is over its bed, metres.
    i64 draught = 4;
    /// FOUND BY THE FUNCTION: the water's level along each leg, 1/1024 m, at stations `kRiverStation` metres apart
    /// from the leg's start to its end, never rising downstream.
    ///
    /// A LEVEL A LEG, NOT A LEVEL A CONTROL POINT. The first version kept one level per control point and interpolated
    /// straight between them, and a level author puts control points kilometres apart: where the ground dipped between
    /// two of them the surface stayed on the straight line and stood 46 m over the valley floor, a wall of water 50 m
    /// wide (tests/canyon.gd's transect, 2026-09-20). The stations are close enough that the water follows the ground
    /// down, and the monotone rule still stops it climbing back out.
    std::vector<std::vector<i64>> leg_levels;
    /// Found by the function: the bounds the carve can reach, whole metres.
    i64 x0 = 0, z0 = 0, x1 = 0, z1 = 0;
};

/// HOW FAR APART THE WATER'S LEVEL IS WORKED OUT ALONG A LEG, metres. Small enough that the surface follows a valley
/// floor rather than cutting the corner off it, and large enough that a 16 km river is a few hundred numbers found
/// once at construction rather than a sample per metre.
inline constexpr i64 kRiverStation = 32;

/// HOW FAR THE BANK RISES above the water between the river's edge and the corridor's, metres. Enough that the water
/// sits in something rather than lying on a plain, and little enough that the corridor stays flyable floor.
inline constexpr i64 kRiverBank = 6;

/// A CUT OR AN EMBANKMENT RISES ONE METRE IN THIS MANY off a pad's edge or a funnel's (lane/testfield, 2026-09-19). The
/// first cut let go over a fixed 400 m smoothstep, and where a 300 m ridge crossed a final it stood at 49.9 degrees and
/// read from the air as a scar; 1 in 8 is 7.1 degrees, a valley side.
inline constexpr i64 kCutSlope = 8;
/// How far off a funnel's side or past its end a town or a lake keeps, metres: a cut 1 in 8 reaches 1,600 m through
/// 200 m of ground above the cap.
inline constexpr i64 kFunnelKeep = 1600;
/// A funnel's cap rises one metre in this many out: TERPS's precision final obstacle clearance surface.
inline constexpr i64 kFunnelSlope = 34;

struct Tuning {
    /// Half the world square's side, metres. The coast's mean radius is `coast`/32 of it.
    i64 world_half = 0;
    /// How tall the ridged ranges stand at their full strength, metres. The highest ground is about 110 m more,
    /// from the lowland and the hills under them.
    i64 peak_height = 0;
    /// Added into every hash's salt, so seed 0 is the recorded world.
    i64 seed = 0;
    /// THE OPTIONAL THREE (lane/testfield, 2026-09-19), each at a value that leaves every recorded world bit for bit
    /// where it was. The coast's mean radius in 32nds of `world_half`: 21 is the island every world has had; at 96 the
    /// land fraction stays above 0.24 even in the square's corner, so there is no sea at all.
    i64 coast = 21;
    /// Towns, lakes and the ground's own strips are catalogued only with their centres within this many metres of the
    /// middle; 0 is anywhere. An all-land world otherwise catalogues sites out to its corners, past any edge band.
    i64 sites_within = 0;
    /// The airports the level lays. With any, the ground finds no strips of its own: these are its airfields.
    std::vector<Pad> pads;
    /// The watercourses the level lays. None is every world recorded before 2026-09-20.
    std::vector<River> rivers;
};

struct Lake {
    i64 cell_i, cell_j, x, z, r, depth, level, salt;
};
struct Town {
    i64 x, z, r, margin, level;
};
struct Strip {
    i64 x, z, half_long, half_wide, margin, level;
    /// How far the ground under the strip rose and fell before it was flattened, in the same 1/1024 m as `level`: the
    /// cutting and embankment it needed. Not on the wire or in the catalogue's ints; the probe reads it.
    i64 relief = 0;
};

/// THE FUNCTION. Built whole by its constructor: the lake and site catalogue is found once, then every query is a
/// pure function of (x, z) in integer metres.
class Field {
public:
    explicit Field(const Tuning& tuning);

    /// The ground at integer metres, in ticks of 1/32 m.
    i64 height_ticks(i64 x, i64 z) const;
    /// The water standing at a place, in ticks: a lake's level, the sea's 0 over ground below it, or kNoWater.
    i64 water_ticks(i64 x, i64 z) const;
    /// A lake's drawn water reaches this far from its centre, metres; its rim holds the ground above the level to here.
    static i64 water_radius(const Lake& lake);

    const Tuning& tuning() const { return tuning_; }
    const std::vector<Lake>& lakes() const { return lakes_; }
    const std::vector<Town>& towns() const { return towns_; }
    const std::vector<Strip>& airfields() const { return airfields_; }
    /// The pads handed in, each with the level the function found for it.
    const std::vector<Pad>& pads() const { return pads_; }
    /// The rivers handed in, each with the levels and the bounds the function found for it.
    const std::vector<River>& rivers() const { return rivers_; }

private:
    struct Site {
        bool strip;
        int index;
    };

    i64 hash3(i64 a, i64 b, i64 salt) const;
    i64 gradient(i64 x, i64 z, int shift, i64 salt) const;
    /// [height in 1/1024 m, range mask in Q16] before lakes and sites.
    void base_and_range(i64 x, i64 z, i64& height, i64& ranged) const;
    i64 base(i64 x, i64 z) const;
    i64 apply_lakes(i64 x, i64 z, i64 h) const;
    i64 apply_sites(i64 x, i64 z, i64 h) const;
    i64 apply_pads(i64 x, i64 z, i64 h) const;
    i64 apply_rivers(i64 x, i64 z, i64 h) const;
    /// THE NEAREST RIVER TO A POINT: its distance in whole metres into `away` and the water's level there, in 1/1024 m,
    /// into `level`; null when no river's corridor reaches the point. One search, so the carve and the water query
    /// cannot disagree about where the river is.
    const River* nearest_river(i64 x, i64 z, i64& away, i64& level) const;
    /// Whether a site of `room` metres' reach round (x, z) may be catalogued: within `sites_within`, and clear of every
    /// pad and funnel. Always true with neither, so a world without them finds exactly the sites it did.
    bool may_place(i64 x, i64 z, i64 room) const;
    void level_the_pads();
    void level_the_rivers();
    const Lake* lake_in_cell(i64 i, i64 j) const;
    bool near_a_lake(i64 x, i64 z, i64 room) const;
    bool near_a_town(i64 x, i64 z, i64 room) const;
    void find_lakes();
    void find_sites();
    void file_the_sites();

    Tuning tuning_;
    i64 island_r_ = 0;
    i64 mountain_ = 0;
    i64 salt_base_ = 0;
    i64 lake_cells_ = 0;
    std::vector<Lake> lakes_;
    /// Index into lakes_ per lake cell, -1 for none; (2 * lake_cells_)^2 entries, i outer.
    std::vector<int> lake_grid_;
    std::vector<Town> towns_;
    std::vector<Strip> airfields_;
    std::vector<Pad> pads_;
    std::vector<River> rivers_;
    std::unordered_map<i64, std::vector<Site>> site_cells_;
};

}  // namespace ground
}  // namespace ashiato_gd

// A LAMP A TOWN SHOWS AT NIGHT, as a point of light that keeps its candela's light at every distance: the red obstruction
// lights on its tall buildings (TownView.obstruction_lights_on) and the lamps along its streets (street_lights_along), whose
// pools on the street lamp_pool.gdshader draws near and this point carries far.
//
// ONE INSTANCE, NEAR AND FAR. A lamp is not handed from a near drawing to a far one: the same quad is a lantern-sized spot
// close to and a point at the pixel floor far off, so no distance draws it twice or not at all. Asked for on 2026-09-15,
// "street lights and obstruction lights on buildings, absolutely, yes".
//
// THE LIGHT IS ITS CANDELA, NOT A GUESS. INSTANCE_CUSTOM.x is the lamp's intensity in candela (ICAO Annex 14 Table 6-3 for
// the obstruction lights) and `light_per_candela` turns it into the luminance-times-area the far lights carry, from the
// windows' own light (TownTuning.LIGHT_PER_CANDELA), so a lamp and a window keep the proportion they have in life. That
// light, in pixels, is spread over a separable tent at least `point_pixels` half-wide, as town_lights.gdshaderinc does and
// for its reason: a tent sampled at pixel centres sums to the same light wherever its middle falls, so a point neither
// flickers crossing pixels nor differs between two eyes. Close to, where the light would put a pixel past `peak_most`, the
// tent grows -- to `grow_most` pixels at most -- and past that it is simply as bright as it is.
//
// FLASHING FROM THE TICK, NOT FROM TIME. A medium-intensity light flashes on `flash_phase`, the one number TownView.show_flash
// hands over from the simulation's tick, so every light in a town flashes together (ICAO 6.3.32: "shall flash
// simultaneously") and two views of one tick agree. No TIME, which is this machine's time since start; no FRAGCOORD; nothing
// per instance in the flash.
//
// DIMMED BY THE SCENE'S OWN FOG, NOT SKIPPED BY IT, as the far lights are: the engine's fog on an additive quad adds the fog
// colour over the whole quad, so this is fog_disabled and takes scene_fog_transmission itself with the density the level
// hands over (TownView.show_fog). AND BY THE LOW MIST between the eye and it (world/shaders/mist.gdshaderinc), taken once a
// vertex at the lamp's own place, as the far lights take it: drawn after the mist pass, an additive lamp is dimmed by what
// the mist takes (tests/lint.gd holds every see-through shader to it).
//
// STOOD OFF WHAT IT IS ON, ALONG THE INSTANCE'S OUT AXIS and up by INSTANCE_CUSTOM.w of that, by STAND_OFF radii. A quad
// faces the eye, so on a surface seen at an angle its corners lean into it by up to its radius times the root of two; a
// corner light's out axis is the diagonal between two walls, which clears each wall by STAND_OFF over the root of two, and a
// roof's light rises by the same, clear of the roof. Placed through billboard.gdshaderinc: steady on the double build.
//
// INSTANCE: basis columns along, up and out, orthonormal; INSTANCE_CUSTOM x candela, y what it is (1 a steady red, 2 a
// flashing red), z the lantern's size in metres, w how far it rises as a share of its stand-off (1 on a roof, 0 on a wall).
#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/scene_fog.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
#include "res://world/shaders/lamp_pool.gdshaderinc"

// The time of day's share of a lamp's light: 0 by day, 1 at night. TownView.light_windows, from the windows' own share.
uniform float lamps = 0.0;
// The environment's fog density, as the level last handed it.
uniform float fog_density = 0.0;
// TownTuning.LIGHT_PER_CANDELA.
uniform float light_per_candela = 0.011;
// The least half-width of a lamp, in pixels: TownTuning.FAR_LIGHT_PIXELS, the far lights' own floor.
uniform float point_pixels = 1.5;
// The brightest a pixel is drawn at before the lamp is drawn wider, and the widest it is drawn so: TownTuning.LAMP_PEAK_MOST
// and LAMP_GROW_MOST.
uniform float peak_most = 4.0;
uniform float grow_most = 3.0;
// The illuminance at the eye over which a lamp is seen, how far over it the floor has eased in, and the least peak a seen lamp
// is drawn at: TownTuning.LAMP_SEEN_LUX, LAMP_SEEN_BAND and LAMP_SEEN_PEAK.
uniform float seen_lux = 0.000001;
uniform float seen_band = 4.0;
uniform float seen_peak = 0.1;
// TownTuning.OBSTRUCTION_RED.
uniform vec3 obstruction_red : source_color = vec3(1.0, 0.06, 0.03);
// A street lamp's colour, the share of its light it shows off its beam, the street's reflectance and where its pool hands its
// light over: TownTuning.STREET_LIGHT_COLOUR, STREET_LIGHT_SIDE_SHARE, ROAD_REFLECTANCE and POOL_TO.
uniform vec3 street_colour : source_color = vec3(1.0, 0.62, 0.26);
uniform float street_side_share = 0.15;
uniform float road_reflectance = 0.08;
uniform float pool_to = 1500.0;
// TownTuning.night_adaptation(): see lamp_pool.gdshader.
uniform float night_adaptation = 1.0;
// Where the town's flash is in its cycle, 0..1, handed over from the tick; how much of the cycle a flash is on, and how
// much of it the flash takes to come on and to go off.
uniform float flash_phase = 0.0;
uniform float flash_on = 0.25;
uniform float flash_ease = 0.05;

// How many of its own radii a lamp stands off what it is on. See the top.
const float STAND_OFF = 2.0;

// Which corner of the quad this is, -1..1 each way.
varying vec2 corner;
// The lamp's colour at its peak. FLAT, so every pixel of the quad has exactly the vertex's value.
varying flat vec3 peak_colour;

// A FLASH, 0..1, at `phase` of its cycle: on over `flash_on` of the cycle, eased in and out over `flash_ease`.
float lamp_flash(float phase) {
	return smoothstep(0.0, flash_ease, phase) * (1.0 - smoothstep(flash_on - flash_ease, flash_on, phase));
}

void vertex() {
	vec3 centre_view = MODELVIEW_MATRIX[3].xyz;
	float away = max(length(centre_view), 1.0);
	// METRES A PIXEL at this distance, off the projection and the viewport this eye is drawn into -- its size, not its sign:
	// PROJECTION_MATRIX[1][1] is negative on the RenderingDevice renderers (town_lights.gdshaderinc).
	float metres_per_pixel = away * 2.0 / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);
	float on = mix(1.0, lamp_flash(flash_phase), step(1.5, INSTANCE_CUSTOM.y));
	// A STREET LAMP (kind 0) is a lantern that throws its light down: seen from below it shows its glass as the cosine from
	// straight down, and from the side or above no less than `street_side_share` of it. And its pool on the street sends the
	// eye a share of the lamp's light too, which the pool itself draws near and this point carries far, across the one band
	// lamp_pool.gdshaderinc names. An obstruction light shows all of its candela every way.
	float street = 1.0 - step(0.5, INSTANCE_CUSTOM.y);
	vec3 up_view = normalize(mat3(MODELVIEW_MATRIX)[1]);
	float looks_up = dot(-centre_view / away, up_view);
	float lantern = mix(1.0, max(street_side_share, -looks_up), street);
	float pool = street * lamp_pool_candela(1.0, road_reflectance, night_adaptation, looks_up) * lamp_pool_far_share(away, pool_to);
	float candela = INSTANCE_CUSTOM.x * lamps * on * (lantern + pool);
	// The light IN CLEAR AIR, in luminance times square pixels: candela, at the time of day's share, flashing. The fog comes last.
	float light = candela * light_per_candela / (metres_per_pixel * metres_per_pixel);
	float least = max(0.5 * INSTANCE_CUSTOM.z / metres_per_pixel, point_pixels);
	float half_pixels = clamp(sqrt(light / peak_most), least, max(least, grow_most));
	// A separable tent half_pixels wide holds half_pixels squared times its peak.
	float peak = light / (half_pixels * half_pixels);
	// A LAMP THE EYE WOULD SEE IN CLEAR AIR IS NOT LOST FOR BEING SPREAD OVER PIXELS: the illuminance it would put on the eye
	// with no air between, in lux, against night's threshold (Allard's law), and a lamp over it drawn at no less than
	// `seen_peak`. See TownTuning.LAMP_SEEN_LUX.
	peak = max(peak, seen_peak * smoothstep(seen_lux, seen_lux * seen_band, candela / (away * away)));
	// AND THEN THE FOG, ON EVERYTHING, THE FLOOR INCLUDED: a floor after the transmission would be a lamp shining through fog
	// that stops its light, and the fog is never skipped (tests/town_lights_shot.gd --fog-check holds the lamps to it).
	peak *= scene_fog_transmission(away, fog_density);
	// The lamp's place in the world from the eye and the view's own rotation, never INV_VIEW_MATRIX (the double build's).
	peak *= 1.0 - mist_along(EYE_POSITION_WORLD, EYE_POSITION_WORLD + transpose(mat3(VIEW_MATRIX)) * centre_view, mist_clock).a;
	peak_colour = mix(obstruction_red, street_colour, street) * peak;
	// A lamp with nothing to give collapses to its centre and costs no pixels.
	float radius = half_pixels * metres_per_pixel * step(1e-5, peak);
	corner = VERTEX.xy;
	// A street lamp hangs in the open over its street, so it only rises, clear of the street under it; an obstruction light
	// stands off its corner too.
	vec3 out_view = normalize(mat3(MODELVIEW_MATRIX)[2]) * (1.0 - street);
	vec3 offset_view = (out_view + up_view * INSTANCE_CUSTOM.w) * (radius * STAND_OFF) + vec3(corner * radius, 0.0);
	VERTEX = BILLBOARD_LOCAL_FROM_VIEW(offset_view);
}

void fragment() {
	vec2 tent = max(1.0 - abs(corner), vec2(0.0));
	ALBEDO = peak_colour * tent.x * tent.y;
}

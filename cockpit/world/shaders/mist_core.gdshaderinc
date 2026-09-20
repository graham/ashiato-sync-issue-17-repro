// THE MIST'S MATHS, AND NOTHING ELSE: the constants and functions `mist_along` is made of, with no uniform, no include and no
// Godot built-in, so that ONE copy is read by both the Godot shaders (through mist.gdshaderinc, which declares the `mist_*`
// globals it reads) and the compute mist (world/shaders/mist_half.glsl, which #defines the same names onto its uniform buffer).
// Written in the part of the language both accept: GLSL 450 and Godot's shading language agree on every line here.
// NOT INCLUDED DIRECTLY by anything but those two: a compute file's #include is not followed inside an included file
// (servers/rendering/rendering_device_binds.cpp, RDShaderFile::parse_versions_from_text), so this may include nothing.

// The stratus is gone on a ray under the first |dir.y| and whole past the second (1.1 and 9.8 degrees from level), and gone
// along a ray past `mist_stratus_look.z` metres, whole within this share of it. Both wide on purpose: see mist_along.
const vec2 M_STRATUS_LEVEL = vec2(0.02, 0.17);
const float M_STRATUS_NEAR = 0.2;
// The angle fade is weighed in only past the first of these metres along the ray and whole past the second: see mist_along.
const vec2 M_STRATUS_LEVEL_FROM = vec2(1500.0, 3000.0);
// How many towns a dome loop reads: MistTuning.MOST_TOWNS (tests/mist.gd holds them equal).
const int M_MOST_TOWNS = 8;

float mist_hash(vec2 m_p) {
	m_p = fract(m_p * vec2(123.34, 456.21));
	m_p += dot(m_p, m_p + 45.32);
	return fract(m_p.x * m_p.y);
}

// VALUE NOISE ON A LATTICE WRAPPED EVERY 128 CELLS, the terrain's rule (terrain_noise.gdshaderinc, `wrap_cell`): a hash of a
// large index loses its fraction in float32 and draws straight seams, so each corner is wrapped before it is hashed.
float mist_noise(vec2 m_p) {
	vec2 m_cell = floor(m_p);
	vec2 m_f = fract(m_p);
	m_f = m_f * m_f * (3.0 - 2.0 * m_f);
	vec2 m_c00 = m_cell - 128.0 * floor((m_cell + 64.0) / 128.0);
	vec2 m_c10 = (m_cell + vec2(1.0, 0.0)) - 128.0 * floor((m_cell + vec2(1.0, 0.0) + 64.0) / 128.0);
	vec2 m_c01 = (m_cell + vec2(0.0, 1.0)) - 128.0 * floor((m_cell + vec2(0.0, 1.0) + 64.0) / 128.0);
	vec2 m_c11 = (m_cell + vec2(1.0, 1.0)) - 128.0 * floor((m_cell + vec2(1.0, 1.0) + 64.0) / 128.0);
	return mix(mix(mist_hash(m_c00), mist_hash(m_c10), m_f.x), mix(mist_hash(m_c01), mist_hash(m_c11), m_f.x), m_f.y);
}

// THE CHART AT A POINT: (the ground's height, its RELIEF -- the ground less the ground round it, below zero on a valley floor;
// see MistChart). A FLAT CHART IS NOT READ: the island's ground is one height everywhere, and a texture fetch a pixel is part of
// what the pass costs a headset (step2-cost, 2026-09-15); a flat has no relief.
vec2 mist_chart_at(vec2 m_xz) {
	if (mist_ground_range.y - mist_ground_range.x < 0.01) {
		return vec2(mist_ground_range.x, 0.0);
	}
	vec2 m_uv = clamp((m_xz - mist_chart_frame.xy) / max(mist_chart_frame.z, 1.0), vec2(0.004), vec2(0.996));
	return textureLod(mist_ground, m_uv, 0.0).rg;
}

float mist_ground_at(vec2 m_xz) {
	return mist_chart_at(m_xz).x;
}

// HOW MUCH THICKER THE HAZE LIES OVER GROUND OF THIS RELIEF (step 4, the valley pools): 1 on a flat, a steady slope or a ridge,
// rising to 1 + `mist_pool.x` where the ground lies `mist_pool.y` metres or more below the ground round it. See MistTuning.
float mist_pool_at(float m_relief) {
	return 1.0 + mist_pool.x * smoothstep(0.0, max(mist_pool.y, 1.0), -m_relief);
}

// Winitzki's approximation to erf, within 0.00035 everywhere.
float mist_erf(float m_x) {
	float m_x2 = m_x * m_x;
	return sign(m_x) * sqrt(1.0 - exp(-m_x2 * (1.2732395 + 0.147 * m_x2) / (1.0 + 0.147 * m_x2)));
}

// The integral over `len` metres of exp(-(y - ground) / h), with y running straight from `ya` to `yb`.
float mist_exp_integral(float m_ya, float m_yb, float m_len, float m_ground, float m_h) {
	float m_g = min(m_ground, min(m_ya, m_yb));
	float m_ea = exp(-(m_ya - m_g) / m_h);
	float m_eb = exp(-(m_yb - m_g) / m_h);
	float m_dy = m_yb - m_ya;
	if (abs(m_dy) < m_h * 0.01) {
		return m_len * 0.5 * (m_ea + m_eb);
	}
	return m_len * m_h * (m_ea - m_eb) / m_dy;
}

// The integral over `len` metres of exp(-((y - centre) / w)^2), y running straight from `ya` to `yb`.
float mist_band_integral(float m_ya, float m_yb, float m_len, float m_centre, float m_w) {
	float m_dy = m_yb - m_ya;
	if (abs(m_dy) < m_w * 0.05) {
		float m_m = (0.5 * (m_ya + m_yb) - m_centre) / m_w;
		return m_len * exp(-m_m * m_m);
	}
	return m_len * m_w * 0.8862269 * (mist_erf((m_yb - m_centre) / m_w) - mist_erf((m_ya - m_centre) / m_w)) / m_dy;
}

// A TOWN'S HAZE DOME over one step of a ray, [ta, tb]: for each town (a texel of `mist_towns`: centre x, ground y, z and radius;
// `mist_town` = count, density at the ground per metre, height it falls by e over, spread in radii), the ray taken where it comes
// nearest the town's axis in plan, the dome's Gaussian across it read there, and its height falling exactly along the stretch
// of the step that crosses the dome -- the Gaussian's own width along a straight line, sqrt(pi) spreads over how level the ray is.
// A town more than three spreads from the ray is skipped: under a ten-thousandth of its density.
float mist_dome_tau(vec3 m_eye, vec3 m_dir, float m_ta, float m_tb) {
	float m_sum = 0.0;
	int m_count = min(int(mist_town.x), M_MOST_TOWNS);
	float m_flat = max(length(m_dir.xz), 0.001);
	for (int m_k = 0; m_k < m_count; m_k++) {
		vec4 m_town = texelFetch(mist_towns, ivec2(m_k, 0), 0);
		float m_spread = max(m_town.w * mist_town.w, 1.0);
		float m_at = clamp(dot(m_town.xz - m_eye.xz, m_dir.xz) / (m_flat * m_flat), m_ta, m_tb);
		vec3 m_near = m_eye + m_dir * m_at;
		float m_off = length(m_near.xz - m_town.xz) / m_spread;
		if (m_off > 3.0) {
			continue;
		}
		float m_chord = min(1.7724539 * m_spread / m_flat, m_tb - m_ta);
		float m_from = clamp(m_at - 0.5 * m_chord, m_ta, max(m_tb - m_chord, m_ta));
		float m_until = min(m_tb, m_from + m_chord);
		float m_ya = m_eye.y + m_dir.y * m_from;
		float m_yb = m_eye.y + m_dir.y * m_until;
		m_sum += mist_town.y * exp(-m_off * m_off) * mist_exp_integral(m_ya, m_yb, m_until - m_from, m_town.y, max(mist_town.z, 1.0));
	}
	return m_sum;
}

// The mist between `eye` and `to`: rgb the colour it puts back, a how much of what is behind it it takes away.
// EVERY LOCAL AND PARAMETER IN HERE IS `m_`-PREFIXED: a host shader's own varyings and uniforms share the scope, and the
// first include redefined beacon.gdshaderinc's `lit` and broke the runway lights (SHADER ERROR, 2026-09-15).
vec4 mist_along(vec3 m_eye, vec3 m_to, float m_time) {
	if (mist_haze.x <= 0.0 && mist_stratus.x <= 0.0) {
		return vec4(0.0);
	}
	vec3 m_ray = m_to - m_eye;
	float m_reach = length(m_ray);
	if (m_reach < 0.01) {
		return vec4(0.0);
	}
	vec3 m_dir = m_ray / m_reach;
	float m_bottom = mist_ground_range.x - 1.0;
	float m_top = mist_ground_range.y + mist_ceiling;
	float m_t0 = 0.0;
	float m_t1 = min(m_reach, max(mist_reach, 1.0));
	if (abs(m_dir.y) > 1e-6) {
		float m_ta = (m_bottom - m_eye.y) / m_dir.y;
		float m_tb = (m_top - m_eye.y) / m_dir.y;
		m_t0 = max(m_t0, min(m_ta, m_tb));
		m_t1 = min(m_t1, max(m_ta, m_tb));
	} else if (m_eye.y > m_top || m_eye.y < m_bottom) {
		return vec4(0.0);
	}
	if (m_t1 <= m_t0) {
		return vec4(0.0);
	}
	int m_steps = max(mist_steps, 1);
	float m_step_len = (m_t1 - m_t0) / float(m_steps);
	float m_haze_height = max(mist_haze.y, 1.0);
	float m_stratus_height = mist_stratus.y;
	float m_stratus_width = max(mist_stratus.z, 1.0);
	float m_phase = pow(clamp(dot(m_dir, mist_towards_sun), 0.0, 1.0), mist_sun.y);
	vec3 m_lit = mist_colour.rgb + mist_sun_colour.rgb * m_phase * mist_sun.x;
	vec2 m_wander = vec2(m_time, m_time * 0.6) * mist_sun.z;
	float m_haze_reach = m_haze_height * 6.0;
	float m_band_reach = m_stratus_width * 3.0;
	float m_transmit = 1.0;
	float m_stratus_sum = 0.0;
	vec3 m_light = vec3(0.0);
	for (int m_i = 0; m_i < m_steps; m_i++) {
		float m_ta = m_t0 + m_step_len * float(m_i);
		float m_tb = m_ta + m_step_len;
		float m_ya = m_eye.y + m_dir.y * m_ta;
		float m_yb = m_eye.y + m_dir.y * m_tb;
		// THE GROUND AT BOTH ENDS OF THE STEP. The stratus reads the lower end's: on a ray down to the ground, where it meets it.
		vec3 m_a = m_eye + m_dir * m_ta;
		vec3 m_b = m_eye + m_dir * m_tb;
		vec2 m_chart_a = mist_chart_at(m_a.xz);
		vec2 m_chart_b = mist_chart_at(m_b.xz);
		float m_ground_a = m_chart_a.x;
		float m_ground_b = m_chart_b.x;
		bool m_rising = m_ya < m_yb;
		float m_ground = m_rising ? m_ground_a : m_ground_b;
		float m_lowest = min(m_ya, m_yb) - m_ground;
		float m_highest = max(m_ya, m_yb) - m_ground;
		float m_band_y = m_ground + m_stratus_height;
		float m_tau = 0.0;
		float m_stratus_tau = 0.0;
		// THE HAZE, EACH HALF OF THE STEP OVER THE LOWER GROUND OF ITS OWN TWO ENDS (the step's start, middle and end), and only a
		// half that comes within six haze heights of it: past that it is under a 400th of its density, and its noise is not worth
		// reading. NOT ONE GROUND A STEP, READ WHERE THE STEP IS LOWEST: that end is the eye on a ray rising a hair to a peak and
		// the peak on a ray falling a hair to it, so above the eye's horizon the ray was the valley's height over the ground and
		// below it a few metres -- a line 42/255 across every mountain at the eye's height (terrain's B1 over_town, alpine;
		// horizon-main048, horizon_jump.py). NOR THE END NEAREST ITS OWN GROUND, NOR EACH HALF OVER ITS OWN END'S: a rising ray's
		// start or middle is then under the peak's ground, `mist_exp_integral` takes it as full density there, and near level
		// that drew a soft band at the same height, 27 and 13/255 (fix-both-ends, fix-split). The lower of a half's two ends is
		// under no point of it, so nothing is clamped and nothing turns on which way the ray goes: 1.1/255, the mist-off picture's
		// own (fix-three). Over flat ground every ground is one and the halves sum to the whole step's integral.
		if (mist_haze.x > 0.0) {
			float m_ym = 0.5 * (m_ya + m_yb);
			float m_half = 0.5 * m_step_len;
			vec2 m_chart_m = mist_chart_at((m_eye + m_dir * (0.5 * (m_ta + m_tb))).xz);
			float m_ground_m = m_chart_m.x;
			float m_near_ground = min(m_ground_a, m_ground_m);
			float m_far_ground = min(m_ground_m, m_ground_b);
			// THE POOL OVER EACH HALF (step 4), read at the same lower end its ground is: the relief comes with the height, no fetch more.
			float m_near_pool = mist_pool_at(m_ground_a <= m_ground_m ? m_chart_a.y : m_chart_m.y);
			float m_far_pool = mist_pool_at(m_ground_m <= m_ground_b ? m_chart_m.y : m_chart_b.y);
			if (min(m_ya, m_ym) - m_near_ground < m_haze_reach) {
				float m_breakup_a = mist_noise((m_a.xz + m_wander) * mist_haze.w);
				m_tau += mist_haze.x * m_near_pool * (1.0 - mist_haze.z * m_breakup_a) * mist_exp_integral(m_ya, m_ym, m_half, m_near_ground, m_haze_height);
			}
			if (min(m_ym, m_yb) - m_far_ground < m_haze_reach) {
				float m_breakup_b = mist_noise((m_b.xz + m_wander) * mist_haze.w);
				m_tau += mist_haze.x * m_far_pool * (1.0 - mist_haze.z * m_breakup_b) * mist_exp_integral(m_ym, m_yb, m_half, m_far_ground, m_haze_height);
			}
		}
		// THE STRATUS, only on a step that comes within three of its widths of the band, read where the ray is nearest it, and
		// faded out along the ray past `mist_stratus_look.z`.
		if (mist_stratus.x > 0.0 && m_lowest < m_stratus_height + m_band_reach && m_highest > m_stratus_height - m_band_reach) {
			float m_at_band = abs(m_dir.y) > 1e-6 ? clamp((m_band_y - m_eye.y) / m_dir.y, m_ta, m_tb) : 0.5 * (m_ta + m_tb);
			// AND LESS ON A RAY NEAR LEVEL: there the band is squashed into slivers a few pixels tall wherever it lies, and capped
			// and lit they drew white lines through the peaks' feet from 300 m up (step2-try7-stratus, mist_city-fine-evening and
			// fields-fine-evening). A NARROW FADE WAS AN EDGE: at 0.6 to 3.4 degrees the slivers stayed (step2-try8-stratus), and under
			// a patch at night the distance fade's own end, 4 to 6.4 km, drew an arc across the sky (step2-try8, grass-plain-night).
			// Both are long ramps now, so neither reads as a place. In the WORLD'S directions, not the screen's: a nod of the head
			// moves nothing (tests/scenery_shot.gd `mist_nod`), only the eye's own height and distance do (`mist_climb`).
			// ONLY PAST 1.5 KM (team-lead): flying low beside the band, a patch a kilometre off is within a few degrees of level, and
			// that low cloud round the eye is the atmosphere asked for; the lines came from the far band (`mist_low` holds it).
			// AND NOT FOR AN EYE UNDER THE BAND'S MIDDLE, ramped over one band width: seen from just beneath, a near patch near level
			// was a pale lens over a town at night, its underside lighter than the sky (cockpit-streetlights' step2c
			// above/town-plain-night-clear-01km, the eye at 160 m under a band at 200). Seen from above (`mist_low`) it stays; a deck
			// overhead at a steeper angle passes the angle fade anyway (`mist_deck`).
			float m_beneath = smoothstep(0.0, m_stratus_width, m_band_y - m_eye.y);
			float m_far = max(smoothstep(M_STRATUS_LEVEL_FROM.x, M_STRATUS_LEVEL_FROM.y, m_at_band), m_beneath);
			float m_level = mix(1.0, smoothstep(M_STRATUS_LEVEL.x, M_STRATUS_LEVEL.y, abs(m_dir.y)), m_far);
			float m_along = 1.0 - smoothstep(mist_stratus_look.z * M_STRATUS_NEAR, mist_stratus_look.z, m_at_band);
			// NOTHING READ WHERE BOTH FADES HAVE TAKEN IT ALL: the fades are worked out first, and a ray they leave under a thousandth
			// of the band reads no noise and no erf (step2-cost, 2026-09-15). The look is the same.
			if (m_level * m_along > 0.001) {
				vec2 m_crossing = (m_eye + m_dir * m_at_band).xz - m_wander;
				float m_cover_noise = mist_noise(m_crossing * mist_stratus.w);
				if (mist_stratus_look.x > 0.0) {
					m_cover_noise = mix(m_cover_noise, m_cover_noise * 0.65 + mist_noise(m_crossing * mist_stratus.w * 2.7) * 0.35,
						mist_stratus_look.x);
				}
				m_stratus_tau = mist_stratus.x * smoothstep(mist_stratus_cover.x, mist_stratus_cover.y, m_cover_noise) * m_along
					* mist_band_integral(m_ya, m_yb, m_step_len, m_band_y, m_stratus_width);
				// NO MORE THAN A PATCH'S WORTH ON ONE RAY: seen edge-on from near its own height, the band ran kilometres along a ray
				// and summed to an opaque white line along the whole horizon and across every peak (step2-try4, fields-fine-day and
				// mist_city-plain-evening, with the reach already capped). Capped, a layer edge-on is as translucent as one patch.
				m_stratus_tau = min(m_stratus_tau, max(mist_stratus_look.w - m_stratus_sum, 0.0)) * m_level;
			}
			m_stratus_sum += m_stratus_tau;
			m_tau += m_stratus_tau;
		}
		// THE TOWNS' DOMES (step 3), lit as the haze is, and at night putting back the towns' window light besides.
		float m_dome_tau = mist_town.y > 0.0 ? mist_dome_tau(m_eye, m_dir, m_ta, m_tb) : 0.0;
		m_tau += m_dome_tau;
		if (m_tau <= 0.0) {
			continue;
		}
		// A LITTLE VOLUME, BY WHICH SIDE OF THE BAND THE EYE IS ON: a layer seen from above shows its sunlit top, a little
		// brighter, and from below its underside, a little darker and with no glow toward the sun -- the sun lights the top.
		// NOT BY THE STEP'S MIDDLE: one step spans the whole ray, whose middle on a ray from the grass into the sky is far above
		// the band, and every patch seen from below lit as its top drew bright arcs across the evening sky (step2-try6-stratus,
		// grass-fine-evening).
		float m_top_lit = smoothstep(-m_stratus_width, m_stratus_width, m_eye.y - m_band_y);
		// NO GLOW TOWARD THE SUN ON THE STRATUS, only its modelling: a patch near level is a sliver, and lit by the glow toward the
		// low sun every sliver was a white line (step2-try9-stratus, fields-fine-evening and mist_low). The haze keeps the glow.
		// AND NEVER BRIGHTER THAN THE HORIZON SKY: its top is the mist's own colour and its underside darker by the modelling. Lit
		// a quarter brighter, a patch near level from 40 m over its band was still a white sliver brighter than the sky behind it
		// (step2-try10-stratus, fields-fine-evening).
		vec3 m_stratus_lit = mist_colour.rgb * (1.0 - mist_stratus_look.y * (1.0 - m_top_lit));
		vec3 m_colour = mix(m_lit, m_stratus_lit, m_stratus_tau / m_tau) + mist_town_glow * (m_dome_tau / m_tau);
		float m_through = exp(-m_tau);
		m_light += m_transmit * (1.0 - m_through) * m_colour;
		m_transmit *= m_through;
	}
	float m_taken = 1.0 - m_transmit;
	return vec4(m_light / max(m_taken, 1e-4), m_taken);
}

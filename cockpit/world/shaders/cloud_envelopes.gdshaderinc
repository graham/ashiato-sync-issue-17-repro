// EVERY CLOUD'S ENVELOPE, for the lumps of the mesh clouds on both finishes: the ellipsoid each cloud is lit through
// (cloud_light.gdshaderinc), one entry a cloud in the order of the batch, written by `LiftYard.show_lift` from
// `LiftYard.cloud_envelope`. A lump finds its own cloud's entry by where it is in the batch: every cloud is `lumps_a_cloud`
// lumps, so its index is INSTANCE_ID over that.
//
// A UNIFORM ARRAY, NOT THE INSTANCE COLOUR: a MultiMesh instance's colour arrives as COLOR, eight bits a channel clamped to 0
// to 1, and a centre is kilometres. SIXTY-FOUR, as `CloudTuning.MOST_CLOUDS`, which tests/air.gd holds this length to; a
// sky with more clouds than that is warned of, and the clouds past it are lit with no envelope, as a shell.

uniform vec4 envelope_at[64];
uniform vec4 envelope_radii[64];
// `CloudTuning.LUMPS`, written by the yard.
uniform int lumps_a_cloud = 24;

// Which cloud an instance of the batch belongs to. Only usable in vertex().
#define CLOUD_OF_INSTANCE (clamp(INSTANCE_ID / max(lumps_a_cloud, 1), 0, 63))

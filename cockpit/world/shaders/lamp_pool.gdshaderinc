// WHERE A STREET LAMP'S LIGHT ON THE ROAD GOES FROM THE ROAD TO THE LAMP: the one function both sides read.
//
// Close to, a street lamp's pool of light is drawn on the street under it (lamp_pool.gdshader); far off, the pool is a
// few pixels of road, and the light it gives the eye is carried by the lamp's own point (lamp.gdshaderinc) instead. Across
// the band between, the pool gives up exactly the share the point takes, from the same `pool_to` handed to both from
// TownTuning, so no distance draws the pool's light twice or not at all. The same shape as town_handover.gdshaderinc.
#ifndef LAMP_POOL_GDSHADERINC
#define LAMP_POOL_GDSHADERINC

// The share of a pool's light the lamp's point carries `away` metres from the eye: 0 inside 0.55 of `pool_to`, 1 past it.
float lamp_pool_far_share(float away, float pool_to) {
	return smoothstep(pool_to * 0.55, pool_to, away);
}

// WHAT A LAMP'S POOL SENDS TOWARDS THE EYE, candela, from a lamp of `candela` straight down over a road of `reflectance`,
// seen `up` (the sine of the eye's elevation over the road). A lamp whose intensity falls as the cube of the cosine lights the
// road with 2 pi times its candela in lumens; a matt road of reflectance rho sends rho over pi of that as luminance,
// integrated over the road: 2 rho candela, times the road's projected share, `up`, and the night's
// adaptation (`gain`, TownTuning.night_adaptation()), so the light carried far is the light the pool draws near.
float lamp_pool_candela(float candela, float reflectance, float gain, float up) {
	return 2.0 * reflectance * gain * candela * max(up, 0.0);
}

#endif

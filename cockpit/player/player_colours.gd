extends RefCounted
class_name PlayerColours
## The eight deliberately distinct colours a player may wear. Network messages carry an
## index, never RGB, so every surface renders the same validated choice.

const PALETTE: Array[Color] = [
	Color("4fc3f7"), Color("ffca28"), Color("ef5350"), Color("ab47bc"),
	Color("66bb6a"), Color("ff7043"), Color("ec407a"), Color("b0bec5"),
]


static func fallback(client_id: int) -> Color:
	return Color.from_hsv(fmod(float(maxi(client_id, 1)) * 0.37, 1.0), 0.55, 0.95)


static func at(index: int, client_id: int = 1) -> Color:
	return PALETTE[index] if index >= 0 and index < PALETTE.size() else fallback(client_id)

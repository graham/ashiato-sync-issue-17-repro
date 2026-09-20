extends RefCounted
## Low-poly, metre-authored exterior meshes for the procedural reference aircraft.
## Physics keeps using the native box; these lofts only replace that box on screen.


## An elliptical fuselage through ordered Vector4(z, half_width, half_height, centre_y)
## stations. Explicit normals keep the inexpensive 16-sided shell visually rounded.
static func fuselage(stations: Array[Vector4], sides: int = 16) -> ArrayMesh:
	assert(stations.size() >= 2)
	assert(sides >= 6)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for station in stations:
		for side in range(sides):
			var angle: float = TAU * float(side) / float(sides)
			vertices.append(Vector3(cos(angle) * station.y,
				station.w + sin(angle) * station.z, station.x))
			normals.append(Vector3(cos(angle) / maxf(station.y, 0.001),
				sin(angle) / maxf(station.z, 0.001), 0.0).normalized())
	for ring in range(stations.size() - 1):
		for side in range(sides):
			var next_side: int = (side + 1) % sides
			var a: int = ring * sides + side
			var b: int = ring * sides + next_side
			var c: int = (ring + 1) * sides + next_side
			var d: int = (ring + 1) * sides + side
			# Godot regards clockwise winding as front-facing.
			indices.append_array(PackedInt32Array([a, c, b, a, d, c]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

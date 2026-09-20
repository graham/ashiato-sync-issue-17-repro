#include "cockpit/massif.hpp"

#include <chrono>

/// See massif.hpp for what this is, and range_core.hpp for the shape.

namespace ashiato_gd {
namespace ground {

Massif::Massif(std::shared_ptr<const Mountains> mountains, b3WorldId world)
    : mountains_(std::move(mountains)), world_(world) {
    const auto began = std::chrono::steady_clock::now();
    std::vector<b3Vec3> points;
    std::vector<std::int32_t> indices;
    for (const MountainTile& tile : mountains_->tiles()) {
        const size_t count = tile.vertices.size() / 3;
        points.resize(count);
        for (size_t v = 0; v < count; ++v) {
            // Whole metres and ticks of 1/32 m: exact in a float32, so these ARE the picture's numbers.
            points[v] = b3Vec3{static_cast<float>(tile.vertices[3 * v]),
                               static_cast<float>(tile.vertices[3 * v + 1]) / static_cast<float>(Mountains::kTicks),
                               static_cast<float>(tile.vertices[3 * v + 2])};
        }
        indices.assign(tile.indices.begin(), tile.indices.end());
        b3MeshDef def{};
        def.vertices = points.data();
        def.stride = 0;
        def.indices = indices.data();
        def.materialIndices = nullptr;
        def.vertexCount = static_cast<int>(count);
        def.triangleCount = static_cast<int>(indices.size() / 3);
        def.weldVertices = false;
        def.useMedianSplit = true;
        // SMOOTH OVER THE SEAMS: a wheel or a hull sliding across an edge between two triangles is not caught on it.
        def.identifyEdges = true;
        def.clockWiseWinding = true;
        b3MeshData* data = b3CreateMesh(&def, nullptr, 0);

        b3BodyDef body_def = b3DefaultBodyDef();
        body_def.type = b3_staticBody;
        body_def.position.x = static_cast<decltype(body_def.position.x)>(tile.x0);
        body_def.position.y = 0;
        body_def.position.z = static_cast<decltype(body_def.position.z)>(tile.z0);
        const b3BodyId body = b3CreateBody(world_, &body_def);
        b3ShapeDef shape = b3DefaultShapeDef();
        b3CreateMeshShape(body, &shape, data, b3Vec3{1.0f, 1.0f, 1.0f});

        data_.push_back(data);
        bodies_.push_back(body);
        bytes_ += data->byteCount;
        degenerate_ += data->degenerateCount;
        hash_ = (hash_ ^ data->hash) * 1099511628211ull;
    }
    build_usec_ = std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now() - began).count();
}

Massif::~Massif() {
    if (b3World_IsValid(world_)) {
        for (const b3BodyId body : bodies_) {
            b3DestroyBody(body);
        }
    }
    for (b3MeshData* data : data_) {
        b3DestroyMesh(data);
    }
}

}  // namespace ground
}  // namespace ashiato_gd

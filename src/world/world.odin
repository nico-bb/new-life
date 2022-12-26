package world

import "lib:iris"
import "lib:iris/gltf"

WORLD_WIDTH :: 10
WORLD_HEIGHT :: 10

World :: struct {
	tiles: [WORLD_WIDTH * WORLD_HEIGHT]World_Tile,
}

World_Tile :: struct {
	index: int,
	node:  ^iris.Model_Node,
}

create_world :: proc(scene: ^iris.Scene) -> World {
	world := World{}
	tile_doc, err := gltf.parse_from_file(
		"models/grass_floor.gltf",
		.Gltf_External,
		context.temp_allocator,
		context.temp_allocator,
	)
	assert(err == nil)
	iris.load_resources_from_gltf(&tile_doc)
	gltf_tile_node, exist := gltf.find_node_with_name(&tile_doc, "floor_A")
	assert(exist)

	tiles_holder := iris.new_node(scene, iris.Empty_Node)
	iris.insert_node(scene, tiles_holder)
	for tile, i in &world.tiles {
		tile.index = i
		tile.node = iris.new_node(scene, iris.Model_Node)

		loader := iris.Model_Loader {
			flags = {.Load_Position, .Load_Normal, .Load_TexCoord0},
			rigged = false,
		}
		shader_exist, spec_exist: bool
		loader.shader_ref, shader_exist = iris.shader_from_name("deferred_geometry")
		loader.shader_spec, shader_exist = iris.shader_specialization_from_name("deferred_default")
		assert(shader_exist && spec_exist)

		iris.model_node_from_gltf(tile.node, loader, gltf_tile_node)
	}

	return world
}

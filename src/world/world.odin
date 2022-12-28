package world

import "lib:iris"
import "lib:iris/gltf"

WORLD_WIDTH :: 5
WORLD_HEIGHT :: 5

World_Grid :: struct {
	width:  int,
	height: int,
	tiles:  []World_Tile,
}

World_Tile :: struct {
	index: int,
	node:  ^iris.Model_Node,
}

create_world :: proc(scene: ^iris.Scene) -> World_Grid {
	world := World_Grid {
		width  = WORLD_WIDTH,
		height = WORLD_HEIGHT,
		tiles  = make([]World_Tile, WORLD_WIDTH * WORLD_HEIGHT),
	}

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

	shader, shader_exist := iris.shader_from_name("deferred_geometry")
	shader_spec, spec_exist := iris.shader_specialization_from_name("deferred_default")
	assert(shader_exist && spec_exist)

	for tile, i in &world.tiles {
		tile.index = i
		tile.node = iris.new_node(scene, iris.Model_Node)

		loader := iris.Model_Loader {
			flags = {.Load_Position, .Load_Normal, .Load_TexCoord0},
			shader_ref = shader,
			shader_spec = shader_spec,
			rigged = false,
		}

		iris.model_node_from_gltf(tile.node, loader, gltf_tile_node)
		iris.node_local_transform(tile.node, iris.transform(t = {0, 0, 0}))
		iris.insert_node(scene, tile.node, tiles_holder)
	}

	return world
}

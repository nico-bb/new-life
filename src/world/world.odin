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
	node:     ^iris.Model_Node,
	index:    int,
	walkable: bool,
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
		tile.node = iris.new_node(scene, iris.Model_Node)
		tile.index = i
		tile.walkable = true

		loader := iris.Model_Loader {
			flags = {.Load_Position, .Load_Normal, .Load_TexCoord0},
			shader_ref = shader,
			shader_spec = shader_spec,
			rigged = false,
		}

		iris.model_node_from_gltf(tile.node, loader, gltf_tile_node)

		x := f32(i % WORLD_WIDTH)
		z := f32(i / WORLD_WIDTH)
		iris.node_local_transform(tile.node, iris.transform(t = {x, 0, z}))
		iris.insert_node(scene, tile.node, tiles_holder)
	}

	return world
}

index_to_coord :: proc(grid: ^World_Grid, index: int) -> iris.Vector3 {
	return iris.Vector3{f32(index % grid.width), 0, f32(index / grid.width)}
}

coord_to_index :: proc(grid: ^World_Grid, coord: iris.Vector3) -> int {
	return int(coord.z) * grid.width + int(coord.x)
}

coord_in_bounds :: proc(grid: ^World_Grid, coord: iris.Vector3) -> bool {
	x := int(coord.x)
	z := int(coord.z)
	return (x >= 0 && x < grid.width) && (z >= 0 && z < grid.height)
}

get_tile_at_coord :: proc(grid: ^World_Grid, coord: iris.Vector3) -> ^World_Tile {
	return &grid.tiles[coord_to_index(grid, coord)]
}

get_tile_at_index :: proc(grid: ^World_Grid, index: int) -> ^World_Tile {
	return &grid.tiles[index]
}

adjacent_tiles :: proc(grid: ^World_Grid, coord: iris.Vector3) -> [4]Maybe(^World_Tile) {
	adjacent := [4]Maybe(^World_Tile){}

	up := coord + {0, 0, -1}
	if coord_in_bounds(grid, up) {
		adjacent[iris.Direction.Up] = get_tile_at_coord(grid, up)
	}

	right := coord + {1, 0, 0}
	if coord_in_bounds(grid, right) {
		adjacent[iris.Direction.Right] = get_tile_at_coord(grid, right)
	}

	down := coord + {0, 0, 1}
	if coord_in_bounds(grid, down) {
		adjacent[iris.Direction.Down] = get_tile_at_coord(grid, down)
	}

	left := coord + {-1, 0, 0}
	if coord_in_bounds(grid, left) {
		adjacent[iris.Direction.Left] = get_tile_at_coord(grid, left)
	}

	return adjacent
}

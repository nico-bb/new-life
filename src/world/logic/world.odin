package logic

import "core:math"
import "core:math/linalg"
import "lib:iris"
import "lib:iris/gltf"
import world ".."

WORLD_WIDTH :: 5
WORLD_HEIGHT :: 5

World_Grid :: world.World_Grid
World_Tile :: world.World_Tile


Tile_Search_Option :: enum {
	Include_Not_Walkable,
}

Tile_Search_Mask :: distinct bit_set[Tile_Search_Option]

init_world_grid :: proc(grid: ^World_Grid, scene: ^iris.Scene) {
	grid^ = World_Grid {
		node   = iris.new_node(scene, iris.Empty_Node),
		width  = WORLD_WIDTH,
		height = WORLD_HEIGHT,
		tiles  = make([]World_Tile, WORLD_WIDTH * WORLD_HEIGHT),
	}
	iris.insert_node(scene, grid)

	for kind in World_Object_Kind {
		grid.objects[kind].allocator = scene.allocator
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

	tiles_holder := iris.new_node(grid.scene, iris.Empty_Node)
	iris.insert_node(grid.scene, tiles_holder, grid)

	shader, shader_exist := iris.shader_from_name("deferred_geometry")
	shader_spec, spec_exist := iris.shader_specialization_from_name("deferred_default")
	assert(shader_exist && spec_exist)

	for tile, i in &grid.tiles {
		tile.node = iris.new_node(grid.scene, iris.Model_Node)
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
		iris.insert_node(grid.scene, tile.node, tiles_holder)
	}

	tree_doc, glb_err := gltf.parse_from_file(
		"models/tree_low.gltf",
		.Gltf_External,
		context.temp_allocator,
		context.temp_allocator,
	)
	assert(glb_err == nil)
	iris.load_resources_from_gltf(&tree_doc)

	tree_node, tree_exist := gltf.find_node_with_name(&tree_doc, "Tree.009")
	assert(tree_exist)


	tree_object := new_world_object_from(
		grid,
		World_Object{
			kind = .Tree,
			scale = {0.5, 0.5, 0.5},
			flags = {.Blocking},
			derived = Tree_Object{node = iris.new_node(grid.scene, iris.Model_Node)},
		},
	)
	iris.model_node_from_gltf(
		tree_object.derived.(Tree_Object).node,
		iris.Model_Loader{
			flags = {.Load_Position, .Load_Normal, .Load_TexCoord0},
			options = {.Cast_Shadows},
			shader_ref = shader,
			shader_spec = shader_spec,
			rigged = false,
		},
		tree_node,
	)

	iris.insert_node(grid.scene, tree_object.derived.(Tree_Object).node, grid)
	set_tile_content(grid, get_tile_at_coord(grid, iris.Vector3{1, 0, 1}), tree_object)


	// INSTANCED RENDERING TESTS
	{
		bush_doc, bush_err := gltf.parse_from_file(
			"models/bush_retro.glb",
			.Glb,
			context.temp_allocator,
			context.temp_allocator,
		)
		assert(bush_err == nil)
		iris.load_resources_from_gltf(&bush_doc)

		bush_node, bush_exist := gltf.find_node_with_name(&bush_doc, "deco_bushPlant")
		assert(bush_exist)

		bushes := iris.new_node_from(scene, iris.Model_Group_Node{count = 9})
		iris.model_node_from_gltf(
			bushes,
			iris.Model_Loader{
				flags = {.Load_Position, .Load_Normal, .Load_TexCoord0, .Load_As_Instanced},
				options = {},
				shader_ref = shader,
				shader_spec = shader_spec,
				rigged = false,
			},
			bush_node,
		)

		iris.insert_node(grid.scene, bushes, grid)

		for y in 0 ..< 3 {
			for x in 0 ..< 3 {
				iris.group_node_instance_transform(
					bushes,
					y * 3 + x,
					iris.transform(t = {f32(x), 0, f32(y)}, s = {0.5, 0.5, 0.5}),
				)
			}
		}
	}
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

adjacent_tiles :: proc(
	grid: ^World_Grid,
	coord: iris.Vector3,
	mask: Tile_Search_Mask,
) -> [4]Maybe(^World_Tile) {
	adjacent := [4]Maybe(^World_Tile){}

	up := coord + {0, 0, -1}
	if coord_in_bounds(grid, up) {
		tile := get_tile_at_coord(grid, up)
		if tile.walkable || (!tile.walkable && .Include_Not_Walkable in mask) {
			adjacent[iris.Direction.Up] = tile
		}
	}

	right := coord + {1, 0, 0}
	if coord_in_bounds(grid, right) {
		tile := get_tile_at_coord(grid, right)
		if tile.walkable || (!tile.walkable && .Include_Not_Walkable in mask) {
			adjacent[iris.Direction.Right] = tile
		}
	}

	down := coord + {0, 0, 1}
	if coord_in_bounds(grid, down) {
		tile := get_tile_at_coord(grid, down)
		if tile.walkable || (!tile.walkable && .Include_Not_Walkable in mask) {
			adjacent[iris.Direction.Down] = tile
		}
	}

	left := coord + {-1, 0, 0}
	if coord_in_bounds(grid, left) {
		tile := get_tile_at_coord(grid, left)
		if tile.walkable || (!tile.walkable && .Include_Not_Walkable in mask) {
			adjacent[iris.Direction.Left] = tile
		}
	}

	return adjacent
}

set_tile_content :: proc(grid: ^World_Grid, tile: ^World_Tile, object: ^World_Object) {
	tile.content = object
	object.parent = tile
	switch d in object.derived {
	case Tree_Object:
		iris.node_local_transform(
			d.node,
			iris.transform(t = index_to_coord(grid, tile.index), s = object.scale),
		)
	}
	if .Blocking in object.flags {
		tile.walkable = false
	}
}


SEARCH_CAP :: 5

Object_Search :: struct {
	kind:   World_Object_Kind,
	policy: Search_Policy,
	origin: iris.Vector3,
	radius: f32,
}

Search_Policy :: enum {
	Find_First,
	Find_Closest,
	Find_All_In_Radius,
}

find_object_of_kind :: proc(
	grid: ^World_Grid,
	search: Object_Search,
) -> (
	result: [SEARCH_CAP]^World_Object,
	count: int,
) {
	objects := grid.objects[search.kind]

	switch search.policy {
	case .Find_First:
		result[0] = objects[0]
		count = 1
	case .Find_Closest:
		closest_index := -1
		closest_distance := math.INF_F32
		for object, i in &objects {
			coord := index_to_coord(grid, object.parent.index)
			distance := linalg.vector_length2(coord - search.origin)
			if distance < closest_distance {
				closest_distance = distance
				closest_index = i
				continue
			}
		}

		if closest_index >= 0 {
			result[0] = objects[closest_index]
			count = 1
		} else {
			count = 0
		}

	case .Find_All_In_Radius:
		for object, i in &objects {
			coord := index_to_coord(grid, object.parent.index)
			distance := linalg.vector_length2(coord - search.origin)
			if distance <= search.radius {
				result[count] = objects[i]
				count += 1
			}

			if count == SEARCH_CAP {
				break
			}
		}
	}
	return
}

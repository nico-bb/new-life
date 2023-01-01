package world

import "lib:smart"
import "lib:iris"
import "lib:iris/gltf"

Pawn :: struct {
	node:           ^iris.Node,
	brain:          ^smart.Behavior_Tree,

	// Spatial data
	rotation:       iris.Quaternion,
	current_coord:  iris.Vector3,
	previous_coord: Maybe(iris.Vector3),
	next_coord:     Maybe(iris.Vector3),

	// Timers
	idle_timer:     iris.Timer,
	move_tween:     iris.Tween,
}

init_pawn :: proc(scene: ^iris.Scene, pawn: ^Pawn, world: ^World_Grid) {
	pawn_doc, err := gltf.parse_from_file(
		"models/character_knight.gltf",
		.Gltf_Embed,
		context.temp_allocator,
		context.temp_allocator,
	)
	assert(err == nil)
	iris.load_resources_from_gltf(&pawn_doc)
	pawn_node, exist := gltf.find_node_with_name(&pawn_doc, "character_knightBody")
	assert(exist)

	shader, shader_exist := iris.shader_from_name("deferred_geometry")
	shader_spec, spec_exist := iris.shader_specialization_from_name("deferred_default")
	assert(shader_exist && spec_exist)

	pawn.node = iris.new_node(scene, iris.Empty_Node)
	model_node := iris.new_node(scene, iris.Model_Node)
	iris.model_node_from_gltf(
		model_node,
		iris.Model_Loader{
			flags = {.Load_Position, .Load_Normal, .Load_TexCoord0, .Load_Children},
			options = {.Dynamic, .Cast_Shadows},
			shader_ref = shader,
			shader_spec = shader_spec,
			rigged = false,
		},
		pawn_node,
	)
	iris.node_local_transform(model_node, iris.transform(s = iris.Vector3{0.5, 0.5, 0.5}))
	// pawn.node.options += {.Cast_Shadows}

	iris.insert_node(scene, pawn.node)
	iris.insert_node(scene, model_node, pawn.node)

	init_pawn_data(pawn)
	// init_pawn_behaviors(pawn, world)
}

init_pawn_data :: proc(pawn: ^Pawn) {
	pawn.idle_timer = iris.Timer {
		duration = 5,
		reset    = true,
	}
	pawn.move_tween = iris.Tween {
		timer = iris.Timer{duration = 1, reset = false},
		interpolation = .In_Out,
		start = f32(0),
		end = f32(1),
	}
}

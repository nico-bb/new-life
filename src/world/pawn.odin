package world

import "core:fmt"
import "lib:smart"
import "lib:iris"
import "lib:iris/gltf"

Pawn :: struct {
	node:  ^iris.Model_Node,
	brain: ^smart.Behavior_Tree,
}

create_pawn :: proc(scene: ^iris.Scene) -> Pawn {
	pawn := Pawn{}

	pawn_doc, err := gltf.parse_from_file(
		"models/cow.gltf",
		.Gltf_External,
		context.temp_allocator,
		context.temp_allocator,
	)
	assert(err == nil)
	iris.load_resources_from_gltf(&pawn_doc)
	pawn_node, exist := gltf.find_node_with_name(&pawn_doc, "Cow_mesh")
	assert(exist)

	shader, shader_exist := iris.shader_from_name("deferred_geometry")
	shader_spec, spec_exist := iris.shader_specialization_from_name("deferred_default")
	assert(shader_exist && spec_exist)

	pawn.node = iris.new_node(scene, iris.Model_Node)
	iris.model_node_from_gltf(
		pawn.node,
		iris.Model_Loader{
			flags = {.Load_Position, .Load_Normal, .Load_TexCoord0},
			shader_ref = shader,
			shader_spec = shader_spec,
			rigged = false,
		},
		pawn_node,
	)
	iris.flag_model_node_as_dynamic(pawn.node)
	iris.node_local_transform(pawn.node, iris.transform(s = iris.Vector3{0.5, 0.5, 0.5}))
	pawn.node.options += {.Cast_Shadows}

	iris.insert_node(scene, pawn.node)

	init_pawn_behaviors(&pawn)
	return pawn
}

init_pawn_behaviors :: proc(pawn: ^Pawn) {
	pawn.brain = smart.new_tree()

	test_behavior := smart.new_node_from(pawn.brain, smart.Behavior_Action {
		action = proc(node: ^smart.Behavior_Node) -> smart.Action_Proc_Result {
			fmt.println("Brainz!")
			return .Done
		},
	})

	smart.set_tree_root(pawn.brain, test_behavior)
}

update_pawn :: proc(pawn: ^Pawn) {
	smart.run(pawn.brain)
}
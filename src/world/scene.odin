package world

import "lib:iris"
import "../interface"

World_State :: struct {
	scene: ^iris.Scene,
	world: World_Grid,
	pawns: [1]Pawn,
}

world_state :: proc() -> interface.Game_Interface {
	world := new(World_State)

	shader, _ := iris.shader_from_name("deferred_geometry")
	shader_spec := iris.shader_specialization_resource(
		"deferred_default",
		shader,
	).data.(^iris.Shader_Specialization)
	iris.set_specialization_subroutine(
		shader,
		shader_spec,
		.Fragment,
		"sampleAlbedo",
		"sampleDefaultAlbedo",
	)

	world.scene = iris.scene_resource("world", {.Draw_Debug_Collisions}).data.(^iris.Scene)

	// Camera and sunlight settings
	{
		camera_node := iris.new_default_camera(world.scene)
		sun_node := iris.new_node_from(
			world.scene,
			iris.Light_Node{
				direction = iris.Vector3{-2, -3, -2},
				color = iris.Color{100, 100, 90, 1},
				options = {.Shadow_Map},
				shadow_map = iris.Shadow_Map{scales = {0 = 6, 1 = 2, 2 = 1}, cascade_count = 3},
			},
		)
		iris.node_local_transform(sun_node, iris.transform(t = iris.Vector3{2, 3, 2}))

		iris.insert_node(world.scene, camera_node)
		iris.insert_node(world.scene, sun_node)
	}

	world.world = create_world(world.scene)
	world.pawns[0] = create_pawn(world.scene)

	it := interface.Game_Interface {
		data   = world,
		update = update_world_state,
		draw   = draw_world_state,
	}
	return it
}

update_world_state :: proc(data: rawptr, dt: f32) {
	world := cast(^World_State)data

	for i in 0 ..< len(world.pawns) {
		update_pawn(&world.pawns[i])
	}
	iris.update_scene(world.scene, dt)
}

draw_world_state :: proc(data: rawptr) {
	world := cast(^World_State)data

	iris.render_scene(world.scene)
}

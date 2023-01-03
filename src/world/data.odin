package world

import "core:mem"
import "lib:iris"
import "lib:iris/allocators"
import "../interface"

World_State :: struct {
	free_list: allocators.Free_List_Allocator,
	allocator: mem.Allocator,
	plugin:    iris.Plugin,
	scene:     ^iris.Scene,
	grid:      World_Grid,
	pawns:     [1]Pawn,
}

world_state :: proc() -> interface.Game_Interface {
	world := new(World_State)

	allocators.init_free_list_allocator(
		&world.free_list,
		make([]byte, mem.Megabyte * 10),
		.Find_Best,
		4,
	)
	world.allocator = allocators.free_list_allocator(&world.free_list)

	world.plugin = iris.Plugin {
		desc = iris.Plugin_Desc{
			source_dir = "../../src/world/logic",
			dll_path = "../game.dll",
			load_symbol = "load",
			reload_symbol = "reload",
			unload_symbol = "unload",
			update_symbol = "update",
		},
		refresh_rate = 5,
		flags = {.Build_On_Load},
		user_ptr = world,
	}

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

	init_pawn(world.scene, &world.pawns[0], &world.grid)

	it := interface.Game_Interface {
		data   = world,
		plugin = &world.plugin,
		update = update_world_state,
		draw   = draw_world_state,
	}
	return it
}

update_world_state :: proc(data: rawptr, dt: f32) {
	world := cast(^World_State)data

	iris.update_scene(world.scene, dt)
}

draw_world_state :: proc(data: rawptr) {
	world := cast(^World_State)data

	iris.render_scene(world.scene)
}

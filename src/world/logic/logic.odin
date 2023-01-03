package logic

import "lib:iris"
import world ".."

World_State :: world.World_State

@(export)
load :: proc(app: rawptr, ptr: rawptr) {
	iris.set_app_ptr(app)
	iris.load_api(.GL)
	world := cast(^World_State)ptr

	context.allocator = world.allocator

	init_world_grid(&world.grid, world.scene)
	for i in 0 ..< len(world.pawns) {
		init_pawn_behaviors(&world.pawns[i], &world.grid)
	}
}

@(export)
reload :: proc(app: rawptr, ptr: rawptr) {
	iris.set_app_ptr(app)
	iris.load_api(.GL)
	world := cast(^World_State)ptr

	context.allocator = world.allocator

	for i in 0 ..< len(world.pawns) {
		destroy_pawn_behaviors(&world.pawns[i])
		init_pawn_behaviors(&world.pawns[i], &world.grid)
	}
}

@(export)
unload :: proc(ptr: rawptr) {}

@(export)
update :: proc(ptr: rawptr) {
	world := cast(^World_State)ptr
	dt := f32(iris.elapsed_time())


	for i in 0 ..< len(world.pawns) {
		update_pawn(&world.pawns[i], dt)
	}
}

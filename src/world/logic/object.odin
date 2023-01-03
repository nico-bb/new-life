package logic

import world "../"

World_Object :: world.World_Object
World_Object_Kind :: world.World_Object_Kind
World_Object_Flags :: world.World_Object_Flags
Tree_Object :: world.Tree_Object

new_world_object :: proc(grid: ^World_Grid, kind: World_Object_Kind) -> ^World_Object {
	object := new(World_Object, grid.scene.allocator)
	object.kind = kind
	append(&grid.objects[kind], object)
	return object
}

new_world_object_from :: proc(grid: ^World_Grid, from: World_Object) -> ^World_Object {
	object := new_clone(from, grid.scene.allocator)
	append(&grid.objects[object.kind], object)
	return object
}

destroy_world_object :: proc(grid: ^World_Grid, object: ^World_Object) {
	for o, i in grid.objects[object.kind] {
		if object == o {
			unordered_remove(&grid.objects[object.kind], i)
			free(object, grid.scene.allocator)
			break
		}
	}
}

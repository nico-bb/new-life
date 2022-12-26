package world

import "lib:iris"

World_State :: struct {
	scene: ^iris.Scene,
}

init_world_scene :: proc(world: ^World_State) {
	world.scene = iris.scene_resource("world", {}).data.(^iris.Scene)

}

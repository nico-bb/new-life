package main

import "lib:iris"
import "interface"
import "world"

main :: proc() {
	iris.init_app(
		&iris.App_Config{
			width = 1600,
			height = 900,
			title = "tinier tactics",
			decorated = true,
			asset_dir = "assets/",
			data = iris.App_Data(&Game{}),
			init = init,
			update = update,
			draw = draw,
			close = close,
		},
	)

	iris.run_app()
	iris.close_app()
}

Game :: struct {
	current: Game_State,
	states:  map[Game_State]interface.Game_Interface,
	// scene:    ^iris.Scene,
	// ui_theme: iris.User_Interface_Theme,
	// ui:       ^iris.User_Interface_Node,
}

Game_State :: enum {
	Main_Menu,
	World,
}

init :: proc(data: iris.App_Data) {
	g := cast(^Game)data

	g.states[.World] = world.world_state()
	plugin_ok := iris.load_plugin(g.states[.World].plugin)
	assert(plugin_ok)
	g.current = .World

	// g.scene = iris.scene_resource("menu", {}).data.(^iris.Scene)
	// g.ui_theme = iris.User_Interface_Theme {
	// 	borders = false,
	// 	// border_color = {1, 1, 1, 1},
	// 	contrast_values = {0 = 0.35, 1 = 0.75, 2 = 1, 3 = 1.25, 4 = 1.5},
	// 	base_color = {0.35, 0.35, 0.35, 1},
	// 	highlight_color = {0.7, 0.7, 0.8, 1},
	// 	text_color = 1,
	// 	text_size = 20,
	// 	font = iris.font_resource(
	// 		iris.Font_Loader{path = "fonts/Roboto-Regular.ttf", sizes = {20}},
	// 	).data.(^iris.Font),
	// 	title_style = .Center,
	// }

	// {
	// 	canvas := iris.new_node_from(g.scene, iris.Canvas_Node{width = 1600, height = 900})
	// 	iris.insert_node(g.scene, canvas)
	// 	g.ui = iris.new_node_from(g.scene, iris.User_Interface_Node{canvas = canvas})
	// 	iris.insert_node(g.scene, g.ui)
	// 	iris.ui_node_theme(g.ui, g.ui_theme)

	// 	iris.new_widget_from(
	// 		g.ui,
	// 		iris.Layout_Widget{
	// 			base = iris.Widget{
	// 				flags = {.Initialized_On_New, .Root_Widget, .Fit_Theme, .Active},
	// 				rect = {x = (1600 - 250) / 2, y = (900 - 350) / 2, width = 250, height = 350},
	// 				background = iris.Widget_Background{style = .Solid},
	// 			},
	// 			options = {},
	// 			format = .Row,
	// 			origin = .Up,
	// 			margin = 3,
	// 			padding = 2,
	// 		},
	// 	)
	// }
}

update :: proc(data: iris.App_Data) {
	g := cast(^Game)data
	dt := f32(iris.elapsed_time())

	current_state := g.states[g.current]

	iris.update_plugin(current_state.plugin)
	current_state.update(current_state.data, dt)
}

draw :: proc(data: iris.App_Data) {
	g := cast(^Game)data

	iris.start_render()
	defer iris.end_render()

	current_state := g.states[g.current]
	current_state.draw(current_state.data)
}

close :: proc(data: iris.App_Data) {
	g := cast(^Game)data

	current_state := g.states[g.current]
	iris.unload_plugin(current_state.plugin)
}

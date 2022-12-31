package interface

import "lib:iris"

Game_Interface :: struct {
	data:   rawptr,
	plugin: ^iris.Plugin,
	update: proc(data: rawptr, dt: f32),
	draw:   proc(data: rawptr),
}

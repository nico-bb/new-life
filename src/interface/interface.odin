package interface

Game_Interface :: struct {
	data:   rawptr,
	update: proc(data: rawptr, dt: f32),
	draw:   proc(data: rawptr),
}

package world

import "lib:iris"

World_Grid :: struct {
	using node: ^iris.Node,
	width:      int,
	height:     int,
	tiles:      []World_Tile,
	objects:    [len(World_Object_Kind)][dynamic]^World_Object,
}

World_Tile :: struct {
	node:     ^iris.Model_Node,
	index:    int,
	walkable: bool,
	content:  ^World_Object,
}

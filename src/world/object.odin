package world

import "lib:iris"

World_Object_Kind :: enum {
	Tree,
	Pawn,
}

World_Object :: struct {
	parent:  ^World_Tile,
	kind:    World_Object_Kind,
	flags:   World_Object_Flags,
	derived: Any_World_Object,
}

World_Object_Flag :: enum {
	Blocking,
}

World_Object_Flags :: distinct bit_set[World_Object_Flag]

Any_World_Object :: union {
	Tree_Object,
}

Tree_Object :: struct {
	node: ^iris.Model_Node,
}

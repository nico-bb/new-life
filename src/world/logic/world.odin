package logic

import "lib:iris"
import world ".."

World_Grid :: world.World_Grid
World_Tile :: world.World_Tile

index_to_coord :: proc(grid: ^World_Grid, index: int) -> iris.Vector3 {
	return iris.Vector3{f32(index % grid.width), 0, f32(index / grid.width)}
}

coord_to_index :: proc(grid: ^World_Grid, coord: iris.Vector3) -> int {
	return int(coord.z) * grid.width + int(coord.x)
}

coord_in_bounds :: proc(grid: ^World_Grid, coord: iris.Vector3) -> bool {
	x := int(coord.x)
	z := int(coord.z)
	return (x >= 0 && x < grid.width) && (z >= 0 && z < grid.height)
}

get_tile_at_coord :: proc(grid: ^World_Grid, coord: iris.Vector3) -> ^World_Tile {
	return &grid.tiles[coord_to_index(grid, coord)]
}

get_tile_at_index :: proc(grid: ^World_Grid, index: int) -> ^World_Tile {
	return &grid.tiles[index]
}

adjacent_tiles :: proc(grid: ^World_Grid, coord: iris.Vector3) -> [4]Maybe(^World_Tile) {
	adjacent := [4]Maybe(^World_Tile){}

	up := coord + {0, 0, -1}
	if coord_in_bounds(grid, up) {
		adjacent[iris.Direction.Up] = get_tile_at_coord(grid, up)
	}

	right := coord + {1, 0, 0}
	if coord_in_bounds(grid, right) {
		adjacent[iris.Direction.Right] = get_tile_at_coord(grid, right)
	}

	down := coord + {0, 0, 1}
	if coord_in_bounds(grid, down) {
		adjacent[iris.Direction.Down] = get_tile_at_coord(grid, down)
	}

	left := coord + {-1, 0, 0}
	if coord_in_bounds(grid, left) {
		adjacent[iris.Direction.Left] = get_tile_at_coord(grid, left)
	}

	return adjacent
}

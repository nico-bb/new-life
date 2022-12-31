package logic

import "core:fmt"
import "lib:iris"
import "lib:smart"
import world ".."

Pawn :: world.Pawn

init_pawn_behaviors :: proc(pawn: ^Pawn, world: ^World_Grid) {
	pawn.brain = smart.new_tree()
	pawn.brain.blackboard["world"] = rawptr(world)
	pawn.brain.blackboard["pawn"] = rawptr(pawn)
	pawn.brain.blackboard["dt"] = 0

// ??


	//odinfmt: disable
  idle_sequence := smart.new_node(pawn.brain, smart.Behavior_Sequence)
	append(
    &idle_sequence.children,
    // Idle pathfinding
    smart.new_node_from(
      pawn.brain, 
      smart.Behavior_Action {
        action = proc(node: ^smart.Behavior_Node) -> smart.Action_Proc_Result {
          world := cast(^World_Grid)node.blackboard["world"].(rawptr)
          pawn := cast(^Pawn)node.blackboard["pawn"].(rawptr)
          adjacents := adjacent_tiles(world, pawn.current_coord)

          node.blackboard["path.found"] = false
          for t in adjacents do if t != nil {
            tile := t.?
            tile_coord := index_to_coord(world, tile.index)
            
            valid_tile := true
            if pawn.previous_coord != nil {
              previous := pawn.previous_coord.?
              if tile_coord == previous {
                valid_tile = false
              }
            }

            if valid_tile {
              pawn.next_coord = tile_coord
              node.blackboard["path.found"] = true
              break
            }
          }
          return .Done
        },
      }, 
      []smart.Begin_Decorator{
        proc(node: ^smart.Behavior_Node) -> smart.Condition_Proc_Result {
          pawn := cast(^Pawn)node.blackboard["pawn"].(rawptr)
          return iris.advance_timer(&pawn.idle_timer, node.blackboard["dt"].(f32))
        },
      },
	  ),

    // Single tile movement
    smart.new_node_from(
      pawn.brain, 
      smart.Behavior_Action {
        action = proc(node: ^smart.Behavior_Node) -> smart.Action_Proc_Result {
          // world := cast(^World_Grid)node.blackboard["world"].(rawptr)
          pawn := cast(^Pawn)node.blackboard["pawn"].(rawptr)
          move_pawn_to_next_coord(pawn)
          return .Done
        },
      }, 
      []smart.Begin_Decorator{
        proc(node: ^smart.Behavior_Node) -> smart.Condition_Proc_Result {
          return node.blackboard["path.found"].(bool)
        },
      },
	  ),
  )
	smart.set_tree_root(pawn.brain, idle_sequence)
	
	//odinfmt: enable
}

move_pawn_to_next_coord :: proc(pawn: ^Pawn) {
	pawn.previous_coord = pawn.current_coord
	pawn.current_coord = pawn.next_coord.?
	pawn.next_coord = nil

	iris.node_local_transform(pawn.node, iris.transform(t = pawn.current_coord))
}

destroy_pawn_behaviors :: proc(pawn: ^Pawn) {
	smart.destroy_tree(pawn.brain)
}

update_pawn :: proc(pawn: ^Pawn, dt: f32) {
	pawn.brain.blackboard["dt"] = dt
	smart.run(pawn.brain)
}

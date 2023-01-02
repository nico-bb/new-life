package logic

// import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:math/linalg"
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
  idle_sequence.halt_signal = .Failure
	append(
    &idle_sequence.children,
    // Idle pathfinding
    smart.new_node_from(
      pawn.brain, 
      smart.Behavior_Action {
        action = proc(node: ^smart.Behavior_Node) -> smart.Action_Proc_Result {
          world := cast(^World_Grid)node.blackboard["world"].(rawptr)
          pawn := cast(^Pawn)node.blackboard["pawn"].(rawptr)
          adjacents := adjacent_tiles(world, pawn.current_coord, {})

          count := len(adjacents)
          node.blackboard["path.found"] = false
          for count > 0 {
            index := int(rand.int63_max(i64(count)))
            
            tile_coord: iris.Vector3
            valid_tile := true
            if adjacents[index] != nil {
              tile_coord = index_to_coord(world, adjacents[index].?.index)

              if pawn.previous_coord != nil {
                if tile_coord == pawn.previous_coord.? {
                  valid_tile = false
                }
              }
            } else {
              valid_tile = false
            }

            if valid_tile {
              start_pawn_move(pawn, tile_coord)
              node.blackboard["path.found"] = true
              node.blackboard["path.arrived"] = false
              break
            } else {
              adjacents[index] = adjacents[count - 1]
              count -= 1
            }
          }
          return .Done
        },
      }, 
      []smart.Begin_Decorator{
        smart.Ignore_Decorator {
          ignore_proc = proc(node: ^smart.Behavior_Node) -> smart.Condition_Proc_Result {
            if found, ok := node.blackboard["path.found"].(bool); ok {
              return found
            }
            return false
          },
        },
        smart.Condition_Decorator {
          condition_proc = proc(node: ^smart.Behavior_Node) -> smart.Condition_Proc_Result {
            pawn := cast(^Pawn)node.blackboard["pawn"].(rawptr)
            return iris.advance_timer(&pawn.idle_timer, node.blackboard["dt"].(f32))
          },
        },
      },
	  ),

    smart.new_node_from(
      tree = pawn.brain,
      from = smart.Behavior_Action {
        action = proc(node: ^smart.Behavior_Node) -> smart.Action_Proc_Result {
          pawn := cast(^Pawn)node.blackboard["pawn"].(rawptr)
          dt := node.blackboard["dt"].(f32)

          t, done := iris.advance_tween(&pawn.move_tween, dt)

          if done {
            iris.reset_tween(&pawn.move_tween)
            node.blackboard["path.arrived"] = true
            return .Done
          }
          
          move_pawn(pawn, t.(f32))
          return .Not_Done
        },
      },
      begins = []smart.Begin_Decorator{
        smart.Ignore_Decorator {
          ignore_proc = proc(node: ^smart.Behavior_Node) -> smart.Condition_Proc_Result {
            return node.blackboard["path.arrived"].(bool)
          },
        },
        smart.Condition_Decorator {
          condition_proc = proc(node: ^smart.Behavior_Node) -> smart.Condition_Proc_Result {
            return node.blackboard["path.found"].(bool)
          },
        },
      },
    ),

    // Movement commit
    smart.new_node_from(
      tree = pawn.brain, 
      from = smart.Behavior_Action {
        action = proc(node: ^smart.Behavior_Node) -> smart.Action_Proc_Result {
          pawn := cast(^Pawn)node.blackboard["pawn"].(rawptr)
          commit_pawn_move(pawn)
          return .Done
        },
      }, 
      ends = []smart.End_Decorator{
        smart.Property_Decorator {
          trigger = .Success,
          key  = "path.found",
          value = false,
        },
      },
	  ),
  )
	smart.set_tree_root(pawn.brain, idle_sequence)
	
	//odinfmt: enable
}

start_pawn_move :: proc(pawn: ^Pawn, next: iris.Vector3) {
	pawn.next_coord = next
	pawn.rotation = linalg.quaternion_angle_axis_f32(
		math.to_radians(move_direction_to_rotation(pawn.next_coord.? - pawn.current_coord)),
		iris.VECTOR_UP,
	)
}

move_pawn :: proc(pawn: ^Pawn, t: f32) {
	v := pawn.next_coord.? - pawn.current_coord
	v *= t
	iris.node_local_transform(
		pawn.node,
		iris.transform(t = pawn.current_coord + v, r = pawn.rotation),
	)
}

commit_pawn_move :: proc(pawn: ^Pawn) {
	pawn.previous_coord = pawn.current_coord
	pawn.current_coord = pawn.next_coord.?
	pawn.next_coord = nil


	iris.node_local_transform(pawn.node, iris.transform(t = pawn.current_coord, r = pawn.rotation))
}

move_direction_to_rotation :: proc(dir: iris.Vector3) -> f32 {
	switch {
	case dir == {0, 0, -1}:
		return 180
	case dir == {1, 0, 0}:
		return 90
	case dir == {0, 0, 1}:
		return 0
	case dir == {-1, 0, 0}:
		return -90
	}

	return 0
}

destroy_pawn_behaviors :: proc(pawn: ^Pawn) {
	smart.destroy_tree(pawn.brain)
}

update_pawn :: proc(pawn: ^Pawn, dt: f32) {
	pawn.brain.blackboard["dt"] = dt
	smart.run(pawn.brain)
}

extends RefCounted
class_name Doors
## THE WAY BACK TO THE MENU, AND NOTHING ELSE.
##
## One constant and one function, in a file that depends on NOTHING. That is the whole
## reason it exists as its own class rather than living on `Boot` beside the rest of the
## doors, and the reason is worth keeping because it is not obvious and it is expensive to
## rediscover.
##
## ---------------------------------------------------------------------------------
## IT WAS ON `Boot` FIRST, AND THAT WAS A CYCLE
## ---------------------------------------------------------------------------------
##
## The router is where the doors live, so `Boot.to_the_desk()` looked like exactly the right
## home for this. It put the whole game in a loop:
##
##   PilotRig            -> Boot                       (to open the door)
##   Boot                -> MarshallingLevel           (to ask if a level name is one of its)
##   MarshallingLevel    -> preload(marshal_rig.tscn)  (the rig it stands the player up in)
##   marshal_rig.tscn    -> pilot_rig.tscn             (it is an inherited scene)
##   pilot_rig.tscn      -> PilotRig
##
## `preload` is what makes it fatal rather than untidy: it resolves while the script is being
## COMPILED, so the editor has to load `marshal_rig.tscn` in the middle of compiling the
## script that the scene it inherits from is waiting on. At runtime the loop happens to come
## apart in a workable order and every test passes. In the editor it does not, and what you
## get is not a word about cycles:
##
##   res://marshalling/hand/marshal_rig.tscn:6 - Parse Error: .
##   Failed loading resource: res://marshalling/hand/marshal_rig.tscn.
##
## Line 6 is the line that instances the rig. The scene parser is reporting that an
## ExtResource came back null, four hops from anything anybody changed.
##
## So the rule: ANYTHING A RIG, A CONTROL OR A COCKPIT REACHES FOR MUST NOT REACH BACK. This
## file is at the bottom of that order and has nothing under it.

## Where the game starts and what a player is asking for when they ask for the main menu.
## `Boot` reads it from here too, so the path is written down once.
const DESK: String = "res://world/desk.tscn"


## BACK TO WHERE YOU CAME IN, from anywhere.
##
## Every level was a one-way door before this. You could reach the world, the hall and both
## marshalling levels from the desk, and once you were in one the only way out was to quit
## the program -- which in a headset means taking it off.
##
## DEFERRED, for the same reason `Boot._go` is: a scene swap asked for from inside an input
## callback tries to remove the node that is still delivering the input, and Godot says so --
## "Parent node is busy adding/removing children".
##
## STATIC, and therefore with no tree of its own. The caller is a panel on the end of
## somebody's arm and has no business knowing which node the router is.
static func to_the_desk() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.change_scene_to_file.call_deferred(DESK)

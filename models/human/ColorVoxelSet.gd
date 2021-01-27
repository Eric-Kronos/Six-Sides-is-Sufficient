tool
extends "res://addons/Voxel-Core/src/VoxelSet.gd"

export (Array, Color) var colors = []
export (Array, String) var names = []

func _load():
	yield(self, "ready")
	for i in range(min(colors.size(), names.size())):
		set_voxel(Voxel.colored(colors[i]), names[i])
#

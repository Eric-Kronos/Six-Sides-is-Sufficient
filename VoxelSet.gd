tool
extends "res://addons/Voxel-Core/src/VoxelSet.gd"

func _load():
	set_voxel(Voxel.colored(Color.black), 'black')
	set_voxel(Voxel.colored(Color.white), 'white')
	set_voxel(Voxel.colored(Color("ffe6da")), 'skin')
	set_voxel(Voxel.colored(Color("bd5ad3")), 'purple')
	set_voxel(Voxel.colored(Color("f5ccff")), 'light_purple')
	set_voxel(Voxel.colored(Color("fbc7a4")), 'coat_accents')
	set_voxel(Voxel.colored(Color("f7b68d")), 'coat_accents_dark')
	set_voxel(Voxel.colored(Color("ffdd82")), 'hair')
	set_voxel(Voxel.colored(Color("ffcc4a")), 'hair_accents')
	set_voxel(Voxel.colored(Color("34b1e3")), 'suit')
	set_voxel(Voxel.colored(Color("247ba0")), 'suit_dark')

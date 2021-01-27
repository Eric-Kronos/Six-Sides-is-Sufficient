tool
extends Spatial



## Enums
enum Biomes { PLAIN, DRY, TUNDRA }



## Constants
const voxel_set := preload("res://examples/ProceduralWorld/TiledVoxelSet.tres")

const Biome = preload("res://Biome.gd")

## Exported Variables
export(int, 8, 512) var height := 128

export(float, 0.01, 10.0, 0.01) var frequency := 1.0

export(float, 0.01, 10.0, 0.01) var amplitude := 1.0

export(float, 0.01, 10.0, 0.01) var redistribution := 1.8

export(float, 0.0, 1.0, 0.01) var structure_rate := 0.8

export(float, 0.0, 100.0, 1.0) var biome_factor := 10.0

export(int, 0, 10) var chunk_layers := 6 #6 is best

export(int, 16, 128) var chunk_size := 16

export var marker_path : NodePath

export (Array, Resource) var biomes = [] setget set_biomes


## Private Variables
var _noise : OpenSimplexNoise

var _chunks := {}
var _chunks_mutex := Mutex.new()


## OnReady Variables
onready var Chunks := get_node("Chunks")



## Built-In Virtual Methods
func _ready():
	if not Engine.editor_hint:
		_noise = OpenSimplexNoise.new()
		randomize()
		_noise.seed = randi()


func _process(delta):
	if not Engine.editor_hint and not marker_path.is_empty():
		var marker : Spatial = get_node(marker_path)
		if is_instance_valid(marker):
			var center_chunk := _world_to_chunk(marker.translation)
			var checked = []
			for x in range(-chunk_layers, chunk_layers + 1):
				for z in range(-chunk_layers, chunk_layers + 1):
					var chunk := center_chunk + Vector3(x, 0, z)
					checked.push_back(chunk)
					_chunks_mutex.lock()
					var b = not _chunks.has(chunk)
					_chunks_mutex.unlock()
					if b:
						_chunks_mutex.lock()
						_chunks[chunk] = null
						_chunks_mutex.unlock()
						_add_chunk(chunk)
			_chunks_mutex.lock()
			var keys = _chunks.keys().duplicate()
			_chunks_mutex.unlock()
			for chunk in keys:
				if not checked.has(chunk):
					_remove_chunk(chunk)

func set_biomes(val : Array):
	if val.size() > biomes.size():
		for i in range(biomes.size(), val.size()):
			if val[i] != null:
				biomes.push_back(val[i])
			else:
				biomes.push_back(Biome.new())
	elif val.size() < biomes.size():
		for i in range(val.size(), biomes.size()):
			biomes.pop_back()


## Private Methods
func _world_to_chunk(world : Vector3) -> Vector3:
	var chunk := (world / chunk_size).round()
	chunk.y = 0
	return chunk


func _chunk_to_world(chunk : Vector3) -> Vector3:
	return chunk * chunk_size

func _generate_chunk(chunk_data : Array) -> void:
	
	var chunk : Vector3 = chunk_data[0]
	var chunk_node : VoxelMesh = chunk_data[1]
	
	_chunks_mutex.lock()
	var b = _chunks.has(chunk) and _chunks[chunk] != null
	_chunks_mutex.unlock()
	
	if b:
		return
	
	var elevation = []
	
	for x in range(-1,chunk_size+1):
		for z in range(-1,chunk_size+1):
			var world_grid := _chunk_to_world(chunk) + Vector3(x, 0, z)
			
			var noise_1 := preload("res://test_curve.tres").interpolate(abs(_noise.get_noise_3dv(
					world_grid * 0.01 * frequency) * amplitude))
			var noise_2 := 0.1 * abs(_noise.get_noise_3dv(
					world_grid * 0.25 * frequency) * amplitude)
			#var noise_4 := 0.0 * _noise.get_noise_3dv(
			#		world_grid * 2 * frequency) * amplitude
			var noise := noise_1 + noise_2
			#var noise = noise_1 
			
			var altitude := noise * height
			altitude = altitude if altitude > 0 else 0
			elevation.push_back(altitude)
	
	var adjusted_chunk_size = chunk_size + 2
	
	var rounds = 5
	for i in range(rounds):
		var smoothed_elevation = []
		for x in range(chunk_size):
			for z in range(chunk_size):
				var smoothed = 0.2 * elevation[1+adjusted_chunk_size*(1+x)+z] \
						+ 0.2 * elevation[1+adjusted_chunk_size*(1+x+1)+z] \
						+ 0.2 * elevation[1+adjusted_chunk_size*(1+x-1)+z] \
						+ 0.2 * elevation[1+adjusted_chunk_size*(1+x)+z+1] \
						+ 0.2 * elevation[1+adjusted_chunk_size*(1+x)+z-1] 
				
				smoothed_elevation.push_back(smoothed)
		for x in range(chunk_size):
			for z in range(chunk_size):
				elevation[1+adjusted_chunk_size*(1+x)+z] = smoothed_elevation[chunk_size*x+z]
			
	
	elevation = PoolRealArray(elevation)
	
	for x in range(chunk_size):
		for z in range(chunk_size):
			var world_grid := _chunk_to_world(chunk) + Vector3(x, 0, z)
			
			var temperature = abs(_noise.get_noise_3dv(
				world_grid * 0.05 * 1))
			
			var current_elevation = elevation[1+adjusted_chunk_size*(1+x)+z]
			
			var biome := Vector2(current_elevation/float(height),temperature-current_elevation/float(height))
			if (biome.x > 0.5):
				print(biome)
			var biome_key := "ERR"
			var biome_res : Biome = null
			var lowest = 5.0

			for pos_biome in biomes:
				if (pos_biome is Biome):
					var proximity = (pos_biome.spawn_environment - biome).length()
					if proximity < lowest:
						lowest = proximity
						biome_key = pos_biome.id
						biome_res = pos_biome
				else:
					printerr("Resource in biomes is of incorrect type.")
			
			var local_grid := Vector3(x, 0, z)
			
			
			
			var height_offset = max(1, max(
				max(
					elevation[1+adjusted_chunk_size*(1+x+1)+z]-current_elevation, 
					elevation[1+adjusted_chunk_size*(1+x-1)+z]-current_elevation),
				max(
					elevation[1+adjusted_chunk_size*(1+x)+z+1]-current_elevation, 
					elevation[1+adjusted_chunk_size*(1+x)+z-1]-current_elevation)))
			
			var altitude = floor(current_elevation + height_offset)
			
			
			
			for y in range(altitude-height_offset, altitude):
				local_grid.y = y
				var voxel_id := -1
				if y == altitude - 1:
					voxel_id = biome_res.temp_voxel_id if biome_res != null else 0
				elif y < altitude - 3:
					voxel_id = 3
					
					#continue
				elif y < altitude - 1:
					voxel_id = 0
					
					#continue
				
				chunk_node.set_voxel(local_grid, voxel_id)
				#if not (local_grid.y < 19 and local_grid.y == altitude - 1):
				#	continue
				#var spawn_point := range_lerp(
				#		_noise.get_noise_3dv(
				#				(Vector3(
				#						floor(world_grid.x / 5),
				#						0,
				#						floor(world_grid.z / 5))
				#				* biome_frequency)) *  biome_amplitude,
				#		-1, 1, 0, 1)
				#if not spawn_points.has(spawn_point) and randf() < biome_structure_rate:
				#	spawn_points.append(spawn_point)
				#	var structure_id : int = _biome_structures[biome_key][randi() % _biome_structures[biome_key].size()]
				#	var structure_chance : float = _structures[structure_id][0]
				#	if randf() < structure_chance:
				#		var structure : VoxelMesh = _structures[structure_id][1]
				#		for structure_grid in structure.get_voxels():
				#			chunk_node.set_voxel(
				#					local_grid + Vector3.UP + structure_grid,
				#					structure.get_voxel_id(structure_grid))

	chunk_node.update_mesh()
	
	chunk_node.translation = chunk * chunk_size
	chunk_node.translation -= Vector3(1, 0, 1) * (chunk_size / 2)
	chunk_node.translation *= Voxel.VoxelWorldSize
	
	
	_chunks_mutex.lock()
	_chunks[chunk] = chunk_node
	_chunks_mutex.unlock()
	
	call_deferred("_add_chunk",chunk)


var threads = {}

func _add_chunk(chunk : Vector3) -> void:
	_chunks_mutex.lock()
	var chunk_node : Spatial = _chunks.get(chunk, null)
	_chunks_mutex.unlock()
	if not is_instance_valid(chunk_node):
		var thread : Thread = Thread.new() if not threads.has(chunk) else threads[chunk]
		threads[chunk] = thread
		if not thread.is_active():
			chunk_node = VoxelMesh.new()
			chunk_node.uv_map = true
			chunk_node.voxel_set = voxel_set
			thread.start(self, "_generate_chunk", [chunk, chunk_node])
		return
	if not is_instance_valid(chunk_node.get_parent()):
		Chunks.add_child(chunk_node)
		#$Tween.interpolate_property(chunk_node, "translation", chunk_node.translation - Vector3(0,10,0) , chunk_node.translation, 1.0)
		#$Tween.start()
		if threads.has(chunk):
			threads[chunk].wait_to_finish()


func _remove_chunk(chunk : Vector3) -> void:
	_chunks_mutex.lock()
	var chunk_node : Spatial = _chunks.get(chunk, null)
	_chunks.erase(chunk)
	_chunks_mutex.unlock()
	if is_instance_valid(chunk_node) and is_instance_valid(chunk_node.get_parent()):
		chunk_node.get_parent().remove_child(chunk_node)
		chunk_node.queue_free()
		

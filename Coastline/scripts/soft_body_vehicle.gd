extends Node3D
class_name SoftBodyVehicle

## Experimental deformable vehicle-body helper for Godot 4.4.
## Attach this node to a vehicle, assign a subdivided MeshInstance3D, then call
## build_deformable_body(). This creates a SoftBody3D visual/physics body;
## wheel suspension and vehicle movement remain the responsibility of the vehicle controller.

@export_node_path("MeshInstance3D") var source_mesh_path: NodePath
@export_range(1.0, 250.0, 1.0) var body_mass: float = 45.0
@export_range(1, 32, 1) var simulation_precision: int = 8
@export_range(0.0, 1.0, 0.01) var body_stiffness: float = 0.55
@export_range(0.0, 1.0, 0.01) var damping: float = 0.08
@export var collision_layer: int = 1
@export var collision_mask: int = 1

var deformable_body: SoftBody3D


func build_deformable_body() -> SoftBody3D:
	var source := get_node_or_null(source_mesh_path) as MeshInstance3D
	if source == null:
		push_error("SoftBodyVehicle: source_mesh_path must point to a MeshInstance3D.")
		return null
	if source.mesh == null:
		push_error("SoftBodyVehicle: the source MeshInstance3D has no mesh.")
		return null

	if deformable_body != null and is_instance_valid(deformable_body):
		deformable_body.queue_free()

	deformable_body = SoftBody3D.new()
	deformable_body.name = "DeformableVehicleBody"
	deformable_body.mesh = source.mesh.duplicate() as Mesh
	deformable_body.transform = source.transform
	deformable_body.total_mass = body_mass
	deformable_body.simulation_precision = simulation_precision
	deformable_body.stiffness = body_stiffness
	deformable_body.damping_coefficient = damping
	deformable_body.collision_layer = collision_layer
	deformable_body.collision_mask = collision_mask

	source.get_parent().add_child(deformable_body)
	source.visible = false
	return deformable_body


func restore_source_mesh() -> void:
	if deformable_body != null and is_instance_valid(deformable_body):
		deformable_body.queue_free()
	deformable_body = null
	var source := get_node_or_null(source_mesh_path) as MeshInstance3D
	if source != null:
		source.visible = true

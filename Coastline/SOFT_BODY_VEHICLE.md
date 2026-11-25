# Experimental soft-body vehicle body (Godot 4.4)

This is an **experimental building block**, not a finished soft-body car.

## What it adds
- A reusable `SoftBodyVehicle` GDScript helper.
- Creates a Godot `SoftBody3D` from a selected vehicle-body `MeshInstance3D`.
- Exposes mass, simulation precision, stiffness, damping, and collision layer/mask.

## Setup
1. Add `SoftBodyVehicle.gd` as a child of the vehicle root.
2. Assign `source_mesh_path` to the vehicle's body `MeshInstance3D`.
3. Make sure the source mesh is suitably subdivided. A low-poly imported car body will not visibly crumple well; use a deformable, evenly tessellated body mesh.
4. Call `build_deformable_body()` after the vehicle scene is ready.

## Current Coastline limitation
The tracked project currently references `res://assets/vehicles/sports-car.glb`, but that model is not present in the repository. Therefore this helper is deliberately not wired into `main.gd`: doing so without the actual model would risk breaking the existing car. It also does not implement wheel suspension, drivetrain, or a complete soft-body vehicle controller. Those need to be integrated with the real vehicle scene and tested in Godot.

Treat this as a prototype for the deformable body layer, not a claim that the playable Coastline car already has full soft-body physics.

extends RigidBody3D

@onready var starting_transform: Transform3D = self.global_transform

func return_home():
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	sleeping = true

	global_transform = starting_transform

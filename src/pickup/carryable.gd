extends RigidBody3D

@onready var starting_transform: Transform3D = self.global_transform

@export var score: int = 1
var delivered: bool = false
var carried: bool = false


func return_home():
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	global_transform = starting_transform

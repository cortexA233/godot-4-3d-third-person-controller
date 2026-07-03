extends Node3D

@onready var _sound: AudioStreamPlayer3D = $ExplosionSound


func _ready() -> void:
	_sound.pitch_scale = randfn(1.0, 0.05)
	_sound.play()

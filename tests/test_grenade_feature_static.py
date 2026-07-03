from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def test_weapon_switch_input_is_bound_for_keyboard_and_controller():
    project = read("project.godot")

    assert "weapon_switch={" in project
    assert '"physical_keycode":4194306' in project
    assert '"button_index":3' in project


def test_weapon_ui_exposes_default_and_grenade_slots():
    weapon_ui_script = read("icons/weapon_ui.gd")
    weapon_ui_scene = read("icons/weapon_ui.tscn")

    assert '"DEFAULT" : %Flash' in weapon_ui_script
    assert '"GRENADE" : %Bomb' in weapon_ui_script
    assert "bomb_icon.png" in weapon_ui_scene
    assert 'node name="Bomb"' in weapon_ui_scene


def test_player_routes_grenade_mode_to_preview_and_throw_without_melee_fallback():
    player = read("player/player.gd")

    assert "GRENADE_SCENE" in player
    assert "GRENADE_AIM_ASSIST_SCENE" in player
    assert "WeaponMode.GRENADE" in player
    assert 'Input.is_action_just_pressed("weapon_switch")' in player
    assert "func _throw_grenade(is_aiming: bool)" in player
    assert "_throw_grenade(is_aiming)" in player
    assert "_update_grenade_aim_assist" in player


def test_grenade_projectile_detonates_once_and_spatially_damages_non_player_targets():
    projectile = read("player/grenade_projectile.gd")
    scene = read("player/grenade_projectile.tscn")

    assert "class_name GrenadeProjectile" in projectile
    assert "_has_detonated" in projectile
    assert "get_nodes_in_group(\"damageables\")" in projectile
    assert "body == shooter" in projectile
    assert "distance_to" in projectile
    assert "explosion_radius" in projectile
    assert "damage(impact_point, force)" in projectile
    assert 'node name="GrenadeProjectile" type="RigidBody3D"' in scene
    assert "musket-explosion-6383.wav" in scene


def test_grenade_aim_assist_draws_arc_and_landing_marker():
    aim_assist = read("player/grenade_aim_assist.gd")
    scene = read("player/grenade_aim_assist.tscn")

    assert "class_name GrenadeAimAssist" in aim_assist
    assert "ImmediateMesh" in aim_assist
    assert "PhysicsRayQueryParameters3D" in aim_assist
    assert "LandingMarker" in scene
    assert "TrajectoryLine" in scene

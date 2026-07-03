from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def test_input_map_has_keyboard_and_controller_weapon_switch() -> None:
    project = read("project.godot")

    weapon_switch_start = project.index("weapon_switch={")
    weapon_switch_end = project.index("\n}", weapon_switch_start)
    weapon_switch_block = project[weapon_switch_start:weapon_switch_end]

    assert "InputEventKey" in weapon_switch_block
    assert "physical_keycode\":4194306" in weapon_switch_block
    assert "InputEventJoypadButton" in weapon_switch_block


def test_player_routes_grenade_mode_to_throwing_and_keeps_default_combat() -> None:
    player = read("player/player.gd")

    assert 'const WEAPON_DEFAULT := "DEFAULT"' in player
    assert 'const WEAPON_GRENADE := "GRENADE"' in player
    assert 'Input.is_action_just_pressed("weapon_switch")' in player
    assert "GRENADE_PROJECTILE_SCENE.instantiate()" in player
    assert "func _throw_grenade()" in player
    assert "func _update_grenade_preview()" in player


def test_grenade_projectile_applies_spatial_damage_and_skips_shooter() -> None:
    projectile = read("player/grenade_projectile.gd")

    assert "extends RigidBody3D" in projectile
    assert 'get_nodes_in_group("damageables")' in projectile
    assert "body == shooter" in projectile
    assert "explosion_radius" in projectile
    assert "EXPLOSION_SCENE.instantiate()" in projectile
    assert "queue_free()" in projectile


def test_hud_contains_default_and_grenade_weapon_choices() -> None:
    weapon_ui_script = read("icons/weapon_ui.gd")
    weapon_ui_scene = read("icons/weapon_ui.tscn")

    assert '"DEFAULT"' in weapon_ui_script
    assert '"GRENADE"' in weapon_ui_script
    assert "Bomb" in weapon_ui_scene
    assert "bomb_icon.png" in weapon_ui_scene


def test_grenade_preview_has_arc_points_and_landing_marker() -> None:
    preview = read("player/grenade_aim_preview.gd")

    assert "class_name GrenadeAimPreview" in preview
    assert "func update_preview" in preview
    assert "MeshInstance3D" in preview
    assert "_landing_marker" in preview

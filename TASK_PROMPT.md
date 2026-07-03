# RoboBlast Grenade Feature Task

You are working on an ablated copy of a Godot third-person shooter demo. The game currently has movement, aiming, shooting, melee attacks, enemies, breakable crates, coins, jump pads, HUD elements, sounds, and visual assets. Your task is to implement a complete grenade weapon feature from scratch.

Treat this as a player-facing gameplay task, not a code-shape task. You may inspect and modify the project as needed, but do not look at git history, other branches, external verifier files, previous solutions, or online copies of this feature. Use only the current project and this specification.

## Goal

Add a second weapon mode: grenades. The player should be able to switch between the existing/default weapon behavior and a grenade mode. In grenade mode, aiming and attacking should throw an arcing grenade that lands or collides in the world, detonates, damages nearby enemies or breakable objects, and gives clear visual/audio feedback.

The feature should feel integrated with the existing third-person shooter controls and presentation. Preserve all existing non-grenade behavior unless this task explicitly changes it.

## Controls And Weapon Switching

- The player starts in the default weapon mode.
- Pressing the weapon-switch control should toggle between default weapon mode and grenade mode.
- Keyboard players should be able to use `Tab` for weapon switching.
- Controller players should also have a reasonable weapon-switch input if the project already supports controller play.
- When default mode is selected:
  - Existing aim, shoot, and melee behavior should continue to work.
  - The player should not throw grenades.
- When grenade mode is selected:
  - Pressing attack while aiming should throw a grenade instead of firing the default projectile.
  - Melee behavior may remain available when not aiming, but it must not accidentally throw a grenade.
  - Grenade throwing should have a cooldown or rate limit so holding or spamming attack cannot create an uncontrolled stream of grenades.
- Switching modes should be reliable before and after throwing grenades.

## HUD And Player Feedback

- The HUD should clearly show that the player has two weapon choices: default weapon and grenades.
- The currently selected weapon should be visibly distinguishable.
- The selected weapon indicator should update immediately when the player switches modes.
- Existing aiming reticle/camera behavior should remain coherent.
- Grenade mode should be understandable without requiring debug text or editor-only indicators.
- The UI should not overlap, flicker, or permanently hide existing HUD information such as coins.

## Aiming Feedback

When grenade mode is selected and the player is aiming:

- Show a visible trajectory preview, landing marker, or equivalent aiming aid before the grenade is thrown.
- The aiming aid should communicate that the grenade will travel in an arc rather than in a straight bullet path.
- The preview should update as the player changes aim direction or camera direction.
- The predicted landing/impact feedback should appear near the intended target area when possible.
- The aiming aid should be hidden when:
  - The player is not aiming.
  - The player switches back to the default weapon.
  - The player cannot currently throw a grenade.
- The aiming aid should be visible in normal gameplay, not only in debug overlays.

## Grenade Throw And Flight

When the player throws a grenade:

- A visible grenade-like object should appear near the player and move into the world.
- It should travel as a physical arcing projectile influenced by gravity or an equivalent believable ballistic simulation.
- It should not instantly teleport to the target or apply damage with no flight phase.
- It should not immediately collide with or damage the player at spawn.
- It should interact plausibly with the environment:
  - It may bounce, roll, or settle after impact.
  - It should not pass through normal level geometry in common cases.
  - It should not fly forever.
- The throw direction should correspond to the player's current aim.
- Throws should remain deterministic and stable enough that repeated attempts behave consistently.

## Detonation

- A grenade should detonate after impact, after a short fuse, or after a combination of impact and fuse timing.
- The delay should be short enough to feel responsive in combat.
- Detonation should happen near the grenade's final flight/impact position.
- Each thrown grenade should detonate once.
- After detonation, temporary grenade and explosion objects should clean themselves up.
- Repeated throws should continue to work after earlier grenades have detonated.

## Explosion Gameplay Effect

The explosion should affect nearby damageable game objects.

- Nearby enemies should be damaged, defeated, knocked back, or otherwise visibly affected in a way consistent with the existing game.
- Nearby breakable crates or equivalent destructible targets should be damaged or broken.
- Multiple nearby targets should be affected by the same explosion.
- Distant enemies and distant destructible targets should not be affected.
- The player should not be damaged by their own grenade explosion.
- The explosion should not globally damage every target in the scene.
- Damage should be spatially based around the detonation point.

## Visual And Audio Feedback

- The thrown grenade should have a visible in-world representation.
- Detonation should produce a visible explosion effect at or very near the detonation point.
- The explosion should be noticeable from the normal gameplay camera.
- Detonation should play an appropriate explosion sound.
- Effects should not persist forever after they are finished.
- Visual and audio feedback should work for more than one throw.

## Stability And Integration

- The game should run without script errors.
- The main scene should still load and play normally.
- Existing movement, jumping, aiming, default shooting, melee attacks, enemies, crates, coins, and jump pads should not be broken by the grenade work.
- The implementation should tolerate repeated weapon switches and repeated grenade throws.
- Avoid test-only shortcuts, debug-only visuals, hard-coded one-off target damage, or behavior that only works in a single prearranged scene setup.
- Prefer using existing project style and Godot conventions where they are apparent.

## Suggested Manual Smoke Test

After implementing, manually verify this flow in the playable game:

1. Start the main game scene.
2. Confirm the default weapon mode is active and normal shooting/melee still works.
3. Press `Tab` and confirm the HUD indicates grenade mode.
4. Aim and confirm a visible arcing trajectory or landing indicator appears.
5. Throw a grenade and confirm a visible projectile travels through the world.
6. Confirm it detonates near where it lands or collides.
7. Confirm nearby enemies or breakable objects are affected while distant targets are not.
8. Confirm the player is not harmed by their own explosion.
9. Throw a second grenade after the cooldown and confirm it also works.
10. Switch back to the default weapon and confirm normal shooting still works.

## Deliverable

Implement the grenade weapon feature in the project. Leave the project in a runnable state and summarize what you changed, how to test it, and any limitations you are aware of.

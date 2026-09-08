# Hub pass: review notes

## Implemented

- Original warm village art direction, with a western smith yard, northeastern research pavilion, southwest pond, and southeastern kitchen garden.
- Unarmed traversal character; walk/jog, camera rotation, zoom, and overview.
- Four swimming ducks that gather at the feeding point, with water wakes.
- Friendly and shy cats, with petting for friendly cats.
- Birds that react to approach and the village bell, then land at a different feeding patch.
- Garden watering with a held watering can and water particles.
- A usable bench with a skeletal sitting pose and movement to stand up.
- Existing smith hammering, researcher reading, tree/grass motion, falling leaves, forge effects, and hub ambience.
- New editable Blender assets and new character activity clips.

## Validation

`./play.fish --headless -- --self-test`: 30 checks passed. Coverage includes movement, no attached weapons, imported skeletal clips, live-collision navigation, activity and service access, the interaction-key petting path, duck gathering, garden state, bench exit, and bird relocation/landing.

The scene was rendered using Godot 4.7.2 Forward+ / Vulkan on an RTX 4070. Reviewed captures cover arrival, overview, pond, blacksmith, research, garden, petting, sitting, and watering. These checks establish rendered appearance and runtime behavior; they are not a substitute for the author's hands-on feel and art-direction review.

## Deliberately deferred

The final protagonist, detailed NPC jobs/schedules, commerce, research timers, item upgrades, combat, and progression. Activity state is currently session-local. Shy cats need space rather than allowing immediate petting.

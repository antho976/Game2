# Hub polish passes

Baseline: `30be029` commits directional combat, progression and the expanded school district. Implement and verify one pass at a time. Remaining entries are requirements, not completed work.

## 1. Interaction and dialogue
- [x] Shop and research interactions take precedence over cats and ambient activities.
- [x] Remove the shy-cat message; retain petting for friendly cats.
- [x] Hide first-person arms in the teacher's external camera and show the player's actual body for optional conversations.
- [x] Remember asked teacher questions and mute their text while allowing revisits.
- [x] Add short expressive, nonverbal dialogue sounds, with a reusable system for other NPCs.

## 2. Input, HUD and settings
- [ ] Full Steam controller support across movement, directional combat, quickstep, shops, research, dialogue and menus. Include focus navigation, device-aware prompts and Steam Input mapping; verify actual device behavior when a controller is available.
- [ ] Replace placeholder hub HUD with a finished game interface.
- [ ] Split settings into submenus.
- [ ] Separate volume controls for master, music, ambience, effects, UI and dialogue sounds, with every source routed appropriately.

## Blacksmith shop: removed from scope
The user confirmed the redesign was already completed elsewhere. Preserve it. Only interaction-priority repairs remain part of this pass.

## 3. Village spaces and routines
- [ ] Give the plant bed a deliberate surrounding environment.
- [ ] Restore a portal near the original dummy area.
- [ ] Add a pub where NPCs sit and converse, with actual displayed exchanges.
- [ ] Replace aimless standing with purposeful routines.
- [ ] Remove NPC feeding of birds and cats; keep ducks. Natural animal foraging can remain.
- [ ] Move duck feeding to the bench with visible feed landing where ducks gather.

## 4. Motion
- [ ] Make work actions loop or end cleanly, without unintended idle gaps before departure.
- [ ] Improve the stiff walking gait.
- [ ] Diagnose running blur at roughly 200 FPS using rendering, interpolation, animation and frame-pacing evidence. Do not assume 60 FPS source animation is the cause.

## Validation record

Pass 1: interaction tests passed for friendly and shy cats overlapping both services, silent shy-cat behavior, and ordinary petting. School tests passed for player body visibility, hidden first-person arms, revisitable question styling, saved question history and dialogue sound routing. The teacher scene was also checked in the renderer. Passes 2 through 4 remain open.

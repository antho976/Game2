# Game2

A small, warm village hub built in Godot 4.7. The original crawler is the visual reference; only reused dependencies are included here.

## Run

```fish
./play.fish
```

Or import `project.godot` into Godot 4.7 and press F5. The launcher imports assets and isolates local data from the original game. The packed Blender sources are excluded from Godot's automatic importer, so Blender is only required when editing or regenerating assets.

## Controls

- WASD/arrows: walk; Shift: run.
- F: interact with the nearest animal or activity.
- I: inventory, equipment and currencies (outside combat). K: combat skills.
- X: draw or sheath the equipped sword. T: release or reacquire a combat target.
- Mouse wheel: zoom. Middle mouse drag: rotate the elevated camera.
- Tab: village overview. H: hide interface. M: mute audio. Options has a slider for music, ambience, effects, interface and voices.
- R: return to the arrival path. F11: fullscreen. Escape: pause/menu.

## Things to try

Approach the feeding birds and watch them fly to another patch. Pet a friendly cat. Scatter feed at the pond bank and watch the ducks gather. Watch the gardener tend the kitchen garden. Sit on either bench and move to stand up. The pond bench leaves the western house lane clear, and ducks can be fed from the open bank. Ring the village bell.

Press F near the blacksmith to buy, equip, preview, or upgrade gear. The shop is laid out like a game armory: gear cards with drawn item icons and rarity framing on the left, an appraisal panel with stat bars and comparisons against worn gear in the middle, and a lit fitting room on the right. Level locks, owned copies and worn pieces are badged on the cards, and the anvil tab shows temper ranks and survival odds as gauges. The shop stocks three greatswords and two full plate sets with independent helmet, chest, gloves and boots slots. Duplicate purchases have separate identities and upgrade ranks. Equipping changes the animated player and first-person equipment; the fitting preview also works without purchasing. Research is available at the archive. Sparring in the eastern yard earns gold and XP. No debug currency or selling is exposed.

Residents collect water, feed birds, cats and ducks, tend the garden, meet to talk, and return to assigned houses at staggered evening times. Shared stations are reserved while a resident travels to and uses them. A twelve-minute day/night cycle changes the lighting and lamp intensity. Your position, village time, garden state and equipment are saved every 15 seconds and when returning to the main menu or quitting. Shop transactions save immediately and roll back if saving fails. Feeding remains temporary. Continue restores the saved visit; New Game replaces it after confirmation.

The title screen orbits the live village. Settings opens a dedicated page, including an optional FPS counter. Options persist display mode, frame limit, VSync, 3D resolution scale, and volume. Defaults use 60 FPS and 85% 3D resolution while keeping the interface sharp. Fullscreen retains the screen aspect ratio, with the HUD anchored to its edges.

This build defaults to OpenGL Compatibility and native Wayland when available. This avoids the Vulkan/XWayland combination used during the reported freezes. A stability test is included, but the original graphics stall has not been isolated to a specific driver fault.

The traversal character begins unarmed and uses the refined player model on the reused villager rig, extended with pet, feed, water, and sit animations. It is a hub stand-in, not a finalized protagonist design.

Prototype upgrades begin with five ranks with survival chances of 85%, 72%, 60%, 48%, and 35%. Equipment research unlocks up to +8 with later base survival of 28%, 22%, and 16%. Failure consumes the gold and permanently destroys that exact copy, including on the first attempt; the confirmation displays both chances. Each rank initially adds 10% of base damage or protection; research improves only future attempts, with earned gains saved per item. Gold cost is rounded up from 25% of the purchase price times the next rank. These values are provisional. Research improves survival and future stat gains, and trade studies reduce prices. Early upgrades can become safe, but the final upgrade always retains risk.

Shop checks: `./play.fish -- --shop-test`. This uses isolated saves and test-only currency to exercise level/gold gates, duplicate copies, equipment, success/destruction, stale confirmations, failed-save rollback and legacy saves, and captures the rendered shop and both plate sets.

## Inventory and combat HUD

The blacksmith offers one free Warden Greatsword per character. Accept it in the shop; it becomes an owned item and equips automatically if the weapon slot is empty. The claim is saved, cannot be repeated after losing the sword, and resets on New Game. Existing saves can claim it too.

Press I to open the inventory outside combat. Inspect, filter and sort owned gear, compare with equipped pieces, equip or remove all five slots, rotate the equipped character preview, and view gold, diamonds and living essence. Each duplicate keeps its own upgrade rank. Equipment changes save immediately and roll back on write failure. Selling, dropping and consumables are not part of this inventory pass.

The compact bottom dock shows health and stamina, with a thin exhaustion strip. Skill tiles, XP text and the shortcut legend have been removed; K still opens skill learning. Enemy health and exhaustion sit above the active enemy. Four small arrows show the selected lane, enemy guard and an amber incoming attack direction. A red spark on the enemy blade and matching red arrow flash signal the final 0.20-second perfect-parry window.

Settings → Camera offers aim lock and hard lock. Aim lock follows the enemy under the pointer in overhead views or near the screen centre in first/third person; hard lock keeps its opponent until released with T. Press T again to acquire the pointed enemy. Target switches preserve damage, exhaustion and recovery, and wait until a committed player swing ends. X draws or sheathes in exploration and combat; a toggle during an attack waits for recovery. Drawing requires an equipped weapon except for the training loan.

Checks: `./play.fish --headless -- --inventory-test`; omit `--headless` to capture the inventory at three window sizes, the starter offer and the HUD.

## First expedition

The portal beside the original eastern dummy now enters **The Spent Works**. Eight Wardens occupy its rooms and use the shared directional combat system, with one active opponent at a time. Gather guarded living fragments, then return through the arrival gate to bank gold, diamonds, living essence and XP. Defeat loses the unbanked haul; Continue restores an unfinished expedition. No boss is included. See `docs/FIRST_PORTAL.md` for scope and validation.

Expedition checks: `./play.fish --headless -- --expedition-test`. Native captures: `./play.fish -- --expedition-capture`.

Targeting and weapon checks: `./play.fish --headless -- --targeting-test`; omit `--headless` for rendered HUD, arrow and draw/sheath captures.

## Sources and checks

- `art/hub/hub_library.blend`: reused editable architecture, scenery, and NPC source.
- `art/village/village_details.blend`: new ducks, tabby cat, dock, garden, watering can, and bell.
- `tools/village_details.py`: regenerate the new props.
- `tools/player_activities.py`: rebuild the hub character's added animations from the original rig.
- `docs/REUSED_ASSETS.md`: source provenance.
- `docs/STORY.md`: story direction.
- `docs/SYSTEMS.md`: progression requirements awaiting implementation.
- `docs/AUDIO.md`: every sound the game needs, by trigger, and how `scripts/audio_kit.gd` plays them.
- `tools/generate_sounds.py`: generate missing sound files from `assets/audio/manifest.json` with ElevenLabs (`ELEVENLABS_API_KEY`).
- `docs/PERFORMANCE.md`: why the hub was renderer-bound and how batching fixed it without changing the picture.

```fish
./play.fish --headless -- --self-test
```

Native menu and fullscreen checks: `./play.fish -- --menu-test` (uses separate test saves/settings).

The runtime checks cover movement, interaction selection, imported animation clips, animal reactions, cat limb attachment, house-lane clearance, access paths, pond feeding, garden state, and bench exit. Visual captures can be generated locally with `./play.fish -- --capture`; these are not committed.

Native three-minute stability and pond traversal check: `./play.fish -- --polish-test`. This exercises movement, repeated fullscreen transitions, seating, bank access, and frame delivery using isolated test save files.

The expanded eastern court contains a reactive training dummy. The temporary portal and its approach path have been removed while the next layout is planned. The garden is maintained by residents rather than a required player chore.

Routine simulation: `./play.fish --headless --fixed-fps 60 -- --routine-test`. Day/night visual captures: `./play.fish -- --village-capture`.

Feeding now has a timed hand release and visible food trajectories. Well visits have a shared two-minute cooldown and a once-per-day limit per resident, with a bucket-lowering and hauling animation. Small props, lamp posts and garden fences have traversal collision. Interaction checks: `./play.fish --headless --fixed-fps 60 -- --cleanup-test`.

Ducks use capsule bodies and separation steering, with individual head dips while feeding. Navigation leaves extra clearance around thin fences and chooses a reachable starting cell; the cleanup regression exercises the southeast garden fence and duck gathering.

The player uses a separate `player_refined.glb`, built by `tools/player_model.py` through `tools/player_activities.py`: layered clothing, a defined face, boots and cuffs. NPC models remain unchanged for comparison. The player's locomotion comes from `tools/hero_animation.py`, which adds neck and shoulder bones on top of the villager skeleton (the shared activity clips still play) and authors the clips procedurally: a grounded ready idle with breathing, weight shifts and a slow scan; a planted walk with heel strike, toe-off, pelvis twist and counter-rotating shoulders; and a run with a flight phase and pumping arms. Playback speed is matched to ground speed so the feet do not slide, and the model leans into speed and banks into turns. Run `./play.fish -- --player-visual` to capture the idle, walking pose, and cleared eastern garden.
The player uses a separate `player_refined.glb`, built by `tools/player_model.py` through `tools/player_activities.py`: layered clothing, a defined face, boots and cuffs, a quiet breathing idle, and relaxed walking arms. NPC models remain unchanged for comparison. Run `./play.fish -- --player-visual` to capture the idle, walking pose, and cleared eastern garden.

Options → Camera offers overhead, first-person, third-person, and far-overhead presets. Height, distance, visible area, perspective FOV, and first-person mouse sensitivity save automatically. Middle mouse rotates overhead/third-person views; the wheel zooms. First person captures the mouse, Esc releases it, and clicking the game restores capture after a focus change. Third-person camera rays pull the view forward at solid obstacles.

Cat feeding now happens on open paving. Residents alternate one visible food throw with a short idle pause, instead of looping empty-handed feeding gestures.

Residents share one animal-feeding reservation, with bird feeding separated from the pond. The smith finishes his approach at the authored anvil position; sparks and sound trigger at the hammer contact frame (0.8 seconds). `--work-test` checks his return route and captures that pose.

The pond is enlarged with smoother irregular textured shoreline stones. Turf uses world-space color, soil, fiber and fine-grain variation beneath the grass blades. The smith yard now has a masonry fire chamber, chimney, slate lean-to, tool bench and stock racks; the archive has a timber pergola, paved terrace, book cabinets and a writing/specimen desk. Existing interaction positions remain connected.

First person displays a separate animated arms asset exported by `tools/player_activities.py`; feeding releases originate at its hand. Birds and ducks target the actual food landing positions, which remain visible long enough for the animals to gather. `--refresh-test` checks gathering and captures both workspaces and the pond.

Press F at the researcher to open branching Character, Equipment, Trade and Scholarship trees, plus a WIP Hub tree. The archive shares the armory's look: study nodes with tree emblems, rank pips and drawn prerequisite connectors, a study panel with per-rank bonuses, costs and timers, and a strip of research desks with live progress. Both screens draw their chrome from `scripts/ui_kit.gd`. Two concurrent studies expand to four; projects can be paused without losing progress. Research starts with gold costs and later adds diamonds, completes automatically with notifications, and progresses at 25% speed offline (improvable to 50%). The longest studies take 5–10 minutes of play. See `docs/RESEARCH.md` for the current prototype balance and `--research-test` for isolated checks. Character stat bonuses are recorded for the forthcoming combat system.

## Sword combat

Press F near the swordsman in the yard east of the school (or F6 from the hub) to spar. It is a directional greatsword duel in four lanes read from your side: High, Right, Low, Left. Arrows, a mouse swipe, or RMB plus a swipe choose the lane; LMB cuts, Q or Shift+LMB cuts heavy, RMB guards, Space quicksteps. A matching guard blocks, a freshly raised one within 0.2 seconds parries and opens a counter window, and a feint (changing lane in the first half of a swing) beats a partner who reads your lane. Two forms, Crossing cut (Left, Right, High) and Serpent's coil (Low, High, Low), give their last cut a property. Swings that meet in one lane clash. The swordsman keeps his measure, reads and answers your swings, feints and doubles at higher levels, and every attack he makes is telegraphed on the reticle drawn over his chest, with an amber direction arrow followed by a red weapon spark and red arrow flash when a guard raised now would parry. Blows carry weight: hit-stop scaled by heft, camera recoil away from the lane that landed, blood on the yard, staggers on heavy and critical hits, and slow-motion finishes. Victories pay gold and XP; levels give skill points for two short combat branches (K). See `docs/COMBAT.md` for the full rules and `./play.fish --headless -- --combat-test` for the checks.

# First portal: The Spent Works

## Agreed direction
- A 10–15 minute expedition through mines and underground settlement ruins.
- Alien ecology mixed with a recognizably inhabited world damaged by previous harvests.
- Local defenders and creatures eventually occupy distinct areas. The first asset review contains one humanoid defender only.
- Resources will come from guarded deposits and enemy drops. The boss and any post-boss harvest are explicitly deferred by the user.
- Defeat returns the player to the hub and loses the expedition's unbanked resources.
- The village gate combines weathered stone with signs of maintenance and ceremony, near the original dummy area.
- The user approved the first Warden and environment sample, then requested expansion. Do not build a boss yet.

## Review assets
Working names are provisional: **Tithe Warden** and **The Spent Works**.

The Warden is a local mine defender wearing layered iron over work clothing, a sealed sallet with a lamp, one reinforced shoulder, breathing filters and a sealed harvest vial. The weapon is a long cutting blade adapted from a mining tool. The humanoid skeleton and existing locomotion clips are retained; the blade uses the existing greatsword grip origin convention. The live expedition uses Claude's completed combat controller, including its posture and grip solvers, directional guards, feints, quicksteps and impact feedback.

The environment sample includes settlement masonry embedded in bedrock, timber mine frames, rails, a cart, supply crates, warm work lamps, exhausted extraction scars and a guarded living mineral seam. These establish a look and prop vocabulary, not a finished 10–15 minute dungeon.

The village portal asset has fitted arch stones, repair straps, ceremonial insets, lamps and offerings. Both review scenes add a restrained moving veil. The live village gate stands beside the original dummy on the eastern path. Press F at its threshold to enter.

## Expanded environment walkthrough

`scenes/first_portal_walkthrough.tscn` remains a separately runnable environment review. The main game embeds the same geometry through `scripts/dungeon/expedition.gd`. Claude's final combat PR #5 is included at `8cd11ac`; the user explicitly confirmed that integration could proceed.

The route descends through five places:

1. **The Threshold:** repaired gate, arrival supplies and a discarded manifest.
2. **The Lamp Gallery:** supported working tunnel and narrow-gauge track.
3. **The Sorting Hall:** a supported ore-screening machine, collection chutes and carts, buried flagstones and collapsed retaining walls. The previous disconnected facades, doors, stall and cistern have been removed.
4. **The Haulage Works:** loading cart, shift ledger, supplies and work lights.
5. **The Last Vein:** surviving mineral growth among fractured pillars and exhausted stone.

A separate service passage joins the far works to the entrance. In the standalone review, eight idle, rigged Warden placements mark the regular encounters; their blades are mounted to the skeleton. In the main game these become live defenders when approached. Inspectable writing is provisional environmental storytelling, not a new lore commitment. Deposits can be inspected, but extracting resources, rewards, saving an expedition, defeat penalties and combat are not implemented in this review. There is no boss or boss encounter. The intended 10–15 minute duration remains a target for the eventual expedition, not a measured duration of this environment walkthrough.

The scene reuses the game's existing player movement and animation, with physical boundary, prop and actor collisions. Overhead view cuts down the cave shell for visibility; first person restores the complete shell and ceiling. This scene never loads or writes the user's hub save. The entrance interaction closes the standalone walkthrough rather than pretending to return to an integrated hub.

Controls: WASD moves, Shift runs, E inspects, V toggles first person and overhead. Escape releases the captured mouse, then closes the review; clicking captures it again in first person.

Launch `scenes/first_portal_walkthrough.tscn` directly in Godot, or run `launch-mine-review.fish`. The launcher uses separate review data/config directories. `--mine-check` validates both floor connectivity and player-capsule reachability through actual scene colliders, including assertions that the cart and tunnel walls obstruct movement. `--mine-capture` generates four overhead views and one first-person view in the ignored `captures/` directory.

## Files and review
- `scenes/first_portal_review.tscn`: isolated three-view review scene. Keys 1/2/3 select the Warden, mine and portal; A/D rotate the Warden; Escape closes it.
- `assets/dungeon/first_portal/`: Warden, mining blade, mine sample and portal GLBs.
- `art/dungeon/first_portal.blend`: editable source collections.
- `tools/first_portal_assets.py`: reproducible Blender generator.
- `scripts/dungeon/asset_review.gd`: lighting, gate veil, camera views, capture and asset checks.
- `tools/first_portal_modules.py`: exports nine reusable scenery modules from the editable Blender source.
- `scripts/dungeon/mine_walkthrough.gd`: isolated layout, collisions, scenery, inspection text and review cameras.

The original isolated art review remains available alongside the integrated expedition. Rigid mine geometry is batched by material, while the editable Blender source retains individual props. The expanded walkthrough uses exported modules and authored collision shapes.

## Validation
The isolated asset review loaded all four original GLBs. Required humanoid bone names and nine retained animation clips passed checks. Front, rear, walking-pose, mine and portal captures were inspected. The source-import helper mesh and preview spotlight shadow acne found during review were corrected.

The expanded walkthrough loads the original nine scenery modules plus a new screening machine, retaining-wall remnants and ten distinct chipped flagstones. All 405 floor cells connect, and a capsule matching the player can reach the five areas and service return through the actual physics geometry. The same check confirms the cart and tunnel boundary block that capsule. Native OpenGL renders were inspected in overhead and first person. This environment check does not establish gamepad support or expedition duration. Integrated combat checks are listed below.

## Sorting hall revision after the September 9 review

The screenshot exposed disconnected architecture, an unexplained circular centerpiece, repeated perimeter boulders and a clean paving rectangle on low-detail ground. This pass removes both non-portal freestanding arches and every decorative door/facade. The hall now reads as a disused screening and loading station. The chutes terminate above the receiving cart, and the frame, wheel bearings, lamps and retaining walls have visible support.

`tools/mine_details.py` generates `art/dungeon/mine_details.blend` and the additional GLBs. `mine_surfaces.gd` builds a continuous excavated rock bank with a surrounding bedrock surface, replacing the perimeter's repeated isolated boulders. The cutaway camera still lowers the shell; first person restores the full-height enclosure. First person uses ambient and mine-lamp lighting rather than directional sunlight through the cave ceiling.

The ground uses finer soil detail and subdued earth colors. The paving consists of ten chipped slab variants with uneven rotation, partial burial and an irregular boundary. Modeled silt deposits cover groups of slabs using the same soil material as the ground; larger collapse banks also have triangle-mesh collision. Collapsed retaining walls and debris fans connect the older stonework to the actual cave sides.

Validation includes successful construction of cave and silt meshes, a reachable route through every area and the return passage using the player's capsule, and obstruction assertions for the sorting machine, cart and tunnel boundary. Native overhead and first-person renders were inspected. Incorrect procedural surface winding and shadow artifacts found during inspection were corrected. The scenery revision is independent of the subsequent combat integration. No boss was added.

## Live expedition

Enter the eastern village gate with F. Eight regular Wardens use the shared combat controller, capped at rank three. There is one active opponent at a time. Approach starts a fight; aim lock can switch to another visible nearby guard. Hard lock holds its target until released with T. With hard lock released, retreat beyond the post's leash ends the fight. The defender walks home through a physics-derived navigation grid, retaining damage, and the player's remaining health carries between fights. Static scenery blocks both movement and melee strikes. Sparring remains available in the village.

Defeated guards yield unbanked gold and XP, with a diamond from the original seam guard. Once both seam-area guards fall, the three living seams allow a small, one-time collection per expedition. Each gives four living essence and one diamond, leaving the vein intact. Return through the arrival gate to bank the haul into the existing equipment, research currency and leveling systems. Living essence is stored for future systems; it has no spending interface yet. Defeat loses the current haul and returns the player to the village without destroying owned gear.

Autosave and Save & Main Menu preserve position, health, enemy damage, cleared guards, collected seams and unbanked resources. Continue restores the expedition. Banking uses the existing transactional save path: a failed save restores the wallet and leaves the haul available, while successful banking clears the saved expedition in the same transaction. Subsequent visits start a fresh test expedition. Regrowth timing and long-term harvesting balance are not implemented yet.

Main-game controls and camera settings carry into the mine. X draws/sheathes, T releases/reacquires the target, left mouse attacks, Q uses a heavy attack, right mouse guards, Space quicksteps, and arrows or mouse swipes choose a lane. F reads notes, gathers fragments or returns through the gate. The hub reset and overview shortcuts are disabled inside the expedition.

`--expedition-test` runs the main-game integration suite with isolated test saves. `--expedition-capture` also records native overhead and first-person views. Checks cover perfect blocks without stamina loss, quickstep invulnerability, scenery obstruction, navigation, automatic enemy engagement and live attacks, physical retreat, saved enemy and hero health, loss on defeat, unique rewards, harvesting, failed-save rollback, atomic banking and preserved village sparring. The combat, menu and research suites also pass after integration. Native renders were inspected; controller hardware, a complete manually played run and the intended 10–15 minute duration remain unverified.

## Extended cave border

The unexcavated rock continues 224 metres beyond the dense inner mesh on each side. Progressively wider vertex spacing keeps distant coverage inexpensive. Bank tops and the cap share height and outline functions, closing their joins while breaking up the straight rim. The cap has broad rock mottling instead of stretched horizontal bands and does not cast cutaway shadows. Four rotated 55-unit overhead captures check the entrance at a wider view than normal play, in addition to the regular room and first-person captures. Physical route validation still reaches all 405 floor cells and the return passage.

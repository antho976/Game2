# Sound design specification

Every sound the village, the school, the menus and the sparring yard need, derived from what the code actually does. Each entry names the trigger in the scripts so the hook is unambiguous. Status uses three words: **shipped** (a recording in `assets/audio`), **synth** (generated at start-up from sine and noise), **missing** (nothing plays today).

Priority: **P1** is heard every minute of play and is missing or a placeholder; **P2** rounds out a scene; **P3** is polish.

## 1. Current state

### Recordings in `assets/audio`

| File | Length | Used by | Notes |
| --- | --- | --- | --- |
| `amb_hub_air_01.ogg` | 30 s loop | `main.gd` `play_ambient`, -23 dB, 2D | Only ambient bed. Plays day and night. |
| `amb_pond_01.ogg` | 30 s loop | `main.gd` `spatial_loop` at (-12, .5, 8.7), radius 12 | Pond water. |
| `amb_forge_01.ogg` | 30 s loop | `main.gd` `spatial_loop` at (-9, 1, 0), radius 9 | Forge fire. |
| `music_hub_01.ogg` | 3 min loop | `main.gd` `play_ambient`, -25 dB | The only music. Plays on the title screen, in every menu, at night and during combat. |
| `smith_hammer_anvil_01.ogg` | 1.5 s | `hub.gd` on `work_struck`; also pitched 1.15 to 1.45 in `combat.gd` `impact(true)` as a blade-on-blade layer | |
| `bird_chirp_01.ogg` | 1.3 s | `hub_life.gd` feeding birds, 12% chance per hop decision | Single variation. |
| `bird_flight_01.ogg` | 0.17 s | `hub_life.gd` `begin_flight` | Too short to sell a take-off. |
| `cat_meow_01.ogg` | 1.4 s | `hub_life.gd` friendly cat noticing the player within 6 m | Single variation. |
| `cat_purr_01.ogg` | 30 s | `hub_life.gd` `pet` | Plays as a one-shot; the petting pose lasts 2.4 s. |

### Synthesised at start-up

| Source | Sounds |
| --- | --- |
| `scripts/combat_audio.gd` | whoosh, heavy_whoosh, clang, parry, thud, slam, flesh, crack, step, stomp, bind, raise, tick, deny (14 sounds, 22 kHz mono, one variation each with ±6% pitch) |
| `scripts/activities.gd` `bell_sound` | A 3 s decaying 660 Hz bell with two overtones |
| `scripts/dialogue_sounds.gd` | Two nonverbal syllable tones, "teacher" (125 Hz) and "pupil" (230 Hz) |

### Playback plumbing

- `main.gd` `play_sound(id, pos)` loads `res://assets/audio/<id>_01.ogg`, so every one-shot must exist as `_01`. It ignores its `_channel` and `_cooldown` arguments, plays at a fixed -16 dB, max distance 18 m, unit size 4, and never pitch-shifts. Variation selection (`_02`, `_03`) and cooldowns need adding here.
- Only the Master bus and a Dialogue bus exist. `HUB_POLISH.md` item 2 already asks for master, music, ambience, effects, UI and dialogue sliders.
- `game.muted` (M key) and `game.test_mode` silence everything; headless runs skip audio entirely. Keep both checks in any new emitter.
- Narration for the opening is retained (`assets/cinematic/narration.mp3`) but disabled by `narration_enabled = false`.

### Proposed buses

| Bus | Carries | Default |
| --- | --- | --- |
| Master | everything | 80% |
| Music | hub theme, combat layer, stingers, cinematic score | -6 dB |
| Ambience | beds, weather, spatial loops (pond, forge, spring), wildlife bed | 0 dB |
| SFX | footsteps, activities, animals, combat, NPC work | 0 dB |
| UI | menu, shop, archive, notifications, banners | -3 dB |
| Dialogue | classroom syllables, NPC chatter, narration | 0 dB |

Route menus so that opening the shop, archive or pause menu low-passes Ambience and SFX (about 900 Hz) and drops Music by 4 dB. Slow motion in combat (`combat.gd` `slow_motion`) should low-pass SFX and Ambience for its duration since `Engine.time_scale` does not pitch audio.

## 2. Player movement and foley

Hooks: `player.gd` `_physics_process` chooses `idle`, `walk` (below 3.3 m/s) or `run` and scales clip speed to ground speed, so footsteps should fire on animation contact frames, not on a timer. Walk cycle ground speed is 1.625 m/s, run 4.59 m/s. First person (`first_person_hands.gd`) uses the same player body, so the same footsteps serve both views.

### Surfaces the player can stand on

| Surface | Where | Detection |
| --- | --- | --- |
| Cobblestone | square, road, work lane, home lane, doorsteps, forge yard, archive lane, east lane, dock lane, pond walk, sparring yard | `HubKit.on_path(Vector2(x, z))` returns true |
| Grass / turf | everything else inside the walls, meadow with shader grass blades | `on_path` false and not inside school |
| Bare earth / dirt | pond shore (`PondShore`), around the garden beds, worn verges | inside pond rim radius 1.10 or within 1.5 m of the vegetable beds at (10, 0, 8.3) and (13.3, 0, 7.8) |
| Flagstone | bench terrace (5.4, 0, 10.5), archive terrace | box position check |
| Wood floorboards | schoolhouse interior | `game.inside_school()` |
| Wood planks | footbridge over the woodland stream (outside the walls, currently unreachable) | reserve the set |

### Sounds

| ID | Trigger | Description | Var. | Priority | Status |
| --- | --- | --- | --- | --- | --- |
| `step_cobble_walk` | contact frame, walk, cobble | Boot on worn stone, slight grit | 8 | P1 | missing |
| `step_cobble_run` | contact frame, run, cobble | Harder heel strike, scuff | 6 | P1 | missing |
| `step_grass_walk` | walk, turf | Soft crush of blades, dry | 8 | P1 | missing |
| `step_grass_run` | run, turf | Fuller swish, blades whipping | 6 | P1 | missing |
| `step_dirt_walk` | walk, earth | Damp packed soil, light crunch | 8 | P1 | missing |
| `step_dirt_run` | run, earth | Loose soil, small stones | 6 | P1 | missing |
| `step_stone_walk` | walk, flagstone | Flat slab, cleaner than cobble | 6 | P2 | missing |
| `step_stone_run` | run, flagstone | | 4 | P2 | missing |
| `step_wood_walk` | walk, floorboards | Boards with slight creak | 8 | P1 | missing (school opening walks on it) |
| `step_wood_run` | run, floorboards | Hollow, resonant | 6 | P2 | missing |
| `step_plank_walk` | footbridge | Thick planks, water under | 6 | P3 | missing |
| `step_wet_edge` | walking on pond shore within .4 m of water | Splash-tinged step for the last strip of bank | 4 | P3 | missing |
| `step_scuff_turn` | yaw rate high while moving (`bank` value above .08 in `player.gd`) | Pivot scuff matching the surface | 3 per surface | P3 | missing |
| `foley_cloth_walk` | every step, always | Layer: wool and linen rustle under the surface step | 6 | P2 | missing |
| `foley_plate_walk` | every step while any plate slot is equipped (`equipment.equipped` has helmet, chest, gloves or boots) | Layer: articulated plate clink, heavier with more slots | 6 | P2 | missing |
| `foley_sword_back` | every step while a weapon is equipped outside combat | Scabbard and strap tap on the back-mounted greatsword | 4 | P3 | missing |
| `foley_run_breath` | running longer than 4 s | Soft breathing loop, fades on stop | loop | P3 | missing |
| `player_land` | `player.gd` teleport to `last_safe` after falling below -3 | Body drop and settle | 2 | P3 | missing |
| `player_sit_bench` | `activities.gd` `interact("sit")` and `"pond_sit"` | Cloth slide and a bench creak | 3 | P2 | missing |
| `player_stand_bench` | leaving `activity == "sit"` on movement input | Bench relief creak, boots on terrace stone | 3 | P2 | missing |

NPCs walk the same surfaces in `village_day.gd` `step` (state `walking` plays `walk`) and `hub_npc.gd`. Use the same sets at -6 dB with a 12 m falloff; four to six residents walk at once, so cap concurrent NPC footsteps at four voices.

## 3. Ambience and weather

The twelve-minute day in `village_day.gd` gives 30 s per hour. Daylight is `smoothstep(5.5, 7.5, h) * (1 - smoothstep(18.2, 20.8, h))`; the clock label reads Day, Evening (after 18:00) and Night (daylight below .2). Residents go inside from 20:00 to 20:45 and reappear from about 06:00. Lamps fade in as daylight falls. Nothing in the code emits a discrete dawn or dusk event yet, so the ambience system should crossfade on the daylight value.

### Beds (2D, crossfaded by daylight)

| ID | When | Description | Priority | Status |
| --- | --- | --- | --- | --- |
| `amb_hub_air` | daylight above .3 | Gentle open air, distant leaves, faint village hum | P1 | shipped |
| `amb_hub_day_birds` | 07:00 to 18:00 | Songbird bed, sparse, no single bird too close | P1 | missing |
| `amb_hub_dawn` | 05:30 to 07:30 | Dawn chorus, rising; a cockerel from the hamlets | P2 | missing |
| `amb_hub_dusk` | 18:00 to 20:30 | Evening birds thinning, first crickets | P2 | missing |
| `amb_hub_night` | daylight below .2 | Crickets, occasional owl, very light wind | P1 | missing (night currently sounds like noon) |
| `amb_wind_gust` | random every 20 to 50 s, louder at night | Wind gust through the oaks and birches; `hub.gd` sways trees at .65 rad/s so gusts fit the motion | P2 | missing |
| `amb_grass_wind` | camera within 6 m of meadow grass | Close blade rustle, ties to the grass shader wind | P3 | missing |
| `amb_distant_village` | day | Rare distant dog, cart, hamlet bell, from the five hamlet centres beyond the walls | P3 | missing |
| `amb_forest_edge` | player within 8 m of the north or west wall | Conifer wind and the woodland stream, low-passed | P3 | missing |

### Spatial loops (3D, always on)

| ID | Position | Description | Priority | Status |
| --- | --- | --- | --- | --- |
| `amb_pond` | (-12, .5, 8.7), r 12 | Water lapping | P1 | shipped |
| `amb_spring` | POND + (-3.15, .35, -.3), r 6 | Small stone spring feeding the pond (`hub_landscape.gd` `pond`, animated ripples) | P2 | missing |
| `amb_forge` | (-9, 1, 0), r 9 | Fire chamber roar, coal tick | P1 | shipped |
| `amb_forge_bellows` | forge, r 6 | Slow bellows breathing while the smith works (`residents` job `work_0`) | P3 | missing |
| `amb_chimney` | (-9.2, 3.3, -.9), r 5 | Faint draw and crackle where the smoke emitter sits | P3 | missing |
| `amb_washing_line` | (-9.05, 1.6, -5.5), r 5 | Cloth flapping, synced loosely to the shader wave at 1.8 and 2.9 Hz | P3 | missing |
| `amb_lamp_post` | six lamps (`hub.gd` lamp positions), r 3, night only | Very quiet oil-lamp flutter | P3 | missing |
| `amb_archive` | (10, 1, -1), r 6 | Paper stirring under the pergola, a specimen jar tink | P3 | missing |
| `amb_garden` | (11.5, .5, 8), r 5 | Insects over the vegetable beds by day | P3 | missing |
| `amb_school_room` | inside school | Muffled exterior, floor settling, a clock if one is added | P2 | missing |
| `amb_stream` | along `stream_x(z)` outside the west wall, r 10 | Woodland stream | P3 | missing |

### Time events

| ID | Trigger | Description | Priority | Status |
| --- | --- | --- | --- | --- |
| `time_lamps_light` | daylight crosses .5 downward (about 19:30) | Six soft lamp ignitions staggered 0.3 s at each lamp post | P3 | missing |
| `time_lamps_out` | daylight crosses .5 upward (about 06:30) | Quiet snuff | P3 | missing |
| `time_cockerel` | 05:45 to 06:30, once or twice | Distant, from a hamlet direction | P2 | missing |
| `time_owl` | night, every 40 to 90 s | Distant tawny owl | P2 | missing |
| `npc_door_home` | `village_day.gd` `arrive` with job `home` (resident hides at a door) | Door open, footsteps in, door close, at the four door positions | P2 | missing |
| `npc_door_morning` | `step` when state `inside` ends and the resident reappears at the door | Door open and close | P2 | missing |

Weather is not simulated. If rain is ever added it needs its own bed, roof drip loops at the four houses, and wet variants of every footstep surface.

## 4. Animals

### Birds (`hub_life.gd`, 15 small ground birds)

| ID | Trigger | Description | Var. | Priority | Status |
| --- | --- | --- | --- | --- | --- |
| `bird_chirp` | feeding state, 12% per decision | Single chirp | 6 | P1 | shipped (1 of 6) |
| `bird_song` | feeding, rarer (3%) | Longer phrase | 4 | P2 | missing |
| `bird_hop` | state `hopping`, per bounce (`position.y` bounce at 12 Hz) | Tiny claw tick on the surface, nearly inaudible on grass | 4 | P3 | missing |
| `bird_peck` | feeding, head dip peaks (`rotation.x` sine at 2.7 Hz) | Beak tap on cobble or soil | 4 | P3 | missing |
| `bird_takeoff` | `begin_flight` | Wing burst, 0.6 to 0.9 s; the current file is 0.17 s | 5 | P1 | shipped but too short |
| `bird_flock_alarm` | bell rung or player within 2.7 m scattering three or more birds within .5 s | Alarm call and combined flutter | 3 | P2 | missing |
| `bird_cruise` | state `cruise`, attached to the body | Faint wingbeats at 22 Hz flap rate while airborne | loop | P3 | missing |
| `bird_land` | state `land` when within .12 m of target | Flutter and settle | 4 | P2 | missing |
| `bird_feed_arrive` | `offer_bird_food` targets | Excited chatter as the six nearest birds converge | 3 | P3 | missing |

### Cats (two friendly, two shy)

| ID | Trigger | Description | Var. | Priority | Status |
| --- | --- | --- | --- | --- | --- |
| `cat_meow` | friendly cat notices player within 6 m after cooldown | Greeting meow | 5 | P1 | shipped (1 of 5) |
| `cat_purr` | `pet` | Purr, 3 s, fades with the 2.4 s pet timer | 3 | P1 | shipped (30 s file; trim to 3 to 4 s or fade on `pet_until`) |
| `cat_chirrup` | friendly cat in `follow` state every 3 to 6 s | Short trill while trailing the player | 4 | P2 | missing |
| `cat_hiss` | shy cat entering `flee` when player within 3.3 m | Hiss or startled yowl | 3 | P2 | missing |
| `cat_scamper` | shy cat flee at 2.5 m/s | Rapid paw patter on the surface | 3 | P3 | missing |
| `cat_food_call` | resident cat feeding (`cat_food_until`) | Hungry meows from cats converging on `cat_food_position` | 3 | P3 | missing |
| `cat_rub` | `petted` state start | Cloth brush and a small mew | 3 | P3 | missing |

### Ducks (`activities.gd`, four mallards)

| ID | Trigger | Description | Var. | Priority | Status |
| --- | --- | --- | --- | --- | --- |
| `duck_quack` | random while `swim`, every 6 to 15 s per duck | Single quack, pitched per duck size (.65 to .95 scale) | 6 | P1 | missing |
| `duck_paddle` | velocity above .2 | Water paddle loop under the wake ring | loop | P2 | missing |
| `duck_dabble` | `feeding` head dips (7 Hz sine) | Bill in water, bubbling | 5 | P2 | missing |
| `duck_gather` | `feed_until` starts (player or resident feeds) | Chorus of eager quacks and a splash rush | 3 | P1 | missing |
| `duck_avoid` | mode `avoid` (player within 2.2 m) | Alarmed quack and wing flap | 4 | P2 | missing |
| `duck_wing_shake` | random idle | Feather shake and drip | 3 | P3 | missing |

The pigeon plushie on the well is static and needs nothing.

## 5. Player activities and props

| ID | Trigger | Description | Var. | Priority | Status |
| --- | --- | --- | --- | --- | --- |
| `feed_grab` | `interact("feed")`, `player.act("feed")` start | Hand into a grain pouch, dry rattle | 3 | P1 | missing |
| `feed_throw` | `throw_feed` release at +0.5 s | Arm swing, seed scatter in air | 3 | P1 | missing |
| `feed_land_water` | seeds reach pond target (+0.65 to 0.85 s), `for_ducks` true | Fourteen tiny plops spread over .2 s | 3 | P1 | missing |
| `feed_land_ground` | seeds land at the bird station | Seeds on cobble or soil | 3 | P2 | missing |
| `feed_refused` | "still enjoying the last handful" toast | Soft UI decline, see UI | | P3 | missing |
| `water_can_lift` | `interact("water")` | Tin can lift, water slosh inside | 2 | P1 | missing |
| `water_pour` | `water_particles` for 3 s (emitter follows the can spout) | Pour onto soil loop with a soft end | loop | P1 | missing |
| `water_can_set` | `water_until` expires, can lerps home | Can set down on paving | 2 | P2 | missing |
| `water_soil_soak` | `watered` set | Brief soaking hiss under the pour tail | 2 | P3 | missing |
| `bell_ring` | `interact("bell")` | Real bronze bell, 4 to 5 s tail with a second lighter strike from the swing; the synth bell today is a placeholder | 3 | P1 | synth |
| `bell_rope` | same, 0.1 s before the strike | Rope pull and pulley creak | 2 | P2 | missing |
| `bell_swing` | `bell_time` 3 s decay | Yoke creak while the cup swings | 1 | P3 | missing |
| `bell_distant_tail` | same event, 2D | A far reverberant echo off the walls, ducks and birds react .3 s later | 1 | P3 | missing |
| `dummy_hit` | `practice_dummy.strike()` | Fist or palm on padded sacking, post thud | 4 | P1 | missing |
| `dummy_swing` | dummy `speed` above 1 | Wooden pivot creak on each swing, decaying with the spring | loop | P2 | missing |
| `bench_sit`, `bench_stand` | see movement | | | | |
| `pet_cat_hand` | `player.act("pet")` | Cloth on fur strokes, 2 s | 3 | P2 | missing |

## 6. Resident work sounds

Residents in `village_day.gd` reserve stations and play the activity clips. Each job needs a matching loop or one-shots at the station position.

| ID | Job / trigger | Description | Var. | Priority | Status |
| --- | --- | --- | --- | --- | --- |
| `smith_hammer` | `work_struck` at 0.8 s of the hammer clip | Hammer on hot steel, anvil ring | 6 | P1 | shipped (1 of 6) |
| `smith_tongs` | hammer clip start | Tongs turning the work | 3 | P3 | missing |
| `smith_quench` | every third or fourth hammer cycle | Steam hiss in the trough | 3 | P2 | missing |
| `smith_grunt` | heavy hammer strikes, 30% | Effort breath | 4 | P3 | missing |
| `scholar_page` | scholar `read` clip, every 4 to 7 s | Page turn | 5 | P2 | missing |
| `scholar_quill` | read clip | Quill scratching in bursts | loop | P3 | missing |
| `scholar_hum` | rare | Thoughtful murmur (nonverbal, Dialogue bus) | 3 | P3 | missing |
| `well_crank` | `draw_water` lower phase (1.8 s) | Windlass and rope paying out | 1 | P1 | missing |
| `well_splash` | end of lower phase | Bucket hits water 3 m down, reverberant | 3 | P1 | missing |
| `well_haul` | raise phase (2.4 s) | Rope creak under load, dripping | 1 | P1 | missing |
| `well_bucket_set` | tween end, bucket freed | Bucket on the coping, water slosh | 2 | P2 | missing |
| `npc_water_pour` | job `garden` (`water_particles`) | Same pour loop as the player | | P1 | see `water_pour` |
| `npc_feed_throw` | job `birds`, `cats`, `ducks` every 4 s | Same grab and throw as the player | | P1 | see `feed_*` |
| `npc_chatter` | jobs `talk_a` and `talk_b`, 40 s conversations at (-3.9, 0, -5.2) and (-2.6, 0, -5.2) | Nonverbal murmur exchanges, two voices alternating with pauses, Dialogue bus. `dialogue_sounds.gd` can be reused per resident with a lower pitch per `variant` | 2 voices, 8 syllables each | P2 | missing |
| `npc_greet` | villager turns to face the player within 3 m (`hub_npc.gd`) | Short friendly syllable | 4 | P3 | missing |
| `npc_bucket_carry` | job `water` travel with the bucket prop visible | Bucket handle creak per step | 3 | P3 | missing |
| `gardener_kneel` | `garden` arrival | Cloth and a soft grunt | 2 | P3 | missing |

## 7. Sword combat (`combat.gd`, `combat_audio.gd`)

Every combat sound is synthesised today. They read correctly but are thin; the plan is to replace each with recordings under the same IDs so `combat_audio.gd` `play` keeps working, then add the missing layers. All positions below are already computed in the code. Keep the ±6% pitch randomisation and the -12 dB default.

### Existing IDs to replace with recordings

| ID | Trigger | Recording brief | Var. | Priority |
| --- | --- | --- | --- | --- |
| `whoosh` | `tick` at 62% of a light windup | Greatsword light cut through air, .25 s | 6 | P1 |
| `heavy_whoosh` | 62% of a heavy windup | Slower, deeper swing with a low body | 4 | P1 |
| `clang` | `resolve_hit` block (light -9 dB, heavy -7 dB); also at -20 dB under every landed hit | Edge on flat, bright and short | 6 | P1 |
| `parry` | perfect block or the partner parrying | Longer ringing bind with a shimmer, .7 s | 4 | P1 |
| `bind` | clash | Two blades grinding to a stop | 4 | P1 |
| `thud` | light hit body layer; also under a blocked heavy at .8 pitch | Dull body impact, low | 6 | P1 |
| `slam` | heavy hit body layer | Deeper, longer, sub layer | 4 | P1 |
| `flesh` | every landed hit, louder on stagger | Wet cut layer | 6 | P1 |
| `crack` | `exhaust` (guard broken) | Guard collapsing: leather snap and a gasp | 3 | P1 |
| `step` | `quickstep` | Fast footwork on the yard surface | 6 | P1 |
| `stomp` | heavy windup front foot plant (with dust puff) | Boot stomp, dust | 4 | P1 |
| `raise` | `block` raising a guard | Blade lifted, cloth and a short steel sing | 4 | P1 |
| `tick` | partner's last .2 s before impact (perfect window cue) | Very short readable tick, unchanged design | 2 | P1 |
| `deny` | `refuse` (no stamina) | Soft negative | 2 | P1 |

### Missing combat sounds

| ID | Trigger | Description | Var. | Priority |
| --- | --- | --- | --- | --- |
| `sword_draw` | `start` after `make_sword` | Greatsword unsheathed from the back, 0.8 s | 2 | P1 |
| `sword_sheathe` | `stop` | Blade returned | 2 | P2 |
| `sword_borrow` | `start` when `weapon()` falls back to the loaned Warden blade | Handed a sword: leather and steel | 1 | P3 |
| `salute` | banner SALUTE | Blade raised and lowered, two short whooshes | 1 | P2 |
| `fight_start` | banner FIGHT (`salute` expires) | Short stinger or drum hit on the Music bus | 1 | P2 |
| `feint` | `feint` (hero or partner) | Blade redirect hiss, tighter than a whoosh | 4 | P1 |
| `pull` | `block` inside `PULL_LIMIT` | Swing checked mid-air, scabbard-like stop and cloth | 3 | P2 |
| `riposte_cut` | attack with `hero.riposte` true | Extra bright air layer on top of the whoosh | 2 | P2 |
| `critical_hit` | `attacker.critical` | Additional deep crack and a stereo widening layer | 2 | P1 |
| `finishing_blow` | `finishing` | Longest, lowest slam with a tail; pairs with the 200 ms hit-stop | 2 | P1 |
| `form_complete` | banner with a form name (Crossing cut, Serpent's coil) | Short steel flourish | 2 | P2 |
| `pierce_guard` | `pierced` | Blade forcing through a held guard: scrape then thud | 2 | P2 |
| `chip_block` | blocked heavy chip damage | Extra body under the clang | 2 | P3 |
| `hero_hurt_light` | hero phase `hurt`, no stagger | Player grunt, nonverbal | 6 | P1 |
| `hero_hurt_heavy` | hero staggered | Sharper cry, longer | 4 | P1 |
| `foe_hurt_light`, `foe_hurt_heavy` | same for the partner | Distinct voice | 6, 4 | P1 |
| `foe_effort` | partner swings (`begin_enemy_attack`) | Effort exhale; heavier for heavy cuts | 6 | P2 |
| `hero_effort` | hero attack | Player effort | 6 | P2 |
| `winded_breath` | `winded(hero)` true | Ragged breathing loop, 2D, fades when stamina recovers | loop | P2 |
| `exhausted_loop` | phase `exhausted` (3 s) | Gasping and a slump, both fighters | 2 | P2 |
| `stagger_stumble` | `staggered` with knockback 3.4 m/s | Boots skidding on the yard | 4 | P2 |
| `blood_spatter` | `blood` | Wet spray onto ground, tied to `stagger` size | 4 | P2 |
| `dodge_evaded` | banner EVADED | Air rush past the ear | 2 | P2 |
| `clash_recoil` | after `bind` | Both fighters stepping back | 2 | P3 |
| `armor_hit_plate` | hit landing on a fighter wearing chest plate | Dented plate ring under the flesh layer | 4 | P2 |
| `armor_rattle_step` | combat footwork with plate equipped | See `foley_plate_walk`, faster | | P3 |
| `circle_step` | partner AI footwork (`partner_ai` strafe) and hero movement in the bout | Combat-weight footsteps on the yard surface, denser than walk | 8 | P1 |
| `victory_stinger` | `finish(true)` | Short resolved phrase over the slow motion, Music bus | 1 | P1 |
| `defeat_stinger` | `finish(false)` | Low unresolved phrase | 1 | P1 |
| `foe_kneel` | `fallen` (partner on one knee) | Sword tip on ground, armor settling | 1 | P2 |
| `foe_rise` | `respawn` reaches zero | Standing back up, blade lifted | 1 | P3 |
| `slowmo_enter`, `slowmo_exit` | `slow_motion` start and end | Whoosh down into a low-pass, then release | 1 each | P2 |
| `hitstop_thump` | every `hitstop` above .1 s | Sub thump exactly on the frozen frame | 1 | P3 |
| `combat_music_layer` | `active` true | Percussive tension layer that fades in over the hub theme and out 2 s after `stop` | loop | P1 |
| `left_yard` | "You left the training yard." | Soft UI decline | | P3 |

### Combat HUD sounds (UI bus)

| ID | Trigger | Description |
| --- | --- | --- |
| `hud_banner` | `show_banner` | Short punch matching the 1.35 to 1.0 scale snap; tint by colour (gold, red, blue, orange) with four variants |
| `hud_damage_number` | `spawn_number` | Tiny tick, larger for size 1.2 and 1.45 |
| `hud_perfect_window` | reticle turning white (`fighter.cued`) | Already `tick`; keep on SFX so it survives UI mute? Decide once buses exist |
| `hud_counter_open` | `defender.counter` set | Rising two-note cue |
| `hud_stamina_refused` | `stamina_flash` | Same as `deny` |
| `hud_exhaust_warning` | partner exhaustion above 85 (arc blinking, OPEN above him) | Soft pulsing cue, once per crossing |
| `hud_low_health` | hero below 30% (vignette throb) | Heartbeat loop, 2D, Music-ducking |
| `hud_level_up` | `award_combat` raises `level` | Fanfare, also used outside combat |
| `skills_open`, `skills_close` | K | Panel slide |
| `skill_learn` | `learn_combat` success | Steel and parchment confirm |
| `skill_refused` | error toast | Decline |

## 8. Interface

Every button in the game goes through `menu.gd` `button`, `UiKit.button`, the shop's `card_in`, `study_node` in the archive and the skill panel. One shared set covers them, with distinct confirms for money.

### Shared set

| ID | Trigger | Description | Priority | Status |
| --- | --- | --- | --- | --- |
| `ui_hover` | `mouse_entered` and focus change (needed for the planned controller support) | Barely-there tick | P1 | missing |
| `ui_click` | `pressed` | Soft wooden click | P1 | missing |
| `ui_back` | Escape, Back, Close | Lower click | P1 | missing |
| `ui_confirm` | ConfirmationDialog OK | Firm confirm | P1 | missing |
| `ui_cancel` | ConfirmationDialog cancel | | P1 | missing |
| `ui_denied` | any error `message` in the shop, `act` with an error in the archive, `toast` with an error | Dull decline | P1 | missing |
| `ui_slider` | volume and camera sliders `value_changed`, rate-limited to 20 Hz | Tick | P2 | missing |
| `ui_toggle` | VSync, FPS counter, display and frame-limit options | Switch | P2 | missing |
| `ui_tab` | shop tabs (Buy, Wardrobe, Anvil, slot filters), archive trees, `tab_style` | Parchment flip | P2 | missing |
| `ui_panel_open`, `ui_panel_close` | `menus.open`, `show_pause`, `smith_shop.open`, `research_menu.open`, `open_skills` | Panel slide with a cloth or leather texture; shop and archive get their own variants below | P1 | missing |
| `ui_toast` | `game.toast` | Quiet parchment tap; skip for toasts fired inside combat `say` | P2 | missing |
| `ui_mute` | M key | A single tick that plays even when muted, then silence | P3 | missing |
| `ui_fullscreen` | F11 | none | | |

### Title, pause and save

| ID | Trigger | Description | Priority | Status |
| --- | --- | --- | --- | --- |
| `title_music` | `show_home` | The hub theme is fine here; add a slow intro swell on first show | P3 | shipped |
| `title_continue` | Continue | Warm confirm and a short reverse swell into the village | P2 | missing |
| `title_new_game` | `request_new` and confirm | Confirm, then the cinematic score takes over | P2 | missing |
| `pause_open`, `pause_close` | Escape | Music dips 6 dB and low-passes while paused | P1 | missing |
| `save_tick` | `save_game` every 15 s and on menu exit | Silent by design; only `Could not save this visit.` gets `ui_denied` | | |
| `quit` | Quit | Short fade-out over 0.4 s before `get_tree().quit()` (currently cuts hard) | P2 | missing |

### Blacksmith shop (`blacksmith_shop.gd`)

| ID | Trigger | Description | Priority | Status |
| --- | --- | --- | --- | --- |
| `shop_open` | `open` | Shop door and forge heat swell; forge loop rises 4 dB while open | P1 | missing |
| `shop_close` | `close` | Door | P1 | missing |
| `shop_card_select` | `card.pressed` | Leather card flip, metal tick for weapons | P2 | missing |
| `shop_preview_drag` | fitting-room drag rotate | Faint turntable creak while dragging | P3 | missing |
| `shop_buy` | `buy` success ("purchased") | Coin pour and a satisfied steel note | P1 | missing |
| `shop_buy_denied` | `buy_error` (gold, level) | `ui_denied` plus a coin-purse shake for gold, a locked-latch for level | P1 | missing |
| `equip_weapon` | `equip` on a weapon | Greatsword slung onto the back | P1 | missing |
| `equip_helmet`, `equip_chest`, `equip_gloves`, `equip_boots` | `equip` per slot | Plate piece donned, distinct per slot | P1 | missing |
| `unequip` | `unequip` | Piece removed, set on a stand | P2 | missing |
| `upgrade_confirm_open` | `request_upgrade` popup | Tense low note under the danger button | P2 | missing |
| `upgrade_attempt` | `attempt_upgrade` start | Three hammer strikes rising over 1.2 s, then a held quench hiss; delay the result message to the last strike so the outcome sound lands on it | P1 | missing |
| `upgrade_success` | `result.survived` | Anvil ring resolving to a bright chord, rank chip clink | P1 | missing |
| `upgrade_fail` | not survived | Steel shatter, pieces falling, silence | P1 | missing |
| `upgrade_refused` | stale quote errors | `ui_denied` | | |

### Research archive (`research_menu.gd`)

| ID | Trigger | Description | Priority | Status |
| --- | --- | --- | --- | --- |
| `archive_open`, `archive_close` | `open`, `close` | Heavy book opening, lamp-lit room tone under the menu | P1 | missing |
| `archive_node_select` | `study_node` pressed | Quill tap on parchment | P2 | missing |
| `research_start` | `start` success | Coins (and a diamond tick when the rank costs diamonds), then a quill flourish | P1 | missing |
| `research_pause`, `research_resume` | `set_paused` | Book closed, book reopened | P2 | missing |
| `research_denied` | `start_error` (cost, prerequisite, no free desk, WIP branch) | `ui_denied` | P1 | missing |
| `research_complete` | `finished` signal, in-game notify (8 s toast, also when out of the archive) | Clear two-note chime, one for several simultaneous completions | P1 | missing |
| `journal_acknowledge` | opening the journal with unread entries | Page turn | P3 | missing |
| `desk_progress_tick` | none by default; the live desk strips are silent | | | |

## 9. Story: cinematic and classroom

### Opening cinematic (`assets/cinematic/cinematic.gd`, 121.5 s, five chapters)

| ID | Trigger | Description | Priority | Status |
| --- | --- | --- | --- | --- |
| `cine_narration` | `narration_enabled` | Existing MP3, currently disabled; timeline-narrated.json holds its cue timing | P2 | shipped, off |
| `cine_score` | chapter 0 start to finish | A 2 min underscore in five moods: village (0 to 19 s), the feast (19 to 37 s), one refused (37 to 80 s), the ordeal (80 to 102 s), children at home (102 to 121 s). Chapter boundaries fade through black over 0.8 s, so write the score with hits at 19.4, 37.4, 80.2 and 102.4 s | P1 | missing |
| `cine_ink_reveal` | `reveal` parameter 0 to 1.4 over 3.4 s at each chapter | Ink spreading on paper, wet brush | P2 | missing |
| `cine_page_turn` | chapter change | Heavy page under the fade | P2 | missing |
| `cine_scene_village` | chapter 0 | Distant village, birds | P3 | missing |
| `cine_scene_feast` | chapter 1 | Low murmur, fire, something wrong underneath | P3 | missing |
| `cine_scene_sacrifice` | chapter 2 | Wind, a single voice, candle | P3 | missing |
| `cine_scene_gates` | chapter 3 | Stone grinding, a vast low drone for the decree | P3 | missing |
| `cine_scene_children` | chapter 4 | Hearth and quiet | P3 | missing |
| `cine_caption` | each cue in `data.cues` | none; captions are silent by design | | |
| `cine_skip` | Skip intro or Escape | `ui_back` and a 0.5 s music fade | P2 | missing |

### Schoolhouse lesson (`classroom.gd`, `schoolhouse.gd`)

| ID | Trigger | Description | Priority | Status |
| --- | --- | --- | --- | --- |
| `speech_teacher` | `chatter.syllable("teacher")` per revealed letter, every .13 s | Nonverbal older voice syllables; replace the sine tone with 8 to 12 recorded syllables per speaker, chosen at random, kept at the same cadence | P1 | synth |
| `speech_pupil` | `syllable("pupil")` | Young voice | P1 | synth |
| `lesson_room_tone` | `enter_dialogue` | Room tone, pupils shifting, a page | P2 | missing |
| `lesson_advance` | `advance` | Soft page tap | P2 | missing |
| `lesson_skip_reveal` | `advance` while text still revealing | Cut the syllables (already `chatter.stop()`), no extra sound | | |
| `lesson_stand` | last line "Stand up" then `begin_roam` | Bench scrape, the player rising, cloth | P1 | missing |
| `question_open` | `ask` | Parchment | P2 | missing |
| `question_asked_again` | choosing a muted (already asked) question | Softer, no syllables | P3 | missing |
| `school_door_exit` | `finished` when the player leaves `room.contains` | Door threshold, outdoor ambience swells (`blend_doorway_view` already fades the camera over 0.32 s) | P1 | missing |
| `school_enter` | `inside_school()` becomes true | Ambience ducks to `amb_school_room` | P1 | missing |
| `school_bookcase` | none | | | |

## 10. Music

| ID | Where | Notes | Priority | Status |
| --- | --- | --- | --- | --- |
| `music_hub` | always | Three-minute loop | P1 | shipped |
| `music_hub_night` | daylight below .2 | Sparser arrangement of the same theme, crossfade over 8 s | P2 | missing |
| `music_combat_layer` | sparring active | Stem that sits on top of the hub loop at the same tempo, so no transition is needed | P1 | missing |
| `music_victory`, `music_defeat` | finish | Stingers, 3 to 4 s | P1 | missing |
| `music_level_up` | level gain | Fanfare | P1 | missing |
| `music_cinematic` | opening | See cinematic | P1 | missing |
| `music_lesson` | classroom lesson mode | Very quiet held pad, stops at `begin_roam` | P3 | missing |
| `music_menu_filter` | any menu open | Low-pass and -4 dB on the hub theme, no new file | P1 | missing |

The title screen orbits the live village, so it should keep the hub theme and the daytime ambience rather than its own track.

## 11. Implementation

The system described in the plan below is now in place; this section records what exists.

- **`scripts/audio_kit.gd`** creates the Music, Ambience, SFX, UI and Dialogue buses, scans `assets/audio` for `<id>_NN.wav|ogg|mp3` and exposes `play(id, pos)`, `play_2d`, `ui`, `loop(key, id, pos)`, `stop(key)`, `bed(id, volume, weight)` and `set_ducked`. Variations never repeat the last take, pitch wobbles a few percent, per-id cooldowns stop machine-gun triggers, and a 40-voice cap protects the mixer. Ambience and SFX drop behind a 900 Hz low-pass with the music 4 dB down whenever a menu, the shop, the archive, the lesson or the skill panel blocks input, and during combat slow motion.
- **`assets/audio/manifest.json`** holds one ElevenLabs sound-effects prompt per id with duration, variation count and target peak. **`tools/generate_sounds.py`** requests the missing files, trims silence, peak-normalises and writes WAV one-shots and OGG loops. Priority 1 runs by default; `--priority 2` or `--all` widens it; naming an id regenerates just that sound. Set `ELEVENLABS_API_KEY` first.
- **Footsteps** fire by distance in `player.gd` (0.65 m walking, 1.53 m running) on the surface `HubKit.surface_at` reports: wood inside the school, dirt on the pond shore and around the vegetable beds, stone on the bench terrace and the archive garden, cobble wherever `on_path` is true, grass elsewhere. Cloth foley rides under every step; plate or the slung greatsword add their own layer when equipped. Residents use the same sets at -24 dB.
- **Day and night** crossfade five beds on the daylight value in `village_day.gd` (`amb_hub_air`, `amb_day_birds`, `amb_dawn`, `amb_dusk`, `amb_night`), fire lamp ignitions once as the light crosses half, an owl at night, a cockerel between 05:36 and 06:36 from a hamlet direction, and wind gusts from a random tree. Inside the school the beds fall to 30% under the room tone.
- **Combat** keeps `combat_audio.gd` as the router: a recorded file under the same id replaces the synthesised version automatically. The player's swing now carries a short ordinary effort grunt (`hero_effort`), not a shout; the partner answers with his own. Hits add hurt voices, blood, and critical or finishing layers; the bout draws and sheathes the sword, fades a percussion layer in and out on the Music bus, breathes while winded, and lands victory and defeat stingers.
- **Interface** goes through `UiKit.sound`, which every `UiKit.button`, menu button, shop card, study node and confirmation dialog calls: hover tick, click, back, confirm and denied. Shop, archive, upgrades, research, level-ups, the skill panel and toasts have their own cues. Options gained a slider per bus, persisted as `volume_<bus>`.
- The synthesised bell, syllables and combat sounds remain as fallbacks so the game never goes silent while a file is missing.

## 12. Technical plan (as written before implementation)

1. **Buses.** Create Music, Ambience, SFX, UI and Dialogue in `main.gd` `_ready` (the Dialogue bus creation in `dialogue_sounds.gd` can move there). Options page gets six sliders; `store_option` already persists values.
2. **`play_sound` upgrade.** Accept a variation count, pick `_NN` at random avoiding the last one played per ID, apply ±4% pitch, honour `_channel` as the bus and `_cooldown` per ID. Add a `volume` argument; today every one-shot is -16 dB.
3. **Footsteps.** Add an `AnimationPlayer` method track or a distance accumulator in `player.gd`: fire a step every 0.65 m walking and 1.53 m running (half the cycle distance: the walk clip is 24 frames at 30 fps covering 1.3 m, the run 20 frames covering 3.06 m, from `tools/hero_animation.py`). Surface lookup: `inside_school()` then `on_path` then the shore and garden checks, else grass. Cache the surface per frame. Reuse for residents in `village_day.gd` with a voice cap.
4. **Day and night.** In `village_day.gd` `update_light` expose `daylight`, crossfade the beds, and emit `dawn` and `dusk` signals when it crosses .5 so lamp and cockerel events fire once.
5. **Combat.** Keep `combat_audio.gd` as the router: when a recording exists for an ID, load it instead of synthesising; otherwise keep the synth so the game never goes silent while assets arrive. Add the missing IDs listed in section 7 at the named call sites.
6. **Menus.** A `UiSounds` autoload with `hover`, `click`, `back`, `confirm`, `denied`; hook `UiKit.button` and `menu.gd` `button` once so every screen inherits it. Duck Ambience and SFX through a low-pass effect on those buses while `game.input_blocked` is true and no bout is running.
7. **Loops with lifetimes.** `cat_purr` and `water_pour` must stop with their activity; use an `AudioStreamPlayer3D` kept in the activity dictionary and faded over .3 s.
8. **Format.** Loops as OGG Vorbis 44.1 kHz stereo (beds) or mono (spatial). One-shots as 16-bit WAV mono, trimmed to the transient, peak -3 dBFS, no baked reverb. Name `category_name_NN.wav`, starting at `_01` so the existing loader keeps working.
9. **Mix targets.** Beds -23 dB, spatial loops -17 to -19 dB, footsteps -18 dB, activities -14 dB, combat impacts -4 to -10 dB as already tuned, UI -12 dB, dialogue -20 dB. Music sits under everything at -25 dB and ducks a further 4 dB in menus and 3 dB while combat impacts play.

## 13. Counts and order of work

| Category | Distinct sounds | Files with variations |
| --- | --- | --- |
| Movement and foley | 20 | about 110 |
| Ambience, weather, time | 26 | 30 |
| Animals | 24 | 95 |
| Player activities | 17 | 40 |
| Resident work | 17 | 45 |
| Combat | 49 (14 replacements, 35 new) | 160 |
| Interface, shop, archive | 44 | 55 |
| Cinematic and classroom | 22 | 40 |
| Music | 9 | 9 |
| **Total** | **about 228** | **about 585** |

Suggested order, each step playable on its own:

1. Buses, `play_sound` variations, menu ducking. Footsteps on cobble, grass, dirt and wood with cloth foley.
2. Night and dawn beds, wind gusts, duck quacks and gather, a real bell, feed and water activity sounds, well draw.
3. Combat recordings for the 14 existing IDs, then draw, feint, hurt voices, victory and defeat stingers, combat music layer.
4. Shared UI set, shop purchase and equip, upgrade attempt and outcomes, research start and complete, level up.
5. Cinematic score and classroom syllable recordings, school door and room tone.
6. Remaining P3 detail: lamp posts, washing line, spring, hop and peck, scholar pages, plate foley, slow-motion filters.

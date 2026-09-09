# Reused assets

Source: original Ash & Oath crawler, commit `4a3c31f6c8634bf84f52702340a98b11de5ba6be`. Original hub models and packed Blender source are procedural authored assets from that project. Only hub dependencies have been copied. Adapted scripts retain the original animal navigation and landscape foundation.

- `assets/hub/anvil_station.glb`
- `assets/hub/armillary.glb`
- `assets/hub/birch_tree.glb`
- `assets/hub/blacksmith.glb`
- `assets/hub/bookcase.glb`
- `assets/hub/cottage.glb`
- `assets/hub/forge.glb`
- `assets/hub/garden_bench.glb`
- `assets/hub/garden_wall.glb`
- `assets/hub/herb_patch.glb`
- `assets/hub/oak_tree.glb`
- `assets/hub/research_desk.glb`
- `assets/hub/research_pavilion.glb`
- `assets/hub/scholar.glb`
- `assets/hub/smith_workshop.glb`
- `assets/hub/street_lantern.glb`
- `assets/hub/townhouse.glb`
- `assets/hub/village_well.glb`
- `assets/hub/villager.glb`
- `scripts/hub.gd`
- `scripts/hub_landscape.gd`
- `scripts/hub_life.gd`
- `scripts/hub_npc.gd`
- `scripts/pigeon_plushie.gd`
- `assets/models/stone_block.glb`
- `art/hub/hub_library.blend`
- `tools/export_hub.py`
- `assets/audio/amb_hub_air_01.ogg`
- `assets/audio/amb_pond_01.ogg`
- `assets/audio/amb_forge_01.ogg`
- `assets/audio/music_hub_01.ogg`
- `assets/audio/smith_hammer_anvil_01.ogg`
- `assets/audio/bird_flight_01.ogg`
- `assets/audio/bird_chirp_01.ogg`
- `assets/audio/cat_purr_01.ogg`
- `assets/audio/cat_meow_01.ogg`

## New work

`tools/village_details.py` and `art/village/village_details.blend` create the new village assets. `tools/player_activities.py` derives `assets/village/hub_player.glb` from the reused villager rig, adding petting, feeding, watering, and sitting clips. Their source and the actually used GLBs are included; unused dungeon/combat assets remain outside this repo.

## Generated sounds

Every file in `assets/audio` other than the nine reused recordings above is generated from `assets/audio/manifest.json` by `tools/generate_sounds.py` through the ElevenLabs sound-effects API and processed with ffmpeg. They are original to Game2; regenerate any of them by name with the script.

## Fonts

`assets/ui/display.ttf` and `assets/ui/display_bold.ttf` are Cinzel (regular and semibold) by Natanael Gama, distributed by Google Fonts under the SIL Open Font License 1.1. The full licence is kept alongside them in `assets/ui/CINZEL-OFL.txt`. The blacksmith screen uses it for every name and rubric; body text and numbers stay on the engine's default sans so figures remain quick to read.

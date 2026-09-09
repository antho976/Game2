# Schoolhouse opening

The silent illustrated chronicle leads into a twelve-exchange lesson. Its original narration.mp3 and narrated timing file are retained; playback is disabled. Silent captions have longer reading times.

The school replaces the former north-central house at (4.6, -12.2) in the actual hub World3D. Windows are open geometry, not a sky texture or another viewport. The finished Blender building contains modeled slate shingles, closed gables, textured limewash and timber, joinery, flooring, desks, benches and books. Source: art/hub/schoolhouse.blend; reproducible generator: tools/schoolhouse_model.py. Geometry is batched by material for export.

The northern boundary wall stops at the school sides. The bell has moved outside and the old house's planting/doorstep clutter is excluded. Four walls, a ceiling, furniture colliders and an open doorway define the walkable interior.

Space, Enter, F or Continue reveals then advances lesson text. Stand up returns control without teleporting. Interior movement uses a first-person camera so the roof and walls cannot obscure the player. The user's outdoor camera mode remains unchanged. Walk through the door to finish the opening, or remain inside as long as desired. F near the teacher opens five optional questions about harvesting, other worlds, the sacrifice, attempts to end the bargain and preparation. The teacher stays available on later visits.

The opening stage is saved. Continue resumes an unfinished opening; legacy saves default to completed. An unfinished lesson restarts at its beginning. No optional question is required before leaving.

Tests: --school-test covers silent audio, shared world, window and ceiling collision, boundary clearance, manual doorway traversal, reentry and optional questions. --menu-test covers saved opening flow and controls. Use isolated test data directories. No save cleanup is necessary.

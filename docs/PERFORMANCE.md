# Performance pass: fewer objects, same picture

Reference machine: Ryzen 7 9800X3D, RTX 4070, Godot 4.7.2, GL Compatibility renderer.
Before this pass the hub ran at 80–90 FPS there. Nothing here changes lighting, shadows,
materials, resolution, MSAA, geometry detail or animation; it only changes how many separate
objects the renderer has to cull, sort, upload and draw each pass.

## What was slow

The scene was not GPU-bound. It was drowning the renderer in tiny objects:

| Scene content                       | origin/main | this branch |
| ----------------------------------- | ----------: | ----------: |
| `MeshInstance3D` nodes              |       3 972 |       1 168 |
| Unique mesh resources               |       2 202 |         350 |
| Unique material resources           |       2 146 |         334 |
| Draw calls per pass (mesh surfaces) |       4 276 |       1 803 |
| Grass `MultiMesh` batches           |           1 |         120 |

(Headless census of the built scene, same script on both branches.)

Three habits in the build scripts produced most of it:

- `hub_landscape.gd`'s `shape()` created a **new `SphereMesh` and a new `StandardMaterial3D`
  for every blob**: each flower petal, stem, stone, shrub lobe, reed, vine and bird body part.
  Around 1 700 nodes, every one a unique mesh and unique material.
- `world.box()` created **one `MeshInstance3D` per stone or wood block**: 987 for the boundary
  walls, coping courses, gateway, road, ruins, fences, bridge, firewood and litter.
- The 47 000-blade meadow was a **single `MultiMesh`** whose bounding box covered the whole
  map, so it could never be culled and every pass drew all of it.

Each object is processed once per **pass**, not per frame. With a 4-split directional shadow
and five shadow-casting lamps (each a 6-face cubemap in the GL renderer), one object can be
handled up to 35 times a frame. 4 300 draws multiplied by several passes at typical OpenGL
driver cost lands right where 80–90 FPS was observed. Nine houses also each compiled their
own copy of the same weathering shader, and each birch compiled its own bark shader.

## What changed

1. **Static batching (`scripts/static_batching.gd`).** After the hub is built, rigid
   runtime-generated meshes under the kit (blobs, pond shore, lily pads, terrain, conifers,
   spring stones) are baked into one multi-surface `ArrayMesh` per 16 m ground cell, one
   surface per material. Uniformly scaled parts go through `SurfaceTool.append_from`, which
   keeps normals, tangents, UVs and vertex colours exact. Squashed blobs get their normals
   transformed by the inverse transpose, which is what the renderer did per node before, so
   shading is unchanged. Each bird's body parts become one object; its wings stay separate.
   Trees, residents, animals, the plushie, particles, tweened ripples, water, anything with a
   custom shader, transparency, billboard, triplanar or screen-space material, and every
   imported GLB mesh are excluded automatically.
2. **Block batching (`HubWorld.merge_blocks`).** The rough stone/wood material projects its
   noise textures in each block's *object* space, and the blocks are squashed unevenly, so a
   plain merge or a `MultiMesh` would have changed the texture stretch and the chamfer
   shading. Instead every vertex of the batched mesh carries the block's original position,
   normal and tangent frame (CUSTOM0–3), and the batch material is Godot's own generated
   shader code for that `StandardMaterial3D` configuration reading those baked values.
   987 block nodes became 18 batches with the same picture.
3. **Shared blob mesh and materials.** `shape()` reuses one sphere and one material per
   colour, so the remaining animated blobs (bird wings, residents' hats) share resources.
4. **Grass culling.** The meadow is split into 8 m `MultiMesh` chunks with a custom AABB that
   includes the wind-blown tip reach, so each pass draws only the blades it can see. Blade
   placement, colours and the wind shader are untouched.
5. **One compiled shader per effect.** The house weathering and birch bark shaders are created
   once and shared; per-object parameters stay in their own materials.
6. **Idle far trees.** Sway re-uploads every mesh of a tree each frame. Trees too far from the
   camera focus to appear on screen, even through a canopy or a full-length shadow, skip the
   update until they can be seen again.
7. **Frame limit options** now include 144, 165 and 240 FPS alongside Unlimited.

## Verification

- `./play.fish --headless -- --self-test`: 36 checks pass.
- Eight fixed views were rendered on both branches with the GL Compatibility renderer, with
  time-varying content hidden (grass, water, particles, residents, animals, trees), and
  compared pixel by pixel at 1440×900:

  | View       | Mean abs. diff (0–255) | Pixels differing by >8 | Max diff |
  | ---------- | ---------------------: | ---------------------: | -------: |
  | arrival    |                  0.018 |                  0.000% |        7 |
  | overview   |                  0.012 |                  0.002% |       39 |
  | pond       |                  0.031 |                  0.007% |       29 |
  | smith      |                  0.007 |                  0.007% |       30 |
  | research   |                  0.007 |                  0.000% |        3 |
  | garden     |                  0.046 |                  0.006% |       20 |
  | gate       |                  0.013 |                  0.000% |        9 |
  | wall corner|                  0.022 |                  0.000% |        1 |

  The handful of stronger pixels are isolated edge samples where overlapping coping stones
  share a plane and now resolve in a different draw order.

- A first version also merged imported props (lanterns, well, beds, ducks). That was
  measurably different: imported meshes carry level-of-detail index sets and compressed
  vertex data that a baked copy loses, and the lantern housings' lamp shadows softened.
  Imported meshes are therefore always left alone.

## Remaining cost

Draw calls are now dominated by the ~85 trees (each 5 meshes, 8–9 surfaces, ~140 000
triangles with import-time LODs), the nine houses, and the cats, ducks and vegetable beds
(imported models with 21–77 parts each). All are left exactly as authored; reducing them
further means changing the art (fewer canopy surfaces, joined props with their own LODs),
not the code.

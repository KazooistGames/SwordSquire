# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Shield Squire" — a 2D pixel-art sword-fighting game in **Godot 4**, written entirely in **GDScript**. Started as a self-imposed game jam (Brad Nulsen, Kazooist Games, June 2025).

The `.csproj`/`.sln` and the `"C#"` entry in `config/features` are leftover .NET scaffolding — there are **no `.cs` files** and nothing depends on the .NET SDK. Don't add C# unless asked.

## Commands

There is no test suite, linter, or build script. The only tooling is the Godot editor/runtime.

```bash
# Run the main scene (Title.tscn)
/Applications/Godot.app/Contents/MacOS/Godot --path .

# Open the editor
/Applications/Godot.app/Contents/MacOS/Godot -e --path .

# Run one scene in isolation (useful for a single archetype/prefab)
/Applications/Godot.app/Contents/MacOS/Godot --path . Scenes/Guy/Archetypes/Swordsman/Swordsman.tscn

# Reimport assets / surface script parse errors without opening the GUI
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit

# Headless smoke test of the map solver (macOS has no timeout(1) — background and kill)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . > /tmp/run.log 2>&1 & \
  sleep 15; kill %1; cat /tmp/run.log
```

### What the scenes currently contain

**On the `wave_function_collapse` branch, no playable scene exists.** `Title.tscn` (the declared main scene) holds only a `CanvasModulate` and the WFC map; `Test.tscn` is a scratch 32×32 `StaticBody2D` tile, untracked by `main`. Nothing in the branch instances `Swordsman.tscn`, `HMI.tscn`, `Tree.tscn`, or `Personality.tscn`.

The full playable arrangement (map + `Hmi` + `Swordsman` + four `Tree`s) lives in **`Title.tscn` on `main`**. To exercise combat, foliage, or the camera, either check out `main` or copy those nodes back in — `git show main:Title.tscn` is the reference.

### Godot version

Locally installed Godot is **4.6.3**; `project.godot` declares **4.4**. Opening the project in the editor silently upgrades `.tscn`/`.godot` files — check `git diff` after any editor session and don't commit incidental format churn. A `--headless` run produces no churn.

`.vscode/settings.json` points `godotTools.editorPath.godot4` at a Windows path; it's stale on macOS.

Controls: WASD (`moveUp` is jump, `moveDown` is duck/drop-through), Space = `smash` (hold to charge, release to swing), F = `Interact`, Enter = `Enter` (re-seeds the map in `map.gd`; unread by anything else).

## Repository hygiene

- **`.godot/` is fully committed** (~731 files) and there is no `.gitignore`. Editor caches and shader caches land in `git status` after every editor run. Expect noise; stage deliberately, and never `git add -A`.
- Because `.godot/uid_cache.bin` is committed and goes stale, `uid://` references can resolve to paths that no longer exist — producing "Cannot open file" / "referenced non-existent resource" errors naming a path the `.tscn`/`.tres` does not actually contain. This bites hardest after a file rename that carried its `.uid` across. Fix with `rm .godot/uid_cache.bin` and re-run Godot to regenerate it. **Suspect this before suspecting the scene.**
- `*.tscn*.tmp` files scattered in the repo are Godot editor crash/autosave artifacts, not sources. Leave them alone; don't reference them.

## Architecture

### `Guy` — the fighter (`Scenes/Guy/Guy.gd`)

`class_name Guy extends CharacterBody2D` is the single body used by every character. It owns a five-state machine (`ready / charging / attacking / recovering / dead`) driven from `_physics_process` in a fixed order: energy → movement → animation → state.

The key design rule: **`Guy` never reads input.** It exposes an imperative API — `left_right` (set to -1/0/1), `jump()`, `duck()`, `charge()`, `release()`, `interact()`, `shove()`, `damage()`, `turn_toward()` — and both the player controller and the AI drive it through that same surface. Adding a new control source means writing something that pokes those members, not subclassing `Guy`.

Combat nuances worth knowing before touching movement/attack code:
- Attack type is decided at `charge()` time from `left_right`: standing still → `smash_attack` (slash), moving → a lunging stab that applies a forward impulse on release.
- Charge is bounded by `charge_timer_min`/`charge_timer_max`; swinging early sets `charge_marked_for_release` rather than firing immediately. Holding past max auto-releases.
- `run_charge_timer` gates a ramp-up before full run speed — direction changes reset it, which is why there's a distinct `slide` animation state.
- `duck()` only resets `duck_debounce`; `_physics_process` is what drops `collision_mask` to `1` for `duck_duration`, letting the character fall through tree branches (layer 5) while staying on the ground floor (layer 1).
- `_handle_animation_finished` is the only thing that advances `attacking → recovering`, so an attack state with `looping = true` would hang the state machine.

`Scenes/Guy/debug.gd` is a `@tool` `Control` inside `Guy.tscn` that prints state / x-velocity / accel over each character.

### `FightingFrames` — animation + hitbox authoring (`Scenes/Guy/FightingFrames/`)

Custom sprite-sheet animator replacing `AnimatedSprite2D`. Both scripts are `@tool` scripts and run in the editor.

- `FightingFrames` (a `Sprite2D`) advances `current_frame_index` and sets `region_rect` on a horizontal sheet. It owns the `hitBox` and `hurtBox` child `Area2D`s.
- `FrameParams` nodes are **children** of the `FightingFrames` node, one per animation state, named for the state (`stance`, `run`, `stab`, `stab_windup`, `stab_recover`, `slash`, `slash_windup`, `slash_recover`, `die`, `slide`). Each holds the sheet, frame range, fps, and — critically — **per-frame hitbox/hurtbox offsets** as `hitbox_positions` / `hurtbox_positions` arrays indexed by frame (indexed relative to `first_frame_index`, and mirrored by `flip_h`/`flip_v`).
- `set_state(name)` finds the child by name and assigns it to `param_node`; the setter copies all params onto the sprite and calls `play()`. So **adding an animation state means adding a `FrameParams` child node in the archetype scene**, then referencing its name from `Guy._animate_state()`.
- `FrameParams.copy_parent` is an editor-only convenience: tick it and the node pulls the current values back off `FightingFrames`, so you can tune hitboxes live in the inspector and then bake them into the state.

### Archetypes

`Scenes/Guy/Archetypes/<Name>/<Name>.tscn` inherits `Guy.tscn` and supplies the `FrameParams` children plus `Team`. `Swordsman` is fully authored. `Squire` has art and an inherited scene but no `FrameParams` states yet — it is not playable.

`Scenes/Guy/Animation/` (`custom_animation.gd`, `sprite_2d.gd`) and the `Archetypes/*/States/*.tscn` files are the **superseded** predecessor of this system. The `States/` scenes still reference those scripts, but nothing references the `States/` scenes — the whole cluster is dead.

### Hit resolution (`Scenes/Guy/Boxes/`) — currently dormant

The intended design: damage is deferred, not immediate. During `State.attacking`, `hit_box.gd` accumulates overlapping targets into `guys_marked_for_hit`, `guys_marked_for_parry`, and `items_marked_for_smack`; on transition to `State.recovering` it flushes those lists as `landed_hit` / `parried` signals and applies item impulses. Parry beats hit: overlapping another attacker's *hitbox* (layer 4) while they're attacking moves them from the hit list to the parry list. Damage and knockback scale with `charge_timer / charge_timer_max`.

**None of that runs today.** `hit_box.tscn` / `hurt_box.tscn` are standalone scenes that no other scene instances. The live `hitBox`/`hurtBox` under `fightingFrames.tscn` are plain unscripted `Area2D`s (and the live `hitBox` never sets `collision_layer`, so it sits on layer 1 rather than 8). `Guy._handle_hit` / `_handle_parry` are never connected to anything. Wiring combat back up means attaching those scripts/layers to the boxes inside `fightingFrames.tscn` and connecting the two signals.

Note the parent chain the boxes assume: `hit_box.gd`/`hurt_box.gd` do `get_parent()` expecting a `CharacterBody2D`, but the boxes are children of `FightingFrames`, which is itself the child of `Guy`. `bush.gd` gets this right with a double `get_parent()`; the box scripts do not.

### Player controller / camera (`Scenes/HMI/HMI.gd`)

A `Camera2D` that doubles as the player input handler, HUD driver, and stealth resolver. It holds an exported `player : CharacterBody2D` (assigned via `node_paths` in the instancing scene), polls `Input` each frame and writes to `player.left_right` / calls `player.jump()` etc., sizes the `hp_bar`/`strength_bar` `ColorRect`s, moves the `PointLight2D` field of view, and hides any `Guy` in the `Guy` group whose `Concealments` aren't all shared with the player. Camera follow uses separate X and Y logic with a Y deadband so vertical motion doesn't jitter.

### AI (`Scenes/AI/Personality/`)

`Personality` is an `Area2D` sense volume intended to be a **child of a `Guy`** (`Me = get_parent()`). It selects among `Behaviour` child nodes by priority (skipping those with `Yielding`), reads `Desired_Coordinates` off the winner, and translates that into `Guy` API calls — steering `left_right`, jumping over obstacles found by the `across`/`down`/`above` raycasts, ducking to descend. Behaviours (`behaviour_fight.gd`, `beahviour_patrol.gd` — note the typo in that filename) only set `Desired_Coordinates` and their own `Yielding` flag; they never move the body.

`personality.gd` discovers behaviours via `find_children('*_*')`, so **behaviour node names must contain an underscore**.

Status: `Personality.tscn` is not instanced in any scene, and `is_deadended()`/`get_slide_length()` reference `Me.jump_height` and `Me.acceleration`, which `Guy` does not define (it has `base_jump_height` / `base_accel`). The AI will error at runtime as-is — expect to fix those names when wiring it up.

### Procedural foliage (`Scenes/Foliage/`)

Trees build themselves at `_ready` from stacked prefabs, each a `@tool` script so they render in the editor:

`Tree` → N × `Trunk_Segment` (24px stack; section index picks stump/trunk/branch/canopy from a vertical sprite atlas) → a `branch` section attaches a `Limb` → N × `Branch_Segment` (horizontal atlas) → an `end` section attaches a `Bush`, a `fruit` section attaches a `Fruit`.

`Bush` is the concealment mechanic: on area overlap it appends itself to the entering `Guy`'s `Concealments` array and propagates the event to `linked_bushes` (adjacent overlapping bushes), so a canopy of several bushes acts as one hiding spot. A `Guy` is visible to an observer only if the observer shares every one of the target's concealments — that check is duplicated in `HMI.can_see_through_all_concealments` and `behaviour_fight._can_see_through_all_concealments`.

`Fruit` is a frozen `RigidBody2D` that unfreezes on `smack()` (from a hitbox) and restores energy on `use()` (from `Guy.interact()`).

### Wave function collapse map (`Scenes/Map/`)

The newest and least settled subsystem — it replaced the old hand-sized floor that used to live at this path. It currently runs clean: a 15-second headless run of `Title.tscn` produces no errors or contradictions.

Two files plus a folder of resources:

- **`Cell` (`cell.gd`, `class_name Cell extends Resource`)** — a WFC module. It has a `Tag : Biomes` (`wildcard/sky/ground/underground`) describing what the cell *is*, and `Sockets : Dictionary[Cardinals, Biomes]` describing what it *accepts* on each of its four edges. `fits(other, direction)` is symmetric: my socket facing them must accept their `Tag`, **and** their mirrored socket must accept my `Tag`; `wildcard` matches anything. `collapse()` builds the visual+physics node inline in code — an `Area2D` for sky/underground, a `StaticBody2D` with a 32×32 box collider for ground, each with a coloured `ColorRect` child. **There are no tile scenes**; `Scenes/Map/tiles/` holds only an unexported `.aseprite`.
- **Templates (`cells/*.tres`)** — `sky`, `ground`, `hole`, `tunnel`, `cave`. Authored by hand; `Tag` and `Sockets` are stored as raw enum ints, so read `cell.gd`'s enums to interpret them.
- **`map.gd`** — the solver on a `Node2D` that renders into a `SubViewport`. `initialize_map()` fills `grid_candidates[coord]` with every template permutation and drops a `Label` per coordinate showing the live candidate count. `_process` runs one `perform_wave_collapse_round()` per frame: pick uniformly among the lowest-entropy coordinates, `collapse_cell()`, then drain `entropy_propagation_queue` through `calculate_entropy()`, which prunes candidates that have no compatible neighbour option, auto-collapses at one candidate, and `push_error`s on zero. `backtrack_chunk()` is the contradiction recovery — it resets the offending cell and its collapsed neighbours to the full template list.

Things to know before editing the solver:

- `load_cell_templates()` **loads templates by directory scan** of `cells/`, so dropping a new `.tres` in that folder registers it — there's no registry to update. It skips only `.import`, so any non-`.tres` file dropped in there will be `load()`ed and pushed into `Array[Cell]`.
- Each template is expanded into its rotations (`rotated_cw`, `rotated_ccw`) and, when `is_assymmetrical()` (left socket ≠ right socket), its mirror. The default orientation's flip is appended **twice** (once inside the permutation loop, once after it), so asymmetric templates are over-represented in `pick_random()`.
- `grid_cells` holds collapsed cells; `grid_candidates` keeps an entry for *every* coordinate including collapsed ones (narrowed to a single-element array). `calculate_entropy`'s `if coordinates not in grid_candidates` guard therefore never fires, and collapsed cells are re-evaluated on propagation.
- Cells are **32px** (`Cell.Size`), unlike the 24px grid the character/foliage art uses.

### Collision layers

Layer numbers are unnamed in `project.godot`, and several scripts test raw bitmasks (`body.collision_layer & 512`, `& 2048`, `& 8`). The de-facto assignment:

| Bit | Value | Used by |
|-----|-------|---------|
| 1 | 1 | World floor / collapsed `ground` cells |
| 2 | 2 | `Guy` body |
| 3 | 4 | hurtbox |
| 4 | 8 | hitbox (per `hit_box.tscn`; the live in-scene hitbox is unset → layer 1) |
| 5 | 16 | Tree trunk/branch segments (drop-through platforms) |
| 10 | 512 | Items (`Fruit`) — interactable/smackable |
| 12 | 2048 | `Bush` concealment |
| 16 | 32768 | `Personality` sense area |

`Guy` masks `17` (floor + trees); ducking temporarily narrows it to `1`.

## Conventions

- Godot groups `Guy` and `Bush` are declared as global groups and queried with `get_tree().get_nodes_in_group(...)`. New character/foliage scenes must join them.
- Exported members use `PascalCase` (`Team`, `HP`, `Energy`, `Concealments`, `Section_Index`); locals and private methods use `snake_case`.
- Physics runs on a separate thread (`2d/run_on_separate_thread=true`). Keep per-frame gameplay logic in `_physics_process`; `_process` is used only for the camera/HUD, box repositioning, and the WFC solver step.
- Rendering is nearest-neighbour (`default_texture_filter=0`) with `stretch/mode="viewport"`, and the window is non-resizable. Character and foliage art is on a 24×24 grid; the map is on 32px. Keep new sprites on whichever grid their subsystem uses.
- `.aseprite` sources sit next to their exported `.png`; when a sprite changes, both need re-exporting through Aseprite.

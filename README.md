# 🥤 The Vending Machine

> Press a button. Get a mood in a can.

A small 3D interactive toy built in **Godot 4.5**. You look at a retro-cyberpunk  
vending machine standing on a quiet night street. It has five buttons, and each  
button sells exactly one thing — a *feeling*. Press one and the machine spits out  
a soda can whose material is repainted to match that emotion, while the whole  
scene around you changes with it: the light shifts colour, particles start  
falling or floating, and the ambience crossfades into a new track.

Made as a study of **procedural material variation + environment state machines**  
in Godot, not as a game with a win condition. There is no goal. You just press  
buttons and watch the mood change.

---

## Contents

- [The Five Emotions](#the-five-emotions)
- [Controls](#controls)
- [How It Works](#how-it-works)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Assets & Credits](#assets--credits)
- [Roadmap & Known Issues](#roadmap--known-issues)
- [License](#license)

---

## The Five Emotions

Every button drives one *emotion profile*. A profile is a single dictionary that  
describes both the can's PBR material and the scene state — one source of truth,  
consumed by two independent systems.

| Button           | Emotion    | Can colour       | Can material                                                | Scene reaction                                                                      |
| ---------------- | ---------- | ---------------- | ----------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `Btn_Melancholy` | Melancholy | `#0033CC` blue   | rough `0.65`, metallic `0.20`, no emission                  | Blue interior light, **rain** particles, rain ambience                              |
| `Btn_Anger`      | Anger      | `#FF0000` red    | rough `0.35`, metallic `0.25`, emission `0.6`               | Dim red light with **random lightning flashes** + thunder crack                     |
| `Btn_Joy`        | Joy        | `#FFAA00` orange | rough `0.20`, metallic `0.85`, emission `3.0`               | Pulsing warm light (`2.0`–`3.0`), **fireflies** orbiting                            |
| `Btn_Zen`        | Zen        | `#00FFAA` teal   | rough `0.92`, metallic `0.05`, no emission                  | Soft teal light, **drifting fog** (8 random textures, tweened in/out)               |
| `Btn_Glitch`     | Glitch     | `#AA00FF` purple | rough `0.45`, metallic `0.30`, emission `1.2`, alpha `0.95` | Light **strobes ~20 Hz** between `0.0` and `5.0` energy, then **the machine locks** |

The Glitch button is the only one with a rule attached: it fires once, and after  
that every button becomes dead. The vending machine is broken. That's the ending.

---

## Controls

The camera is a free orbit rig clamped to a box around the machine — you can  
look at it from any side, but you can't leave the street corner.

| Input                      | Action                             |
| -------------------------- | ---------------------------------- |
| **Left click** on a button | Press it                           |
| **Right mouse drag**       | Orbit (yaw / pitch)                |
| **Mouse wheel**            | Zoom (`1.5` – `6.0` units)         |
| **W A S D**                | Move the camera pivot horizontally |
| **Q / E**                  | Move down / up                     |
| **Shift**                  | Sprint (`2.5×` move speed)         |

---

## How It Works

Three scripts do the work, and they never talk to each other directly — the  
emotion `String` is the only thing that travels between them.

```
button press (String)
      │
      ▼
   main.gd ──────────────────────────┐
      │                              │
      │ spawn_can(transform, profile)│ set_mode(emotion)
      ▼                              ▼
 can_factory.gd               environment_manager.gd
  ├─ instantiate can.tscn       ├─ OmniLight3D colour / energy
  ├─ keep only the newest can   ├─ rain / firefly / fog particles
  ├─ recursive material swap    ├─ A/B audio crossfade
  └─ apply PBR profile          └─ thunder one-shot
```

### `Scripts/main.gd` — orchestrator

On `_ready()` it walks `VendingMachine/Buttons` and connects every child that  
exposes a `pressed` signal. On press it does three things:

1. Reads the emotion profile from the `PROFILES` dictionary.
2. Asks `CanFactory` to spawn a can at the `DispenserSpawn` marker.
3. Asks `EnvironmentManager` to switch mode.
4. If the emotion was `glitch`, sets `_machine_locked = true` — all later presses  
   are ignored and logged.

### `Scripts/can_factory.gd` — object spawning & material override

Instantiates `can.tscn` (a `RigidBody3D` with a capsule collider, mass `0.6`),  
places it at the dispenser, gives it a small random tilt and an initial velocity  
along the dispenser's `-Z`. Only one can is ever alive: the previous one is  
`queue_free()`d on each spawn.

The interesting part is `_apply_material_recursive()`: it walks the instantiated  
model tree, and for every `MeshInstance3D` it **duplicates** the surface material  
before writing to it. Without that duplicate, every can would share one material  
resource and they would all change colour together.

### `Scripts/environment_manager.gd` — scene state machine

A `match` on the mode string drives everything: light colour and energy, which  
particle system emits, and which ambience plays. Audio uses a **two-player  
crossfade** — `AudioA`/`AudioB` alternate, the incoming player fades `-80 dB →
-10 dB` while the outgoing fades out, over 2 seconds.

Anger and Glitch are animated in `_process()`: Anger counts down to a random  
`3–5 s` lightning event, Glitch toggles the light energy every `0.05 s` with a  
coin flip. Zen fog is tweened via `amount_ratio` (`0.5 s` in, `2 s` out) and  
picks one of eight fog textures at random each time it appears.

### `Scripts/orbit_camera.gd` — camera rig

The camera is a child of `CameraPivot` looking at it. Dragging rotates the pivot;  
the wheel moves the camera along its local Z. Movement is clamped relative to the  
`VendingMachine` node using a min/max box, so the framing can't be lost.

### `Scripts/button_interactable.gd` — one button

Tiny by design: an `Area3D` catches `input_event`, and a left click re-emits a  
`pressed(emotion_id)` signal. `emotion_id` is an exported string, so a new button  
is a scene edit, not a code edit.

---

## Project Structure

```
the-vending-machine/
├── Main.tscn                   # entry scene — world, camera, factory, environment
├── vending_machine.tscn        # the machine: body, 5 buttons, labels, colliders
├── can.tscn                    # the dispensed can (RigidBody3D + capsule)
├── project.godot               # Godot 4.5, Forward+, 1920×1080
├── Scripts/
│   ├── main.gd                 #  58 lines — profiles + button wiring
│   ├── can_factory.gd          #  80 lines — spawn + recursive material swap
│   ├── environment_manager.gd  # 258 lines — light / particles / audio state machine
│   ├── orbit_camera.gd         # 107 lines — clamped orbit + WASD rig
│   └── button_interactable.gd  #  18 lines — click → signal
├── Assets/
│   ├── Audio/                  # 6 ambience tracks (rain / thunder / joy / zen / glitch)
│   └── Models/                 # 2 glTF models, textures embedded in the .glb
│       ├── retro_cyberpunk_vending_machine.glb
│       └── soda_cangray.glb
└── Materials/
    ├── fog_01…08.png           # Zen fog sprites (one is picked at random)
    └── back/
        └── street_lamp_2k.exr  # night-street HDRI used as the sky
```

**Total shipped assets: 2 models, 1 HDRI, 8 fog sprites, 6 audio tracks — 54 MB.**
That is the complete set; nothing else in the repository is loaded at runtime.

**~520 lines of GDScript, 3 scenes, 5 systems.** Nothing else.

---

## Getting Started

Requires **Godot 4.5** (Forward+ renderer). No plugins, no build step, no  
dependencies.

```bash
git clone https://github.com/xmanwo/vendingmachine.git
cd vendingmachine
```

Then open `project.godot` in Godot 4.5 and hit **F5**. `Main.tscn` is already set  
as the main scene.

> **Note on first open:** the repo ships the raw models and the `.import` files,  
> but not the `.godot/` cache — it's gitignored. Godot will re-import every asset  
> on first open, which takes a minute because of the large HDRI and glTF files.  
> That's normal.

---

## Assets & Credits

The code is mine. The 3D models are not — and both of them are **CC-BY-4.0**,
which *legally requires* attribution. This section is not optional.

### 3D models

| Asset | Author | Licence | Source |
| --- | --- | --- | --- |
| `retro_cyberpunk_vending_machine.glb`<br/><sub>the machine body</sub> | **franklin clodfelter**<br/><sub>[sketchfab.com/fsclodfelter](https://sketchfab.com/fsclodfelter)</sub> | [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/) | [Sketchfab — *retro cyberpunk vending machine*](https://sketchfab.com/3d-models/retro-cyberpunk-vending-machine-f87c57bf1b0743f78966fb1e535940a7) |
| `soda_cangray.glb`<br/><sub>the dispensed can</sub> | **Ya**<br/><sub>[sketchfab.com/Yarik16](https://sketchfab.com/Yarik16)</sub> | [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/) | [Sketchfab — *Soda can*](https://sketchfab.com/3d-models/soda-can-f28f781755a84a4e83e56e36d06c624f) |

Both models ship with every texture embedded inside the `.glb`, so no external
texture files are needed. The author and licence above were read directly from
the `asset.extras` metadata embedded in each file by the Sketchfab exporter —
this is the authoritative record, not a guess.

> **If you fork this project, keep this attribution.** CC-BY-4.0 lets you use and
> modify these models — including commercially — but you must credit the authors
> above and state the licence.

### Environment

| Asset | Licence | Source |
| --- | --- | --- |
| `street_lamp_2k.exr` — night-street HDRI sky | **CC0** — no attribution required | Likely [Poly Haven](https://polyhaven.com/) (CC0, public domain) |
| `fog_01…08.png` — Zen fog sprites | unrecorded | unrecorded |

### Audio

| File | Used by | Embedded tags |
| --- | --- | --- |
| `1youyu.ogg` | Melancholy ambience | ⚠️ `artist=InspectorJ` |
| `2fennu.mp3` | Anger thunder crack | LAME-encoded, no tags |
| `3huanyu.mp3` | Joy ambience | no tags |
| `4chanyi.ogg` | Zen ambience | encoder only |
| `5guzhang1.ogg` | Glitch ambience | encoder only |
| `windback.ogg` | Anger ambience bed | `encoded_by=Pro Tools` |

> ⚠️ **Unresolved — needs your input.** The origin and licence of the six audio
> tracks and the eight fog sprites are not recorded anywhere in this repository.
> `1youyu.ogg` carries an embedded `artist=InspectorJ` tag, and InspectorJ is a
> well-known [freesound.org](https://freesound.org/) contributor whose uploads
> are often **CC-BY** — which would require attribution. Please confirm where
> each file came from, or replace them with assets you own or that are CC0.

---

## Roadmap & Known Issues

**Gameplay**

- [ ] Buttons have no press animation or click SFX  
  (`ButtonSFX` nodes exist but no stream is assigned)
- [ ] No way to reset the machine after Glitch without restarting the scene
- [ ] Cans are purely cosmetic — no interaction, no sound on landing

**Code**

- [ ] `PROFILES` lives in `main.gd` while the environment colours are duplicated  
  in `environment_manager.gd` — the two should read from one shared source

**Licensing**

- [ ] Six audio files and eight fog sprites have no recorded source or licence
      (see *Assets & Credits* above)
- [ ] The repository has no `LICENSE` file of its own (see *License* below)

**Resolved**

- [x] **371 unused files removed.** The project went from **376 MB to 54 MB**.
      Only four asset groups are actually referenced by the scenes: the two
      models, one HDRI, eight fog sprites and six audio tracks. Everything else
      — 14 unused glTF models, the `city_corner` environment pack, three spare
      HDRIs, and several hundred duplicate texture files that the Sketchfab
      `.glb` bundles already had embedded — is gone.
- [x] **Git history rebuilt and repacked.** `.git` was 359 MB because every
      blob had been sitting unpacked since the first commit. It now contains
      only the assets that are actually used.
- [x] Vestigial empty nodes `EnvironmentController` / `AudioController` removed
      from `Main.tscn`
- [x] Empty `_Scenes/` and `Materials/res1/` directories removed
- [x] Unused `Assets/Audio/5guzhang2.flac` removed

---

## License

There is **no `LICENSE` file in this repository yet**, which legally means "all
rights reserved" even though the code is public. Since this is a portfolio
project, adding one is worth doing — MIT is the usual choice for a small Godot
project.

Note the split, though: an MIT licence here could only cover *my* code. The two
3D models sit under **CC-BY-4.0** and keep their own terms regardless of what
licence the repository carries (see *Assets & Credits*).

---

<p align="center"><sub>Built with Godot 4.5 · GDScript · Forward+</sub></p>

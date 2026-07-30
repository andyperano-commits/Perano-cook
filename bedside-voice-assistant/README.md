# Bedside Voice Assistant

A fixed, USB-C-powered bedside satellite for the existing Jarvis voice
pipeline (Voice → Faster Whisper → HA Assist → Extended OpenAI Conversation
→ Piper → Speaker), built around a round AMOLED display in a glowing
ball-shaped enclosure.

## Hardware

**Waveshare ESP32-S3-Touch-AMOLED-1.75C**

- ESP32-S3R8, dual-core 240MHz, 32MB flash, 8MB PSRAM
- 1.75" round AMOLED, Φ55mm, capacitive touch
- Dual microphones + ES7210 echo-cancellation chip + ES8311 audio codec
- AXP2101 power management, Type-C port, onboard speaker pads

Chosen over the 1.85C (single mic, no echo cancellation) and 1.85B (dual
mic claimed but undocumented — no wiki page exists). No battery: this is a
permanent USB-C-powered bedside unit, so there's no need to budget for
power draw or charge circuitry.

## Enclosure

`enclosure/bedside_ball_enclosure.scad` — a parametric OpenSCAD model:

- Sphere, 92mm OD, 2.6mm wall, flat-cut base so it sits freestanding with
  no cradle
- Board cavity tilted 25° so the screen faces up toward the bed
- Mic gap slot cut at the true top of the shell for pickup
- USB-C cutout and BOOT/PWR button access holes
- **Split into two printable halves** (front: screen bezel + mic gap +
  board mounting standoffs; back: flat base + USB-C + most of the
  interior), joined by a tongue-and-groove seam plus four small
  self-tapping screws driven in from access holes near the front dome.
  This replaces the original single-hollow-sphere design, which needed
  heavy internal supports and was near-impossible to clean out — printing
  each half with its flat parting face down on the bed keeps both domes
  fully self-supporting.
- The screen window is a **separate** clear PETG/acrylic disc
  (`screen_window()` module) that sits in a stepped rabbet over the
  display — diffusion PETG can't go over the actual AMOLED without
  blurring it, so only the surrounding bezel ring is printed in the glow
  material.

Validated with `openscad` (installed via apt for this): both halves render
as `Simple: yes` manifold solids with no part poking outside the outer
sphere. Render either half or the assembled preview with:

```bash
openscad -D 'PART="front"' -o front.stl bedside_ball_enclosure.scad
openscad -D 'PART="back"' -o back.stl bedside_ball_enclosure.scad
openscad -D 'PART="window"' -o window.stl bedside_ball_enclosure.scad
openscad bedside_ball_enclosure.scad   # opens the assembled preview in the GUI
```

**Open items before printing final parts** (all called out as `TODO
verify` comments in the file itself):
- Board footprint, mounting hole positions, and screen module diameter are
  placeholder measurements — measure the actual PCB with calipers once it
  arrives and adjust `board_w`, `board_d`, `board_mount_holes`,
  `window_d`/`window_step_d`.
- `board_tilt` (currently 25°) needs confirming against the actual
  nightstand/bed height once the unit is in place.
- Tongue/groove and screw-boss clearances (`lip_clearance`, `boss_od`,
  etc.) are reasonable first-pass values for PETG — expect to tune after
  a test print.

## ESPHome firmware

`esphome/bedside-voice-assistant.yaml` — configures this node as another
`voice_assistant:` satellite into the existing HA Assist pipeline (Whisper
STT / Extended OpenAI / Piper TTS are all configured server-side in Home
Assistant, not here — this device just streams mic audio in and plays
speaker audio back), plus:
- 466×466 round AMOLED display (CO5300 driver over QSPI)
- Capacitive touchscreen
- LVGL UI: clock face, weather tile (pulled from a Home Assistant
  `weather.*` entity), and a "Lights Off" button calling
  `light.turn_off`
- BOOT button starts a voice-assistant turn; PWR button stops one

Copy `esphome/secrets.yaml.example` to `esphome/secrets.yaml` and fill in
real WiFi/API/OTA credentials before compiling.

Validated with `esphome config bedside-voice-assistant.yaml` (ESPHome
2026.6.5, installed into a venv for this) — the full schema checks out
after fixing several real issues along the way (OTA flag for 32MB flash,
several GPIO pin collisions between placeholder assignments, wrong LVGL/
audio config shapes). A full firmware **compile** wasn't completed in this
environment — it needs to download the ESP-IDF toolchain, which failed on
this sandbox's proxied network (SSL cert issue unrelated to the config
itself); this doesn't affect the validity of the YAML but the first
`esphome compile` on real hardware should be watched for anything the
schema validator can't catch.

**Open items before flashing** (all called out as `TODO verify` comments
in the file itself):
- Almost every GPIO number is a best-effort placeholder sourced from
  public search results for the sibling ESP32-S3-Touch-AMOLED-1.75 board
  (docs.waveshare.com and devices.esphome.io both blocked this session's
  fetch tool) — **every pin must be confirmed against the actual 1.75C
  schematic/wiki before flashing**, especially the QSPI display data
  lines, which are the least-confirmed of the bunch.
- The touch controller is a CST9217; ESPHome 2026.6.5 has no dedicated
  driver for it (only `cst816`/`cst226` exist). The config uses `cst816`
  as an unconfirmed placeholder — check for a newer ESPHome release or an
  external_component before relying on touch input.
- Confirm whether the other N16R8 voice satellites use on-device wake
  word (`micro_wake_word:`) or delegate to the Assist pipeline
  (`use_wake_word: false`, what this config currently does) and match
  whichever they actually use.
- `weather.home` in the `text_sensor`/`sensor` blocks needs pointing at
  the real Home Assistant weather entity ID.

## Next steps

1. Verify all placeholder GPIOs and board dimensions once the physical
   board is in hand.
2. Confirm `board_tilt` against the real nightstand/bed height.
3. Sort out CST9217 touch driver support.
4. Test-print the two enclosure halves, tune joint clearances, then print
   final parts in diffusion PETG (shell) + clear PETG/acrylic (window).

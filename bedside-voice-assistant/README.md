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
- Two mic gap slots (not one) mirrored across one side of the board, and
  two button access holes mirrored across the opposite side — matching
  the real board's layout (MIC1/MIC2 diagonal corners on one edge,
  BOOT/PWR on the other), confirmed from Waveshare's own schematic/layout
  pages rather than guessed
- USB-C cutout
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
- BOOT button starts a voice-assistant turn

Copy `esphome/secrets.yaml.example` to `esphome/secrets.yaml` and fill in
real WiFi/API/OTA credentials before compiling.

Validated with `esphome config bedside-voice-assistant.yaml` (ESPHome
2026.6.5, installed into a venv for this) — the full schema checks out
after fixing several real issues along the way. A full firmware
**compile** wasn't completed in this environment — it needs to download
the ESP-IDF toolchain, which failed on this sandbox's proxied network
(SSL cert issue unrelated to the config itself); this doesn't affect the
validity of the YAML but the first `esphome compile` on real hardware
should be watched for anything the schema validator can't catch.

**GPIO pins were re-derived from the real 1.75C schematic** (photos of
the schematic pages and PCB layout), not just web search — this caught
and fixed real errors from the first draft, which had guessed pins that
actually collided with the true I2S/touch assignments (e.g. it thought
the QSPI clock/data lines used GPIO9-13, which are actually the I2S BCLK
and touch pins). Confirmed directly off legible schematic labels:
- I2C: SDA=GPIO15, SCL=GPIO14 (shared bus for codec, mic ADC, IMU)
- Display QSPI: SIO0-3=GPIO4/5/6/7, clock=GPIO38, CS=GPIO12, reset=GPIO1
- Touch: reset=GPIO2 (TP_RESET), interrupt=GPIO10 (TP_INT)
- Audio: I2S LRCLK=GPIO45, BCLK=GPIO9, MCLK=GPIO16, speaker DOUT=GPIO8,
  speaker-amp enable (PA_CTRL)=GPIO46
- BOOT button = GPIO0 (standard S3 strap pin, matches the KEYS schematic
  block)

**Open items before flashing** (all called out as `TODO verify` comments
in the file itself):
- The mic's I2S data-in pin (ESP32 <- ES7210) wasn't legible in the photo
  of the ADC schematic block — `GPIO3` in the config is a placeholder,
  not a transcribed value. Needs a clearer photo of that block.
- The PWR button (Key2) isn't a plain ESP32 GPIO at all — it's wired to
  the AXP2101 PMIC's PWRON pin for hardware power sequencing. ESPHome
  2026.6.5 has no `axp2101` component, so there's currently no
  implemented way to read this button's state from ESPHome; left
  unimplemented rather than wired to a wrong pin.
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

1. Get a clear photo/read of the ADC (ES7210) schematic block to confirm
   the mic I2S data-in pin.
2. Verify board footprint/mounting-hole dimensions once the physical
   board is in hand, and confirm `board_tilt` against the real
   nightstand/bed height.
3. Sort out CST9217 touch driver support and the PWR/AXP2101 button.
4. Test-print the two enclosure halves, tune joint clearances, then print
   final parts in diffusion PETG (shell) + clear PETG/acrylic (window).

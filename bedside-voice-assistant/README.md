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
- Module mounting axis tilted 25° so the screen faces up toward the bed
- Two mic gap slots (not one) mirrored across one side of the module, and
  two button access holes mirrored across the opposite side — matching
  the real board's layout (MIC1/MIC2 diagonal corners on one edge,
  BOOT/PWR on the other), confirmed from Waveshare's own schematic/layout
  pages rather than guessed
- USB-C cutout
- **Split into two printable halves** (front: display module pocket + mic
  gap + button holes; back: flat base + USB-C + most of the interior),
  joined by a tongue-and-groove seam plus four small self-tapping screws
  driven in from access holes near the front dome. This replaces the
  original single-hollow-sphere design, which needed heavy internal
  supports and was near-impossible to clean out — printing each half with
  its flat parting face down on the bed keeps both domes fully
  self-supporting.

**Mounting changed once the physical module arrived**: the
ESP32-S3-Touch-AMOLED-1.75C turns out to be sold as a fully-assembled
round module with its own metal bezel and glass (confirmed from
Waveshare's outline-dimension drawing: Φ55mm OD, Φ48.96mm glass,
Φ43.76mm active area, 15.05mm thick) — not a bare rectangular PCB, and it
has **no mounting screws** on the back. So the earlier design's
board-footprint/corner-standoff/screw-mount logic and the separate clear
acrylic window insert are both gone — the module just drops into a
stepped circular pocket (`module_pocket_cut()`) from the back and seats
against a shoulder, held by friction plus the pocket's fit. The module's
own glass shows through a narrower through-hole that hides its metal rim
behind the shell material.

**A real size constraint came out of this**: a 55mm module is large
relative to a 92mm ball, and a sphere's cross-section narrows quickly
near the pole. Seating the module close to the outer surface would make
its pocket wider than the ball's cross-section at that depth — i.e. it
would blow out the side of the shell instead of sitting in a clean
socket. The fix was recessing the module ~10mm behind the outer surface
(`window_step_depth = 10`, leaving ~4mm of shell material around the
pocket's rim at its narrowest point) rather than the ~1.5mm originally
assumed. Practically, this means the display sits in a noticeably
recessed socket rather than flush with the ball's surface — if that's
not the look you want, the fix is a bigger `sphere_od`, not a smaller
`window_step_depth` (shrinking that number just breaks the geometry).

Validated with `openscad`: both halves render as `Simple: yes` manifold
solids with no part poking outside the outer sphere. Render either half
or the assembled preview (now includes a simple mock cylinder standing in
for the module, just to sanity-check the fit visually) with:

```bash
openscad -D 'PART="front"' -o front.stl bedside_ball_enclosure.scad
openscad -D 'PART="back"' -o back.stl bedside_ball_enclosure.scad
openscad bedside_ball_enclosure.scad   # opens the assembled preview in the GUI
```

**Open items before printing final parts** (all called out as `TODO
verify` comments in the file itself):
- `window_step_depth` (module recess depth) is a geometrically-valid
  first pass, not a measured value — Waveshare's drawing doesn't give the
  exact rim-to-glass offset, so tune after a test fit.
- Mic/button hole depth (`z0` in `mic_gap_cut()`/`button_holes_cut()`) is
  a guess at how far along the module's 15mm thickness those ports sit —
  worth checking against the physical module before printing final parts.
- `board_tilt` (currently 25°) needs confirming against the actual
  nightstand/bed height once the unit is in place.
- Tongue/groove and screw-boss clearances (`lip_clearance`, `boss_od`,
  etc.) are reasonable first-pass values for PETG — expect to tune after
  a test print.
- `module_pocket_clearance` (0.6mm) is an untested first guess for how
  loosely/snugly the module drops into its pocket.

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
2. Sort out CST9217 touch driver support and the PWR/AXP2101 button.
3. Test-print the two enclosure halves, check the module actually seats
   and shows through the window opening correctly, tune
   `window_step_depth`/`module_pocket_clearance`/joint clearances as
   needed, then print final parts in diffusion PETG.
4. Confirm `board_tilt` against the real nightstand/bed height once the
   unit is assembled.

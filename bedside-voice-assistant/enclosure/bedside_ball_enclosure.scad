// Bedside Ball Enclosure — ESP32-S3-Touch-AMOLED-1.75C voice assistant
//
// Freestanding sphere with a flat-cut foot, split into two printable halves:
//   - front half: a stepped circular pocket the round display module drops
//     into (module OD/glass diameter/thickness confirmed from Waveshare's
//     outline drawing — it's a fully-assembled module with its own bezel
//     and glass, not a bare PCB, and has no mounting screws), plus the mic
//     gap and button access holes
//   - back half: flat foot, USB-C cutout, most of the interior volume
// The two halves join on a tilted parting plane (perpendicular to the
// module's mounting axis) via a tongue-and-groove lip, secured with small
// screws driven in from just outside the seam.
//
// Print orientation: print each half with its flat parting face down on the
// bed — this keeps the dome curvature self-supporting with no internal
// scaffolding, which was the whole point of splitting the original single
// hollow-sphere design.
//
// Values marked "TODO verify" are best-effort placeholders — measure/tune
// against the physical module and a test print before printing final
// parts. Everything else derives from these parameters, so tuning them
// re-shapes the whole model.

/* ============================================================
   USER-TUNABLE PARAMETERS
   ============================================================ */

// --- Overall shell ---
sphere_od   = 92;    // sphere outer diameter (mm)
wall        = 2.6;   // shell wall thickness (mm)

// --- Freestanding flat base ---
// How far up from the sphere's lowest point the flat foot is cut.
// Bigger = wider, more stable foot, but a shorter overall ball height.
base_cut_offset   = 12;   // mm, measured up from the bottom pole
base_plate_thick  = 3.2;  // mm, solid floor thickness (thicker than `wall`
                           // for a stable, weighted base — it's a fixed
                           // bedside unit, no need to save weight here)

// --- Board mounting tilt ---
// 25 deg tilts the screen up toward the bed. TODO: confirm against the
// real nightstand/bed height once the unit is in place — this is the
// single number to change to re-angle the whole display.
board_tilt = 25;          // degrees, rotation about world X axis

// --- Round module footprint ---
// The ESP32-S3-Touch-AMOLED-1.75C is sold as a fully-assembled round
// module with its own metal bezel/case and glass — not a bare rectangular
// PCB — confirmed from Waveshare's own outline-dimension drawing and by
// checking the physical unit (no mounting screw holes on the back). It
// drops into a circular pocket and is retained by friction + the bezel
// seating against a shoulder, so there's no standoff/screw mounting logic
// here at all.
module_od         = 55;     // module OD including metal bezel, mm — confirmed (Waveshare drawing)
module_glass_d    = 48.96;  // outer edge of the visible glass/bezel border, mm — confirmed
module_active_d   = 43.76;  // active display area diameter, mm — confirmed, for reference only
module_thickness  = 15.05;  // total module depth front-to-back, mm — confirmed
module_pocket_clearance = 0.6; // mm diametral clearance so the module drops in
module_pocket_d   = module_od + module_pocket_clearance;

// --- Screen opening ---
// A narrow through-hole reveals the module's own glass while the shell's
// front material hides the metal bezel behind it; the module's rim seats
// against the shoulder where the narrow hole meets the wider pocket.
//
// window_step_depth can't be a small cosmetic number here — a 55mm module
// is large relative to a 92mm ball, and a sphere's cross-section narrows
// fast near the pole. Seating the module too close to the outer surface
// makes the pocket wider than the ball's cross-section at that depth,
// which would blow a hole out the side instead of a clean socket facing
// outward. 10mm keeps ~4mm of shell material around the pocket's rim at
// its narrowest (front) point — see the geometry check this derives from
// in the project README. The practical effect: the display sits in a
// noticeably recessed socket (like a deep-set eye) rather than flush with
// the surface. If that's not the desired look, the fix is a bigger
// sphere_od, not a smaller window_step_depth.
window_d          = module_glass_d + 1; // through-hole diameter, reveals the glass
window_step_depth = 10;    // mm, see note above — TODO tune after a test
                            // fit once the module's exact rim-to-glass
                            // offset is known (Waveshare's drawing doesn't
                            // give it)

// Radius used to place the mic/button cutouts just outside the module's
// edge, so they land on the module's own side-mounted mic/button ports.
module_edge_r = module_od/2 + 1;

// --- Mic gap (dual mic pickup) ---
// Per the real board layout: MIC1 and MIC2 sit at opposite corners of one
// side of the board (not a single slot at the pole, as an earlier draft
// of this file assumed before the real layout was available) — angles
// below are in the board's own local frame, mirroring each other across
// the local X axis. TODO verify against the actual layout's exact corner
// offset once the board is in hand; these angles put them near the board
// perimeter at roughly the same spread as the real photo.
mic_gap_w    = 10;   // slot length, mm (smaller now there are two)
mic_gap_h    = 2.6;  // slot width, mm (matches wall so it fully perforates)
mic_gap_corner_r = 1.0;
mic_angles = [150, 210]; // degrees around the board's local perimeter

// --- USB-C cutout (back half, opposite the screen side, near the base) ---
usbc_w = 10.5;  // cutout width, mm (panel-mount USB-C clearance)
usbc_h = 4.2;   // cutout height, mm
usbc_r = 1.2;   // corner rounding
usbc_height_offset = 10; // mm above the flat base cut, cutout center height
usbc_azimuth = 180;      // degrees in world XY, 0 = toward bed (+Y), 180 = away

// --- BOOT / PWR button access holes ---
// Per the real board layout: both side buttons (Key1/BOOT, Key2/PWR) sit
// on the same edge of the board, opposite the mics — angles below mirror
// mic_angles across the local X axis. TODO verify exact offset once the
// board is in hand.
button_hole_d      = 4.0;   // through-hole diameter, mm
button_countersink_d = 7.0; // shallow finger-access countersink on outside
button_countersink_depth = 1.0;
button_angles = [30, -30];  // degrees around the board's local perimeter — PWR, BOOT

// --- Split-plane tongue & groove joint ---
split_offset   = 2;    // mm, split plane offset from sphere center along the
                        // board-normal axis (toward the back half)
lip_depth      = 5;    // mm, how far the tongue protrudes / groove is cut
lip_wall       = 1.2;  // mm, tongue ring wall thickness
lip_clearance  = 0.25; // mm, radial fit clearance for the groove
weld_overlap   = 0.6;  // mm two features sink into each other by, so CGAL
                        // unions a real overlap instead of merely tangent
                        // (touching) faces, which isn't reliably manifold

// --- Seam screws (small self-tapping screws driven in near the seam) ---
screw_count     = 4;
screw_pilot_d   = 2.0;  // pilot hole in the boss, mm (M2 self-tapping)
screw_pilot_depth = 6;  // pilot hole depth, drilled down from the top, mm
screw_clear_d   = 2.6;  // clearance hole through the front half, mm
screw_head_d    = 4.5;  // countersink for screw head, mm
screw_head_depth = 1.6;
boss_od         = 5.5;  // boss outer diameter around the pilot hole, mm
boss_len        = 8;     // boss length along the board-normal axis, mm

// --- Rendering ---
high_quality = false;       // true = smooth render, false = fast preview
$fn = high_quality ? 96 : 48;

/* ============================================================
   DERIVED VALUES
   ============================================================ */

sphere_r = sphere_od / 2;
inner_r  = sphere_r - wall;

base_cut_z    = -sphere_r + base_cut_offset;
cavity_floor_z = base_cut_z + base_plate_thick;

outer_cs_r = sqrt(max(sphere_r*sphere_r - split_offset*split_offset, 0));
inner_cs_r = sqrt(max(inner_r*inner_r  - split_offset*split_offset, 0));
lip_mid_r  = (outer_cs_r + inner_cs_r) / 2;

// The seam screw bosses (boss_od) are wider than the shell wall itself, so
// they can't sit centered mid-wall like the tongue ring does — instead
// they hang from the inner wall down into the open interior cavity, with
// their outward face flush just under the outer surface. This keeps them
// from poking through the visible outside of the shell.
screw_r = outer_cs_r - boss_od/2 - 0.3;

BIG = 300;

/* ============================================================
   HELPERS
   ============================================================ */

// Places children in the tilted board-normal frame: local +Z is the
// board's outward (screen-facing) normal, tilted `board_tilt` degrees
// from world +Z toward world +Y.
module board_frame() {
    rotate([-board_tilt, 0, 0]) children();
}

module rounded_rect(w, h, r) {
    hull() {
        for (sx = [-1, 1], sy = [-1, 1])
            translate([sx*(w/2 - r), sy*(h/2 - r)]) circle(r=r);
    }
}

/* ============================================================
   CORE SHELL
   ============================================================ */

module full_shell() {
    difference() {
        intersection() {
            sphere(r=sphere_r);
            translate([0, 0, base_cut_z + BIG/2]) cube(BIG, center=true);
        }
        intersection() {
            sphere(r=inner_r);
            translate([0, 0, cavity_floor_z + BIG/2]) cube(BIG, center=true);
        }
    }
}

/* ============================================================
   MODULE POCKET (board-frame features)
   ============================================================ */

// z-height (board-frame local) where the module's front rim seats — the
// shoulder between the narrow glass-reveal hole and the wider body pocket.
module_seat_z = sphere_r - wall - window_step_depth;

module module_pocket_cut() {
    board_frame() {
        // narrow through-hole from the outer surface down to the seat,
        // revealing the module's glass and hiding its metal bezel
        translate([0, 0, module_seat_z - 1])
            cylinder(h=(sphere_r - module_seat_z) + 1, d=window_d);
        // pocket for the module's full body (rim + depth), recessed
        // inward from the seat — the module drops in from the back and
        // its rim stops against the shoulder here, since the pocket is
        // wider than the glass-reveal hole above
        translate([0, 0, module_seat_z - module_thickness])
            cylinder(h=module_thickness + 1, d=module_pocket_d);
    }
}

module mic_gap_cut() {
    // Two slots just outside the module's edge, mirrored across the local
    // X axis to match the real MIC1/MIC2 corner placement (see
    // mic_angles above) — same placement style as button_holes_cut().
    // TODO verify depth (z0) once the module's own mic port locations
    // along its 15mm thickness are confirmed.
    //
    // Each slot has to actually punch through to the outer surface — at
    // this lateral radius the sphere's surface (a straight run along the
    // board-normal axis, same convention as seam_screw_clearance below)
    // is reached at z_exit, which is *not* just a wall's thickness away
    // once the port sits this far from the local Z axis, so the span is
    // computed explicitly rather than assumed to be a few mm.
    board_frame() {
        z0 = module_seat_z - 3; // approx. depth of the mic port, TODO verify
        z_exit = sqrt(max(sphere_r*sphere_r - module_edge_r*module_edge_r, 0));
        z_start = z0 - 1;
        z_end = z_exit + 1;
        h = z_end - z_start;
        for (a = mic_angles) {
            x = module_edge_r * cos(a);
            y = module_edge_r * sin(a);
            translate([x, y, (z_start + z_end) / 2])
                rotate([0, 0, a])
                    rounded_rect_solid(mic_gap_w, mic_gap_h, mic_gap_corner_r, h);
        }
    }
}

module rounded_rect_solid(w, h, r, extrude_h) {
    translate([0, 0, -extrude_h/2])
        linear_extrude(height=extrude_h) rounded_rect(w, h, r);
}

/* ============================================================
   USB-C SLOT (plain spherical-surface cutout, back of the shell)
   ============================================================ */

module usbc_cut() {
    az = usbc_azimuth;
    z  = base_cut_z + usbc_height_offset;
    // radius of the sphere's surface at this height
    r_at_z = sqrt(max(sphere_r*sphere_r - z*z, 0));
    x = r_at_z * sin(az);
    y = r_at_z * cos(az);
    // outward normal at that point, projected to XY for azimuth alignment
    translate([x, y, z])
        rotate([0, 0, az])
            rotate([90, 0, 0])
                rounded_rect_solid(usbc_w, usbc_h, usbc_r, wall*4);
}

/* ============================================================
   BOOT / PWR BUTTON HOLES (board-frame features)
   ============================================================ */

module button_holes_cut() {
    // Same reasoning as mic_gap_cut() above: at module_edge_r the outer
    // surface isn't just a wall's-thickness away, so the hole's span and
    // the countersink's position are both computed from the real z_exit
    // rather than assumed to sit right next to z0.
    board_frame() {
        z0 = module_seat_z - 3; // approx. depth of the button port, TODO verify
        z_exit = sqrt(max(sphere_r*sphere_r - module_edge_r*module_edge_r, 0));
        z_start = z0 - 1;
        z_end = z_exit + 1;
        h = z_end - z_start;
        for (a = button_angles) {
            x = module_edge_r * cos(a);
            y = module_edge_r * sin(a);
            translate([x, y]) {
                translate([0, 0, (z_start + z_end) / 2])
                    cylinder(h=h, d=button_hole_d, center=true);
                translate([0, 0, z_exit - button_countersink_depth / 2])
                    cylinder(h=button_countersink_depth + 0.01, d=button_countersink_d);
            }
        }
    }
}

/* ============================================================
   SPLIT PLANE + TONGUE / GROOVE JOINT
   ============================================================ */

module front_half_space() {
    board_frame()
        translate([0, 0, split_offset + BIG/2])
            cube(BIG, center=true);
}

module tongue_ring() {
    // starts slightly below the split plane so it truly overlaps (not just
    // touches) the back half's own shell material — CGAL unions of merely
    // tangent faces aren't reliably manifold.
    board_frame()
        translate([0, 0, split_offset - weld_overlap])
            difference() {
                cylinder(h=lip_depth + weld_overlap, r=lip_mid_r + lip_wall/2);
                cylinder(h=lip_depth + weld_overlap + 1, r=lip_mid_r - lip_wall/2);
            }
}

module groove_cut() {
    board_frame()
        translate([0, 0, split_offset - 0.01])
            difference() {
                cylinder(h=lip_depth + lip_clearance + 0.02,
                         r=lip_mid_r + lip_wall/2 + lip_clearance);
                cylinder(h=lip_depth + lip_clearance + 1,
                         r=lip_mid_r - lip_wall/2 - lip_clearance);
            }
}

// boss_od is wider than the shell wall, so a boss can't just sit embedded
// in the wall like the tongue ring does — its own body hangs at `screw_r`
// (inboard of the outer surface, into the open interior) and each one is
// joined back to the tongue ring with a hull() gusset rather than relying
// on it happening to touch the shell wall on its own.
boss_z_lo = split_offset - weld_overlap; // aligned with tongue_ring's own base

module seam_screw_bosses() {
    board_frame()
        for (i = [0 : screw_count - 1]) {
            a = i * 360 / screw_count;
            hull() {
                translate([screw_r * cos(a), screw_r * sin(a), boss_z_lo])
                    cylinder(h=boss_len, d=boss_od);
                // slim marker on the tongue ring's own centerline radius,
                // guaranteed embedded in tongue_ring's solid body so the
                // hull actually fuses to it rather than merely touching it
                translate([lip_mid_r * cos(a), lip_mid_r * sin(a), boss_z_lo])
                    cylinder(h=boss_len, d=lip_wall);
            }
        }
}

module seam_screw_pilots() {
    board_frame()
        for (i = [0 : screw_count - 1]) {
            a = i * 360 / screw_count;
            translate([screw_r * cos(a), screw_r * sin(a),
                       boss_z_lo + boss_len - screw_pilot_depth])
                cylinder(h=screw_pilot_depth + 0.5, d=screw_pilot_d);
        }
}

module seam_screw_clearance() {
    // Each screw is accessed from a small hole on the front dome's outer
    // surface, straight down (along the board-normal axis) into the boss
    // on the back half — z_exit is where that straight line exits the
    // outer sphere, computed directly rather than guessed.
    z_exit = sqrt(max(sphere_r*sphere_r - screw_r*screw_r, 0));
    board_frame()
        for (i = [0 : screw_count - 1]) {
            a = i * 360 / screw_count;
            translate([screw_r * cos(a), screw_r * sin(a), split_offset])
                cylinder(h=z_exit - split_offset + 1, d=screw_clear_d);
            translate([screw_r * cos(a), screw_r * sin(a),
                       z_exit - screw_head_depth])
                cylinder(h=screw_head_depth + 1, d=screw_head_d);
        }
}

/* ============================================================
   ASSEMBLIES
   ============================================================ */

module shell_cut() {
    difference() {
        full_shell();
        module_pocket_cut();
        mic_gap_cut();
        usbc_cut();
        button_holes_cut();
    }
}

module front_half() {
    difference() {
        intersection() { shell_cut(); front_half_space(); }
        groove_cut();
        seam_screw_clearance();
    }
}

module back_half() {
    union() {
        difference() { shell_cut(); front_half_space(); }
        difference() {
            union() { tongue_ring(); seam_screw_bosses(); }
            seam_screw_pilots();
        }
    }
}

module module_mock() {
    // preview-only stand-in for the round display module — not a real
    // part, just here so the assembled render shows it seated correctly
    color("DarkSlateGray") cylinder(h=module_thickness, d=module_od);
}

module preview_assembled() {
    front_half();
    back_half();
    board_frame()
        translate([0, 0, module_seat_z - module_thickness])
            module_mock();
}

/* ============================================================
   RENDER SELECTOR
   Uncomment exactly one line below (or override PART on the CLI with
   `openscad -D PART="\"front\""`).
   ============================================================ */

PART = "assembled"; // "front" | "back" | "assembled"

if (PART == "front") front_half();
else if (PART == "back") back_half();
else preview_assembled();

// Bedside Ball Enclosure — ESP32-S3-Touch-AMOLED-1.75C voice assistant
//
// Freestanding sphere with a flat-cut foot, split into two printable halves:
//   - front half: screen bezel/window opening, mic gap, board mounting standoffs
//   - back half: flat foot, USB-C cutout, most of the interior volume
// The two halves join on a tilted parting plane (perpendicular to the board's
// mounting axis) via a tongue-and-groove lip, secured with small screws driven
// in from just outside the seam.
//
// Print orientation: print each half with its flat parting face down on the
// bed — this keeps the dome curvature self-supporting with no internal
// scaffolding, which was the whole point of splitting the original single
// hollow-sphere design.
//
// Values marked "TODO verify" are best-effort placeholders (no PCB in hand
// yet) — measure the actual board with calipers and adjust before printing
// final parts. Everything else derives from these parameters, so tuning
// them re-shapes the whole model.

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

// --- Board footprint (TODO verify against actual PCB) ---
board_w         = 58;     // board footprint width, mm
board_d         = 58;     // board footprint depth, mm
board_clearance = 1.5;    // extra clearance around board footprint, mm
standoff_d      = 6;      // mounting standoff post diameter, mm
standoff_pilot_d = 2.2;   // pilot hole for M2 self-tapping screw into post
standoff_pilot_depth = 6; // pilot hole depth, drilled down from the top, mm
standoff_weld_overlap = 0.6; // mm the post sinks into the inner shell wall
                              // so it fuses into one solid instead of
                              // floating (union of tangent faces isn't
                              // reliably manifold in CGAL)

// Board mounting hole positions, in the board's own local XY frame,
// origin at board center (TODO verify against actual PCB mounting holes).
board_mount_inset = 6;
board_mount_holes = [
    [ -(board_w/2 - board_mount_inset),  (board_d/2 - board_mount_inset) ],
    [  (board_w/2 - board_mount_inset),  (board_d/2 - board_mount_inset) ],
    [ -(board_w/2 - board_mount_inset), -(board_d/2 - board_mount_inset) ],
    [  (board_w/2 - board_mount_inset), -(board_d/2 - board_mount_inset) ],
];

// How deep inside the shell (along the board's own normal) the board's
// front face sits, measured from the inner shell surface at the pole of
// the board-normal axis. TODO verify once display module thickness and
// standoff stack height are known.
board_face_depth = 10;

// --- Screen window (1.75" round AMOLED, ~44.5mm active diagonal) ---
// TODO verify actual display module glass/bezel diameter against the
// real board — this assumes a common round module size for this class
// of Waveshare board.
display_active_d = 44.6;  // display active area diameter, mm (1.75in)
window_d          = 50;    // through-hole diameter for the clear window
window_step_d     = 54;    // rabbet (step) outer diameter, window sits in this
window_step_depth = 1.6;   // rabbet depth, mm
window_thickness  = 2.0;   // clear PETG/acrylic window disc thickness, mm
window_fit_clearance = 0.3; // radial clearance so the disc drops into the rabbet

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

// --- Seam screws (small self-tapping screws driven in near the seam) ---
screw_count     = 4;
screw_pilot_d   = 2.0;  // pilot hole in the boss, mm (M2 self-tapping)
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
   SCREEN WINDOW OPENING + STANDOFFS (board-frame features)
   ============================================================ */

module screen_window_cut() {
    board_frame() {
        // full through-hole for the display
        translate([0, 0, sphere_r - board_face_depth - 1])
            cylinder(h=board_face_depth + 2, d=window_d);
        // rabbet step the clear window disc sits in, cut from outside in
        translate([0, 0, sphere_r - wall - window_step_depth])
            cylinder(h=wall + window_step_depth + 1, d=window_step_d);
    }
}

module mic_gap_cut() {
    // Two slots near the board's perimeter, mirrored across the local X
    // axis to match the real MIC1/MIC2 corner placement (see
    // mic_angles above) — same placement style as button_holes_cut().
    board_frame() {
        board_r = sqrt(board_w*board_w + board_d*board_d) / 2 + board_clearance;
        z0 = sphere_r - board_face_depth - wall/2;
        for (a = mic_angles) {
            x = board_r * cos(a);
            y = board_r * sin(a);
            translate([x, y, z0])
                rotate([0, 0, a])
                    rounded_rect_solid(mic_gap_w, mic_gap_h, mic_gap_corner_r, wall*3);
        }
    }
}

module rounded_rect_solid(w, h, r, extrude_h) {
    translate([0, 0, -extrude_h/2])
        linear_extrude(height=extrude_h) rounded_rect(w, h, r);
}

module mounting_standoffs() {
    // Posts run from the (curved) inner shell surface directly below each
    // mounting hole up to the board-mounting plane, so their length varies
    // per hole instead of assuming a flat floor underneath them.
    board_mount_z = sphere_r - board_face_depth;
    board_frame() {
        for (p = board_mount_holes) {
            r_xy = sqrt(p[0]*p[0] + p[1]*p[1]);
            z_inner = sqrt(max(inner_r*inner_r - r_xy*r_xy, 0));
            base_z = z_inner - standoff_weld_overlap;
            h = board_mount_z - base_z;
            translate([p[0], p[1], base_z])
                difference() {
                    cylinder(h=h, d=standoff_d);
                    translate([0, 0, h - standoff_pilot_depth])
                        cylinder(h=standoff_pilot_depth + 0.5, d=standoff_pilot_d);
                }
        }
    }
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
    board_frame() {
        board_r = sqrt(board_w*board_w + board_d*board_d) / 2 + board_clearance;
        z0 = sphere_r - board_face_depth - wall/2;
        for (a = button_angles) {
            x = board_r * cos(a);
            y = board_r * sin(a);
            translate([x, y, z0]) {
                cylinder(h=wall*4, d=button_hole_d, center=true);
                translate([0, 0, wall/2 - button_countersink_depth/2])
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
        translate([0, 0, split_offset - standoff_weld_overlap])
            difference() {
                cylinder(h=lip_depth + standoff_weld_overlap, r=lip_mid_r + lip_wall/2);
                cylinder(h=lip_depth + standoff_weld_overlap + 1, r=lip_mid_r - lip_wall/2);
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
boss_z_lo = split_offset - standoff_weld_overlap; // aligned with tongue_ring's own base

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
                       boss_z_lo + boss_len - standoff_pilot_depth])
                cylinder(h=standoff_pilot_depth + 0.5, d=screw_pilot_d);
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
        screen_window_cut();
        mic_gap_cut();
        usbc_cut();
        button_holes_cut();
    }
}

module front_half() {
    difference() {
        union() {
            intersection() { shell_cut(); front_half_space(); }
            mounting_standoffs();
        }
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

module screen_window() {
    // separate part: cut from clear PETG or acrylic sheet, not printed in
    // the diffusion material — sits in the rabbet cut by screen_window_cut()
    cylinder(h=window_thickness, d=window_step_d - window_fit_clearance);
}

module preview_assembled() {
    front_half();
    back_half();
    color("SkyBlue", 0.5) board_frame()
        translate([0, 0, sphere_r - wall - window_step_depth])
            screen_window();
}

/* ============================================================
   RENDER SELECTOR
   Uncomment exactly one line below (or override PART on the CLI with
   `openscad -D PART="\"front\""`).
   ============================================================ */

PART = "assembled"; // "front" | "back" | "window" | "assembled"

if (PART == "front") front_half();
else if (PART == "back") back_half();
else if (PART == "window") screen_window();
else preview_assembled();

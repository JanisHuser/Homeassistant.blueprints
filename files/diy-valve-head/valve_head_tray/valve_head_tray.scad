// DIY battery valve head for floor-heating manifolds (M30x1.5) - tray version
// N20 lock motor standing upright, lead screw on the valve axis, nut + pusher press the pin.
// (The older left/right clamshell version is versions/clamshell/valve_head.scad.)
//
// Layout along the body:  [ drive | logic: ESP, DRV and charger stacked | battery ]
//
// Coordinates:
//   Z = valve axis, Z=0 is the valve's thread face (top of the M30 stub), +Z points at you
//   X = across the body (along the manifold)
//   Y = along the body, the valve sits at Y=0, the battery at the far +Y end
//
// Parts:
// - tray: front face, walls, drive column, ESP seat and battery bay in one part, printed
//   front-face-down, open towards the valve. Everything goes in from the valve side.
// - lid: the back face (against the manifold), printed flat. It slides in from the back end in grooves at the
//   bottom of the side walls; a spring tab at its back end clicks into the back wall. Only a cover: the motor's
//   push goes from the gear plates into the tray's front face, through the walls into the adapter's lugs.
// - adapter: twist-lock (bayonet). Its stem goes up between two "ears" of the tray, 2 lugs turn 40 deg into
//   grooves in the ears. The lid's front edge then slides into a slot in the stem, so the adapter can't turn back.
// - ring nut: threads onto the valve and clamps the adapter's flange.
// - DRV holder, charger holder: small frames the DRV8833 and the TP4056 slide into; they click up into the tray
//   under the ESP. To charge, open the lid and pull the charger holder out on its wires.
// - pusher: holds the screw's nut and presses the pin. Its rectangular tip runs in the adapter's bore, which keeps
//   it from turning and from tilting; the tray needs no guide for it.
// The drive unit (gear plates + motor + screw + pusher) goes in from below as one piece, into a column as wide as
// the gear plates (the widest part). Stops: "open" = nut against the gear plates, "closed" = the pusher's
// chamfered shoulder in the adapter's countersink.
//
// Everything marked MEASURE is a placeholder - replace it with your caliper values.
// Render one part at a time with  openscad -D 'part="tray"' -o tray.stl valve_head_tray.scad

part = "tray"; // assembly | exploded | section | tray | lid | drv_holder | charger_holder | adapter | pusher | nut | print

/* ---------------- valve / manifold (MEASURE) ---------------- */
valve_spacing  = 50;   // MEASURE centre-to-centre distance of the valves
depth_avail    = 45;   // MEASURE free space from thread face to door/wall
thread_len     = 9;    // MEASURE length of the external M30 thread on the valve
pin_top        = 3.0;  // MEASURE pin tip above thread face, not pressed (negative = recessed)
valve_stroke   = 3.5;  // MEASURE how far the pin goes in until it stops

/* ---------------- N20 lock motor with lead screw (MEASURE all on arrival) ---------------- */
// AliExpress 1005007468668750 (Kinmore KM-1020FN20): screw parallel to the motor
gp_len     = 21;   // gear plate stack, long side (along Y, covers screw and motor)
gp_w       = 12;   // gear plate stack, short side (along X)
gp_t       = 6;    // gear plate stack thickness (along Z)
gp_scr     = 4.5;  // screw axis, measured from the plate end on the screw side
mot_offset = 8.5;  // screw axis to motor axis
mot_w      = 12;   // motor can, wide side (along X)
mot_h      = 10;   // motor can, narrow side (along Y)
mot_len    = 18;   // motor can + end cap + terminals below the gear plates
scr_d      = 3;    // lead screw diameter
scr_len    = 19;   // screw length below the gear plates
nut_af     = 6;    // nut across flats (hex)
nut_len    = 7;    // nut length along the screw

/* ---------------- other bought parts ---------------- */
batt_len = 78;   // 18650 holder length
batt_w   = 21;   // 18650 holder width
batt_h   = 21;   // 18650 holder height
// XIAO ESP32-C6 (MEASURE): lies flat under the front face, parts facing it, USB-C end towards the battery
esp_l    = 21;   // along the body (Y)
esp_w    = 17.8; // across the body (X)
esp_pcb  = 1.2;  // PCB thickness
esp_h    = 3.5;  // PCB underside to the top of the shield / USB-C
btn_x    = 6.2;  // BOOT and RESET button centres, sideways from the board's centre (one each side of the USB-C)
btn_y    = 2.2;  // button centres from the USB-C end of the board
// DRV8833 module (MEASURE)
drv_l    = 18.5; // along the body (Y)
drv_w    = 16.5; // across the body (X)
drv_t    = 1.6;  // PCB thickness
drv_parts = 1.5; // tallest thing on the DRV's top: parts, pin stubs
// TP4056 USB-C charger board with protection (MEASURE): lies flat just above the lid, parts up, USB-C end towards
// the motor, in a holder you pull out to charge
tp_w     = 17.5; // board width (X)
tp_len   = 28;   // board length (Y), USB-C end flush with the board edge
tp_t     = 1.6;  // PCB thickness
usb_w    = 9.2;  // USB-C socket width
usb_h    = 3.3;  // USB-C socket height above the PCB
usb_x    = 0;    // USB-C centre, sideways from the board's centre

/* ---------------- design ---------------- */
wall     = 2;
base_t   = 3;      // lid and ears: from the body's bottom face to the inside
lid_t    = 3;      // front face: takes the push from the gear plates
wire_gap = 1.2;    // above the battery: room for its wires
tp_back  = 1.5;    // under the charger board: its solder joints (its holder's floor)
esp_clip = 1;      // ESP: stops and clips cover this much at its corners
hook_t   = 1.0;    // ESP's spring hook at its motor end: thickness (bends ~3 % when it clicks)
hook_w   = 6;      // its width
hook_lip = 0.5;    // how far its catch reaches under the PCB
pin_d    = 1.6;    // pin holes in the front face over the BOOT and RESET buttons
drv_gap  = 3;      // between the DRV's top and the ESP's clips: its parts and the wires
drv_wire = 1.5;    // in front of the DRV and the charger, against the drive column wall: the motor wires go up there
hold_t   = 1.2;    // board holders: floor (DRV) and lips
hold_tab = 0.5;    // their spring tabs' catches, into recesses in the side walls
clr      = 0.25;   // general print clearance
corner_r = 3;

stroke_margin = 0.1;           // stop just before the pin bottoms out
travel      = valve_stroke - stroke_margin;
pin_preload = 0.3;             // pusher presses the pin this much when "open"
pusher_trim = 0;               // fine tune pusher tip length in steps of 0.2

pu_x   = 5;                    // pusher half width (X)
pu_y0  = -5;                   // pusher -Y face
pu_y1  = mot_offset - mot_h / 2 - 0.5;   // pusher +Y face, towards the motor
tip_sh = 1.2;                  // shoulder ledge around the tip (-Y and +/-X), a 45 deg chamfer
tip_shm = 0.6;                 // shoulder ledge on the motor side (+Y): only ~1 mm between screw bore and can
scr_bore = scr_d + 0.6;        // bore for the screw in the pusher
tip_r  = 1.5;                  // tip corner radius
// tip through the adapter: the pusher minus the shoulder all round (narrower on the motor side), so the shoulder
// seats on all four sides; rectangular, so it can't turn in the adapter's bore

nut_od    = 36;
lip_t     = 2.5;
flange_d  = 27.6;  // must pass through the nut's thread (minor dia ~28.4)
flange_h  = 2.5;
neck_d    = 24;
lip_id    = neck_d + 1;
lip_play  = 0.2;   // gap between the nut's lip cone and the adapter's flange cone

// bayonet: 2 lugs on the adapter's stem, under-side a 45 deg cone (prints without supports on both parts;
// it carries the motor's push), turn bay_turn into grooves in the tray's ears
stem_d   = 16;     // adapter stem through the bottom of the tray
bay_r1   = 9.6;    // lugs reach out to here
bay_w    = 30;     // lug width, degrees
bay_turn = 40;     // twist to lock
bay_a    = [-20, 160];   // lug angles before the twist (left/right, clear of the drive column)
bay_top  = 0.3;    // lug top below the inside face of the lid
bay_t    = 0.8;    // flat part of the lug above its cone
ear_up   = 1.0;    // ears stand this far above the lid: cover over the grooves
ear_y1   = 7;      // ears end here (towards the motor); the lid starts behind them
// lid
lid_tg   = 0.9;    // tongue on the lid's long edges, into the wall grooves (flat faces: no wedging)
lid_tg_h = 1.0;    // tongue thickness
lock_w   = 3;      // tongue at the lid's front edge, into the adapter's stem (locks the twist)
lock_d   = 1.5;    // how deep it goes into the stem
tab_w    = 6;      // spring tab at the lid's back end
tab_l    = 10;
tab_t    = 1.2;    // tab thickness (the lid's upper layer): bends ~1.3 % when it clicks
tab_bump = 0.6;    // its catch, into a notch in the back wall

$fn = 64;

/* ---------------- derived ---------------- */
lip_ch    = (flange_d + 0.8 - lip_id) / 2;     // 45 deg cone under the nut's lip (prints either way up)
z_body0   = flange_h + lip_t + 0.5;            // body sits just above the nut
z_floor   = z_body0 + base_t;                  // inside face of the lid
z_mot0    = z_floor;                           // motor can stands on the lid (and the adapter's stem)
z_gp0     = z_mot0 + mot_len;                  // gear plates, bottom face
z_gp1     = z_gp0 + gp_t;
z_top     = z_gp1 + 0.2;                       // inside face of the front face
depth_total = z_top + lid_t;

z_scr_tip = z_gp0 - scr_len;
z_nut1    = z_gp0 - 0.5;                       // nut top, open
z_nut0    = z_nut1 - nut_len;                  // nut bottom, open
z_shoulder = z_floor + travel;                 // pusher shoulder, open (in the adapter's countersink when closed)
z_tip     = pin_top - pin_preload - pusher_trim;  // pusher tip, open

body_w    = batt_w + 2 * wall + 1;
in_half   = body_w / 2 - wall;
gp_y0     = -gp_scr;                           // gear plates, Y range
gp_y1     = gp_y0 + gp_len;
// drive column: the gear plates are the widest part, so everything goes up through their footprint
col_x     = gp_w / 2 + clr;
col_y0    = min(gp_y0, pu_y0) - clr;
col_y1    = max(gp_y1, mot_offset + mot_h / 2) + clr;
tw_x      = col_x + 1.35;                      // walls around the column
tw_y0     = col_y0 - 1.6;
tw_y1     = col_y1 + 1.35;
ear_x     = col_x + 0.15;                      // ears start here (outside the column)
y_min     = tw_y0 - wall;
y_logic0  = tw_y1 + 1;

// bayonet heights: lug top just under the lid's inside face, flat part, then the 45 deg cone down to the stem
bay_r0    = stem_d / 2;
bay_z1    = z_floor - bay_top;                 // lug top
bay_z0    = bay_z1 - bay_t;                    // where the cone meets the flat part (at bay_r1)
bay_zc    = bay_z0 - (bay_r1 - bay_r0);        // cone bottom (at the stem)

// logic bay: the ESP lies flat under the front face, parts up (its buttons under pin holes in the front face);
// the DRV and under it the charger lie flat too, parts up, each in a holder that clicks into the side walls. The
// tray itself can't hold them there: the ESP goes in from below, and anything holding them would be in its way.
// along Y: [hook | ESP ... USB-C end | clips]; the holders' open ends against the drive column wall
y_hook0   = y_logic0;                          // ESP's spring hook: bends back into the gap to the drive column wall
y_esp0    = y_hook0 + hook_t + clr;            // ESP motor end
y_esp1    = y_esp0 + esp_l;                    // ESP USB-C end
z_esp1    = z_top - clr - (esp_h - esp_pcb);   // ESP PCB top face (its parts up to just under the front face)
z_esp0    = z_esp1 - esp_pcb;                  // ESP PCB underside
z_esp_clip = z_esp0 - 1.4;                     // bottom of the ESP's stops and clips: the clips' lip is 1 mm thick
y_drv0    = tw_y1 + drv_wire;                  // DRV motor end = the holder's open end
y_hold1   = y_drv0 + drv_l + clr + hold_t;     // the holder's closed end
z_drv1    = z_esp_clip - drv_gap;              // DRV PCB top face
z_drv0    = z_drv1 - drv_t;
z_hold0   = z_drv0 - hold_t;                   // DRV holder, bottom
y_tp0     = tw_y1 + drv_wire;                  // charger's USB-C end = its holder's open end
z_thold0  = z_floor + clr;                     // charger holder, bottom: on the lid
z_tp0     = z_thold0 + tp_back;                // charger PCB underside
y_thold1  = y_tp0 + tp_len + clr + hold_t;     // charger holder's closed end
logic_len = max(y_esp1 + clr + 1.2, y_hold1, y_thold1) - y_logic0;
y_batt0   = y_logic0 + logic_len + 0.5;
y_max     = y_batt0 + batt_len + (corner_r - 1) + wall;   // room for the inside corners' radius at the back wall
body_len  = y_max - y_min;

echo(str("total depth from thread face: ", depth_total, " mm (available ", depth_avail, ")"));
echo(str("body: ", body_w, " x ", body_len, " mm (X x Y)"));
echo(str("pusher: tip ", z_tip, " .. top ", z_nut1, ", travel ", travel, " mm"));
assert(depth_total <= depth_avail, "head is deeper than the available space");
assert(body_w <= valve_spacing - 2, "head is wider than the valve spacing");
assert(tw_x <= in_half + 0.01, "gear plates wider than the body");
assert(z_scr_tip < z_nut0 - travel, "screw too short: the nut would run off its end when closed");
assert(z_scr_tip > z_tip + 2, "screw too long: it would hit the bottom of the pusher");
assert(z_scr_tip - 1 > z_tip + 1.2, "screw too long: the pusher tip end gets too thin");
assert(pu_y1 - tip_shm - scr_bore / 2 >= 0.59, "tip wall towards the motor too thin around the screw bore");
assert(scr_bore >= scr_d + 0.4, "screw bore too tight");
assert(lip_ch <= lip_t - 0.6, "lip too thin for its 45 deg cone: raise lip_t or lip_id");
assert(nut_af / 2 <= pu_y1 + 0.01, "nut sticks out of the pusher towards the motor");
assert(pu_x <= col_x && pu_y0 >= col_y0, "pusher wider than the drive column");
assert(z_tip < z_body0 - 1, "pusher tip does not reach the pin - pin is too far down");
assert(stem_d / 2 - norm([pu_x, pu_y0]) >= 0.4, "adapter stem too thin around the pusher's countersink");
assert(bay_zc >= z_body0 + 0.29, "bayonet cone runs out of the bottom of the tray: raise base_t");
assert(bay_r0 * cos(max(abs(bay_a[0]), abs(bay_a[0] + bay_turn)) + bay_w / 2) >= ear_x - 0.6,
       "bayonet lugs reach into the drive column");
assert(z_top >= z_floor + batt_h + wire_gap, "no room for the battery and its wires under the front face");
assert(esp_w + 2 * clr + 2.4 <= 2 * in_half, "ESP too wide for the inside: no room for its side guides");
assert(in_half - clr - 1.4 - (drv_w / 2 + clr) >= 0.3, "DRV too wide for its holder's spring tabs");
assert(in_half - clr - 1.4 - (tp_w / 2 + clr) >= 0.3, "charger too wide for its holder's spring tabs");
assert(z_tp0 + tp_t + usb_h + 1 <= z_hold0, "no room between the charger's USB-C and the DRV holder");
assert(drv_parts + 1 <= drv_gap, "no room over the DRV's parts for the wires");
assert(btn_x + pin_d / 2 + 0.5 <= esp_w / 2 - esp_clip, "BOOT/RESET pin holes run into the ESP's corner clips");
assert(lock_d + 0.6 <= stem_d / 2 - (pu_y1 - tip_shm + clr), "adapter stem too thin for the lid's lock tongue");

/* ---------------- helpers ---------------- */
module rounded_box(size, r) {
    // size = [x, y, z], centred in x/y, starting at z=0
    hull() for (sx = [-1, 1], sy = [-1, 1])
        translate([sx * (size[0]/2 - r), sy * (size[1]/2 - r), 0])
            cylinder(r = r, h = size[2]);
}

// right-hand internal thread cutter (sinusoidal profile, prints fine at 0.12-0.16 mm layers)
module int_thread_cut(d, pitch, len, c) {
    e = pitch * 0.36;
    linear_extrude(height = len, twist = -360 * len / pitch,
                   slices = ceil(len / pitch * 24), convexity = 4)
        translate([e, 0]) circle(r = d / 2 - e + c, $fn = 72);
}

module tip_shape(c = 0, g = 0) {
    // 2D tip section; c = clearance all round, g = grow the shoulder (g = tip_sh gives the full pusher;
    // the motor side grows in proportion to its smaller ledge)
    x = pu_x - tip_sh + g + c;
    y0 = pu_y0 + tip_sh - g - c;
    y1 = pu_y1 - tip_shm + g * tip_shm / tip_sh + c;
    translate([-x, y0]) offset(r = tip_r) offset(delta = -tip_r) square([2 * x, y1 - y0]);
}

module tip_with_chamfer(z_sh, h_below, c = 0, h_above = 0.01) {
    // tip below z_sh, 45 deg chamfer up to the full pusher section at z_sh
    translate([0, 0, z_sh - h_below]) linear_extrude(h_below - tip_sh + 0.01) tip_shape(c);
    hull() {
        translate([0, 0, z_sh - tip_sh]) linear_extrude(0.01) tip_shape(c);
        translate([0, 0, z_sh - 0.01]) linear_extrude(h_above) tip_shape(c, tip_sh);
    }
}

module hex(af, h) {
    // flats facing +/-Y
    rotate(30) cylinder(d = af / cos(30), h = h, $fn = 6);
}

module outer_solid(i = 0) {
    // outside of the housing, inset by i: one height over the whole length
    translate([0, (y_min + y_max) / 2, z_body0 + i]) rounded_box([body_w - 2 * i, body_len - 2 * i, depth_total - z_body0 - 2 * i], corner_r);
}

/* ---------------- bayonet ---------------- */
module lug_profile(c = 0) {
    // (r, z) section of a lug: 45 deg cone underneath (carries the push), flat part, flat top
    offset(delta = c) polygon([[bay_r0 - 1, bay_zc], [bay_r0, bay_zc], [bay_r1, bay_z0], [bay_r1, bay_z1], [bay_r0 - 1, bay_z1]]);
}

module bay_lug(a, c = 0, sweep = 0) {
    // the groove (sweep > 0) starts 0.5 deg before the notch, so the two cuts overlap instead of sharing a face
    o = sweep > 0 ? 0.5 : 0;
    rotate(a - bay_w / 2 - c * 8 - o) rotate_extrude(angle = bay_w + sweep + c * 16 + o) lug_profile(c);
}

/* ---------------- parts ---------------- */
module nut() {
    difference() {
        translate([0, 0, -thread_len]) cylinder(d = nut_od, h = thread_len + flange_h + lip_t, $fn = 96);
        translate([0, 0, -thread_len - 0.01]) int_thread_cut(30, 1.5, thread_len + 0.02, clr);
        // room for the flange
        translate([0, 0, -0.01]) cylinder(d = flange_d + 0.8, h = flange_h + 0.02);
        // lip underside: 45 deg cone, no flat overhang
        translate([0, 0, flange_h]) cylinder(d1 = flange_d + 0.8, d2 = lip_id, h = lip_ch);
        cylinder(d = lip_id, h = 50);
        // grip
        for (a = [0 : 30 : 359]) rotate(a)
            translate([nut_od / 2 + 0.6, 0, -thread_len - 1]) cylinder(d = 3, h = 30, $fn = 16);
    }
}

module adapter(turn = bay_turn) {
    // in place; turn = 0 is the angle it goes in at, bay_turn is locked
    rotate(turn) difference() {
        union() {
            // flange with a 45 deg cone on top that seats in the nut's lip cone
            cylinder(d = flange_d, h = flange_h + 0.4 - lip_play);
            translate([0, 0, flange_h + 0.4 - lip_play]) cylinder(d1 = flange_d, d2 = neck_d, h = (flange_d - neck_d) / 2);
            cylinder(d = neck_d, h = z_body0);
            // stem up to the lid's inside face, lugs on it
            cylinder(d = stem_d, h = z_floor);
            for (a = bay_a) bay_lug(a);
        }
        // the slot the lid's lock tongue goes into: towards +Y once the adapter is locked
        rotate(-bay_turn) translate([-lock_w / 2 - clr, stem_d / 2 - lock_d - clr, z_body0 - 0.01]) cube([lock_w + 2 * clr, lock_d + 1, base_t + 1]);
    }
    // the pusher's bore and countersink do not turn with the adapter: the tip is rectangular
    // (so the bore is cut after the turn: it must line up with the pusher when locked)
}

module adapter_bored(turn = bay_turn) {
    difference() {
        adapter(turn);
        rotate(turn - bay_turn) {
            translate([0, 0, -1]) linear_extrude(50) tip_shape(clr);
            // countersink for the pusher's chamfer = the "closed" stop, so it pushes straight on the valve;
            // raised by clr so the clearance doesn't let the pusher sink deeper on the 45 deg seat
            tip_with_chamfer(z_floor + clr, tip_sh + 0.1, clr, 50);
        }
    }
}

module pusher(s = 0) {
    // in place; s = travel (0 = open)
    translate([0, 0, -s]) difference() {
        union() {
            // body, with the same rounded corners as the adapter's seat, so it seats on its shoulder
            translate([0, 0, z_shoulder]) linear_extrude(z_nut1 - z_shoulder) tip_shape(0, tip_sh);
            // stout tip through the adapter onto the pin, 45 deg chamfer up to the shoulder
            tip_with_chamfer(z_shoulder, z_shoulder - z_tip);
        }
        // hex pocket for the nut, open at the top and towards the motor
        translate([0, 0, z_nut0 - clr]) hex(nut_af + 2 * clr, nut_len + 2 * clr + 1);
        // lead-in so the nut finds the pocket when you push the pusher up the screw
        hull() {
            translate([0, 0, z_nut1 - 0.8]) hex(nut_af + 2 * clr, 0.01);
            translate([0, 0, z_nut1]) hex(nut_af + 2 * clr + 1.6, 0.01);
        }
        translate([-(nut_af / cos(30)) / 2 - clr, 0, z_nut0 - clr]) cube([nut_af / cos(30) + 2 * clr, 10, nut_len + 2 * clr + 1]);
        // bore for the screw below the nut
        translate([0, 0, z_scr_tip - 1]) cylinder(d = scr_bore, h = 50, $fn = 24);
    }
}

module lid_2d(c = 0) {
    // the lid's outline: full width behind the ears, round cut-out for the adapter's stem
    difference() {
        translate([-in_half - c, ear_y1 + clr - c]) square([2 * (in_half + c), y_max - ear_y1 + 1]);
        circle(r = bay_r0 + clr - c);
    }
}

module lid_solid(c = 0) {
    translate([0, 0, z_body0 - 1]) linear_extrude(z_floor - z_body0 + 1 + c) lid_2d(c);
    // tongues on the long edges, into the wall grooves
    for (sx = [-1, 1]) translate([sx > 0 ? in_half - 0.01 : -in_half - lid_tg - c, ear_y1 + clr - c, z_body0 + (base_t - lid_tg_h) / 2 - c])
        cube([lid_tg + c + 0.01, y_max - ear_y1 + 1, lid_tg_h + 2 * c]);
}

module lid() {
    difference() {
        union() {
            intersection() {
                lid_solid();
                outer_solid();
            }
            // lock tongue at the front edge, into the slot in the adapter's stem
            translate([-lock_w / 2, bay_r0 - lock_d, z_body0]) cube([lock_w, lock_d + clr + 1, base_t]);
        }
        // spring tab at the back end: the lid's upper layer, cut free on three sides, thin from below
        for (sx = [-1, 1]) translate([sx * (tab_w / 2 + 0.4) - 0.4, y_max - tab_l, z_body0 - 1]) cube([0.8, tab_l + 1, base_t + 2]);
        translate([-tab_w / 2 - 0.4, y_max - tab_l, z_body0 - 1]) cube([tab_w + 0.8, tab_l + 1, base_t - tab_t + 1]);
    }
    // the tab's catch: square towards the back (holds the lid), ramp towards the front (slides in)
    translate([0, y_max - wall + 0.3, z_floor - 0.01]) rotate([90, 0, 90]) linear_extrude(tab_w - 1, center = true)
        polygon([[0, 0], [1.2, 0], [1.2, tab_bump], [0.6, tab_bump]]);
}

module esp_seat() {
    // the ESP lies flat under the front face, parts up. It goes up from below USB-C end first, under the clips at
    // its two USB-side corners, then its motor end clicks past the spring hook (esp_hook). Stops over its four
    // corners (the corner pads stay unused), end stops and side guides beside its long edges.
    x1 = esp_w / 2;
    za = z_esp_clip;
    difference() {
        for (sx = [-1, 1]) mirror([sx < 0 ? 1 : 0, 0, 0]) {
            // motor end: end stop, corner stop, side guide
            translate([x1 - esp_clip, y_hook0, za]) cube([in_half - x1 + esp_clip + 0.01, y_esp0 + 3 - y_hook0, z_top - za + 0.01]);
            // USB-C end: corner clip, side guide
            translate([x1 - esp_clip, y_esp1 - 3, za]) cube([in_half - x1 + esp_clip + 0.01, 3 + clr + 1.2, z_top - za + 0.01]);
        }
        // the PCB: open from below up to its top face, except under the clips
        translate([-x1 - clr, y_esp0 - clr, za - 1]) cube([esp_w + 2 * clr, esp_l - esp_clip + clr, z_esp1 - za + 1]);
        // the clips' slot
        translate([-x1 - clr, y_esp1 - esp_clip - 0.01, z_esp0 - clr]) cube([esp_w + 2 * clr, esp_clip + clr + 0.01, z_esp1 - z_esp0 + clr]);
    }
}

module esp_hook() {
    // spring hook at the ESP's motor end, hanging from a 1 mm skin of the front face (a pocket around it makes it
    // longer); its catch ramps out of the way as the board goes up, then holds it from below
    yp = y_esp0 - clr;                         // hook face towards the ESP
    yl = y_esp0 + hook_lip;                    // tip of the catch, under the PCB
    zc = z_esp0 - 0.1;                         // top of the catch
    zb = zc - 0.6 - (yl - yp);                 // bottom of its 45 deg ramp
    rotate([90, 0, 90]) linear_extrude(hook_w, center = true)
        polygon([[y_hook0, depth_total - 1 + 0.01], [y_hook0, zb], [yp, zb], [yl, zc - 0.6], [yl, zc], [yp, zc], [yp, depth_total - 1 + 0.01]]);
}

module board_holder(bw, bl, bt, y0, zb, ft, corner_lips) {
    // a board lying flat, parts up, in a frame: bw across, bl along the body, PCB thickness bt, open end at y0 (towards
    // the motor), bottom at zb, floor ft under the PCB. Slide the board in from the open end (in your hand), then push
    // the holder up into the tray, open end towards the motor, until its spring tabs click into the side walls; the
    // drive column wall then closes the open end. Lips over the board's top corners (corner_lips) or along its long
    // edges, a 1 mm ledge under its edges.
    x1 = bw / 2;
    hx = in_half - clr;                        // holder half width
    z0 = zb + ft; z1 = z0 + bt;                // PCB underside, top face
    zt = z1 + clr + hold_t;                    // holder top
    yt = holder_tab_y(y0, bl);
    difference() {
        union() {
            translate([-hx, y0, zb]) cube([2 * hx, bl + clr + hold_t, zt - zb]);
            // the catches at the tabs' free ends: 45 deg both ways, so they click in and pull out again
            for (sx = [-1, 1]) mirror([sx < 0 ? 1 : 0, 0, 0]) translate([hx - 0.01, yt + 6, (zb + zt) / 2]) rotate([-90, 0, 0]) linear_extrude(3)
                polygon([[0, -1.2], [hold_tab + clr + 0.01, -1.2 + hold_tab + clr], [hold_tab + clr + 0.01, 1.2 - hold_tab - clr], [0, 1.2]]);
        }
        // the PCB, open at the motor end
        translate([-x1 - clr, y0 - 1, z0]) cube([bw + 2 * clr, bl + clr + 1, bt + clr]);
        // room for its parts, and the lips cut back to its corners or its long edges
        translate([-x1 + 1, y0 - 1, z1]) cube([bw - 2, bl + clr + 1, hold_t + clr + 1]);
        if (corner_lips) translate([-x1 - clr, y0 + 3, z1]) cube([bw + 2 * clr, bl - 6, hold_t + clr + 1]);
        else for (ya = [y0 - 1, y0 + bl - 3]) translate([-x1 - clr, ya, z1]) cube([bw + 2 * clr, 4 + clr, hold_t + clr + 1]);
        // window in the floor for its solder joints
        translate([-x1 + 1, y0 + 1, zb - 1]) cube([bw - 2, bl - 2, ft + 1.01]);
        // spring tabs: the outer 0.8 mm of each side, cut free behind and at the end
        for (sx = [-1, 1]) mirror([sx < 0 ? 1 : 0, 0, 0]) {
            translate([hx - 1.4, yt, zb - 1]) cube([0.6, 10.6, zt - zb + 2]);
            translate([hx - 1.4, yt + 10, zb - 1]) cube([2.4, 0.6, zt - zb + 2]);
        }
    }
}

function holder_tab_y(y0, bl) = y0 + bl / 2 - 5;   // spring tabs' root; 10 long, catch at the free end

module holder_recesses(bl, bt, y0, zb, ft) {
    // recesses in the side walls for a holder's catches
    zt = zb + ft + bt + clr + hold_t;
    for (sx = [-1, 1]) mirror([sx < 0 ? 1 : 0, 0, 0])
        translate([in_half - 0.01, holder_tab_y(y0, bl) + 6 - clr, (zb + zt) / 2 - 1.2 - clr]) cube([hold_tab + 2 * clr + 0.01, 3 + 2 * clr, 2.4 + 2 * clr]);
}

// the DRV: under the ESP; corner lips, its corner pads stay free
module drv_holder() board_holder(drv_w, drv_l, drv_t, y_drv0, z_hold0, hold_t, true);
// the charger: on the lid, under the DRV; lips along its long edges, its wire pads are at its corners
module charger_holder() board_holder(tp_w, tp_len, tp_t, y_tp0, z_thold0, tp_back, false);

module tray() {
    esp_hook();
    difference() {
        union() {
            difference() {
                outer_solid();
                // inside, open towards the valve
                translate([0, (y_min + y_max) / 2, z_body0 - 1]) rounded_box([body_w - 2 * wall, body_len - 2 * wall, z_top - z_body0 + 1], corner_r - 1);
            }
            // walls around the drive column, from the ears up to the front face
            // (starts inside the end wall, so it overlaps it instead of meeting it on one face)
            translate([-tw_x, tw_y0 - 0.5, z_body0]) cube([2 * tw_x, tw_y1 - tw_y0 + 0.5, z_top - z_body0 + 0.01]);
            // ears left and right of the adapter: carry the bayonet, a little taller than the lid
            for (sx = [-1, 1]) translate([sx > 0 ? ear_x : -in_half - 0.01, y_min + wall - 0.01, z_body0])
                cube([in_half - ear_x + 0.01, ear_y1 - y_min - wall + 0.01, base_t + ear_up]);
            esp_seat();
        }
        // drive column: the drive unit goes up into it from below (the gear plates are the widest part)
        translate([-col_x, col_y0, z_body0 - 1]) cube([2 * col_x, col_y1 - col_y0, z_top - z_body0 + 1]);
        // motor wires to the boards
        translate([-2, col_y1 - 1, z_mot0]) cube([4, tw_y1 - col_y1 + 2, 4]);
        // the lid and its grooves, open at the back end
        lid_solid(clr);
        translate([-body_w, y_max - wall - 1, z_body0 - 1]) cube([2 * body_w, wall + 2, base_t + 1 + clr]);
        // the lid tab's catch: notch in the back wall's underside
        translate([-tab_w / 2, y_max - wall + 0.1, z_floor - 0.01]) cube([tab_w, 1.4, tab_bump + 0.2]);
        // pin holes over the ESP's BOOT and RESET buttons, countersunk outside so the pin finds them
        for (sx = [-1, 1]) translate([sx * btn_x, y_esp1 - btn_y, z_top - 0.01]) {
            cylinder(d = pin_d, h = depth_total - z_top + 1, $fn = 24);
            translate([0, 0, depth_total - z_top - 0.79]) cylinder(d1 = pin_d, d2 = pin_d + 1.6, h = 0.81, $fn = 24);
        }
        // recesses in the side walls for the holders' catches
        holder_recesses(drv_l, drv_t, y_drv0, z_hold0, hold_t);
        holder_recesses(tp_len, tp_t, y_tp0, z_thold0, tp_back);
        // pocket in the front face around the ESP's spring hook, down to a 1 mm skin
        translate([-hook_w / 2 - 0.4, y_hook0 - 0.9, z_top - 0.01]) cube([hook_w + 0.8, hook_t + 1.3, depth_total - 1 - z_top + 0.01]);
        // bayonet: stem hole, lug notches from below, grooves the lugs turn into
        translate([0, 0, z_body0 - 1]) cylinder(d = stem_d + 2 * clr, h = base_t + 1 + clr);
        for (a = bay_a) {
            translate([0, 0, z_body0 - 1]) linear_extrude(bay_z1 + clr - z_body0 + 1) projection() bay_lug(a, clr);
            bay_lug(a, clr, bay_turn);
        }
    }
}

/* ---------------- placeholders for bought parts ---------------- */
module motor(s = 0) {
    color("goldenrod") translate([-gp_w / 2, gp_y0, z_gp0]) cube([gp_w, gp_len, gp_t]);
    color("silver") translate([-mot_w / 2, mot_offset - mot_h / 2, z_gp0 - mot_len]) cube([mot_w, mot_h, mot_len]);
    color("gray") translate([0, 0, z_scr_tip]) cylinder(d = scr_d, h = scr_len, $fn = 16);
    color("red") translate([0, 0, z_nut0 - s]) hex(nut_af, nut_len);
}

module ghost_parts(s = 0) {
    motor(s);
    color("royalblue", 0.2) translate([-batt_w / 2, y_batt0, z_floor]) cube([batt_w, batt_len, batt_h]);
    color("darkgreen") translate([-esp_w / 2, y_esp0, z_esp0]) cube([esp_w, esp_l, esp_h]);                         // XIAO ESP32-C6
    for (sx = [-1, 1]) color("black") translate([sx * btn_x, y_esp1 - btn_y, z_esp1]) cylinder(d = 1.5, h = 1, $fn = 16);  // its buttons
    color("purple") translate([-drv_w / 2, y_drv0, z_drv0]) cube([drv_w, drv_l, drv_t + drv_parts]);                    // DRV8833
    color("teal") translate([-tp_w / 2, y_tp0, z_tp0]) cube([tp_w, tp_len, tp_t]);                                   // TP4056
    color("silver") translate([usb_x - usb_w / 2, y_tp0, z_tp0 + tp_t]) cube([usb_w, 7.5, usb_h]);                   // its USB-C
    // valve: threaded stub up to its thread face (z = 0), pin above it
    color("lightblue", 0.3) translate([0, 0, -thread_len]) cylinder(d = 30, h = thread_len);
    color("lightblue", 0.6) cylinder(d = 3, h = pin_top - s - pin_preload - 0.01, $fn = 16);
}

/* ---------------- output ---------------- */
show_travel = 0; // set to travel to see the closed position

// assembly: up=-z explode=-z   (site assembly guide: built upside down, everything goes in from the valve side)
if (part == "assembly") {
    color("white") tray();
    color("lightsteelblue") lid();
    color("khaki") drv_holder();
    color("tan") charger_holder();
    color("orange") adapter_bored();
    color("darkorange") nut();
    color("violet") pusher(show_travel);
    ghost_parts(show_travel);
} else if (part == "exploded") {
    // as you assemble it: tray front face down, parts go in from above, lid slides on, adapter twists in
    rotate([0, 180, 0]) {
        color("white") tray();
        color("lightsteelblue") translate([0, 70, -10]) lid();
        color("khaki") translate([0, 0, -30]) drv_holder();
        color("tan") translate([0, 0, -30]) charger_holder();
        translate([0, 0, -34]) { color("violet") pusher(); motor(); }
        color("orange") translate([0, 0, -62]) adapter_bored(0);
        color("darkorange") translate([0, 0, -82]) nut();
    }
} else if (part == "section") {
    // cut along the body through the valve axis (keeps x > 0)
    intersection() {
        union() {
            color("white") tray(); color("lightsteelblue") lid(); color("khaki") drv_holder(); color("tan") charger_holder();
            color("orange") adapter_bored(); color("darkorange") nut(); color("violet") pusher(show_travel);
        }
        translate([0, -100, -50]) cube([100, 300, 150]);
    }
    ghost_parts(show_travel);
} else if (part == "tray") {
    // print front face down
    translate([0, 0, depth_total]) mirror([0, 0, 1]) tray();
} else if (part == "lid") {
    // print bottom face down
    translate([0, 0, -z_body0]) lid();
} else if (part == "drv_holder") {
    // print floor down
    translate([0, -y_drv0, -z_hold0]) drv_holder();
} else if (part == "charger_holder") {
    // print floor down
    translate([0, -y_tp0, -z_thold0]) charger_holder();
} else if (part == "adapter") {
    // print flange down
    adapter_bored(0);
} else if (part == "pusher") {
    // print standing on the tip
    translate([0, 0, -z_tip]) pusher();
} else if (part == "nut") {
    translate([0, 0, flange_h + lip_t]) rotate([180, 0, 0]) nut();
} else if (part == "print") {
    translate([0, 0, depth_total]) mirror([0, 0, 1]) tray();
    translate([35, 0, -z_body0]) lid();
    translate([-40, 15, 0]) adapter_bored(0);
    translate([-40, 50, -z_tip]) pusher();
    translate([-40, 90, flange_h + lip_t]) rotate([180, 0, 0]) nut();
    translate([-40, 120 - y_drv0, -z_hold0]) drv_holder();
    translate([-40, 150 - y_tp0, -z_thold0]) charger_holder();
}

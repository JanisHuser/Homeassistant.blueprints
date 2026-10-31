// DIY battery valve head for floor-heating manifolds (M30x1.5)
// N20 lock motor standing upright, lead screw on the valve axis, nut + pusher press the pin.
//
// Layout along the body:  [ pusher | logic | battery ]
//
// Coordinates:
//   Z = valve axis, Z=0 is the valve's thread face (top of the M30 stub), +Z points at you
//   X = across the body (along the manifold)
//   Y = along the body, the valve sits at Y=0, the battery at the far +Y end
//
// The motor hangs from its gear plates beside the screw. The screw points down at the pin.
// The nut sits in the pusher; the pusher slides in a U-shaped guide so it can't turn.
// Stops: "open" = nut against the gear plates, "closed" = pusher's chamfered shoulder in the floor countersink.
//
// Everything marked MEASURE is a placeholder - replace it with your caliper values.
// Render one part at a time with  openscad -D 'part="left"' -o left.stl valve_head.scad
//
// The housing is a clamshell split lengthwise (at X=0) with a tongue-and-groove lip on the seam.
// Both halves carry the ceiling over the whole length. The ESP and the DRV8833 stand across the body,
// parts facing the motor, each in a slot (back fin + corner clips) that the two halves close around.

part = "right"; // assembly | section | left | right | nut | adapter | pusher | print

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
batt_len = 78;   // MEASURE 18650 holder length
batt_w   = 21;   // MEASURE 18650 holder width
batt_h   = 20;   // MEASURE 18650 holder height (a printed cradle instead of the holder saves ~1.5 mm)
// boards lie flat on the right half's side wall, side by side along the body, parts facing the seam
// XIAO ESP32-C6 (MEASURE): USB-C towards the drive (stays inside: flashing only, housing open)
esp_l    = 21;   // across the body (X)
esp_w    = 17.8; // up (Z)
esp_pcb  = 1.2;  // PCB thickness
esp_h    = 3.5;  // PCB underside to the top of the shield / USB-C
// DRV8833 module (MEASURE)
drv_l    = 18.5; // across the body (X)
drv_w    = 16.5; // up (Z)
drv_t    = 1.6;  // PCB thickness
drv_parts = 1.5; // tallest thing on the DRV's front: parts, pin stubs
// TP4056 USB-C charger board with protection (MEASURE): stands across the body behind the battery,
// parts facing the motor, USB-C end up: the charging port is in the front face
tp_w     = 17.5; // board width (X)
tp_len   = 28;   // board length (Z), USB-C end flush with the board edge
tp_t     = 1.6;  // PCB thickness
tp_skin  = 0.6;  // floor left under the board's lower edge
usb_w    = 9.2;  // USB-C socket width
usb_h    = 3.3;  // USB-C socket height above the PCB
usb_x    = 0;    // USB-C centre, sideways from the board's centre

/* ---------------- design ---------------- */
wall     = 2;
floor_t  = 2;
mot_back = 1.2;    // wall behind the motor can (towards the logic bay)
gp_ledge = 1.2;    // ledge under the gear plates' far end, above the hollow behind the can
wire_gap = 1.2;    // above the battery: room for the wires to the far end
tp_back  = 1.5;    // behind the charger board: its solder joints
brd_fin  = 1.2;    // fin behind each board, holds its edges
brd_clip = 1;      // clips at the board's front corners: thickness and overlap
esp_back = 2.5;    // room behind the ESP for the wires on its back pads
drv_back = 3;      // room behind the DRV for solder joints and wires
seam_lip = 1.5;    // tongue on the right half's seam, into a groove in the left half
lid_t    = 3;      // ceiling, thicker: takes the push reaction from the gear plates
clr      = 0.25;   // general print clearance
corner_r = 3;

stroke_margin = 0.1;           // stop just before the pin bottoms out
travel      = valve_stroke - stroke_margin;
pin_preload = 0.3;             // pusher presses the pin this much when "open"
pusher_trim = 0;               // fine tune pusher tip length in steps of 0.2

pu_x   = 5;                    // pusher half width (X)
pu_y0  = -5;                   // pusher -Y face
pu_y1  = mot_offset - mot_h / 2 - 0.5;   // pusher +Y face, flat towards the motor
tip_sh = 1.2;                  // shoulder ledge around the tip (-Y and +/-X), a 45 deg chamfer
tip_shm = 0.6;                 // shoulder ledge on the motor side (+Y): only ~1 mm between screw bore and can
scr_bore = scr_d + 0.6;        // bore for the screw in the pusher
// the pusher's motor side has no wall (the can is 0.5 mm away), so rails on the guide's side walls
// run in grooves in the pusher's sides: it can't tilt towards the motor
rail_y0 = -4;                  // groove in the pusher, -Y edge
rail_w  = 1.6;                 // groove width (along Y)
rail_d  = 1;                   // groove depth (X)
tip_r  = 1.5;                  // tip corner radius
// tip through floor and adapter: the pusher minus the shoulder all round (narrower on the motor side),
// so the shoulder seats on all four sides; off-centre, so it only goes in one way round

nut_od    = 36;
lip_t     = 2.5;
flange_d  = 27.6;  // must pass through the nut's thread (minor dia ~28.4)
flange_h  = 2.5;
neck_d    = 24;
lip_id    = neck_d + 1;
lip_play  = 0.2;   // gap between the nut's lip cone and the adapter's flange cone

// adapter lock: a short stem through the floor and a plate on it, sunk into the floor and trapped between
// the two halves. The plate overhangs the stem on all four sides (a T), so the adapter can't rock:
// towards the valve end it reaches into the base of the end wall, towards the motor it runs under the can.
ap_stem_d = 16;
ap_s0     = -6.25; // stem flat towards the valve end (room for the plate to overhang)
ap_s1     = 3.4;   // stem flat towards the motor
ap_t      = 1.5;   // plate thickness
ap_x      = 10.5;  // plate half width
ap_y0     = -7.75; // plate -Y edge (in the end wall's base)
ap_y1     = 5.5;   // plate +Y edge (under the motor can)
ap_r      = 3;     // plate corner radius
ap_floor  = 0.8;   // floor under the plate (incl. the play below it)
ap_play   = 0.15;  // play under the plate

// seam keys, no screws: small bowtie keys, printed flat as separate parts, press into bowtie pockets that
// span the seam on the outer faces and sit flush. The halves print lying on their outer side, so anything of
// a half that crossed the seam would stand upright with its layers across the pull; the keys cross it lying
// flat instead, along their layers. The halves only get pockets, pulling them apart presses their material
// together. Nothing bends, so nothing fatigues. To open: lever each key out at its notch with a small screwdriver.
key_t     = 1.4;   // key thickness (= pocket depth)
key_e     = 4;     // key half length, across the seam
key_w     = 4;     // key width at the waist (on the seam)
key_wo    = 7;     // key width at its ends
key_play  = 0.05;  // key smaller than its pocket all round
// detent: an arm at each end of the key (cut free by a slot, bends along the key's printed lines) carries a
// small 45 deg bump at the key's deep edge; it clicks into a groove at the bottom of the pocket's end wall
key_arm   = 0.8;   // arm thickness (across the seam)
key_slot  = 0.5;   // slot behind the arm
key_bump  = 0.4;   // bump height: raise if the keys come out too easily, lower if they won't go in
// seam pins at the drive end: only line the halves up (square pin, round hole with a little play)
pin_play  = 0.1;   // hole diameter minus pin diagonal
pin_ch    = 0.4;   // chamfer on the pin tip and the hole's mouth
pin_boss_d = 5;

$fn = 64;

/* ---------------- derived ---------------- */
lip_ch    = (flange_d + 0.8 - lip_id) / 2;     // 45 deg cone under the nut's lip (prints either way up)
z_body0   = flange_h + lip_t + 0.5;            // body sits just above the nut
z_floor   = z_body0 + floor_t;
z_ap0     = z_body0 + ap_floor;                // adapter plate, bottom
z_ap1     = z_ap0 + ap_t;                      // adapter plate, top
z_ah1     = z_ap1 + clr + 1.2;                 // housing over the adapter plate, top
z_mot0    = z_ah1;                             // motor can bottom, on the housing over the adapter plate
z_gp0     = z_mot0 + mot_len;                  // gear plates, bottom face
z_gp1     = z_gp0 + gp_t;
z_top     = z_gp1 + 0.2;                       // drive ceiling underside
depth_total = max(z_top + lid_t, z_body0 + tp_skin + clr + tp_len);   // the charger board stands floor to front face

z_scr_tip = z_gp0 - scr_len;
z_nut1    = z_gp0 - 0.5;                       // nut top, open
z_nut0    = z_nut1 - nut_len;                  // nut bottom, open
z_shoulder = z_floor + travel;                 // pusher shoulder, open (hits the floor when closed)
z_tip     = pin_top - pin_preload - pusher_trim;  // pusher tip, open

body_w    = batt_w + 2 * wall + 1;
in_half   = body_w / 2 - wall;
gp_y0     = -gp_scr;                           // gear plates, Y range
gp_y1     = gp_y0 + gp_len;
tw_x      = gp_w / 2 + 1.6;                    // drive tower half width
tw_y0     = min(gp_y0, pu_y0 - clr) - 1.6;
tw_y1     = gp_y1 + 1.6;
y_min     = tw_y0 - wall;
y_logic0  = tw_y1 + 1;

// logic bay: the boards stand across the body, parts facing the motor
// [ESP parts | ESP | fin | wires | DRV parts | DRV | fin | wires]
y_esp0    = y_logic0 + 0.5 + (esp_h - esp_pcb) + 0.5;               // ESP PCB front face
y_drv0    = y_esp0 + esp_pcb + clr + brd_fin + esp_back + drv_parts + 0.5;   // DRV PCB front face
logic_len = y_drv0 + drv_t + clr + brd_fin + drv_back - y_logic0;
y_batt0   = y_logic0 + logic_len;
y_tp0     = y_batt0 + batt_len + 0.5 + usb_h + 0.5;   // charger PCB front face (its USB-C faces the battery)
z_tp0     = depth_total - tp_len;              // charger board, lower edge (USB-C end flush with the front face)
tp_hold   = max(z_floor, z_tp0 + 1.5);         // top of what holds its lower edge: the floor, or a seat on it
y_max     = y_tp0 + tp_t + clr + tp_back + wall;
body_len  = y_max - y_min;

z_brd     = (z_floor + z_top) / 2;             // board centre line


// keys hold the halves together; the pins and the tongue-and-groove lip line them up
seam_keys = [                                  // [wall, centre: y in front/back face, z in the end wall]
    ["ceiling", 4],                            // front face, over the gear plates
    ["ceiling", 27],                           // front face, over the boards
    ["ceiling", y_batt0 + 30],                 // front face, over the battery
    ["ceiling", y_tp0 - 10],                   // front face, back end (before the USB-C)
    ["floor", y_batt0 + 10],                   // back face, battery front
    ["floor", y_tp0 - 12],                     // back face, battery back
    ["front", 18],                             // valve end wall, low
    ["front", 26]];                            // valve end wall, high
seam_pins = [                                  // [y, z, pin size, length]
    [y_min + 2.2, z_ah1 + pin_boss_d / 2, 2, 4],   // valve end, low, just above the adapter plate
    [y_min + 2.2, z_top - 0.3, 2, 4],          // valve end, high, into the ceiling
    [tw_y1 - 2.5, z_floor + 10, 2, 4]];        // behind the motor, through the tower

echo(str("total depth from thread face: ", depth_total, " mm (available ", depth_avail, ")"));
echo(str("body: ", body_w, " x ", body_len, " mm (X x Y)"));
echo(str("pusher: tip ", z_tip, " .. top ", z_nut1, ", travel ", travel, " mm"));
assert(depth_total <= depth_avail, "head is deeper than the available space");
assert(body_w <= valve_spacing - 2, "head is wider than the valve spacing");
assert(gp_w / 2 + 1.6 <= in_half + 0.01, "gear plates wider than the body");
assert(z_scr_tip < z_nut0 - travel, "screw too short: the nut would run off its end when closed");
assert(z_scr_tip > z_tip + 2, "screw too long: it would hit the bottom of the pusher");
assert(pu_y1 - tip_shm - scr_bore / 2 >= 0.59, "tip wall towards the motor too thin around the screw bore");
assert(scr_bore >= scr_d + 0.4, "screw bore too tight");
assert(tip_sh <= floor_t - 0.6, "shoulder chamfer deeper than the floor");
assert(lip_ch <= lip_t - 0.6, "lip too thin for its 45 deg cone: raise lip_t or lip_id");
assert(nut_af / 2 <= pu_y1 + 0.01, "nut sticks out of the pusher towards the motor");
assert(z_scr_tip - 1 > z_tip + 1.2, "screw too long: the pusher tip end gets too thin");
assert(z_top >= z_floor + batt_h + wire_gap, "no room for the battery and its wires under the ceiling");
for (k = seam_keys) if (k[0] != "front") assert(k[1] - key_wo / 2 >= y_min + corner_r + 1 && k[1] + key_wo / 2 <= y_max - corner_r - 1, "seam key runs into a rounded corner");
for (k = seam_keys) if (k[0] == "front") assert(k[1] - key_wo / 2 >= seam_pins[0][1] + pin_boss_d / 2 && k[1] + key_wo / 2 <= seam_pins[1][1] - pin_boss_d / 2, "end wall key runs into a seam pin");
for (k = seam_keys) if (k[0] == "floor") assert(k[1] - key_wo / 2 >= y_batt0 && k[1] + key_wo / 2 <= y_tp0 - 2.7, "back face key outside the battery bay");
for (k = seam_keys) if (k[0] == "ceiling") assert(k[1] + key_wo / 2 <= y_tp0 - usb_h - 0.5, "front face key runs into the USB-C opening");
assert(key_t + 0.1 + 0.5 <= floor_t, "floor too thin for its keys");
assert(key_t + 0.1 + 0.5 <= pu_y0 - clr - y_min, "valve end wall too thin for its keys");
assert(key_e + 1.6 <= in_half, "keys too long for the body");
assert(max(norm([ap_x - ap_r, ap_y0 + ap_r]), norm([ap_x - ap_r, ap_y1 - ap_r])) + ap_r < lip_id / 2 - 0.3, "adapter plate won't pass through the ring nut");
assert(ap_x + clr < in_half, "adapter plate wider than the inside of the shell");
assert(ap_y0 - clr >= y_min + 0.8, "adapter plate runs through the end wall");
assert(ap_y0 <= ap_s0 - 1 && ap_y1 >= ap_s1 + 1 && ap_x >= ap_stem_d / 2 + 1, "adapter plate doesn't overhang the stem all round");
assert(pu_y0 - clr - ap_s0 >= 0.75, "adapter stem too thin around the pusher seat (valve end)");
assert(ap_s1 - (pu_y1 - tip_shm + clr) >= 0.6, "adapter stem too thin around the pusher tip (motor side)");
assert(z_floor + clr - tip_sh - 0.1 >= z_ap0, "pusher seat deeper than the adapter plate");
assert(max(esp_l, drv_l) + 2 * clr <= 2 * in_half, "boards too wide for the inside");
assert(max(esp_w, drv_w) + 2 * (clr + 1.2) <= z_top - z_floor, "boards too tall for the inside");
assert(z_tip < z_floor - 1, "pusher tip does not reach the pin - pin is too far down");

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

module adapter() {
    difference() {
        union() {
            // flange with a 45 deg cone on top that seats in the nut's lip cone
            cylinder(d = flange_d, h = flange_h + 0.4 - lip_play);
            translate([0, 0, flange_h + 0.4 - lip_play]) cylinder(d1 = flange_d, d2 = neck_d, h = (flange_d - neck_d) / 2);
            cylinder(d = neck_d, h = z_body0);
            // stem through the shell floor and the locking plate the two halves close around
            // (stem cut flat towards the valve end and the motor, so the plate overhangs it all round)
            linear_extrude(z_ap0 + 0.01) ap_stem();
            translate([0, 0, z_ap0]) linear_extrude(ap_t) ap_plate();
        }
        translate([0, 0, -1]) linear_extrude(50) tip_shape(clr);
        // countersink for the pusher's chamfer = the "closed" stop, so it pushes straight on the valve;
        // raised by clr so the clearance doesn't let the pusher sink deeper on the 45 deg seat
        tip_with_chamfer(z_floor + clr, tip_sh + 0.1, clr, 50);
    }
}

module ap_stem(c = 0) {
    // 2D: the adapter's stem through the floor, flat towards the motor
    intersection() {
        circle(d = ap_stem_d + 2 * c);
        translate([-50, ap_s0 - c]) square([100, ap_s1 - ap_s0 + 2 * c]);
    }
}

module ap_plate(c = 0) {
    // 2D: the adapter's locking plate
    translate([-ap_x - c, ap_y0 - c]) offset(r = ap_r) offset(delta = -ap_r) square([2 * (ap_x + c), ap_y1 - ap_y0 + 2 * c]);
}

module pusher(s = 0) {
    // in place; s = travel (0 = open)
    translate([0, 0, -s]) difference() {
        union() {
            // guided body: rectangle with the same rounded corners as the adapter's seat,
            // so it seats on its shoulder and not on its corners
            translate([0, 0, z_shoulder]) linear_extrude(z_nut1 - z_shoulder) tip_shape(0, tip_sh);
            // stout tip through floor and adapter onto the pin, 45 deg chamfer up to the shoulder
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
        // grooves for the guide rails, full height of the body and the shoulder chamfer
        for (sx = [-1, 1]) translate([sx > 0 ? pu_x - rail_d : -pu_x - 0.01, rail_y0, z_shoulder - tip_sh - 0.01]) cube([rail_d + 0.01, rail_w, z_nut1 - z_shoulder + tip_sh + 0.02]);
    }
}

module outer_solid(i = 0) {
    // outside of the housing, inset by i: one height over the whole length
    translate([0, (y_min + y_max) / 2, z_body0 + i]) rounded_box([body_w - 2 * i, body_len - 2 * i, depth_total - z_body0 - 2 * i], corner_r);
}

module shell() {
    // the whole housing; left() and right() cut it at X=0
    // pusher guide rails, on the channel's side walls from above the adapter plate to the gear plates
    for (sx = [-1, 1]) translate([sx > 0 ? pu_x - rail_d + clr : -pu_x - clr - 0.01, rail_y0 + clr, z_ap1 + clr])
        cube([rail_d + 0.01, rail_w - 2 * clr, z_gp0 - z_ap1 - clr]);
    difference() {
        union() {
          intersection() {
            outer_solid();
            union() {
                difference() {
                    outer_solid();
                    translate([0, (y_min + y_max) / 2, z_floor]) rounded_box([body_w - 2 * wall, body_len - 2 * wall, z_top - z_floor], corner_r - 1);
                }
                // drive tower, floor to ceiling: guides the pusher, holds the motor, traps the gear plates;
                // behind the can only a thin wall, a ledge under the gear plates' end
                difference() {
                    translate([-tw_x, tw_y0, z_body0]) cube([2 * tw_x, tw_y1 - tw_y0, z_top - z_body0 + 0.01]);
                    translate([-tw_x - 1, mot_offset + mot_h / 2 + clr + mot_back, z_floor]) cube([2 * tw_x + 2, tw_y1, z_gp0 - gp_ledge - z_floor]);
                }
                // charger seat: when the board's lower edge is above the floor, a block lifts the pocket
                if (tp_hold > z_floor) translate([-tp_w / 2 - 1.5, y_tp0 - 2.7, z_floor - 0.01]) cube([tp_w + 3, tp_t + clr + 3.9, tp_hold - z_floor + 0.01]);
                // adapter housing: fills the valve end around the adapter plate
                translate([-in_half - 0.01, y_min + wall - 0.01, z_body0]) cube([2 * in_half + 0.02, ap_y1 + clr + 1.6 - (y_min + wall), z_ah1 - z_body0]);
                // seam pin bosses
                for (p = seam_pins) translate([-in_half - 0.01, p[0], p[1]]) rotate([0, 90, 0]) cylinder(d = pin_boss_d, h = 2 * in_half + 0.02, $fn = 24);
                // logic bay: a slot for each board, across the body
                board_slot(y_esp0, esp_l, esp_w, esp_pcb);
                board_slot(y_drv0, drv_l, drv_w, drv_t);
            }
          }
        }
        // pusher guide: rectangular channel, open towards the motor
        translate([-pu_x - clr, pu_y0 - clr, z_floor - 0.01]) cube([2 * pu_x + 2 * clr, mot_offset, z_gp0 - z_floor + 0.02]);
        // adapter: stem through the floor, plate recess above it
        translate([0, 0, z_body0 - 1]) linear_extrude(z_ap0 - z_body0 + 1.01) ap_stem(clr);
        translate([0, 0, z_ap0 - ap_play]) linear_extrude(z_ap1 + clr - z_ap0 + ap_play) ap_plate(clr);
        // motor can pocket, sunk into the floor + wire slot towards the logic bay
        translate([-mot_w / 2 - clr, mot_offset - mot_h / 2 - clr, z_mot0]) cube([mot_w + 2 * clr, mot_h + 2 * clr, z_gp0 - z_mot0 + 0.01]);
        translate([-2, mot_offset, z_mot0]) cube([4, tw_y1 - mot_offset + 1, 4]);
        // gear plates: pocket up to the ceiling, which takes the push reaction
        translate([-gp_w / 2 - clr, gp_y0 - clr, z_gp0 - 0.01]) cube([gp_w + 2 * clr, gp_len + 2 * clr, z_top - z_gp0 + 0.01]);
        // charger board: pocket in the floor (or in its seat) and slot through the ceiling hold its two ends,
        // the halves close around it; the pocket has room in front for the solder joints
        translate([-tp_w / 2 - clr, y_tp0 - 0.1, z_tp0 - clr]) cube([tp_w + 2 * clr, tp_t + clr + 0.1, depth_total - z_tp0 + clr + 1]);
        translate([-tp_w / 2 + 2, y_tp0 - 1.5, z_tp0 - clr]) cube([tp_w - 4, 1.5, tp_hold - z_tp0 + clr + 0.01]);
        // its USB-C = the charging port, in the front face
        translate([usb_x - usb_w / 2 - 0.4, y_tp0 - usb_h - 0.4, z_top - 0.01]) cube([usb_w + 0.8, usb_h + 0.5, depth_total - z_top + 1]);
    }
}

module seam_pin(p) {
    // right half: square pin from the seam face into the left half, chamfered tip
    s = p[2];
    translate([0, p[0], p[1]]) rotate([0, -90, 0]) hull() {
        translate([-s / 2, -s / 2, -0.01]) cube([s, s, p[3] - pin_ch + 0.01]);
        translate([-s / 2 + pin_ch, -s / 2 + pin_ch, 0]) cube([s - 2 * pin_ch, s - 2 * pin_ch, p[3]]);
    }
}

module seam_pin_hole(p) {
    // left half: round hole just over the pin's diagonal, chamfered mouth
    d = p[2] * sqrt(2) + pin_play;
    translate([0, p[0], p[1]]) rotate([0, -90, 0]) {
        translate([0, 0, -0.01]) cylinder(d = d, h = p[3] + 0.5, $fn = 24);
        translate([0, 0, -0.01]) cylinder(d1 = d + 2 * pin_ch, d2 = d, h = pin_ch + 0.01, $fn = 24);
    }
}

module board_slot(y0, bx, bz, t) {
    // a board standing across the body, PCB front face at y0, parts facing the motor (-Y).
    // Held between a fin behind it and four clips at its front corners; the slot is open towards
    // the seam, so the board slides into the right half's clips, and the left half's clips close over it.
    x0 = -bx / 2; x1 = bx / 2; z0 = z_brd - bz / 2; z1 = z_brd + bz / 2;
    difference() {
        union() {
            // fin behind the board
            translate([-in_half - 0.01, y0 + t + clr, z_floor - 0.01]) cube([2 * in_half + 0.02, brd_fin, z_top - z_floor + 0.02]);
            // corner blocks, out to the side walls: carry the front clips
            for (sx = [-1, 1], sz = [-1, 1]) {
                xa = sx < 0 ? -in_half - 0.01 : x1 - 3;
                xb = sx < 0 ? x0 + 3 : in_half + 0.01;
                za = sz < 0 ? z0 - clr - 1.2 : z1 - 3;
                zb = sz < 0 ? z0 + 3 : z1 + clr + 1.2;
                translate([xa, y0 - brd_clip, za]) cube([xb - xa, brd_clip + t + clr + 0.01, zb - za]);
            }
        }
        // the PCB
        translate([x0 - clr, y0 - 0.1, z0 - clr]) cube([bx + 2 * clr, t + clr + 0.1, bz + 2 * clr]);
        // in front: only the corner clips stay
        translate([x0 + brd_clip, y0 - brd_clip - 1, z0 + brd_clip]) cube([bx - 2 * brd_clip, brd_clip + 1.01, bz - 2 * brd_clip]);
        // window in the fin for the wires on the back pads
        translate([x0 + 1, y0 + t, z0 + 1]) cube([bx - 2, brd_fin + clr + 1, bz - 2]);
        // wire passages past the board: above and below it, and beside it where there is room
        for (sz = [-1, 1]) translate([x0 + 4, y0 - brd_clip - 1, sz < 0 ? z_floor - 1 : z1 + clr])
            cube([bx - 8, brd_clip + t + clr + brd_fin + 2, sz < 0 ? z0 - clr - z_floor + 1 : z_top + 1 - z1 - clr]);
        if (in_half - x1 - clr > 1) for (sx = [-1, 1]) translate([sx < 0 ? -in_half - 1 : x1 + clr, y0 - brd_clip - 1, z0 + 4])
            cube([in_half + 1 - x1 - clr, brd_clip + t + clr + brd_fin + 2, bz - 8]);
    }
}

module seam_tongue(c = 0) {
    // inner half of the wall thickness, from X = -seam_lip to 0 (c grows it for the groove)
    intersection() {
        difference() {
            outer_solid(wall / 2 - c);
            outer_solid(wall + c);
        }
        translate([-seam_lip - c, y_min - 1, -1]) cube([seam_lip + c + 0.01, body_len + 2, depth_total + 2]);
    }
}

// keys are drawn in a local frame: x across the seam, y along it, z inwards from the outer face
module key_frame(w) {
    if (w == "floor") translate([0, 0, z_body0]) children();
    else if (w == "ceiling") translate([0, 0, depth_total]) mirror([0, 0, 1]) children();
    else multmatrix([[1, 0, 0, 0], [0, 0, 1, y_min], [0, 1, 0, 0], [0, 0, 0, 1]]) children();   // valve end wall
}

module key_2d() {
    // bowtie: narrow on the seam, wide at both ends
    polygon([[-key_e, -key_wo / 2], [0, -key_w / 2], [key_e, -key_wo / 2],
             [key_e, key_wo / 2], [0, key_w / 2], [-key_e, key_wo / 2]]);
}

// bump positions along the arm (key's local y)
kb0 = 0.5; kb1 = key_wo / 2 - 1;

module key_bumps(g = 0) {
    // the 45 deg bumps on both arms, at the key's deep edge (z = key_t); g grows them for the pocket's groove
    for (sx = [-1, 1]) mirror([sx < 0 ? 1 : 0, 0, 0])
        translate([0, kb0 - g, 0]) rotate([90, 0, 0]) mirror([0, 0, 1]) linear_extrude(kb1 - kb0 + 2 * g)
            polygon([[key_e - key_play - 0.01, key_t + g], [key_e - key_play + key_bump + g, key_t - key_bump],
                     [key_e - key_play - 0.01, key_t - 2 * key_bump - g]]);
}

module key_pocket(k) {
    // both halves: the key's pocket, 0.1 deeper than the key, the grooves the bumps click into,
    // and a notch at one end to lever the key out
    key_frame(k[0]) translate([0, k[1], 0]) {
        translate([0, 0, -1]) linear_extrude(1 + key_t + 0.1) key_2d();
        translate([0, 0, 0.1]) key_bumps(0.1);
        translate([key_e - 0.01, -key_wo / 2 + 0.5, -1]) cube([1.2, 1.5, 1 + key_t + 0.1]);
    }
}

module key() {
    // the key in place (z = 0 outer face, z = key_t deep face); its waist crosses the seam along its layers.
    // The slots free an arm at each end, which bends in the key's plane when the bumps click in.
    difference() {
        linear_extrude(key_t) offset(delta = -key_play) key_2d();
        for (sx = [-1, 1]) mirror([sx < 0 ? 1 : 0, 0, 0])
            translate([key_e - key_play - key_arm - key_slot, -key_wo / 2 + 1, -1]) cube([key_slot, key_wo, key_t + 2]);
    }
    key_bumps();
}

module half(side) {
    // side = -1: left (x < 0), +1: right (x > 0, carries the seam tongue)
    if (side > 0) {
        difference() {
            intersection() {
                shell();
                union() {
                    translate([0, y_min - 10, -10]) cube([100, body_len + 20, depth_total + 20]);
                    seam_tongue();
                }
            }
            for (k = seam_keys) key_pocket(k);
        }
        for (p = seam_pins) seam_pin(p);
    } else {
        difference() {
            intersection() {
                shell();
                translate([-100, y_min - 10, -10]) cube([100, body_len + 20, depth_total + 20]);
            }
            seam_tongue(clr / 2);
            for (p = seam_pins) seam_pin_hole(p);
            for (k = seam_keys) key_pocket(k);
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
    color("darkgreen") translate([-esp_l / 2, y_esp0 - (esp_h - esp_pcb), z_brd - esp_w / 2]) cube([esp_l, esp_h, esp_w]);  // XIAO ESP32-C6
    color("purple") translate([-drv_l / 2, y_drv0 - drv_parts, z_brd - drv_w / 2]) cube([drv_l, drv_t + drv_parts, drv_w]);   // DRV8833
    color("teal") translate([-tp_w / 2, y_tp0, z_tp0]) cube([tp_w, tp_t, tp_len]);                                   // TP4056
    color("silver") translate([usb_x - usb_w / 2, y_tp0 - usb_h, depth_total - 7.5]) cube([usb_w, usb_h, 7.5]);       // its USB-C
    // valve: threaded stub up to its thread face (z = 0), pin above it
    color("lightblue", 0.3) translate([0, 0, -thread_len]) cylinder(d = 30, h = thread_len);
    color("lightblue", 0.6) cylinder(d = 3, h = pin_top - s - pin_preload - 0.01, $fn = 16);
}

/* ---------------- output ---------------- */
show_travel = 0; // set to travel to see the closed position

if (part == "assembly") {
    color("white") half(1);
    %half(-1);
    color("orange") nut();
    color("orange") adapter();
    color("violet") pusher(show_travel);
    color("orange") for (k = seam_keys) key_frame(k[0]) translate([0, k[1], 0.1]) key();
    ghost_parts(show_travel);
} else if (part == "section") {
    // cut along the body through the valve axis (keeps x > 0)
    intersection() {
        union() {
            color("white") half(1); color("orange") nut(); color("orange") adapter();
            color("violet") pusher(show_travel);
        }
        translate([0, -100, -50]) cube([100, 300, 150]);
    }
    ghost_parts(show_travel);
} else if (part == "left") {
    // print lying on its outer side, seam face up
    translate([0, 0, body_w / 2]) rotate([0, -90, 0]) half(-1);
} else if (part == "right") {
    translate([0, 0, body_w / 2]) rotate([0, 90, 0]) half(1);
} else if (part == "nut") {
    translate([0, 0, flange_h + lip_t]) rotate([180, 0, 0]) nut();
} else if (part == "adapter") {
    adapter();
} else if (part == "key") {
    // print flat, deep face (with the bumps) down; you need one per entry in seam_keys
    translate([0, 0, key_t]) mirror([0, 0, 1]) key();
} else if (part == "pusher") {
    // print standing on the tip
    translate([0, 0, -z_tip]) pusher();
} else if (part == "print") {
    translate([-depth_total / 2 - 2, 0, body_w / 2]) rotate([0, -90, 0]) half(-1);
    translate([depth_total / 2 + 2, 0, body_w / 2]) rotate([0, 90, 0]) half(1);
    translate([depth_total + 80, 20, flange_h + lip_t]) rotate([180, 0, 0]) nut();
    translate([depth_total + 80, 65, 0]) adapter();
    translate([depth_total + 80, 95, -z_tip]) pusher();
    for (i = [0 : len(seam_keys) - 1]) translate([depth_total + 60 + (i % 4) * 11, 115 + floor(i / 4) * 10, key_t]) mirror([0, 0, 1]) key();
}

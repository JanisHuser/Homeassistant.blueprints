// DIY battery valve head for floor-heating manifolds (M30x1.5) - tray version
// N20 lock motor standing upright, lead screw on the valve axis, nut + pusher press the pin.
//
// Layout along the body:  [ drive | battery ], with the rollo board (../smart-pcb/pcb) over the battery
//
// Coordinates:
//   Z = valve axis, Z=0 is the valve's thread face (top of the M30 stub), +Z points at you
//   X = across the body (along the manifold)
//   Y = along the body, the valve sits at Y=0, the battery at the far +Y end
//
// Parts:
// - tray: front face, walls, drive column, seat for the motor board and battery bay in one part, printed
//   front-face-down, open towards the valve. Everything goes in from the valve side.
// - lid: the back face (against the manifold), printed flat. It slides in from the back end in grooves at the
//   bottom of the side walls; a spring tab at its back end clicks into the back wall. Only a cover: the motor's
//   push goes from the gear plates into the tray's front face, through the walls into the adapter's thread.
// - adapter: screws into the tray with a left-hand thread, up to its shoulder on the tray's bottom face. Its flange
//   sits on the valve's thread face. The pin pushes the tray off the valve, which loads the thread so it backs off;
//   so once it is seated, a key on the lid's front edge drops into a notch in its thread and locks it against turning
//   (screw the adapter in first, then slide the lid on; the lid won't go on unless the adapter is home).
// - ring nut: a separate part that turns freely around the adapter: threads onto the valve and clamps the flange. Its
//   drag on the flange can only tighten the left-hand thread.
// - pusher: holds the screw's nut and presses the pin. The drive column keeps its body from turning. Its tip runs in
//   the adapter's round bore, so the adapter can turn around it with the pusher at any height.
// The drive unit (gear plates + motor + screw + pusher) goes in from below as one piece, into a column as wide as
// the gear plates (the widest part). Stops: "open" = the nut (flush with the pusher's top) against the gear plates, "closed" = the pusher's
// chamfered shoulder in the adapter's countersink.
//
// Everything marked MEASURE is a placeholder - replace it with your caliper values.
// Render one part at a time with  openscad -D 'part="tray"' -o tray.stl valve_head_tray.scad

part = "tray"; // assembly | exploded | section | tray | lid | adapter | pusher | nut | print

/* ---------------- valve / manifold (MEASURE) ---------------- */
valve_spacing  = 50;   // MEASURE centre-to-centre distance of the valves
depth_avail    = 45;   // MEASURE free space from thread face to door/wall
thread_len     = 9;    // MEASURE length of the external M30 thread on the valve
pin_top        = 12.2; // pin tip above thread face, not pressed (user, 2026-11-14)
valve_stroke   = 5;    // how far the pin goes in until it stops (user, 2026-11-14)

/* ---------------- N20 lock motor with lead screw (MEASURE all on arrival) ---------------- */
// AliExpress 1005007468668750 (Kinmore KM-1020FN20): screw parallel to the motor
gp_len     = 20;   // gear plate stack, long side (along Y, covers screw and motor)
gp_w       = 10;   // gear plate stack, short side (along X)
gp_ch      = 4;    // 45 deg chamfer on one corner of the gear plates (4 x 4)
gp_ch_x    = 1;    // which corner: +1 = +X side, -1 = -X side
gp_ch_y    = -1;   // +1 = motor end (+Y), -1 = screw end (-Y), next to the nut
gp_t       = 6;    // gear plate stack thickness (along Z)
gp_scr     = 4.5;  // screw axis, measured from the plate end on the screw side
mot_offset = 8.5;  // screw axis to motor axis
mot_w      = 12;   // motor can, wide side (along X)
mot_h      = 10;   // motor can, narrow side (along Y)
mot_len    = 18;   // motor can + end cap + terminals below the gear plates
scr_d      = 3;    // lead screw diameter
scr_len    = 19;   // screw length below the gear plates
nut_af     = 6;    // nut across flats (hex; 7 across the corners), measured 2026-11-14
nut_len    = 2;    // nut's hex length along the screw, measured 2026-11-14
nut_boss_d = 6;    // round boss on one face of the nut, measured 2026-11-14; it points down into the pusher
nut_boss_h = 4;
nut_clr    = 0.4;  // nut pocket clearance per side (printed hex holes come out small)

/* ---------------- other bought parts ---------------- */
cell_d   = 18.4; // 18650 diameter (MEASURE)
cell_len = 65;   // 18650 length, plain cell; a protected one is up to 70 (MEASURE)
cell_nub = 0.5;  // its + nub (MEASURE)
batt_fit = 0.2;  // around the cell
batt_h   = cell_d + 2 * batt_fit;
// bare contact plates, pressed into seats from the valve side; their side catches bite into the seats
con_w    = 12;   // plate, square
con_t    = 0.3;  // plate thickness
con_tab  = 4.5;  // solder tab, snipped from 7 mm: longer hits the board and its USB-C
con_spring = 5.5; // spring plate: its front to the cell's - end. The spring is solid at 5, so it keeps some travel
con_dome = 1;    // button plate: height of its dome (MEASURE)
con_slot = 0.5;  // seat: slot for the plate
con_lip  = 0.8;  // seat: lip in front of the plate
rib_t    = 3;    // ribs that hold the cell, along the body
mark_l   = 6;    // polarity marks in the tray's side walls: bar length
mark_t   = 1.4;  // bar width
mark_d   = 0.6;  // cut depth
mark_z   = 4.5;  // centre, above the lid's inside face
// Rollo board (../smart-pcb/pcb, branch pcb-designs): ESP32-H2 chip, charger, protection, motor driver and its own
// USB-C on one board. It lies flat over the battery, parts up, its USB-C edge against the back wall: the USB-C is the
// charging port, and the chip antenna in the same end sits in plastic. Positions below are from its KiCad layout:
// u = from the USB-C edge towards the drive, x = across the body (+X), seen from the front face.
brd_l    = 48.7; // along the body (Y)
brd_w    = 17;   // across the body (X)
brd_t    = 0.8;  // PCB thickness
brd_top  = 2;    // tallest part on top (the BOOT button); parts are on top only
brd_under = 2.5; // room under it: the USB-C's 0.8 mm, the motor pads' (J2) solder joints and the wires to them
btn_u    = 40.8; // BOOT button (SW1)
btn_x    = 5;
led_u    = 35.15; // light window over the charge LED (D1, u 34.1) and the status LED (D2, u 36.2)
led_x    = 4.55;
led_win  = [2.6, 4.6];  // window size, X x Y
led_skin = 0.4;  // front face left over the window: the LEDs shine through it; 0 = open hole
board_stl = "../smart-pcb/pcb/rollo_board.stl";  // exported from KiCad (branch pcb-designs): origin USB-C edge, centre line, underside
// its USB-C (GT-USB-7014C, mid-mount)
usb_x    = 2;    // centre, off the board's centre line
usb_dn   = 0.8;  // below the board's underside
usb_up   = 1.56; // above the board's top
usb_len  = 7.8;  // how far it reaches into the board from its edge
usb_out  = 0;    // receptacle's face past the board's edge (MEASURE)
usb_w    = 9.3;  // opening in the back wall, width
usb_h    = 3.6;  // opening in the back wall, height
usb_wall = 0.8;  // back wall left in front of the receptacle, so the plug's overmold reaches it
usb_rec  = [13, 7.5];  // recess outside for the plug's overmold

/* ---------------- design ---------------- */
wall     = 2;
base_t   = 4.8;      // body thread: from the body's bottom face to the adapter's top
cover_t  = 2.4;      // the lid: only a cover
lid_t    = 3;      // front face: takes the push from the gear plates
wire_gap = 0.2;    // between the battery and the board's underside parts: they rest on it if the board ever comes loose
board_clip = 1;    // board: stops cover this much at its corners
pad_stop = 0.5;    // board: stops reach this far along its long edges, so the pads next to them stay free
board_fit = 0.05;  // board: press fit between the side walls of its pocket, gap per side (too tight or loose: change it, reprint the tray)
pin_d    = 1.6;    // pin hole in the front face over the BOOT button
drv_wire = 1.5;    // between the drive column wall and the spring plate: room for the plate's tab and wire
// wire channel: motor, board and contact plates are soldered together outside, then the harness is laid in from the
// valve side. The motor wires leave the drive column through a slot open towards the valve, go up the gap beside the
// column and along the top corner of the battery bay (beside the cell, under the board) to the board's pad end.
wire_side = -1;    // which side the channel runs on: -1 = -X (the board's BAT+ pad side), +1 = +X
wire_d   = 1.6;    // the bundle it must pass (two 26-28 AWG silicone wires)
wire_slot = 4;     // motor exit slot through the column's side wall, along Y
wire_y   = 11;     // its centre, beside the motor's end cap
stop_t   = 1.2;    // board: end stops, along the body
clr      = 0.25;   // general print clearance
corner_r = 3;

stroke_margin = 0.1;           // stop just before the pin bottoms out
mount_gap   = 0.5;             // at the top stop ("open") the tip stays this far above the unpressed pin: the head goes on with no force
travel      = mount_gap + valve_stroke - stroke_margin;   // the bottom stop ("closed") presses the pin valve_stroke - stroke_margin, never more
pusher_trim = 0;               // fine tune pusher tip length in steps of 0.2

pu_x   = 5;                    // pusher half width (X)
pu_y0  = -5;                   // pusher -Y face
pu_y1  = mot_offset - mot_h / 2 - 0.5;   // pusher +Y face, towards the motor
tip_d  = 6;                    // round tip through the adapter: the adapter turns around it
tip_sh = 1.2;                  // shoulder ledge around the tip, a 45 deg chamfer (cut off by the pusher's +Y face)
scr_bore = scr_d + 0.6;        // bore for the screw in the pusher
tip_r  = 1.5;                  // pusher body corner radius
pu_rd  = tip_d + 2 * tip_sh;   // round collar above the shoulder: fits the adapter's round recess, so no corner meets the adapter
pu_rh  = 1;                    // collar height: the square body stays this far above the adapter when closed
pu_loft = 2.2;                 // 45 deg loft from the collar out to the square body (prints tip down without overhang)

nut_od    = 36;
lip_t     = 2.5;
flange_d  = 27.6;  // must pass through the nut's thread (minor dia ~28.4)
flange_h  = 2.5;
neck_d    = 24;    // its top is the shoulder against the tray's bottom face
lip_id    = neck_d + 1;
lip_play  = 0.2;   // gap between the nut's lip cone and the adapter's flange cone
bt_d      = 19;    // left-hand thread into the body: outer diameter
bt_p      = 4;     // its pitch: ridge to ridge, a coarse thread so each ridge is about 10 layers thick at 0.2 mm
bt_starts = 2;     // two ridges side by side: 0.6 turn from first catch to the shoulder
bt_lead   = bt_p * bt_starts;   // one turn moves it this far
bt_h      = 1.2;   // ridge height; 45 deg flanks, so the layer steps barely eat the clearance
bt_crest  = bt_p / 2 - bt_h;    // flat on top of the ridge: same ridge on the adapter and in the tray
bt_entry  = 0.8;   // lead-in at the tray's mouth, so no thin edge is left where the ridges run out
bt_gap    = 0.25;  // its clearance on the adapter, from thread_test.scad (too tight or loose: change it, reprint only the adapter)
slot_w    = 2;     // tool slot across the flange's underside: holds the adapter with a flat screwdriver
slot_d    = 1.5;   // its depth
slot_r    = 11.5;  // it ends here, inside the neck, so the flange's rim stays whole under the nut's clamp
ear_up    = 1.25;  // ears stand this far above the lid: cover over the thread
ear_y1    = 8;     // ears end here (towards the motor); the lid starts behind them
// anti-turn key: tongue on the lid's front edge into a notch in the adapter's thread (at +Y, inside the drive column,
// where the tray has no ridges anyway; a second notch at -Y for the other thread start)
key_w     = 3;     // tongue width
key_play  = 0.5;   // notch wider than the tongue, per side (~3 deg of turn, 0.07 mm of axial slack)
key_r     = 7.85;  // tongue tip, from the valve axis (the adapter's root is at bt_d/2 - bt_h - bt_gap)
key_ch    = 0.6;   // chamfers on the tongue's tip corners: it finds the notch even if the adapter stops a bit short
key_deep  = 0.45;  // notch goes this far past the tongue tip (the lid can slide on until it meets the ears)
// lid
lid_tg   = 0.9;    // tongue on the lid's long edges, into the wall grooves (flat faces: no wedging)
lid_tg_h = 1.0;    // tongue thickness
lid_tg_z = 1.0;    // tongue above the body's bottom face
tab_w    = 6;      // spring tab at the lid's back end
tab_l    = 10;
tab_t    = 1.2;    // tab thickness (the lid's upper layer): bends ~1.3 % when it clicks
tab_bump = 0.6;    // its catch, into a notch in the back wall

$fn = 64;

/* ---------------- derived ---------------- */
lip_ch    = (flange_d + 0.8 - lip_id) / 2;     // 45 deg cone under the nut's lip (prints either way up)
scr_clear = 2.5;                               // pusher material between the screw's end and the tip, open
// body sits on the adapter's shoulder: just above the nut, or higher where the pin sticks out far,
// so the unpressed pin stays clear of the screw's end (the motor can stands on the adapter, so the screw moves with it)
z_body0   = max(flange_h + lip_t + 0.5, pin_top + mount_gap - pusher_trim + scr_clear - base_t - mot_len + scr_len);
z_floor   = z_body0 + base_t;                  // adapter's top
z_cover   = z_body0 + cover_t;                 // inside face of the lid
z_mot0    = z_floor;                           // motor can stands on the adapter; the drive column keeps it from tilting
z_gp0     = z_mot0 + mot_len;                  // gear plates, bottom face
z_gp1     = z_gp0 + gp_t;
z_col_top = z_gp1 + 0.2;                       // top of the drive column: the gear plates push on it
z_pcb0    = z_cover + batt_h + brd_under + wire_gap;   // board's underside, its parts just over the battery
z_top     = max(z_col_top, z_pcb0 + brd_t + brd_top + clr);   // inside face of the front face
depth_total = z_top + lid_t;

z_scr_tip = z_gp0 - scr_len;
z_nut1    = z_gp0 - 0.5;                       // nut's hex top = the pusher's top, open: stops against the gear plates
z_nut0    = z_nut1 - nut_len;                  // nut's hex bottom, open
z_boss0   = z_nut0 - nut_boss_h;               // bottom of the nut's boss, inside the pusher
z_shoulder = z_floor + travel;                 // pusher shoulder, open (in the adapter's countersink when closed)
z_tip     = pin_top + mount_gap - pusher_trim;    // pusher tip, open

body_w    = 2 * (max(batt_h / 2 + 0.3, brd_w / 2 + board_clip + 0.2) + wall);   // the battery sets it
in_half   = body_w / 2 - wall;
gp_y0     = -gp_scr;                           // gear plates, Y range
gp_y1     = gp_y0 + gp_len;
// drive column: the gear plates are the widest part, so everything goes up through their footprint
col_x     = max(gp_w, mot_w) / 2 + clr;           // the motor can may be wider than the plates
col_y0    = min(gp_y0, pu_y0) - clr;
col_y1    = max(gp_y1, mot_offset + mot_h / 2) + clr;
tw_x      = col_x + 1.35;                      // walls around the column
tw_y0     = -(bt_d / 2 + clr + 1.2 - wall);    // the end wall's inside, so 1.2 mm stays behind the thread
tw_y1     = col_y1 + 1.35;
ear_x     = col_x + 0.15;                      // ears start here (outside the column)
y_min     = tw_y0 - wall;

y_batt0   = tw_y1 + drv_wire;                  // spring plate, rear face; the motor wires go up behind it
y_cell0   = y_batt0 + con_t + con_spring;      // cell's - end
y_cell1   = y_cell0 + cell_len;                // cell's + end
y_batt1   = y_cell1 + con_dome + con_t;        // button plate, rear face: the back wall
y_max     = y_batt1 + wall;
z_batt    = z_cover + batt_h / 2;              // cell's axis
body_len  = y_max - y_min;
y_brd1    = y_max - wall - usb_out;            // board's USB-C edge, against the back wall
y_brd0    = y_brd1 - brd_l;                    // board's other end: motor and cell pads
z_brd1    = z_pcb0 + brd_t;
z_usb     = z_pcb0 + (brd_t + usb_up - usb_dn) / 2;   // its USB-C's centre
wire_ch   = in_half - tw_x;                    // the channel's width: the gap between the column wall and the side wall
wire_z    = z_pcb0 - 0.4 - wire_ch / 2;        // the channel's centre in the top corner, just under the board

echo(str("total depth from thread face: ", depth_total, " mm (available ", depth_avail, ")"));
echo(str("body: ", body_w, " x ", body_len, " mm (X x Y)"));
echo(str("pusher: tip ", z_tip, " .. top ", z_nut1, ", travel ", travel, " mm"));
echo(str("body thread: ", base_t / bt_lead, " turns"));
assert(tab_t + 0.6 <= cover_t, "lid too thin for its spring tab");
assert(lid_tg_z + lid_tg_h <= cover_t, "lid too thin for its tongues");
assert(depth_total <= depth_avail, "head is deeper than the available space");
assert(body_w <= valve_spacing - 2, "head is wider than the valve spacing");
assert(tw_x <= in_half + 0.01, "gear plates wider than the body");
assert(z_nut1 - (z_shoulder + pu_rh + pu_loft) >= 5, "pusher's square part (up to its top, around the nut) too short to keep it from turning");
assert(z_boss0 - nut_clr - (z_shoulder + pu_rh + pu_loft) >= 2, "pusher too thin between its loft and the nut's boss");
assert(z_tip - travel >= pin_top - valve_stroke + stroke_margin - 0.001, "closed stop presses the pin past its stroke");
assert(z_scr_tip < z_boss0 - travel, "screw too short: the nut would run off its end when closed");
assert(z_scr_tip > z_tip + 2, "screw too long: it would hit the bottom of the pusher");
assert(z_scr_tip - 1 > z_tip + 1.2, "screw too long: the pusher tip end gets too thin");
assert(tip_d / 2 - scr_bore / 2 >= 1, "tip wall too thin around the screw bore");
assert(tip_d / 2 <= pu_y1, "round tip sticks out of the pusher towards the motor");
assert(scr_bore >= scr_d + 0.4, "screw bore too tight");
assert(nut_af / 2 <= pu_y1 + 0.01, "nut sticks out of the pusher towards the motor");
assert(pu_rd < tip_d + 2 * clr + 2 * tip_sh, "pusher's round collar wider than the adapter's recess");
assert(pu_x <= col_x && pu_y0 >= col_y0, "pusher wider than the drive column");
assert(z_tip < z_floor - 1, "pusher tip does not reach down into the adapter - pin sticks out too far");
assert(lip_ch <= lip_t - 0.6, "lip too thin for its 45 deg cone: raise lip_t or lip_id");
assert(neck_d / 2 >= bt_d / 2 + clr + 1, "adapter's shoulder too narrow to seat on the tray");
assert(slot_r <= neck_d / 2, "adapter's tool slot runs out under the nut's clamp");
assert(bt_d / 2 - bt_h - bt_gap - (tip_d / 2 + clr + tip_sh) >= 1.5, "adapter wall too thin between its countersink and its thread");
assert(bt_crest > 0, "thread ridges too tall for their pitch");
assert(key_r - key_deep - (tip_d / 2 + clr) >= 3, "adapter wall too thin behind the key's notch");
assert(key_r < bt_d / 2 - bt_h - bt_gap - 0.1, "lid key doesn't reach past the adapter's thread root");
assert(key_deep > clr, "lid key bottoms in the notch before the lid meets the ears");
assert(key_w / 2 + key_play < tw_x - 1, "key's notch wider than the drive column");
assert(bt_d / 2 - bt_h > sqrt(col_x * col_x + col_y0 * col_y0) - 0.5, "drive column cuts too much off the tray's ridges");
assert(brd_w / 2 + board_fit <= in_half, "board wider than the body");
assert(y_brd0 - clr - stop_t >= y_batt0 + 2, "board too long: it reaches the drive column");
assert(z_pcb0 - usb_dn >= z_cover + batt_h + wire_gap, "board's USB-C hits the battery");
assert(z_usb + usb_rec[1] / 2 <= depth_total - 1, "USB-C recess runs into the front face's edge");
assert(z_batt + con_w / 2 + con_tab < z_pcb0 - usb_dn, "contact tab hits the board's USB-C");
assert(body_w / 2 - (bt_d / 2 + clr) >= 1.2, "side walls too thin around the body thread");
assert(wire_ch >= wire_d + 0.4, "wire channel beside the drive column too narrow");
assert(norm([in_half - wire_ch, wire_z - wire_ch / 2 - z_batt]) >= batt_h / 2 + 0.2, "wire channel in the corner pinches against the cell");
assert(in_half - wire_ch >= con_w / 2 + 1.5 + 0.1, "wire channel runs into the contact plates' seats");
assert(cell_nub + con_dome >= con_slot + con_lip, "cell hits the seat's lips before it reaches the button");

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

module body_shape(c = 0) {
    // 2D section of the pusher's body; c = clearance all round
    translate([-pu_x - c, pu_y0 - c]) offset(r = tip_r) offset(delta = -tip_r) square([2 * (pu_x + c), pu_y1 - pu_y0 + 2 * c]);
}

module tip_with_chamfer(z_sh, h_below) {
    // round tip below z_sh, 45 deg chamfer up to the pusher's body at z_sh
    translate([0, 0, z_sh - h_below]) cylinder(d = tip_d, h = h_below - tip_sh + 0.01);
    intersection() {
        translate([0, 0, z_sh - tip_sh]) cylinder(d1 = tip_d, d2 = tip_d + 2 * tip_sh, h = tip_sh);
        translate([0, 0, z_sh - tip_sh]) linear_extrude(tip_sh) body_shape();
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

// radius of the body's thread at angle a: a trapezoid ridge with 45 deg flanks, bt_starts times round
function bt_r(a, c) = let(t = ((a * bt_lead / 360) % bt_p + bt_p) % bt_p)
    bt_d / 2 - bt_h + c + min(bt_h, max(0, bt_crest / 2 + bt_h - abs(t - bt_p / 2)));

// the body's left-hand thread; c = clearance (negative on the adapter).
// Lined up over the whole height, so the tray's and the adapter's meet whatever z0 each starts at.
module body_thread(z0, len, c) {
    n = 240;
    translate([0, 0, z0]) rotate(-(z0 - z_body0) * 360 / bt_lead)
        linear_extrude(height = len, twist = 360 * len / bt_lead, slices = ceil(len / bt_lead * 120), convexity = 6)
            polygon([for (i = [0 : n - 1]) let(a = i * 360 / n) bt_r(a, c) * [cos(a), sin(a)]]);
}

// the adapter's side of the thread with clearance g, a lead-in on its end: from the ridge's root at the tip up to its crest
module adapter_thread(g) {
    r_root = bt_d / 2 - bt_h - g;
    intersection() {
        body_thread(z_body0 - 0.01, base_t + 0.01, -g);
        union() {
            translate([0, 0, z_body0 - 1]) cylinder(d = bt_d + 1, h = base_t - bt_h + 1 - 0.05);
            // ends just inside the root, so it cuts through instead of touching it
            translate([0, 0, z_floor - bt_h - 0.05]) cylinder(r1 = r_root + bt_h + 0.01, r2 = r_root - 0.05, h = bt_h + 0.05);
        }
    }
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
    // in place; prints flange down, thread up
    difference() {
        union() {
            // flange with a 45 deg cone on top that seats in the nut's lip cone
            cylinder(d = flange_d, h = flange_h + 0.4 - lip_play);
            translate([0, 0, flange_h + 0.4 - lip_play]) cylinder(d1 = flange_d, d2 = neck_d, h = (flange_d - neck_d) / 2);
            // neck up to the shoulder on the tray's bottom face
            cylinder(d = neck_d, h = z_body0);
            // left-hand thread into the body
            adapter_thread(bt_gap);
        }
        // round bore for the pusher's tip
        translate([0, 0, -1]) cylinder(d = tip_d + 2 * clr, h = z_floor + 2);
        // tool slot, reached from the valve side through the nut's thread
        translate([-slot_r, -slot_w / 2, -1]) cube([2 * slot_r, slot_w, slot_d + 1]);
        // notches for the lid's key, one per thread start
        for (a = [0, 180]) rotate(a) translate([-key_w / 2 - key_play, key_r - key_deep, z_body0 - 0.01])
            cube([key_w + 2 * key_play, bt_d, z_cover + clr - z_body0 + 0.01]);
        // countersink for the pusher's chamfer = the "closed" stop, so it pushes straight on the valve;
        // raised by clr so the clearance doesn't let the pusher sink deeper on the 45 deg seat;
        // round all the way, because it ends up at any angle under the pusher
        translate([0, 0, z_floor + clr - tip_sh]) cylinder(d1 = tip_d + 2 * clr, d2 = tip_d + 2 * clr + 2 * tip_sh, h = tip_sh);
        translate([0, 0, z_floor + clr - 0.01]) cylinder(d = tip_d + 2 * clr + 2 * tip_sh, h = 2);
    }
}

module pusher(s = 0) {
    // in place; s = travel (0 = open)
    translate([0, 0, -s]) difference() {
        union() {
            // body: round collar at the bottom, lofting out to the square that keeps it from turning in the column
            intersection() {
                translate([0, 0, z_shoulder]) linear_extrude(z_nut1 - z_shoulder) body_shape();
                union() {
                    translate([0, 0, z_shoulder]) cylinder(d = pu_rd, h = pu_rh + 0.01);
                    hull() {
                        translate([0, 0, z_shoulder + pu_rh]) cylinder(d = pu_rd, h = 0.01);
                        translate([0, 0, z_shoulder + pu_rh + pu_loft]) linear_extrude(z_nut1 - z_shoulder - pu_rh - pu_loft) body_shape(2);
                    }
                }
            }
            // round tip through the adapter onto the pin, 45 deg chamfer up to the shoulder
            tip_with_chamfer(z_shoulder, z_shoulder - z_tip);
        }
        // nut pocket, open at the top and towards the motor: hex flush with the pusher's top, its boss in a round hole below
        translate([0, 0, z_nut0 - nut_clr]) hex(nut_af + 2 * nut_clr, nut_len + 2 * nut_clr + 1);
        translate([0, 0, z_boss0 - nut_clr]) cylinder(d = nut_boss_d + 2 * nut_clr, h = nut_boss_h + 0.01);
        translate([-nut_boss_d / 2 - nut_clr, 0, z_boss0 - nut_clr]) cube([nut_boss_d + 2 * nut_clr, 10, nut_boss_h + 0.01]);
        // corner reliefs: printed hex corners round off and would grip the nut's corners (not at -Y: wall too thin there)
        for (a = [30, 150, 210, 330]) rotate(a) translate([(nut_af / 2 + nut_clr) / cos(30), 0, z_nut0 - nut_clr])
            cylinder(d = 1, h = nut_len + 2 * nut_clr + 1, $fn = 12);
        // lead-in so the nut finds the pocket when you push the pusher up the screw
        hull() {
            translate([0, 0, z_nut1 - 0.4]) hex(nut_af + 2 * nut_clr, 0.01);
            translate([0, 0, z_nut1]) hex(nut_af + 2 * nut_clr + 0.8, 0.01);
        }
        translate([-(nut_af / cos(30)) / 2 - nut_clr, 0, z_nut0 - nut_clr]) cube([nut_af / cos(30) + 2 * nut_clr, 10, nut_len + 2 * nut_clr + 1]);
        // bore for the screw below the nut
        translate([0, 0, z_scr_tip - 1]) cylinder(d = scr_bore, h = 50, $fn = 24);
    }
}

module lid_2d(c = 0) {
    // the lid's outline: full width behind the ears, round cut-out for the adapter's thread
    difference() {
        translate([-in_half - c, ear_y1 + clr - c]) square([2 * (in_half + c), y_max - ear_y1 + 1]);
        circle(r = bt_d / 2 + clr - c);
    }
}

module lid_solid(c = 0) {
    translate([0, 0, z_body0 - 1]) linear_extrude(z_cover - z_body0 + 1 + c) lid_2d(c);
    // tongues on the long edges, into the wall grooves
    for (sx = [-1, 1]) translate([sx > 0 ? in_half - 0.01 : -in_half - lid_tg - c, ear_y1 + clr - c, z_body0 + lid_tg_z - c])
        cube([lid_tg + c + 0.01, y_max - ear_y1 + 1, lid_tg_h + 2 * c]);
}

module lid() {
    difference() {
        intersection() {
            lid_solid();
            outer_solid();
        }
        // spring tab at the back end: the lid's upper layer, cut free on three sides, thin from below
        for (sx = [-1, 1]) translate([sx * (tab_w / 2 + 0.4) - 0.4, y_max - tab_l, z_body0 - 1]) cube([0.8, tab_l + 1, cover_t + 2]);
        translate([-tab_w / 2 - 0.4, y_max - tab_l, z_body0 - 1]) cube([tab_w + 0.8, tab_l + 1, cover_t - tab_t + 1]);
        // polarity, on the face towards the cell
        for (m = [[y_cell0 + 4, "-"], [y_cell1 - 16, "+"]]) translate([0, m[0], z_cover - 0.4]) linear_extrude(1)
            text(m[1], size = 8, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
    }
    // key on the front edge: into the adapter's notch, so the adapter can't back off
    translate([0, 0, z_body0]) linear_extrude(cover_t) polygon([
        [-key_w / 2, bt_d / 2 + clr + 1], [-key_w / 2, key_r + key_ch], [-key_w / 2 + key_ch, key_r],
        [key_w / 2 - key_ch, key_r], [key_w / 2, key_r + key_ch], [key_w / 2, bt_d / 2 + clr + 1]]);
    // the tab's catch: square towards the back (holds the lid), ramp towards the front (slides in)
    translate([0, y_max - wall + 0.3, z_cover - 0.01]) rotate([90, 0, 90]) linear_extrude(tab_w - 1, center = true)
        polygon([[0, 0], [1.2, 0], [1.2, tab_bump], [0.6, tab_bump]]);
}

module board_seat(bw, by0, by1, z1, stop_l) {
    // pocket for a board lying flat, parts up: press it in from below between the side walls until it stops. Stops over
    // its corners and end stops beside its short edges.
    x1 = bw / 2;
    difference() {
        for (sx = [-1, 1], e = [0, 1]) mirror([sx < 0 ? 1 : 0, 0, 0])
            translate([x1 - board_clip, e == 0 ? by0 - clr - stop_t : by1 - stop_l, z_pcb0]) cube([in_half - x1 + board_clip + 0.01, stop_t + clr + stop_l, z_top - z_pcb0 + 0.01]);
        // the PCB: open from below up to its top face
        translate([-x1 - board_fit, by0 - clr, z_pcb0 - 1]) cube([bw + 2 * board_fit, by1 - by0 + 2 * clr, z1 - z_pcb0 + 1]);
    }
}

module contact_seat(y0, dir, y_wall) {
    // seat for a contact plate: open towards the valve, the plate presses in until it stops at the top. Only at the
    // plate's sides, so the tab, spring and wires stay free. y0 = plate's rear face, dir = towards the cell,
    // y_wall = the wall behind it. The top slopes up to that wall: prints front face down without supports.
    z0 = z_batt - con_w / 2;
    z1 = z_batt + con_w / 2 + clr;
    y_front = y0 + dir * (con_slot + con_lip);
    difference() {
        for (sx = [0, 1]) mirror([sx, 0, 0]) translate([con_w / 2 - 1, 0, 0]) rotate([90, 0, 90]) linear_extrude(2.5)
            polygon([[y_wall - dir * 0.01, z0], [y_front, z0], [y_front, z1], [y_wall - dir * 0.01, z1 + abs(y_front - y_wall)]]);
        translate([-con_w / 2 - 0.15, min(y0, y0 + dir * con_slot), z0 - 1]) cube([con_w + 0.3, con_slot, z1 - z0 + 1]);
    }
}

module batt_ribs() {
    // hold the cell sideways and towards the front face; below its axis it's free to go in. The corners left around
    // the cell take the wires. 45 deg on top: prints without supports, and stays under the board.
    z_r = z_pcb0 - 0.1;
    for (y = [y_cell0 + 10, y_cell1 - 10 - rib_t]) translate([0, y + rib_t, 0]) rotate([90, 0, 0]) linear_extrude(rib_t) difference() {
        for (sx = [0, 1]) mirror([sx, 0])
            polygon([[in_half + 0.01, z_batt], [in_half + 0.01, z_r], [in_half - (z_r - z_batt), z_batt]]);
        translate([0, z_batt]) circle(d = batt_h);
        // notch for the wire channel in the top corner
        translate([wire_side * (in_half - wire_ch / 2), wire_z]) square([wire_ch + 0.02, wire_ch], center = true);
    }
}

module polarity_mark(y, plus) {
    // + or - cut into the +X side wall's inside face, centred on y
    translate([in_half - 0.01, y, z_cover + mark_z]) {
        translate([0, -mark_l / 2, -mark_t / 2]) cube([mark_d + 0.01, mark_l, mark_t]);
        if (plus) translate([0, -mark_t / 2, -mark_l / 2]) cube([mark_d + 0.01, mark_t, mark_l]);
    }
}

module tray() {
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
            // ears left and right of the adapter: carry the thread, a little taller than the lid
            for (sx = [-1, 1]) translate([sx > 0 ? ear_x : -in_half - 0.01, y_min + wall - 0.01, z_body0])
                cube([in_half - ear_x + 0.01, ear_y1 - y_min - wall + 0.01, base_t + ear_up]);
            board_seat(brd_w, y_brd0, y_brd1, z_brd1, pad_stop);
            contact_seat(y_batt0, 1, tw_y1);
            contact_seat(y_batt1, -1, y_batt1);
            batt_ribs();
        }
        // drive column: the drive unit goes up into it from below (the gear plates are the widest part)
        // gear plate footprint (with its chamfer) all the way up, the motor can and pusher only below the plates.
        // The chamfered corner stays solid at the plates' level, so the drive unit only fits one way round.
        translate([0, 0, z_body0 - 1]) linear_extrude(z_col_top - z_body0 + 1) offset(delta = clr) gp_outline();
        translate([-col_x, col_y0, z_body0 - 1]) cube([2 * col_x, col_y1 - col_y0, z_gp0 - z_body0 + 1]);
        // the board's slot runs into the back wall's rounded inside corners: it goes in tilted, USB-C end first over the
        // button plate's seat, slides against the back wall and swings up under the stops
        translate([-brd_w / 2 - board_fit, y_brd0 - clr, z_pcb0 - usb_dn - 0.5]) cube([brd_w + 2 * board_fit, brd_l + 2 * clr, z_brd1 - z_pcb0 + usb_dn + 0.5]);
        // motor exit slot: through the column's side wall into the gap beside it, open towards the valve so the
        // drive unit goes in with its wires already soldered
        translate([wire_side > 0 ? 0 : -in_half - 0.01, wire_y - wire_slot / 2, z_body0 - 1])
            cube([in_half + 0.01, wire_slot, z_mot0 + 4 - z_body0 + 1]);
        // the lid and its grooves, open at the back end
        lid_solid(clr);
        translate([-body_w, y_max - wall - 1, z_body0 - 1]) cube([2 * body_w, wall + 2, cover_t + 1 + clr]);
        // the lid tab's catch: notch in the back wall's underside
        translate([-tab_w / 2, y_max - wall + 0.1, z_cover - 0.01]) cube([tab_w, 1.4, tab_bump + 0.2]);
        // pin hole over the BOOT button, countersunk outside so the pin finds it; plain window over the charge LED
        translate([btn_x, y_brd1 - btn_u, z_top - 0.01]) {
            cylinder(d = pin_d, h = depth_total - z_top + 1, $fn = 24);
            translate([0, 0, depth_total - z_top - 0.79]) cylinder(d1 = pin_d, d2 = pin_d + 1.6, h = 0.81, $fn = 24);
        }
        translate([led_x - led_win[0] / 2, y_brd1 - led_u - led_win[1] / 2, z_top - 0.01]) cube([led_win[0], led_win[1], lid_t - led_skin + 0.01 + (led_skin > 0 ? 0 : 1)]);
        // left-hand thread for the adapter, through the ears and the end wall
        body_thread(z_body0 - 1, base_t + 1 + clr, 0.01);
        translate([0, 0, z_body0 - 0.01]) cylinder(r1 = bt_d / 2 + 0.01, r2 = bt_d / 2 - bt_entry, h = bt_entry + 0.01);
        // polarity, cut into both side walls beside each end of the cell, where the cell curves away from the wall
        for (sx = [0, 1]) mirror([sx, 0, 0]) {
            polarity_mark(y_cell0 + 5, false);
            polarity_mark(y_cell1 - 5, true);
        }
        // the board's USB-C through the back wall, a recess outside so the plug's overmold reaches the receptacle
        translate([usb_x - usb_w / 2, y_max - wall - 0.5, z_usb - usb_h / 2]) cube([usb_w, wall + 1, usb_h]);
        translate([usb_x - usb_rec[0] / 2, y_max - (wall - usb_wall), z_usb - usb_rec[1] / 2]) cube([usb_rec[0], 2, usb_rec[1]]);
    }
}

// gear plate stack seen from the front, chamfered corner per gp_ch_x / gp_ch_y
module gp_outline() {
    difference() {
        translate([-gp_w / 2, gp_y0]) square([gp_w, gp_len]);
        translate([gp_ch_x * gp_w / 2, gp_ch_y > 0 ? gp_y1 : gp_y0]) rotate(45) square(gp_ch * sqrt(2), center = true);
    }
}

/* ---------------- placeholders for bought parts ---------------- */
// the rollo board with its parts, from its KiCad export, in place
module rollo_board() {
    translate([0, y_brd1 + usb_out, z_pcb0]) rotate([0, 0, -90]) import(board_stl, convexity = 6);
}

module motor(s = 0) {
    color("goldenrod") translate([0, 0, z_gp0]) linear_extrude(gp_t) gp_outline();
    color("silver") translate([-mot_w / 2, mot_offset - mot_h / 2, z_gp0 - mot_len]) cube([mot_w, mot_h, mot_len]);
    color("gray") translate([0, 0, z_scr_tip]) cylinder(d = scr_d, h = scr_len, $fn = 16);
    color("red") translate([0, 0, -s]) { translate([0, 0, z_nut0]) hex(nut_af, nut_len); translate([0, 0, z_boss0]) cylinder(d = nut_boss_d, h = nut_boss_h); }
}

module cell() {
    translate([0, y_cell0, z_batt]) rotate([-90, 0, 0]) cylinder(d = cell_d, h = cell_len);
}

module contact_plates() {
    // plates with their snipped tabs; spring and dome only as far as the cell compresses them
    for (y = [y_batt0, y_batt1 - con_t]) {
        translate([-con_w / 2, y, z_batt - con_w / 2]) cube([con_w, con_t, con_w]);
        translate([-1.5, y, z_batt + con_w / 2 - 0.01]) cube([3, con_t, con_tab + 0.01]);
    }
    translate([0, y_batt0 + con_t, z_batt]) rotate([-90, 0, 0]) cylinder(d = 7, h = con_spring, $fn = 24);
    translate([0, y_cell1, z_batt]) rotate([-90, 0, 0]) cylinder(d = 6, h = con_dome, $fn = 24);
}

module ghost_parts(s = 0) {
    motor(s);
    color("royalblue", 0.4) cell();
    color("silver") contact_plates();
    color("darkgreen") rollo_board();
    // valve: threaded stub up to its thread face (z = 0), pin above it
    color("lightblue", 0.3) translate([0, 0, -thread_len]) cylinder(d = 30, h = thread_len);
    color("lightblue", 0.6) cylinder(d = 3, h = pin_top - max(0, s - mount_gap) - 0.01, $fn = 16);
}

/* ---------------- output ---------------- */
show_travel = 0; // set to travel to see the closed position

// assembly: up=-z explode=-z   (site assembly guide: built upside down, everything goes in from the valve side)
if (part == "assembly") {
    color("white") tray();
    color("lightsteelblue") lid();
    color("orange") adapter();
    color("darkorange") nut();
    color("violet") pusher(show_travel);
    ghost_parts(show_travel);
} else if (part == "exploded") {
    // as you assemble it: tray front face down, parts go in from above, lid slides on, adapter screws in
    rotate([0, 180, 0]) {
        color("white") tray();
        color("lightsteelblue") translate([0, 70, -10]) lid();
        translate([0, 0, -34]) { color("violet") pusher(); motor(); }
        color("orange") translate([0, 0, -62]) adapter();
        color("darkorange") translate([0, 0, -82]) nut();
    }
} else if (part == "section") {
    // cut along the body through the valve axis (keeps x > 0)
    intersection() {
        union() {
            color("white") tray(); color("lightsteelblue") lid();
            color("orange") adapter(); color("darkorange") nut(); color("violet") pusher(show_travel);
        }
        translate([0, -100, -50]) cube([100, 300, 150]);
    }
    ghost_parts(show_travel);
} else if (part == "tray") {
    // print front face down: turned over, never mirrored, or its left-hand thread becomes right-hand
    translate([0, 0, depth_total]) rotate([0, 180, 0]) tray();
} else if (part == "lid") {
    // print bottom face down
    translate([0, 0, -z_body0]) lid();
} else if (part == "adapter") {
    // print flange down
    adapter();
} else if (part == "pusher") {
    // print standing on the tip
    translate([0, 0, -z_tip]) pusher();
} else if (part == "nut") {
    translate([0, 0, flange_h + lip_t]) rotate([180, 0, 0]) nut();
} else if (part == "print") {
    translate([0, 0, depth_total]) rotate([0, 180, 0]) tray();
    translate([35, 0, -z_body0]) lid();
    translate([-40, 15, 0]) adapter();
    translate([-40, 90, flange_h + lip_t]) rotate([180, 0, 0]) nut();
    translate([-40, 50, -z_tip]) pusher();
}

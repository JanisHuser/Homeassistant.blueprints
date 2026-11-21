// CASE STUDY - print-in-place valve tray (no adapter, no screw-in parts)
//
// Same head as valve_head_tray.scad (battery bay, rollo board, contact plates, sliding lid: all reused from there),
// but:
// - the ring nut is printed IN PLACE around a neck + flange that are now part of the tray. It turns freely, clamps the
//   flange onto the valve's thread face, and can't come off. No adapter, no body thread, no anti-turn key.
// - the pusher is printed IN PLACE in its column, caught between two ledges under the gear plates (top) and the
//   countersink in the floor (bottom).
// - the drive unit (gear plates + motor + screw + nut) goes in from the INSIDE: dropped into the empty battery bay just
//   behind the column (lid off), then slid towards the valve (-Y): plates into their slot under the front face, motor
//   can along its pad, nut flats first into the pusher's pocket (open towards the motor anyway). No opening outside.
// - the spring contact plate goes in afterwards, turned 45 deg (corners up/down/sideways): its side corners sit in
//   grooves at |x| >= seat_x, outside the motor can's path, its bottom corner against a small cheek under the path.
//
// Print: ONE print, tray + nut + pusher together, front face down, no supports. The lid is the only other part.
// - nut: its top face is a flat ring printed on a thin zig-zag wall that stands on the tray's bottom face; the rest of
//   the nut is 45 deg cones. The ring lies inside the round nose, so it is over tray everywhere. The first turn of
//   the nut shears the zig-zag off.
// - flange: grows out of the neck at 45 deg, over the nut's matching lip cone (pip_cone_gap apart).
// - pusher: printed at its open position, its top face pip_zgap over the ledges (the -Y and the far-side ledge), the
//   rest bridges over the empty gear plate slot.
//
// Assembly: harness soldered (board, contact plates, motor), lid off, bay empty. Spin the screw's nut up until it
// touches the gear plates (its pocket is open at the top, so that is in range; the first close pulls it down onto the
// pocket's floor). Push the pusher up against its ledges. Drop the drive unit into the bay, slide it towards the valve
// until the latch clicks behind the gear plates. Lay the motor wires into their slot. Spring plate, board, cell, lid.
//
// Drive unit retention: a print-in-place spring latch under the front face (+X side) catches the gear plates' back
// end; the plates' chamfered corner pushes its tooth aside on the way in. Crush ribs take out the axial play.
//
// Still to measure before the first full print: the motor (can 12 x 10 x mot_len, gear plates 10 x 20 x 6, screw
// 1 mm past the can's end, the plates' top face for can_rib); the print gaps come from pip="coupon".
// Turning on the valve: the motor's torque closes inside the head (nut -> pusher -> column, screw -> gear plates ->
// tray), so only bumps and the body's own weight (~0.03 Nm) act on the clamped flange (~0.3 Nm of friction, nut
// hand-tight). If it still turns in practice: a TPU washer under the flange.
//
// Render:  openscad -D 'pip="print"' -o pip_print.3mf valve_head_pip.scad

// new parameters go before the include: the overrides below are evaluated where the included file first sets them
/* ---------------- case study parameters ---------------- */
pip_zgap     = 0.2;  // flat print-in-place gap: pusher on its ledges, one 0.2 mm layer of air (TEST)
// break-away zig-zag: the nut's top ring is printed on a thin zig-zag wall standing on the tray; the first turn of the
// nut shears it off (the stubs stay on the tray, under the nut, out of the way)
zz_h         = 0.8;  // its least height = gap between the tray's bottom face and the nut's top ring; rounded up (zz_hh)
                     // so the nut's underside lands on a layer boundary
zz_w         = 0.45; // wall thickness: one extrusion line (a bit over the 0.42 default line width, or the slicer may drop it)
zz_n         = 18;   // number of teeth round the ring (the nut's first layer bridges ~2 mm between lines)
zz_gap       = 0.2;  // one layer of air between the wall and the nut (like a support interface); 0 = fused: far too strong,
                     // ~80 mm of wall welded at both ends did not break by hand (TEST)
layer_h      = 0.2;  // slicer layer height (and first layer): the gap only slices as one empty layer if it is aligned to it
pip_side_gap = 0.35; // pusher in its column and its tip in the bore, per side: printed in place on long vertical faces (TEST)
pip_rgap     = 0.4;  // nut around the neck, radial (TEST)
pip_cone_gap = 0.4;  // nut's lip cone over the flange cone, at right angles to the cone (TEST)
pip_neck_d   = 18;   // neck between the tray and the flange: the pusher's bore + countersink inside
pip_flange_d = 27.6; // flange on the valve's thread face, inside the nut's thread (minor dia ~28.4)
pip_nut_od   = 36;
ledge_w      = 1;    // ledges beside the gear plates that stop the pusher (open) and carry it in the print
scr_floor_gap = 0.5; // screw's end above the floor, so it slides in over the floor
seat_gap     = 2.05; // drive unit's back end to the spring plate's front face: clr + the separator's slot (sep_t + 2 sep_clr)
                     // + 0.8 of seat block in front of the plate's groove (was 1.2 without the separator)
// separator: a printed card between the drive unit and the spring plate (bare metal on both sides: can, gear plates,
// contact plate). Can't be printed in place (the drive slides through there), so it is a loose part on print B: pushed
// up into slots in the side walls after the drive unit, from the manifold side; the lid holds it in
sep_t        = 0.8;  // card thickness (4 layers)
sep_clr      = 0.1;  // per side in its slot (along Y)
sep_slot     = 0.6;  // slot depth into each side wall
seat_x       = 6.6;  // the spring plate's side grooves start here: outside the motor channel (col_x)
// drive unit keeper: a leaf spring beside the gear plates' path, its tooth behind their back end (flexes in X, along
// its layers). Printed in place, its top edge pip_zgap under the front face
wire_h       = 3;
seat_cheek_h = 1.5;  // button plate's seat: cheeks reach this far below the cell's axis (up to the plate's top)
seat_cheek_w = 2;    // and this wide, from 1 mm inside the plate's edge    // motor wires: passage from the can's end through the channel's side wall, height
latch_t      = 0.7;  // leaf thickness
latch_len    = 13;   // leaf length along Y, from its free end (tooth) to its post
latch_tooth  = 1.2;  // tooth reaches this far in behind the plates' end
latch_gap    = 0.3;  // leaf's free end off the tray's face at the end of the column (so they don't fuse)
can_rib      = 0.35; // crush ribs under the front face on the gear plates: take out the 0.2 mm axial play (0.15 press). MEASURE: the plates' top face must be flat where they sit; if not, set 0 (the latch still keeps the drive unit in, the axial play stays)
can_rib_l    = 4;    // rib length along Y, at the plates' front end: they ride on over the last few mm

// gear motor as measured (2026-11-15): gearbox 4 thick, a 2.7 step around the shaft on its motor side (from the gearbox's
// screw end up to the can), can top 20.4 and terminals 22 above the gearbox's far face, shaft up to 20.4.
// Widths along the 20 mm side not measured yet: gp_scr, mot_offset, scr_d, mot_w/mot_h are still the old guesses
gp_boss_h    = 2.7;  // step around the shaft below the gear plates
holder_t     = 2;    // battery holders: thickness along the cell
holder_h     = 6.5;  // and how far above the cell's axis their 45 deg wedge reaches

include <valve_head_tray.scad>

gp_t    = 4;      // gearbox thickness
scr_len = 16.4;   // shaft beyond the gearbox (20.4 - 4)
mot_len = 18;     // can + terminals beyond the gearbox (22 - 4)
// more travel (2026-11-21): 5 mm of stroke was not enough. 6.7 gives 7.1 mm of travel (0.5 mount gap + 6.7 - 0.1), the
// most the 16.4 mm screw allows with the whole nut on it when closed; each mm more of travel makes the head 1 mm deeper
valve_stroke = 6.7;

part = "none";       // the included file draws nothing of its own
pip  = "assembly";   // assembly | section | section_closed | insert | tray | nut | pusher | lid | print | collide

/* ---------------- overrides of valve_head_tray.scad ---------------- */
// floor and pad: the screw's end has to clear the floor when the drive slides in, so the motor can stands on a pad
z_body0 = pin_top + mount_gap - pusher_trim + scr_clear - scr_floor_gap - base_t;
// the screw's end has to clear the floor; with the measured motor the pusher wins: 2 mm of pusher under the nut's boss,
// its top 0.5 under the gearbox's step
z_mot0  = max(z_floor + scr_floor_gap + scr_len,
              z_floor + travel + pu_rh + pu_loft + 2 + nut_clr + nut_boss_h + nut_len + gp_boss_h + 0.5 + 0.001) - mot_len;
z_nut1  = z_gp0 - gp_boss_h - 0.5;   // pusher's top, open: under the gearbox's step
// pusher channel: wider than the gear plates, so ledges are left beside the plates
col_x   = max(mot_w / 2, gp_w / 2 + ledge_w) + clr;
pu_x    = max(mot_w / 2, gp_w / 2 + ledge_w) + clr - pip_side_gap;   // = col_x - pip_side_gap (col_x is set later)
pu_y0   = -5.5;          // reaches past the plates' -Y end: the -Y ledge
y_min   = -body_w / 2;   // round nose around the valve axis
col_y0  = min(gp_y0 - clr, pu_y0 - pip_side_gap);   // pusher channel's -Y wall
tw_y1   = col_y1;        // no column wall towards the bay: the drive unit comes through there
y_batt0 = col_y1 + seat_gap;   // spring plate's rear face, just behind the drive unit

/* ---------------- derived ---------------- */
neck_r   = pip_neck_d / 2;
flange_r = pip_flange_d / 2;
z_fl_top = flange_h + flange_r - neck_r;       // top of the flange's 45 deg cone, on the neck
zz_hh    = layer_h * ceil((depth_total - z_body0 + zz_h) / layer_h - 0.001) - (depth_total - z_body0);   // zig-zag height, layer-aligned
z_n1     = z_body0 - zz_hh;                     // nut's top face: the break-away zig-zag under the tray
r_n_in   = neck_r + pip_rgap;                  // nut's bore around the neck
r_n_top  = body_w / 2 - 0.3;                   // nut's flat top ring ends here: inside the nose, so tray is over it
z_n_cyl  = z_n1 - (pip_nut_od / 2 - r_n_top);  // nut's grip cylinder ends here, a 45 deg cone above it
z_ledge  = z_nut1 + pip_zgap;                  // ledges' underside (pusher's top at its open stop + print gap)
mot_y0c  = mot_offset - mot_h / 2 - clr;       // motor channel starts here (the pusher channel ends here)
con_diag = con_w / sqrt(2);                    // spring plate turned 45 deg: its corners this far from its centre
lx0      = gp_w / 2 + clr + 0.3;               // latch leaf, inner face (beside the plates' path)
ly0      = col_y1 + latch_gap;                 // latch: tooth's catching face (behind the plates' end)
lx_t     = gp_w / 2 - latch_tooth;             // tooth's tip
ly_t1    = ly0 + 0.7 + (lx0 - lx_t);           // tooth's ramp ends on the leaf here (45 deg)
z_l0     = z_gp0 + 0.2;                        // latch: lower edge, above the motor can
latch_d  = gp_w / 2 + clr - lx_t;              // how far the tooth is pushed aside
latch_strain = 3 * latch_t * latch_d / (2 * latch_len * latch_len);
dy_drop  = max(y_batt0 + 0.3, ly_t1 + 0.3) - (gp_y0 - clr);   // drive unit dropped into the bay this far behind home: clear of cheek + latch
rib_front = max(10, dy_drop + gp_y1 + clr + 0.4 - y_cell0);   // first battery rib behind the dropped drive unit
holder_x0 = col_x + 0.35;                      // battery holder starts here (outside the drive unit's way down)
holder_yf = y_cell0 + 1;                        // front pair: just behind the cell's minus end
holder_yb = y_cell1 - 4 - holder_t;             // back pair: in front of the cell's plus end (clear of the button seat)
holder_xb = brd_w / 2 + board_fit + 0.15;       // back pair starts beyond the board's width
z_cheek1 = min(z_scr_tip, z_mot0) - 0.3;       // top of the cheek under the spring plate's bottom corner: the drive (its lowest part: can or screw) passes over
sep_y0   = tw_y1 + clr;                        // separator slot's front face (= the lid's front edge: the bay is open behind it)
sep_y1   = sep_y0 + sep_t + 2 * sep_clr;       // and its back face
sep_z0   = z_cover + clr;                      // card's bottom edge: on the lid
sep_z1   = z_l0 - 0.4;                         // card's top edge: under the latch leaf
// nut lip: perpendicular thickness between its lip cone and its outer cone (both 45 deg)
lip_perp = ((r_n_top + z_n1) - (flange_r + flange_h + pip_cone_gap * sqrt(2))) / sqrt(2);

echo(str("PIP: latch strain ", latch_strain * 100, " %, drop at dy ", dy_drop, ", first rib +", rib_front, ", spring plate at y ", y_batt0, "; depth ", depth_total, ", body ", body_w, " x ", y_max - y_min, ", nut ", pip_nut_od, " x ", z_n1 + thread_len,
         ", lip ", lip_perp, ", pad ", z_mot0 - z_floor));
assert(r_n_top <= body_w / 2 - 0.2, "nut's top ring sticks out of the nose: nothing to print it on");
assert(r_n_top - r_n_in >= 1.5, "nut's top ring too narrow to print on");
assert(flange_r + pip_cone_gap <= 14.2 + 0.001, "flange too wide for the nut's thread");
assert(z_n_cyl >= 0.5, "nut's grip cylinder doesn't cover its thread");
assert(lip_perp >= 2, "nut's lip too thin");
assert(z_fl_top < z_body0 - 1, "flange cone runs into the tray");
assert(z_scr_tip - 0.3 >= z_floor, "screw's end can't slide in over the floor");
assert(z_mot0 >= z_floor + 0.5, "motor pad too thin");
assert(y_batt0 - sep_y1 >= 0.8 - 0.001, "seat block between the separator and the spring plate too thin");
assert(sep_z1 >= z_batt + con_diag + con_tab, "separator lower than the spring plate's solder tab");
assert(z_batt + holder_h < z_l0 - 0.5, "front battery holders reach up into the latch");
assert(holder_yb + holder_t < y_cell1 - 1, "back battery holders behind the cell");
assert(pu_x - (gp_w / 2 + clr) >= 0.5, "pusher doesn't reach over the ledge beside the plates");
assert(gp_y0 - clr - pu_y0 >= 0.5, "pusher doesn't reach over the -Y ledge");
assert(latch_strain <= 0.01, "latch leaf bends too hard: longer or thinner");
assert(lx0 + latch_t + latch_d + 0.3 <= in_half, "no room beside the latch leaf for it to bend");
assert(z_l0 >= z_gp0 + 0.1 && z_top - pip_zgap - z_l0 >= 3.5, "latch too low (motor can) or too short (3.8 with the 4 mm gearbox)");
assert(seat_x >= col_x + 0.3, "spring plate's side grooves reach into the motor can's path");
assert(con_diag - seat_x >= 1.5, "spring plate's corners hardly reach into their grooves");
assert(con_diag + 0.3 <= in_half - 0.6, "spring plate's grooves cut through the side walls");
assert(z_cheek1 - (z_batt - con_diag) >= 1, "cheek too low to hold the spring plate's bottom corner");
assert(z_batt - con_diag >= z_cover + clr, "spring plate's bottom corner hits the lid");
assert(zz_hh - zz_gap >= 0.6 - 0.001, "zig-zag too low to print as a wall");
zz_nut_z = depth_total - z_n1;             // nut's underside above the bed in the print
assert(abs(zz_nut_z / layer_h - round(zz_nut_z / layer_h)) < 0.01, str("nut underside at ", zz_nut_z, " is not on a layer boundary: change zz_h"));
assert(abs(zz_gap / layer_h - round(zz_gap / layer_h)) < 0.01, "zz_gap must be whole layers");
assert(pip_side_gap >= clr, "pusher's print-in-place gap smaller than the general clearance");
assert(neck_r - (tip_d / 2 + clr + tip_sh) >= 3, "neck wall too thin around the countersink");

/* ---------------- shapes ---------------- */
// flange + neck in (r, z), up past the tray's bottom face
module flange_profile(top) {
    polygon([[0, 0], [flange_r, 0], [flange_r, flange_h], [neck_r, z_fl_top], [neck_r, top], [0, top]]);
}

module pip_outer() {
    // round nose around the valve axis, then the body as before
    translate([0, 0, z_body0]) hull() {
        cylinder(r = body_w / 2, h = depth_total - z_body0, $fn = 96);
        translate([0, y_max / 2, 0]) rounded_box([body_w, y_max, depth_total - z_body0], corner_r);
    }
}

module bay_cut() {
    // battery bay, open to the valve, from the drive column's +Y wall to the back wall
    intersection() {
        translate([0, (tw_y1 + y_max - wall) / 2 - 2, z_body0 - 1]) rounded_box([body_w - 2 * wall, y_max - wall - tw_y1 + 4, z_top - z_body0 + 1], corner_r - 1);
        translate([-body_w, tw_y1, z_body0 - 2]) cube([2 * body_w, y_max, z_top - z_body0 + 3]);
    }
}

module drive_cuts() {
    // bore for the pusher's tip through floor, neck and flange; countersink = closed stop (as on the old adapter)
    // (raised by the gap, so the pusher's chamfer still seats at the same height)
    translate([0, 0, -1]) cylinder(d = tip_d + 2 * pip_side_gap, h = z_floor + 2);
    translate([0, 0, z_floor + pip_side_gap - tip_sh]) cylinder(d1 = tip_d + 2 * pip_side_gap, d2 = tip_d + 2 * pip_side_gap + 2 * tip_sh, h = tip_sh);
    // pusher channel, up to the ledges (pip_side_gap round the pusher; towards the motor it runs into the motor channel)
    translate([-col_x, col_y0, z_floor - 0.01]) cube([2 * col_x, max(mot_y0c, pu_y1 + pip_side_gap) - col_y0 + 0.01, z_ledge - z_floor + 0.01]);
    // gear plates: their own outline from the ledges up (one way round: the chamfered corner stays solid) ...
    translate([0, 0, z_ledge - 0.01]) linear_extrude(z_col_top - z_ledge + 0.01) offset(delta = clr) gp_outline();
    // ... and swept back into the battery bay at plate level (the chamfered corner leads, so they fit one way only)
    translate([0, 0, z_gp0 - 0.1]) linear_extrude(z_col_top - z_gp0 + 0.1) hull() {
        offset(delta = clr) gp_outline();
        translate([0, dy_drop + 5]) offset(delta = clr) gp_outline();
    }
    // motor can: channel, open into the bay, on the pad
    translate([-col_x, mot_y0c, z_mot0]) cube([2 * col_x, tw_y1 - mot_y0c + 1, z_gp0 - z_mot0 + 0.01]);
    // motor wires: from the can's end out through the channel's side wall, then up a slot on the wire side to the
    // channel in the bay's top corner (as in valve_head_tray.scad). The slot opens into the bay, so the wires are laid in
    // after the drive unit (the spring plate's seat block covers its middle: slide them behind it)
    translate([wire_side < 0 ? -in_half : col_x - 0.01, col_y1 - wire_d - 0.6, z_mot0]) cube([in_half - col_x + 0.01, wire_d + 0.61, wire_h]);
    translate([wire_side < 0 ? -in_half : in_half - wire_ch, col_y1 - wire_d - 0.6, z_mot0]) cube([wire_ch, wire_d + 0.61, wire_z + wire_ch / 2 - z_mot0]);
    // screw: groove through the pad (its end hangs 1 mm under the can), out into the bay
    translate([-scr_bore / 2, mot_y0c - 0.01, z_scr_tip - 0.3]) cube([scr_bore, tw_y1 - mot_y0c + 1, z_mot0 - z_scr_tip + 0.31]);
}

module pip_breakaway() {
    // zig-zag wall between the tray's bottom face and the nut's top ring; part of the print only
    r1 = r_n_in + zz_w / 2 + 0.1;
    r2 = r_n_top - zz_w / 2 - 0.1;
    pts = [for (i = [0 : 2 * zz_n]) (i % 2 == 0 ? r1 : r2) * [cos(i * 180 / zz_n), sin(i * 180 / zz_n)]];
    translate([0, 0, z_n1 + zz_gap - (zz_gap > 0 ? 0 : 0.01)]) linear_extrude(zz_hh - zz_gap + (zz_gap > 0 ? 0.01 : 0.02))
        for (i = [0 : 2 * zz_n - 1]) hull() { translate(pts[i]) circle(d = zz_w, $fn = 8); translate(pts[i + 1]) circle(d = zz_w, $fn = 8); }
}

module diamond_seat() {
    // spring plate turned 45 deg: grooves for its side corners in small blocks on the side walls (outside the can's
    // path), a lip in front of it; and a cheek behind its bottom corner
    y0 = y_batt0;
    y1 = y0 + con_slot + con_lip;
    zg1 = z_batt + con_diag - seat_x + clr;   // groove's top: the plate's upper edges stop here
    for (sx = [0, 1]) mirror([sx, 0, 0]) difference() {
        // only around the corner groove; flat top: in the print it hangs off the column's back face and the side wall
        translate([seat_x, tw_y1 - 0.01, z_batt - (con_diag - seat_x) - 0.5]) cube([in_half - seat_x + 0.01, y1 - tw_y1 + 0.01, zg1 + 0.8 - (z_batt - (con_diag - seat_x) - 0.5)]);
        // the groove, open towards the valve: the plate pushes in until its upper edges stop at the groove's top
        translate([seat_x - 0.01, y0, z_body0 - 1]) cube([con_diag + 0.3 - seat_x + 0.01, con_slot, z_batt + con_diag - seat_x + clr - z_body0 + 1]);
    }
    // (only between the separator's slot and the plate: the separator goes up in front of it)
    translate([-2.5, sep_y1 - 0.01, z_cover + clr]) cube([5, y0 - sep_y1 + 0.01, z_cheek1 - z_cover - clr]);
}

module sep_card_2d(c = 0) {
    // separator outline in X/Z: across the bay into both wall slots; a notch for the motor wires' corner channel
    difference() {
        translate([-(in_half + sep_slot - sep_clr) - c, sep_z0 - c]) square([2 * (in_half + sep_slot - sep_clr + c), sep_z1 - sep_z0 + 2 * c]);
        translate([wire_side * (in_half - wire_ch / 2), wire_z]) square([wire_ch + 2 * clr - 2 * c, wire_ch + 2 * clr - 2 * c], center = true);
        translate([wire_side * (in_half + sep_slot), wire_z]) square([2 * sep_slot + 0.02, wire_ch + 2 * clr - 2 * c], center = true);
    }
}
module sep_card_flat(x, y) {   // flat on the bed, starting at x (+X), centred on y
    translate([x, y, 0]) rotate([0, 0, -90]) translate([0, -sep_z0, 0]) linear_extrude(sep_t) sep_card_2d();
}
module sep_card() {   // in place
    translate([0, sep_y0 + sep_clr + sep_t, 0]) rotate([90, 0, 0]) linear_extrude(sep_t) sep_card_2d();
}
module sep_slot_cut() {
    // slots in the side walls (through the spring plate's seat blocks), open down to the bay's opening
    translate([-(in_half + sep_slot), sep_y0, z_body0 - 1]) cube([2 * (in_half + sep_slot), sep_y1 - sep_y0, sep_z1 + 0.3 - z_body0 + 1]);
}

module latch() {
    // leaf spring with its tooth, on a post on the side wall under the front face (+X side: the plates' chamfered
    // corner leads on that side and pushes the tooth aside)
    h = z_top - pip_zgap - z_l0;
    translate([0, 0, z_l0]) {
        translate([lx0, ly0, 0]) cube([latch_t, latch_len + 0.01, h]);
        linear_extrude(h) polygon([[lx0 + 0.01, ly0], [lx_t, ly0], [lx_t, ly0 + 0.7], [lx0 + 0.01, ly_t1]]);
        // post, fused to the side wall and the front face
        translate([lx0, ly0 + latch_len, 0]) cube([in_half - lx0 + 0.01, 2, z_top - z_l0 + 0.01]);
    }
}

module button_seat() {
    // as contact_seat() in valve_head_tray.scad (open towards the valve, the plate stops at the top), but its cheeks
    // only hold the plate's upper part: shorter, narrower
    y0 = y_batt1; dir = -1; y_wall = y_batt1;
    z0 = z_batt - seat_cheek_h;
    z1 = z_batt + con_w / 2 + clr;
    y_front = y0 + dir * (con_slot + con_lip);
    difference() {
        for (sx = [0, 1]) mirror([sx, 0, 0]) translate([con_w / 2 - 1, 0, 0]) rotate([90, 0, 90]) linear_extrude(seat_cheek_w)
            polygon([[y_wall + 0.01, z0], [y_front, z0], [y_front, z1], [y_wall + 0.01, z1 + abs(y_front - y_wall)]]);
        translate([-con_w / 2 - 0.15, y0 - con_slot, z0 - 1]) cube([con_w + 0.3, con_slot, z1 - z0 + 1]);
    }
}

module pip_batt_ribs() {
    // as batt_ribs() in valve_head_tray.scad, but the first rib sits behind where the drive unit is dropped in
    z_r = z_pcb0 - 0.1;
    // trimmed to outside the board's width: the board goes in past them from the manifold side (it then holds the cell
    // towards the front face; the ribs only keep the cell centred)
    for (y = [y_cell0 + rib_front, y_cell1 - 10 - rib_t]) translate([0, y + rib_t, 0]) rotate([90, 0, 0]) linear_extrude(rib_t) difference() {
        for (sx = [0, 1]) mirror([sx, 0]) intersection() {
            polygon([[in_half + 0.01, z_batt], [in_half + 0.01, z_r], [in_half - (z_r - z_batt), z_batt]]);
            translate([brd_w / 2 + board_fit + 0.15, z_batt - 1]) square([in_half, z_r - z_batt + 2]);
        }
        translate([0, z_batt]) circle(d = batt_h);
        translate([wire_side * (in_half - wire_ch / 2), wire_z]) square([wire_ch + 0.02, wire_ch], center = true);
    }
}

module pip_contact_plates() {
    // spring plate turned 45 deg, its tab off the upper edge on the wire side; button plate as before
    translate([0, y_batt0, z_batt]) rotate([0, 45 * wire_side, 0]) {
        translate([-con_w / 2, 0, -con_w / 2]) cube([con_w, con_t, con_w]);
        translate([-1.5, 0, con_w / 2 - 0.01]) cube([3, con_t, con_tab + 0.01]);
        rotate([-90, 0, 0]) cylinder(d = 7, h = con_spring, $fn = 24);
    }
    translate([-con_w / 2, y_batt1 - con_t, z_batt - con_w / 2]) cube([con_w, con_t, con_w]);
    translate([-1.5, y_batt1 - con_t, z_batt + con_w / 2 - 0.01]) cube([3, con_t, con_tab + 0.01]);
    translate([0, y_cell1, z_batt]) rotate([-90, 0, 0]) cylinder(d = 6, h = con_dome, $fn = 24);
}

module pip_lid_2d(c = 0) {
    translate([-in_half - c, tw_y1 + clr - c]) square([2 * (in_half + c), y_max - tw_y1 + 1]);
}

module pip_lid_solid(c = 0) {
    translate([0, 0, z_body0 - 1]) linear_extrude(z_cover - z_body0 + 1 + c) pip_lid_2d(c);
    for (sx = [-1, 1]) translate([sx > 0 ? in_half - 0.01 : -in_half - lid_tg - c, tw_y1 + clr - c, z_body0 + lid_tg_z - c])
        cube([lid_tg + c + 0.01, y_max - tw_y1 + 1, lid_tg_h + 2 * c]);
}

/* ---------------- parts ---------------- */
module batt_holder() {
    // battery holders: small 45 deg wedges above the cell's axis on each side wall, one pair at each end of the cell,
    // centring it (like valve_head_tray.scad's ribs, smaller). Front pair: below the latch, starting outside the drive
    // unit's way down (holder_x0). Back pair: under the board, so only the strip beyond the board's width (holder_xb):
    // the board comes up past them on its way in
    z_r = z_batt + holder_h;
    for (h = [[holder_yf, holder_x0], [holder_yb, holder_xb]]) translate([0, h[0] + holder_t, 0]) rotate([90, 0, 0]) linear_extrude(holder_t) difference() {
        for (sx = [0, 1]) mirror([sx, 0]) intersection() {
            polygon([[in_half + 0.01, z_batt], [in_half + 0.01, z_r], [in_half - (z_r - z_batt), z_batt]]);
            translate([h[1], z_batt - 1]) square([in_half, z_r - z_batt + 2]);
        }
        translate([0, z_batt]) circle(d = batt_h);
        translate([wire_side * (in_half - wire_ch / 2), wire_z]) square([wire_ch + 0.02, wire_ch], center = true);
    }
}

module pip_tray() {
    difference() {
        union() {
            difference() { pip_outer(); bay_cut(); }
            // neck + flange, part of the tray now
            intersection() {
                rotate_extrude($fn = 96) flange_profile(z_body0 + 1);
                translate([0, 0, -1]) cylinder(r = flange_r + 1, h = z_body0 + 1.01);
            }
            board_seat(brd_w, y_brd0, y_brd1, z_brd1, pad_stop);
            diamond_seat();
            button_seat();
            batt_holder();
        }
        drive_cuts();
        sep_slot_cut();
        // board slot (as in valve_head_tray.scad)
        translate([-brd_w / 2 - board_fit, y_brd0 - clr, z_pcb0 - usb_dn - 0.5]) cube([brd_w + 2 * board_fit, brd_l + 2 * clr, z_brd1 - z_pcb0 + usb_dn + 0.5]);
        // lid, its grooves and the opening at the back end; the lid's front edge stops against the floor
        pip_lid_solid(clr);
        translate([-body_w, y_max - wall - 1, z_body0 - 1]) cube([2 * body_w, wall + 2, cover_t + 1 + clr]);
        translate([-tab_w / 2, y_max - wall + 0.1, z_cover - 0.01]) cube([tab_w, 1.4, tab_bump + 0.2]);
        // BOOT pin hole, light window, polarity marks, USB-C (as in valve_head_tray.scad)
        translate([btn_x, y_brd1 - btn_u, z_top - 0.01]) {
            cylinder(d = pin_d, h = depth_total - z_top + 1, $fn = 24);
            translate([0, 0, depth_total - z_top - 0.79]) cylinder(d1 = pin_d, d2 = pin_d + 1.6, h = 0.81, $fn = 24);
        }
        translate([led_x - led_win[0] / 2, y_brd1 - led_u - led_win[1] / 2, z_top - 0.01]) cube([led_win[0], led_win[1], lid_t - led_skin + 0.01 + (led_skin > 0 ? 0 : 1)]);
        for (sx = [0, 1]) mirror([sx, 0, 0]) {
            polarity_mark(y_cell0 + 5, false);
            polarity_mark(y_cell1 - 5, true);
        }
        translate([usb_x - usb_w / 2, y_max - wall - 0.5, z_usb - usb_h / 2]) cube([usb_w, wall + 1, usb_h]);
        translate([usb_x - usb_rec[0] / 2, y_max - (wall - usb_wall), z_usb - usb_rec[1] / 2]) cube([usb_rec[0], 2, usb_rec[1]]);
    }
    latch();   // after the cuts: the gear plates' slot would cut its tooth off
    // crush ribs under the front face, along the way in, rounded ends, near the plates' front end (clear of their
    // chamfer): the plates ride under them over the last few mm and the drive unit is clamped between pad and front face
    // (no axial play, held against sliding back). On the front face: they grow up from the bed side in the print
    for (x = [-3, 3]) intersection() {
        hull() for (y = [gp_y0 + 4, gp_y0 + 4 + can_rib_l]) translate([x, y, z_col_top]) sphere(r = can_rib * 3, $fn = 24);
        translate([x - 2, gp_y0, z_col_top - can_rib]) cube([4, 2 * can_rib_l + 4, can_rib + 0.01]);
    }
}

module pip_nut() {
    // in place; printed with the tray. Flat top ring on the tray (pip_zgap), everything else 45 deg or steeper
    difference() {
        rotate_extrude($fn = 96) polygon([
            [r_n_in, -thread_len], [pip_nut_od / 2, -thread_len], [pip_nut_od / 2, z_n_cyl],
            [r_n_top, z_n1], [r_n_in, z_n1]]);
        translate([0, 0, -thread_len - 0.01]) int_thread_cut(30, 1.5, thread_len + 0.02, clr);
        // flange + neck with the print-in-place gap all round
        rotate_extrude($fn = 96) intersection() { offset(r = pip_cone_gap, $fn = 16) flange_profile(z_body0 + 2); translate([0, -5]) square([30, 30]); }
        // grip, on the cylinder only
        for (a = [0 : 30 : 359]) rotate(a)
            translate([pip_nut_od / 2 + 0.6, 0, -thread_len - 1]) cylinder(d = 3, h = z_n_cyl + thread_len + 1, $fn = 16);
    }
}

module pip_pusher(s = 0) {
    // in place; s = travel (0 = open). As in valve_head_tray.scad, but wider (it reaches over the ledges) and with a slot
    // towards the motor for the screw: the drive unit slides in from that side, the nut flats first into the open pocket
    translate([0, 0, -s]) difference() {
        union() {
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
            tip_with_chamfer(z_shoulder, z_shoulder - z_tip);
        }
        // nut pocket (hex flush with the top, boss below), open at the top and towards the motor as before
        translate([0, 0, z_nut0 - nut_clr]) hex(nut_af + 2 * nut_clr, nut_len + 2 * nut_clr + 1);
        translate([0, 0, z_boss0 - nut_clr]) cylinder(d = nut_boss_d + 2 * nut_clr, h = nut_boss_h + 0.01);
        translate([-(nut_af / cos(30)) / 2 - nut_clr, 0, z_boss0 - nut_clr]) cube([nut_af / cos(30) + 2 * nut_clr, 10, nut_len + nut_boss_h + 2 * nut_clr + 1]);
        for (a = [30, 330]) rotate(a) translate([(nut_af / 2 + nut_clr) / cos(30), 0, z_nut0 - nut_clr])
            cylinder(d = 1, h = nut_len + 2 * nut_clr + 1, $fn = 12);
        hull() {
            translate([0, 0, z_nut1 - 0.4]) hex(nut_af + 2 * nut_clr, 0.01);
            translate([0, 0, z_nut1]) hex(nut_af + 2 * nut_clr + 0.8, 0.01);
        }
        // screw slot towards the motor, down to just under the screw's end
        translate([-scr_bore / 2, 0, z_scr_tip - 0.4]) cube([scr_bore, 10, 30]);
        translate([0, 0, z_scr_tip - 0.4]) cylinder(d = scr_bore, h = 50, $fn = 24);
    }
}

module pip_lid() {
    difference() {
        intersection() { pip_lid_solid(); pip_outer(); }
        for (sx = [-1, 1]) translate([sx * (tab_w / 2 + 0.4) - 0.4, y_max - tab_l, z_body0 - 1]) cube([0.8, tab_l + 1, cover_t + 2]);
        translate([-tab_w / 2 - 0.4, y_max - tab_l, z_body0 - 1]) cube([tab_w + 0.8, tab_l + 1, cover_t - tab_t + 1]);
        for (m = [[y_cell0 + 4, "-"], [y_cell1 - 16, "+"]]) translate([0, m[0], z_cover - 0.4]) linear_extrude(1)
            text(m[1], size = 8, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
    }
    translate([0, y_max - wall + 0.3, z_cover - 0.01]) rotate([90, 0, 90]) linear_extrude(tab_w - 1, center = true)
        polygon([[0, 0], [1.2, 0], [1.2, tab_bump], [0.6, tab_bump]]);
}

// the drive unit as one piece: dy = slid back into the bay, dz = still below its height (dropping in); nut open
module gp_boss_2d() {   // the gearbox's step: from its screw end to the can, its full width (no width measured: the worst case)
    intersection() { gp_outline(); translate([-gp_w, gp_y0 - 1]) square([2 * gp_w, mot_offset - mot_h / 2 - gp_y0 + 1]); }
}
module pip_motor(s = 0) {   // valve_head_tray.scad's motor() plus the gearbox's step
    motor(s);
    color("goldenrod") translate([0, 0, z_gp0 - gp_boss_h]) linear_extrude(gp_boss_h + 0.01) gp_boss_2d();
}
module drive_unit(dy = 0, s = 0, dz = 0) { translate([0, dy, -dz]) pip_motor(s); }

module pip_ghosts(s = 0, dx = 0) {
    drive_unit(dx, s);
    color("royalblue", 0.4) cell();
    color("silver") pip_contact_plates();
    color("darkgreen") rollo_board();
    color("lightblue", 0.3) translate([0, 0, -thread_len]) cylinder(d = 30, h = thread_len);
    color("lightblue", 0.6) cylinder(d = 3, h = pin_top - max(0, s - mount_gap) - 0.01, $fn = 16);
}

module print_set() {
    // one print: tray + nut + pusher, front face down. Turned over, never mirrored (the nut's thread)
    translate([0, 0, depth_total]) rotate([0, 180, 0]) { pip_tray(); pip_breakaway(); pip_nut(); pip_pusher(); }
}

// every part and placeholder cut by children(0), each in its own colour
module cut_parts(s) {
    color("white") intersection() { pip_tray(); children(0); }
    color("lightsteelblue") intersection() { pip_lid(); children(0); }
    color("darkorange") intersection() { pip_nut(); children(0); }
    color("violet") intersection() { pip_pusher(s); children(0); }
    color("goldenrod") intersection() { union() { translate([0, 0, z_gp0]) linear_extrude(gp_t) gp_outline(); translate([0, 0, z_gp0 - gp_boss_h]) linear_extrude(gp_boss_h + 0.01) gp_boss_2d(); } children(0); }
    color("silver") intersection() { translate([-mot_w / 2, mot_offset - mot_h / 2, z_gp0 - mot_len]) cube([mot_w, mot_h, mot_len]); children(0); }
    color("dimgray") intersection() { translate([0, 0, z_scr_tip]) cylinder(d = scr_d, h = scr_len, $fn = 16); children(0); }
    color("red") intersection() { translate([0, 0, -s]) { translate([0, 0, z_nut0]) hex(nut_af, nut_len); translate([0, 0, z_boss0]) cylinder(d = nut_boss_d, h = nut_boss_h); } children(0); }
    color("royalblue") intersection() { cell(); children(0); }
    color("darkgreen") intersection() { rollo_board(); children(0); }
    color("lightblue") intersection() { union() { translate([0, 0, -thread_len]) cylinder(d = 30, h = thread_len); cylinder(d = 3, h = pin_top - max(0, s - mount_gap) - 0.01, $fn = 16); } children(0); }
}

/* ---------------- output ---------------- */
insert_dy = 12;   // pip="insert": how far back in the bay the drive unit still is
xsec_y    = -1;   // pip="xsection": where the cut is
y_coupon  = ly0 + latch_len + 2 + 1.5;   // pip="coupon": cut here (behind the latch's post)
insert_dz = 0;    // pip="drop": how far below its height

if (pip == "assembly") {
    color("white") pip_tray(); color("lightsteelblue") pip_lid();
    color("darkorange") pip_nut(); color("violet") pip_pusher(); color("red") pip_breakaway();
    pip_ghosts();
} else if (pip == "breakaway") {
    // the nut lifted off to show the zig-zag on the tray's bottom face
    color("white") pip_tray(); color("red") pip_breakaway(); color("darkorange", 0.5) translate([0, 0, -25]) pip_nut();
} else if (pip == "section" || pip == "section_closed") {
    // cut along the body through the valve axis (keeps x > 0), each part cut and coloured on its own
    s = pip == "section" ? 0 : travel;
    cut_parts(s) translate([0, -100, -50]) cube([100, 300, 150]);
} else if (pip == "xsection") {
    // cut across the body just behind the valve axis (keeps y > xsec_y): nut, flange, ledges, side window
    cut_parts(0) translate([-100, xsec_y, -50]) cube([200, 300, 150]);
} else if (pip == "insert") {
    color("white") pip_tray(); color("darkorange") pip_nut(); color("violet") pip_pusher();
    drive_unit(insert_dy);
    color("silver", 0.5) translate([0, 0, -20]) pip_contact_plates();   // spring plate: goes in after, from the valve side
} else if (pip == "drop") {
    // drive unit dropped into the bay behind the column, before it slides in
    color("white") pip_tray(); color("darkorange") pip_nut(); color("violet") pip_pusher();
    drive_unit(dy_drop, 0, insert_dz);
} else if (pip == "tray") {
    translate([0, 0, depth_total]) rotate([0, 180, 0]) pip_tray();
} else if (pip == "nut") {
    pip_nut();
} else if (pip == "pusher") {
    pip_pusher();
} else if (pip == "lid") {
    translate([0, 0, -z_body0]) pip_lid();
} else if (pip == "print") {
    print_set();
    translate([-(body_w + 18), 0, -z_body0]) pip_lid();   // on the other side of the tray
    sep_card_flat(body_w / 2 + 8, 40);   // separator card beside the tray
} else if (pip == "print_a") {
    print_set();   // print A: tray with the nut and pusher printed in place, no lid
} else if (pip == "print_b") {
    translate([0, 0, -z_body0]) pip_lid();   // print B: the lid and the separator card (flat)
    sep_card_flat(body_w / 2 + 6, 40);
} else if (pip == "coupon") {
    // print test: the front of the one print (nut, zig-zag, pusher, drive column, latch), cut behind the latch's post.
    // Tests zz_gap, pip_rgap, pip_cone_gap, pip_zgap (pusher and latch) and the drive unit's fit. Open at the cut, so
    // the drive unit slides straight in from there
    intersection() { print_set(); translate([-50, -50, -50]) cube([100, y_coupon + 50, 150]); }
} else if (pip == "collide") {
    // set collide_a / collide_b; an empty result = no collision
    intersection() {
        if (collide_a == "tray") pip_tray(); else if (collide_a == "nut") pip_nut(); else if (collide_a == "pusher") pip_pusher(collide_s);
        if (collide_b == "nut") pip_nut(); else if (collide_b == "pusher") pip_pusher(collide_s); else if (collide_b == "drive") drive_unit(collide_dy, collide_s, collide_dz);
        else if (collide_b == "plates") pip_contact_plates();
        else if (collide_b == "lid") pip_lid();
    }
}
collide_a = "tray"; collide_b = "nut"; collide_s = 0; collide_dy = 0; collide_dz = 0;

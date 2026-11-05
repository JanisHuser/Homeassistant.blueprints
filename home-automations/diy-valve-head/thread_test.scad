// Test pieces for the adapter's left-hand thread into the tray (valve_head_tray.scad).
// - coupon: the real tray cut down to the part around the thread, printed the same way up as the tray
// - plugs: the adapter's thread with a growing clearance, on a fluted grip. They also fit a tray you already
//   printed. The number under the grip is the clearance per side in 1/100 mm; the best one becomes bt_gap.
// Render with  openscad -D 'test="plate"' -o plate.3mf thread_test.scad

include <valve_head_tray.scad>

part = "none";      // the included file draws nothing of its own

test = "plate";     // plate | coupon | plug
gap  = 0.35;        // test="plug": clearance per side
gaps = [0.25, 0.35, 0.45, 0.55, 0.65];

coupon_y1 = 12;     // past the ears, so they stand as they do in the tray
coupon_z1 = z_floor + ear_up + 2.5;   // a foot under the ears, so they bridge as they do in the tray

grip_h = 2.5;       // the neck up to the shoulder, as on the adapter, just tall enough to hold

module coupon() {
    // print front face down, like the tray
    translate([0, 0, coupon_z1]) rotate([0, 180, 0]) intersection() {
        tray();
        translate([-body_w, y_min - 1, z_body0 - 1]) cube([2 * body_w, coupon_y1 - y_min + 1, coupon_z1 - z_body0 + 1]);
    }
}

module plug(g) {
    // in place, like adapter(), so its thread lines up with the tray's; prints grip down, thread up
    r_root = bt_d / 2 - 2 * bt_p * 0.36 - g;   // lead-in: from the thread's root at the tip up to its crest
    translate([0, 0, grip_h - z_body0]) difference() {
        union() {
            translate([0, 0, z_body0 - grip_h]) cylinder(d = neck_d, h = grip_h);
            intersection() {
                body_thread(z_body0 - 0.01, base_t + 0.01, -g);
                union() {
                    translate([0, 0, z_body0 - 1]) cylinder(d = bt_d + 1, h = base_t - 0.1);
                    translate([0, 0, z_floor - 1.1 - 0.01]) cylinder(r1 = r_root + 1.11, r2 = r_root, h = 1.11);
                }
            }
        }
        // the adapter's bore, so the thread flexes the same
        translate([0, 0, z_body0 - grip_h - 1]) cylinder(d = tip_d + 2 * clr, h = grip_h + base_t + 2);
        // grip, stops short of the shoulder so it still seats all round
        for (a = [0 : 30 : 359]) rotate(a)
            translate([neck_d / 2 + 0.6, 0, z_body0 - grip_h - 1]) cylinder(d = 3, h = grip_h, $fn = 16);
        // clearance per side in 1/100 mm, cut into the underside: mirrored, so it reads from below
        translate([7.4, 0, z_body0 - grip_h - 1]) mirror([1, 0, 0])
            linear_extrude(1.6) text(str(round(g * 100)), size = 4.5, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
    }
}

if (test == "coupon") {
    coupon();
} else if (test == "plug") {
    plug(gap);
} else if (test == "plate") {
    translate([-45, -y_min - (coupon_y1 - y_min) / 2, 0]) coupon();
    for (i = [0 : len(gaps) - 1]) translate([0, (i - (len(gaps) - 1) / 2) * 27, 0]) plug(gaps[i]);
}

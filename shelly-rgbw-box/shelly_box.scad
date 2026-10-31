// =====================================================================
//  Kleine Box für LED-Steuerung
//  - Shelly Plus RGBW PM
//  - Purecrea 3-Pin DC Einbaubuchse 5.5 / 2.1 mm (Gewinde-Typ DC-022)
//  - WAGO 221-415 (5-fach) zum Verteilen von +V
//
//  Links:  DC-Buchse in der Wand
//  Mitte:  WAGO-Klemme (Einführungen zeigen nach links/rechts)
//  Rechts: Shelly, dahinter 4 Kabelauslässe (ein LED-Streifen pro Kanal)
//          mit je einer Kabelbinder-Brücke
//  Deckel: 4x M3 Blechschraube (oder M3 in 2.5 mm Bohrung), Lüftungsschlitze
//
//  Alle Bauteil-Masse sind Datenblatt-/Schätzwerte: nachmessen!
//  Export:  part = "box" / "lid"
// =====================================================================

/* [Ansicht / Export] */
part = "assembly"; // [assembly, exploded, box, lid, jack_adapter]

/* [Shelly Plus RGBW PM] */
shelly_l = 43;    // entlang X
shelly_w = 38;
shelly_h = 17;

/* [WAGO 221-415 (5-fach)] */
wago_l = 29.7;    // über alle 5 Klemmstellen
wago_w = 18.7;    // Hebel -> Leitereinführung
wago_h = 8.5;     // Hebel geschlossen

/* [DC-Buchse] */
jack_hole_d = 11.2;  // Wandloch: 11.2 mit Reduzierring, 8.2 = Buchse direkt (ohne Ring)
jack_z      = 11;    // Mitte über Innenboden
jack_space  = 22;    // Platz hinter der Wand (Körper + Lötfahnen)

/* [Reduzierring für die DC-Buchse] */
// Steckt im Loch jack_hole_d, Bund innen; Buchse mit kleinerem Gewinde
jack_thread_d = 8;   // Purecrea: Montageloch 8 mm -> M8, max. 3 mm Plattendicke
ad_clr        = 0.3; // Spiel Gewinde
ad_fit        = 0.2; // Spiel im Wandloch
ad_flange_d   = 16;  // Bund-Ø (innen an der Wand)
ad_flange_t   = 0.6;  // Wand 2.4 + Bund 0.6 = 3 mm (Maximum der Buchse)
ad_threaded   = true; // Innengewinde: Buchse direkt einschrauben
jack_pitch    = 0.75; // M8x0.75 (übliche Feingewinde dieser Buchsen)
ad_thread_clr = 0.2;  // Spiel Gewinde (radial)

/* [LED-Kabel] */
cable_n     = 4;    // Anzahl Auslässe (1 pro Kanal R/G/B/W bzw. 4x Weiss)
wire_d      = 2.4;  // Litze 0.5 mm² inkl. Isolation (nachmessen!)
wire_n      = 2;    // Adern pro Auslass (+V und Kanal)
wire_clr    = 0.4;  // Spiel
cable_pitch = 11;   // Abstand der Auslässe
cable_z     = 7;    // Mitte über Innenboden

/* [Gehäuse] */
t        = 2.4;   // Wandstärke
floor_t  = 2.4;   // Bodenstärke
lid_t    = 2;     // Deckelstärke
inner_h  = 24;    // Innenhöhe (Shelly 17 + Kabel)
clr      = 0.6;   // Spiel um Bauteile
gap      = 6;     // Abstand WAGO <-> Shelly
side_gap = 8;     // Platz neben dem Shelly (Kabel zu den Klemmen)
end_gap  = 16;    // Platz zwischen Shelly und Kabelauslässen
r        = 3;     // äussere Eckenrundung
stop_h   = 4;     // Höhe der Halte-Winkel am Boden

/* [Schrauben] */
post_d       = 7;    // Deckel-Schraubdom
pilot_d      = 2.5;  // M3 selbstschneidend
lid_hole_d   = 3.4;
lid_head_d   = 6.4;  // Senkkopf
mount_holes  = true; // 2 Senklöcher im Boden für Wandmontage
mount_d      = 4.2;
mount_head_d = 8;

$fn = 48;

// ---------- abgeleitete Masse ----------
inner_l = jack_space + wago_w + 2*clr + gap + shelly_l + 2*clr + end_gap;
inner_w = max(shelly_w, wago_l) + 2*clr + 2*side_gap;
L = inner_l + 2*t;
W = inner_w + 2*t;
H = floor_t + inner_h;

wago_x   = t + jack_space;                         // Taschenanfang (inkl. Spiel)
shelly_x = wago_x + wago_w + 2*clr + gap;
post_c   = post_d/2 - 0.5;                         // Dommitte ab Innenecke
lip_h    = 3;
lip_t    = 1.6;

echo(str("Box aussen: ", L, " x ", W, " x ", H + lid_t, " mm"));

module rbox(l, w, h, rr) {
    hull() for (x = [rr, l - rr], y = [rr, w - rr])
        translate([x, y, 0]) cylinder(r = rr, h = h);
}

function cable_ys() = [for (i = [0 : cable_n - 1]) W/2 + (i - (cable_n - 1)/2) * cable_pitch];

function post_pos() = [for (x = [t + post_c, L - t - post_c], y = [t + post_c, W - t - post_c]) [x, y]];

// Dom, mit der Ecke verschmolzen
module post_shape(h, grow = 0) {
    for (p = post_pos()) {
        cx = p[0] < L/2 ? t : L - t;
        cy = p[1] < W/2 ? t : W - t;
        hull() {
            translate([p[0], p[1], 0]) cylinder(d = post_d + 2*grow, h = h);
            translate([min(cx, p[0]) - grow, min(cy, p[1]) - grow, 0])
                cube([abs(p[0] - cx) + 2*grow, abs(p[1] - cy) + 2*grow, h]);
        }
    }
}

// L-Winkel an allen 4 Ecken einer Tasche (Innenmass a x b)
module corner_stops(a, b, h, leg = 6, th = 1.6) {
    for (mx = [0, 1], my = [0, 1])
        translate([mx*a, my*b, 0]) mirror([mx, 0, 0]) mirror([0, my, 0])
            translate([-th, -th, 0]) {
                cube([leg, th, h]);
                cube([th, leg, h]);
            }
}

module countersink(d, head_d, depth) {
    // Kopf oben (z = depth)
    translate([0, 0, -1]) cylinder(d = d, h = depth + 2);
    translate([0, 0, depth - (head_d - d)/2]) cylinder(d1 = d, d2 = head_d, h = (head_d - d)/2 + 0.01);
    translate([0, 0, depth]) cylinder(d = head_d, h = 1);
}

module box() {
    difference() {
        union() {
            difference() {
                rbox(L, W, H, r);
                translate([t, t, floor_t]) cube([inner_l, inner_w, inner_h + 1]);
            }
            translate([0, 0, floor_t]) post_shape(inner_h);

            // Halter Shelly
            translate([shelly_x, (W - shelly_w)/2 - clr, floor_t])
                corner_stops(shelly_l + 2*clr, shelly_w + 2*clr, stop_h);
            // Halter WAGO (90° gedreht: Klemmstellen entlang Y)
            translate([wago_x, (W - wago_l)/2 - clr, floor_t])
                corner_stops(wago_w + 2*clr, wago_l + 2*clr, stop_h - 1);
            // Kabelbinder-Brücke vor jedem Auslass (Binder läuft quer unter dem Steg durch)
            for (y = cable_ys())
                translate([L - t - end_gap/2 - 4, y - 3, floor_t])
                    difference() {
                        cube([8, 6, 4]);
                        translate([2, -1, -0.01]) cube([4, 8, 2.2]);
                    }
        }
        // DC-Buchse (linke Wand)
        translate([-1, W/2, floor_t + jack_z]) rotate([0, 90, 0])
            cylinder(d = jack_hole_d, h = t + 2);
        // LED-Kabelauslässe (rechte Wand)
        for (y = cable_ys())
            // Langloch: Adern nebeneinander
            hull() for (i = [0 : wire_n - 1])
                translate([L - t - 1, y + (i - (wire_n - 1)/2) * wire_d, floor_t + cable_z])
                    rotate([0, 90, 0]) cylinder(d = wire_d + wire_clr, h = t + 2);
        // Deckelschrauben
        for (p = post_pos())
            translate([p[0], p[1], H - 12]) cylinder(d = pilot_d, h = 13);
        // Wandmontage: Senkkopf innen
        if (mount_holes)
            for (x = [t + jack_space/2, shelly_x + clr + shelly_l/2])
                translate([x, W/2, 0]) countersink(mount_d, mount_head_d, floor_t);
    }
}

// Deckel in Einbaulage: Platte z = 0..lid_t, Zentrierrand nach unten
module lid() {
    difference() {
        union() {
            rbox(L, W, lid_t, r);
            translate([0, 0, -lip_h]) difference() {
                translate([t + clr, t + clr, 0]) cube([inner_l - 2*clr, inner_w - 2*clr, lip_h]);
                translate([t + clr + lip_t, t + clr + lip_t, -1])
                    cube([inner_l - 2*clr - 2*lip_t, inner_w - 2*clr - 2*lip_t, lip_h + 2]);
                translate([0, 0, -1]) post_shape(lip_h + 2, clr);
            }
        }
        for (p = post_pos())
            translate([p[0], p[1], 0]) countersink(lid_hole_d, lid_head_d, lid_t);
        // Lüftungsschlitze über dem Shelly
        for (i = [0 : 4])
            translate([shelly_x + clr + 4 + i * (shelly_l - 8) / 4 - 1, W/2 - 12, -1])
                cube([2, 24, lid_t + 2]);
    }
}

// Reduzierring: Zapfen im Wandloch (bündig aussen), Bund innen, druckt Bund unten
module jack_adapter() {
    difference() {
        union() {
            cylinder(d = ad_flange_d, h = ad_flange_t);
            cylinder(d = jack_hole_d - 2*ad_fit, h = ad_flange_t + t);
        }
        if (ad_threaded)
            translate([0, 0, -1]) thread_cut(jack_thread_d + 2*ad_thread_clr, jack_pitch, ad_flange_t + t + 2);
        else
            translate([0, 0, -1]) cylinder(d = jack_thread_d + 2*ad_clr, h = ad_flange_t + t + 2);
        // Fase an beiden Enden zum leichten Ansetzen
        for (z = [0, ad_flange_t + t]) translate([0, 0, z])
            cylinder(d1 = jack_thread_d + 1.2, d2 = jack_thread_d - 0.4, h = 0.8, center = true);
    }
}

// Metrisches Gewinde (Bolzenform) zum Abziehen: Querschnitt r(θ) = Flankenprofil,
// mit Drall extrudiert -> eingängige Schraubenlinie mit 60°-Trapezprofil
module thread_cut(d, p, h, steps = 72) {
    r_maj = d/2;
    r_min = d/2 - 0.5413 * p;              // ISO: d1 = d - 1.0825 p
    function prof(u) =                     // u = Position in der Steigung, 0..1
        u < 0.125 ? r_maj :                // Spitze (P/8 flach)
        u < 0.4375 ? r_maj - (r_maj - r_min) * (u - 0.125) / 0.3125 :
        u < 0.6875 ? r_min :               // Grund (P/4 flach)
        r_min + (r_maj - r_min) * (u - 0.6875) / 0.3125;
    linear_extrude(height = h, twist = -360 * h / p, slices = ceil(h / p * 24), convexity = 4)
        polygon([for (i = [0 : steps - 1]) let(a = 360 * i / steps) prof(i / steps) * [cos(a), sin(a)]]);
}

// grobe Platzhalter nur für die Vorschau
module dummies() {
    color("#e0e0e0") translate([shelly_x + clr, (W - shelly_w)/2, floor_t]) cube([shelly_l, shelly_w, shelly_h]);
    color("#f2f2f2") translate([wago_x + clr, (W - wago_l)/2, floor_t]) cube([wago_w, wago_l, wago_h]);
    color("#f5a623") for (i = [0 : 4])
        translate([wago_x + clr + wago_w - 5, (W - wago_l)/2 + 1.5 + i * (wago_l - 3)/5, floor_t + wago_h])
            cube([5, (wago_l - 3)/5 - 0.8, 1.5]);
    color("#333") translate([t, W/2, floor_t + jack_z]) rotate([0, 90, 0]) cylinder(d = 13, h = 15);
    color("#333") translate([-3, W/2, floor_t + jack_z]) rotate([0, 90, 0]) cylinder(d = 14, h = 3, $fn = 6);
}

if (part == "box") box();
else if (part == "jack_adapter") jack_adapter();
else if (part == "lid") translate([0, 0, lid_t]) rotate([180, 0, 0]) translate([0, -W, 0]) lid();
else if (part == "exploded") {
    color("#5b8def") box();
    dummies();
    color("#9bbcf5", 0.9) translate([0, 0, H + 25]) lid();
}
else {
    color("#5b8def") box();
    dummies();
    color("#9bbcf5", 0.5) translate([0, 0, H]) lid();
}

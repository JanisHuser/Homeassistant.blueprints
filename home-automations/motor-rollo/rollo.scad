// ============================================================
//  Motorrollo auf Basis IKEA FÖNSTERBLAD 80x155  –  Matter über Thread
//  Akku + N20-Encodermotor im Originalrohr (Innen-Ø ~22 mm), komplett
//  ohne Schrauben: Halter mit 3M VHB, sonst Schnapphaken, Pressitz,
//  Rastnase und ein Filament-Stift.
//
//  Aufbau (Achse = X, Motorseite links bei x = 0 = Wand):
//   [Halter]─[Kopf Ø28: USB-C (unten) │ Motorplatine (../motor-board)]─[Endkappe]═ IKEA-Rohr ═[608 direkt im Rohr]─[Achse]─[Halter]
//                     └─ Journal ─ Kartusche: 18650 │ N20 ─ Mitnehmer (dreht Rohr)
//
//  Kopf, Journal und Kartusche stehen fest (Vierkantkeil im Halter),
//  das Rohr dreht sich darum. Die Platine mit dem ESP32-H2 sitzt ausserhalb des
//  Alu-Rohrs, sonst kommt kein Funk durch.
//
//  Vor dem Druck nachmessen: tube_id, tube_od, Motor (mot_*),
//  Ausschnitt der USB-C-Buchse (usb_panel).
//
//  Einzelteil wählen:  part = "...";   oder
//    openscad -D 'part="cartridge"' -o cartridge.stl rollo.scad
//  Alle Teile sind fürs Drucken bereits richtig orientiert.
// ============================================================

part = "assembly"; // [assembly, bracket_motor, bracket_idle, head_body, head_lid, head_key, cap_motor, idle_axle, cartridge, drive_adapter]

$fn = 96;
eps = 0.01;

/* [Einbau] */
recess_w = 850;     // lichte Breite zwischen den Wänden
fit_gap  = 2;       // Luft gesamt

/* [IKEA-Rohr – nachmessen!] */
tube_id    = 22;    // 608-Lager passt laut Thingiverse 6775493 ohne Adapter
tube_od    = 25;    // Annahme
fabric_t   = 0.4;   // Stoffdicke
fabric_len = 1050;  // aufgewickelte Länge (95 cm + Reserve)

/* [Toleranzen] */
clr      = 0.3;
rib_i    = 0.3;     // Übermass der Klemmrippen im Rohr
pin_hole = 1.9;     // für 1.75-mm-Filament als Stift

/* [Halter (VHB-Klebeband auf Rückseite bzw. Flansch)] */
br_t      = 6;
br_w      = 30;
flange_t  = 3;
flange_l  = 15;
top_clear = 1.5;    // Luft Stoffwickel ↔ Flansch
pocket_d  = br_t - 1.2;
tenon     = 10;     // Vierkant
drop      = 2.5;    // Einhängetiefe

/* [Kopf (Elektronik)] */
head_d      = 28;
head_wall   = 1.6;
face_t      = 3.5;  // Boden zur Wand
key_pocket  = 3;
usb_l       = 10;   // Abschnitt für die USB-C-Einbaubuchse
board_l     = 33;   // Motorplatine: Antenne 3.03 + Platine 27.6 + Platz für die Kabel Richtung Journal
lid_t       = 3;
hook_angles = [90, 210, 330];
hook_w      = 5;
hook_t      = 1.2;
usb_panel   = [9.3, 3.6]; // Ausschnitt Schnapp-Buchse (X, Y) – an der Buchse nachmessen
journal_od  = 14;
journal_id  = 9;    // Kabeldurchgang
key_z       = 4.8;  // Abflachung = Verdrehsicherung Journal ↔ Kartusche
jour_engage = 7;

/* [Motorplatine, siehe ../motor-board] */
brd_l      = 27.6;
brd_w      = 21;
brd_t      = 0.8;
brd_z      = -2;     // Unterkante Platine; darunter 1.7 mm Bauteile, darüber 4.6 mm Super Mini mit USB-C
brd_under  = 1.7;
esp_stack  = 4.6;
esp_w      = 18.4;
esp_over   = 3.03;   // Antenne des Super Mini ragt so weit über die Platine, Richtung Wand
rail_in    = 10;     // Schienen decken die Platine von hier bis zur Kante ab, die Randpads bleiben frei
rail_clr   = 0.1;

/* [Endkappe Motorseite] */
cap_flange = 1.5;
cap_plug   = 10;

/* [Lager 608 (direkt im Rohr)] */
b608_d  = 22;
b608_w  = 7;
b608_id = 8;

/* [Motor GA12-N20 mit Encoder – nachmessen!] */
mot_w        = 12;   // Getriebe Breite
mot_h        = 10;   // Getriebe Höhe (Abflachungen oben/unten = Verdrehsicherung)
mot_len      = 36;   // Getriebe + Motor + Encoder
mot_boss_d   = 4;
mot_shaft_d  = 3;
mot_shaft_D  = 2.5;  // Mass über Abflachung
mot_shaft_len= 10;

/* [Kartusche] */
cart_od    = tube_id - 1;
cart_flat  = 0.6;
cell_d     = 18.6;   // 18650 ungeschützt
cell_z     = 0.3;    // Zelle leicht nach oben versetzt, damit unten Boden bleibt
cell_bay   = 69;     // 65.5 Zelle + Kontaktplatte + Feder (gedrückt ~3 mm)
contact_w  = 12;     // Federkontakte 12x12 mm, Lötfahne nach oben in den Kabelkanal biegen
contact_t  = 0.7;    // Schlitz für 0.3-mm-Blech
bulk_t     = 3;
elec_bay   = 8;      // nur noch Kabel: Treiber sitzt auf der Platine im Kopf
elec_floor = -4;
elec_w     = 16.6;
sock_l     = 11;     // Journal-Aufnahme + Kabelkammer + Pluskontakt
plate_t    = 3;

/* [Mitnehmer mit Rastnase] */
adapter_l  = 12;
bore_depth = 7;
arm_t      = 1.2;
nub_d      = 3.0;    // Loch im Rohr: 3.5 mm
nub_x      = adapter_l - 3;

// ---------- abgeleitete Masse ----------
W        = recess_w - fit_gap;
tube_wall= (tube_od - tube_id)/2;
r_roll   = sqrt(pow(tube_od/2, 2) + fabric_t*fabric_len/PI);
axis_z   = ceil(r_roll);                       // Halter-Unterkante = Unterkante Wickel
H        = ceil(axis_z + r_roll + top_clear + flange_t);
head_l   = face_t + usb_l + board_l + lid_t;
lid_x    = br_t + head_l - lid_t;
x_cap    = br_t + head_l + 1.5;
x_tube0  = x_cap + cap_flange;
x_c0     = x_tube0 + cap_plug + 1;
journal_l= (x_c0 + jour_engage) - (br_t + head_l);
cart_len = sock_l + cell_bay + bulk_t + elec_bay + mot_len + plate_t;
x_ad     = x_c0 + cart_len + 1;
x_tube1  = W - br_t - 1.5;
tube_len = x_tube1 - x_tube0;

echo(str("Bauhöhe gesamt: ", H, " mm (Wickel-Ø ", round(20*r_roll)/10, " mm)"));
echo(str("Rohrlänge: ", tube_len, " mm"));
echo(str("Stoffbreite max.: ", tube_len - 4, " mm"));
echo(str("Loch Ø3.5 für Rastnase: ", x_ad + nub_x - x_tube0, " mm ab Rohrende Motorseite"));
echo(str("Kartuschenlänge: ", cart_len, " mm"));
assert(esp_over + brd_l <= board_l, "Motorplatine zu lang für den Kopf");
assert(sqrt(pow(head_d/2 - head_wall, 2) - pow(brd_w/2 + rail_clr, 2)) >= brd_z + brd_t + esp_stack, "Platinenkanten passen nicht in den Kopf");

// ---------- Hilfsmodule ----------

module xcyl(d, h) { rotate([0, 90, 0]) cylinder(d = d, h = h); }

// Stopfen mit Klemmrippen fürs Rohr, entlang +X
module ribbed_plug(l) {
    xcyl(tube_id - 0.3, l);
    for (a = [0 : 45 : 359])
        rotate([a, 0, 0]) translate([0, -0.6, 0]) cube([l, 1.2, tube_id/2 + rib_i]);
}

// Schnapphaken am Topfrand, radial = +Z (wird per rotate([a-90,0,0]) verteilt)
module snap_hook(Lb, ri) {
    r_out = ri - 0.4;
    translate([Lb - 8, -hook_w/2, r_out - hook_t]) cube([1.5, hook_w, hook_t + 0.8]);
    translate([Lb - 7, -hook_w/2, r_out - hook_t]) cube([7 + lid_t + 1.2, hook_w, hook_t]);
    translate([0, hook_w/2, 0]) rotate([90, 0, 0]) linear_extrude(hook_w)
        polygon([[Lb + lid_t, r_out - eps], [Lb + lid_t, r_out + 0.6],
                 [Lb + lid_t + 0.3, r_out + 0.6], [Lb + lid_t + 1.2, r_out - eps]]);
}

// ---------- Teile ----------

// Halter. Rückseite x = 0 mit VHB an die Laibung, Flanschoberseite für Deckenmontage.
// Keil wird von vorne (-Y) eingeschoben und fällt 'drop' mm in den Sitz.
module bracket() {
    s = tenon + 0.4;
    difference() {
        union() {
            translate([0, -br_w/2, 0]) cube([br_t, br_w, H]);
            translate([0, -br_w/2, H - flange_t]) cube([br_t + flange_l, br_w, flange_t]);
        }
        translate([br_t - pocket_d, -s/2, axis_z - s/2]) cube([pocket_d + eps, s, s]);
        translate([br_t - pocket_d, -br_w/2 - eps, axis_z + drop - s/2]) cube([pocket_d + eps, br_w/2 + s/2 + eps, s]);
    }
}

// Schiene für eine Platinenkante (+Y), läuft zum Deckel hin aus. Die Platine schiebt sich vom
// Deckel her ein, bis zum Anschlag x0; der Deckel hält sie dort.
module brd_rail(x0, Lb, ri) {
    top = brd_z + brd_t + 0.2 + 1;
    bot = brd_z - 1;
    intersection() {
        xcyl(2*ri + eps, Lb);
        difference() {
            hull() {
                translate([x0 - 1.2, rail_in, bot]) cube([Lb - x0 + 1.2, ri - rail_in + 1, top - bot]);
                translate([x0 - 1.2 - (ri - rail_in), ri, bot]) cube([0.1, 1, top - bot]);
            }
            // Nut für die Platine
            translate([x0, rail_in - 1, brd_z - 0.1]) cube([Lb, brd_w/2 + rail_clr - rail_in + 1, brd_t + 0.2]);
            // Oberhalb der Nut die Schiene erst ab rail_in: dort stehen die Randpads frei
        }
    }
}

// Kopfgehäuse, Boden zum Halter.
// Wandseitig: USB-C-Schnappbuchse nach unten. Dahinter die Motorplatine in zwei Schienen,
// Antenne zur Wand, Super Mini nach oben.
module head_body() {
    Lb = head_l - lid_t;
    ri = head_d/2 - head_wall;
    x_usb = face_t + usb_l/2;
    difference() {
        union() {
            difference() {
                xcyl(head_d, Lb);
                translate([face_t, 0, 0]) xcyl(2*ri, Lb);
            }
            x0 = face_t + usb_l + esp_over;
            brd_rail(x0, Lb, ri);
            mirror([0, 1, 0]) brd_rail(x0, Lb, ri);
            for (a = hook_angles) rotate([a - 90, 0, 0]) snap_hook(Lb, ri);
        }
        translate([-eps, -(tenon + 0.15)/2, -(tenon + 0.15)/2]) cube([key_pocket + eps, tenon + 0.15, tenon + 0.15]);
        // Ausschnitt USB-C-Buchse
        translate([x_usb - usb_panel[0]/2, -usb_panel[1]/2, -head_d/2 - 1]) cube([usb_panel[0], usb_panel[1], head_wall + 2]);
        // Blitz daneben, 0.5 mm tief
        translate([x_usb, 0, 0]) rotate([asin(6/(head_d/2)), 0, 0])
            translate([0, 0, -head_d/2 - 1]) linear_extrude(1.5)
                scale(0.75) polygon([[3.5, 0.8], [0.2, -1.5], [0.2, -0.3], [-3.5, -0.8], [-0.2, 1.5], [-0.2, 0.3]]);
    }
}

// Deckel mit Journal (Lagerzapfen + Kabeldurchgang). x = 0 = Innenseite.
module head_lid() {
    jl = journal_l;
    ri = head_d/2 - head_wall;
    difference() {
        union() {
            xcyl(head_d, lid_t);
            translate([lid_t - eps, 0, 0]) xcyl(journal_od, jl + eps);
        }
        translate([-eps, 0, 0]) xcyl(journal_id, lid_t + jl + 1);
        translate([lid_t + jl - jour_engage, -journal_od, key_z]) cube([jour_engage + 1, 2*journal_od, journal_od]);
        translate([lid_t + jl - jour_engage/2, 0, 0]) rotate([90, 0, 0]) cylinder(d = pin_hole, h = journal_od + 2, center = true);
        for (a = hook_angles) rotate([a - 90, 0, 0])
            translate([-eps, -(hook_w + 0.6)/2, ri - 0.4 - hook_t - 0.3]) cube([lid_t + 2*eps, hook_w + 0.6, hook_t + 0.5]);
    }
}

// Vierkantkeil: stramm im Kopfboden, locker in der Halter-Tasche.
module head_key() {
    cube([key_pocket - 0.1 + pocket_d - 0.2, tenon, tenon]);
}

// Endkappe Motorseite: dreht mit dem Rohr, gleitet auf dem Journal.
module cap_motor() {
    difference() {
        union() {
            xcyl(tube_od, cap_flange);
            translate([cap_flange - eps, 0, 0]) ribbed_plug(cap_plug + eps);
        }
        translate([-eps, 0, 0]) xcyl(journal_od + 2*clr, cap_flange + cap_plug + 1);
    }
}

// Feststehende Achse Lagerseite: Keil | Bund | Ø8 ins 608 (sitzt direkt im Rohr).
module idle_axle() {
    translate([-(pocket_d - 0.2), -tenon/2, -tenon/2]) cube([pocket_d - 0.2 + eps, tenon, tenon]);
    xcyl(11, 1.5);
    translate([1.5 - eps, 0, 0]) xcyl(b608_id - 0.1, b608_w);
}

module cart_profile(l) {
    intersection() {
        xcyl(cart_od, l);
        translate([-1, -cart_od, -cart_od/2 + cart_flat]) cube([l + 2, 2*cart_od, cart_od]);
    }
}

// Kartusche: Steckaufnahme | 18650 | Schott | Kabel | N20 | Frontplatte
module cartridge() {
    x_bat = sock_l;
    x_el  = x_bat + cell_bay + bulk_t;
    x_mot = x_el + elec_bay;
    x_pl  = x_mot + mot_len;
    difference() {
        cart_profile(cart_len);
        translate([-eps, 0, 0]) intersection() {
            xcyl(journal_od + 2*clr, jour_engage + clr);
            translate([0, -journal_od, -journal_od]) cube([jour_engage + clr, 2*journal_od, journal_od + key_z + clr]);
        }
        // Kabelkammer: vom Journal nach oben in den Kabelkanal
        translate([jour_engage + clr - eps, -3, -journal_id/2]) cube([sock_l - contact_t - jour_engage - clr + eps, 6, cart_od]);
        translate([jour_engage/2, 0, 0]) rotate([90, 0, 0]) cylinder(d = pin_hole, h = cart_od + 2, center = true);
        // Schlitze für Plus- und Federkontakt, von oben einschieben
        for (xs = [sock_l - contact_t, x_bat + cell_bay])
            translate([xs, -(contact_w + 0.6)/2, cell_z - (contact_w + 0.6)/2]) cube([contact_t, contact_w + 0.6, cart_od]);
        // Akkufach, von oben einlegen
        translate([x_bat, 0, cell_z]) {
            xcyl(cell_d + 0.4, cell_bay);
            translate([0, -(cell_d + 0.4)/2, 0]) cube([cell_bay, cell_d + 0.4, cart_od]);
        }
        // Kabelkammer vor dem Motor
        translate([x_el, -elec_w/2, elec_floor]) cube([elec_bay, elec_w, cart_od]);
        // Motorfach: Getriebe-Abflachungen verhindern das Verdrehen
        translate([x_mot, -(mot_w + 0.4)/2, -(mot_h + 0.4)/2]) cube([mot_len + eps, mot_w + 0.4, cart_od]);
        // Frontplatte: Durchgang für Getriebebund und Welle
        translate([x_pl - eps, 0, 0]) xcyl(mot_boss_d + 0.6, plate_t + 2*eps);
        // Kabelkanal oben durch die Schotte
        translate([sock_l - eps, -3, 4]) cube([x_mot - sock_l + 2*eps, 6, cart_od]);
    }
}

// Mitnehmer: Rastnase schnappt in ein Ø3.5-Loch im Rohr, D-Bohrung für die N20-Welle.
// Zum Ausbauen die Nase mit einem Stift durchs Loch drücken.
module drive_adapter() {
    r_arm = tube_id/2 - 0.15;
    nub_top = tube_id/2 + min(tube_wall - 0.1, 1.0);
    difference() {
        union() {
            difference() {
                ribbed_plug(adapter_l);
                translate([2, -(hook_w + 2)/2, r_arm - arm_t - 1.5]) cube([adapter_l, hook_w + 2, 10]);
            }
            translate([1, -hook_w/2, r_arm - arm_t]) cube([adapter_l - 1, hook_w, arm_t]);
            translate([nub_x, 0, r_arm - 0.1]) {
                cylinder(d = nub_d, h = nub_top - r_arm - 0.2);
                translate([0, 0, nub_top - r_arm - 0.2 - eps]) cylinder(d1 = nub_d, d2 = nub_d - 0.8, h = 0.3);
            }
        }
        translate([-eps, 0, 0]) intersection() {
            xcyl(mot_shaft_d + 0.15, bore_depth);
            translate([0, -mot_shaft_d, -mot_shaft_d])
                cube([bore_depth, 2*mot_shaft_d, mot_shaft_d + (mot_shaft_D - mot_shaft_d/2) + 0.05]);
        }
    }
}

// ---------- Zusammenbau ----------

module tube() {
    color([0.8, 0.8, 0.85, 0.35]) translate([x_tube0, 0, 0]) difference() {
        xcyl(tube_od, tube_len);
        translate([-1, 0, 0]) xcyl(tube_id, tube_len + 2);
    }
}

module assembly() {
    color("SteelBlue") translate([0, 0, -axis_z]) bracket();
    color("SteelBlue") translate([W, 0, -axis_z]) mirror([1, 0, 0]) bracket();
    color("Gold")       translate([br_t - (pocket_d - 0.2), -tenon/2, -tenon/2]) head_key();
    color("Orange")     translate([br_t, 0, 0]) head_body();
    color("Gold")       translate([lid_x, 0, 0]) head_lid();
    color("DarkOrange") translate([x_cap, 0, 0]) cap_motor();
    color("LightGreen") translate([x_c0, 0, 0]) cartridge();
    color("Tomato")     translate([x_ad, 0, 0]) drive_adapter();
    color("Gold")       translate([W - br_t, 0, 0]) mirror([1, 0, 0]) idle_axle();
    tube();
    // Platzhalter
    color("DarkGreen") translate([br_t + face_t + usb_l + esp_over, -brd_w/2, brd_z]) cube([brd_l, brd_w, brd_t]);
    color("RoyalBlue") translate([br_t + face_t + usb_l, -esp_w/2, brd_z + brd_t + 0.1]) cube([24, esp_w, 1.2]);
    color("DimGray") translate([x_tube1 - b608_w, 0, 0]) difference() { xcyl(b608_d, b608_w); translate([-1, 0, 0]) xcyl(b608_id, b608_w + 2); }
    color("Blue")    translate([x_c0 + sock_l + 0.5, 0, cell_z]) xcyl(cell_d, 65.5);
    color("Silver")  translate([x_c0 + cart_len - plate_t - mot_len, -mot_w/2, -mot_h/2]) cube([mot_len, mot_w, mot_h]);
    %translate([x_tube0 + 2, 0, 0]) xcyl(2*r_roll, tube_len - 4);   // Stoffwickel aufgerollt
}

// ---------- Ausgabe (druckfertig orientiert) ----------

if      (part == "assembly")      assembly();
else if (part == "bracket_motor") rotate([0, -90, 0]) bracket();
else if (part == "bracket_idle")  rotate([0, 90, 0]) mirror([1, 0, 0]) bracket();
else if (part == "head_body")     rotate([0, -90, 0]) head_body();
else if (part == "head_lid")      rotate([0, -90, 0]) head_lid();
else if (part == "head_key")      head_key();
else if (part == "cap_motor")     rotate([0, -90, 0]) cap_motor();
else if (part == "idle_axle")     translate([0, 0, pocket_d - 0.2]) rotate([0, -90, 0]) idle_axle();
else if (part == "cartridge")     translate([0, 0, cart_od/2 - cart_flat]) cartridge();
else if (part == "drive_adapter") rotate([0, -90, 0]) drive_adapter();

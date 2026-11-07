// ============================================================
//  Motorrollo auf Basis IKEA LÅNGDANS  –  Matter über Thread
//  Version "Motor dreht": Motor, Elektronik und Akku drehen mit dem Rohr. Fest steht nur der Schlüssel:
//  er sitzt mit dem Vierkant im Halter, die Motorwelle treibt ihn, also dreht sich der Motor samt Rohr darum.
//  Damit läuft kein Kabel zwischen festen und drehenden Teilen, es braucht keinen Kabeldurchgang.
//
//  Aufbau (Achse = X, Motorseite links bei x = 0 = Wand):
//   [Halter]─[Schlüssel]─[Nase 4 mm]═ IKEA-Rohr: ESP32-H2 │ Kupplung │ N20 ═ Kartusche: DRV8833 │ TP4056 │ 18650 ═[608]─[Achse]─[Halter]
//                └── Sechskantstab 4 mm (Stahl) unter dem Super Mini bis zur Kupplung
//
//  Ausserhalb des Rohrs liegen nur der Halter (br_t) und die Nase: zusammen höchstens 15 mm.
//  Der Schlüssel hält einen Sechskantstab (4 mm SW, z.B. abgesägter Inbusschlüssel), der unter dem Super Mini
//  durch den Kopf zur Kupplung läuft. Die Kupplung sitzt auf der Motorwelle. Der Kopf läuft auf der Motorwelle
//  und mit der Bohrung lose um den Stab.
//  Der Super Mini liegt flach über dem Stab, von oben eingelegt; das Rohr hält ihn. Nur sein Antennenende
//  (nose_l - esp_x0 mm) liegt in der Nase ausserhalb des Alu-Rohrs: Funk vor dem Einbau prüfen.
//  Laden ist hier nicht gelöst: die USB-C-Buchse der TP4056-Platine liegt in der Kartusche im Rohr.
//  BOOT, RESET und USB nur bei ausgebautem Kopf erreichbar.
//  Die Kartusche hängt am Kopf: ein Adapter schraubt sich ins Innengewinde am Motorende des Kopfs, wie der
//  Ventilkopf-Adapter (Steigung 4, zwei Gänge, 0.6 Umdrehung bis zum Bund), und hält dabei den Motor im Fach.
//  Die Kartusche steckt auf dem Zapfen des Adapters, zwei Filament-Stifte halten sie.
//  Akku wie beim Ventilkopf: 18650 ohne Halter zwischen zwei blanken Kontaktplatten in gedruckten Sitzen.
//  Die Lötfahnen bleiben ganz, werden aber an der Plattenkante 90° von der Zelle weg umgebogen: gerade
//  würden sie am Rohr streifen. Die der Federplatte liegt über dem TP4056, die der Knopfplatte geht durch
//  den Schlitz im Boden und steht 4 mm hinten heraus.
//
//  Vor dem Druck nachmessen: tube_id, ridge_*, tube_od, Motor (mot_*), Module (esp_*, drv_*, tp_*),
//  Kontaktplatten und Zelle (con_*, cell_*).
//
//  Einzelteil wählen:  part = "...";   oder
//    openscad -D 'part="head"' -o head.stl rollo.scad
//  Alle Teile sind fürs Drucken bereits richtig orientiert.
// ============================================================

part = "assembly"; // [assembly, section, bracket_motor, bracket_idle, key, hex_rod, head, coupler, motor_stop, adapter, cartridge, idle_axle]

$fn = 96;
eps = 0.01;

/* [Einbau] */
recess_w = 850;     // lichte Breite zwischen den Wänden
fit_gap  = 2;       // Luft gesamt

/* [IKEA-Rohr – nachmessen!] */
tube_id    = 22.4;  // LÅNGDANS, gemessen
ridge_d    = 21.5;  // zwei Stege innen, gegenüber (±Y): Ø über die Stegspitzen
ridge_w    = 1.0;   // Stegbreite. Alles im Rohr hat Nuten dafür: die Stege nehmen das Drehmoment
tube_od    = 25;    // Annahme
roll_d     = 40;    // Stoffwickel aufgerollt, gemessen

/* [Toleranzen] */
clr      = 0.3;
rib_i    = 0.3;     // Übermass der Klemmrippen im Rohr
pin_hole = 1.9;     // für 1.75-mm-Filament als Stift

/* [Halter: Wandplatte mit VHB an der Rückwand, Arm bis zur Achse] */
// An der Wand höchstens 25 mm hoch, dafür breit: der ganze Halter ist ein 25 mm hohes Profil, flach gedruckt.
br_t      = 10;     // Arm, entlang der Achse
wp_t      = 6;      // Wandplatte, Dicke
wp_h      = 25;     // Wandplatte und ganzer Halter, Höhe (mittig zur Achse). Max. 25 an der Wand
arm_h     = wp_h;   // Arm, Höhe
wp_w      = 120;    // Wandplatte, entlang der Achse nach innen (hinter dem Stoff): VHB-Fläche
gus_l     = 70;     // Dreieck neben dem Arm (Richtung Rohr), Länge am Arm
gus_t     = 4;      // Stegbreite des Dreiecks: nur Rahmen, innen offen
arm_fl    = 4;      // Arm: Gurt oben und unten, dazwischen Rautenfenster (45°, druckt ohne Stütze)
arm_web   = 4;      // Arm: Steg zwischen den Rauten, quer gemessen
back_gap  = 100;
pocket_d  = 4.8;
tenon     = 10;     // Vierkant
drop      = 2.5;

/* [Schlüssel und Sechskantstab] */
collar_d  = 11;     // Bund zwischen Halter und Nase
collar_t  = 0.8;
key_gap   = 0.2;    // Bund ↔ Nase
hex_af    = 4;      // Sechskantstab, Schlüsselweite (Stahl)
hex_fit   = 0.15;   // im Schlüssel: stramm
hex_slide = 0.3;    // in der Kupplung: schiebt sich beim Einbau hinein
hex_in    = 6;      // Stab in der Kupplung

/* [Kopf] */
nose_l    = 4;      // ausserhalb des Rohrs. Mit collar_t + key_gap höchstens 5 mm
esp_x0    = 0.6;    // Antennenende des Super Mini ab Stirnseite
floor_t   = 0.6;    // Boden zwischen Bohrung und Platine
wire_room = 3;      // hinter dem Super Mini, für die Kabel zum Motor
cp_d      = 9.6;    // Kupplung Stab ↔ Motorwelle. Passt durchs Motorfach (mot_h + 0.4)
cp_clr    = 0.4;

/* [Gewinde Kopf ↔ Adapter, wie beim Ventilkopf] */
th_d      = 19;     // Aussen-Ø. Innen bleibt das Gewinde im Kopf grösser als der Motor, er geht hindurch
th_p      = 4;      // Steigung je Gang: grob, damit jeder Gang beim Drucken rund 10 Schichten hat
th_starts = 2;      // zwei Gänge: 0.6 Umdrehung bis zum Bund
th_h      = 1.2;    // Ganghöhe, 45°-Flanken
th_gap    = 0.25;   // Spiel am Adapter, wie beim Ventilkopf (thread_test.scad)
th_l      = 4.8;    // Gewindelänge
ad_id     = 13;     // Adapter innen: Kabel und Encoder
sh_t      = 3;      // Bund zwischen Kopf und Kartusche, unten 45° (druckt ohne Stütze)
tail_od   = 16;     // Adapter in der Kartusche, mit zwei Filament-Stiften gehalten
tail_l    = 6;
tail_pin_y= 7.6;    // Stifte als Sehne: halb im Zapfen, halb in der Kartusche

/* [Module – nachmessen!] */
mod_z    = -1.5;    // Unterkante DRV8833 und TP4056 in der Kartusche
mod_clr  = 0.2;
mod_gap  = 1;
kapton   = 0.1;
esp_l    = 22.5;    // ESP32-H2 Super Mini
esp_w    = 18.4;
esp_pcb  = 1.0;
esp_top  = 3.3;     // USB-C
esp_comp = 14;      // Breite der Bauteile auf dem Super Mini
drv_l    = 18.5;    // DRV8833-Platine (ohne Stiftleisten)
drv_w    = 16.5;
drv_pcb  = 1.6;
drv_top  = 1.8;
tp_l     = 28;      // TP4056 USB-C mit Schutzschaltung (DW01)
tp_w     = 17.5;
tp_pcb   = 1.6;
tp_top   = 3.5;
wire_ch  = [5, 2];  // Kabelkanal unter den Modulen (Breite, Tiefe)

/* [Lager 608 Lagerseite (direkt im Rohr)] */
brg_d  = 22;
brg_w  = 7;
brg_id = 8;
brg_comp = 0.3;    // stehend gedruckte Zapfen kommen so viel dünner heraus (gemessen: 7.9 → 7.6)
brg_rib  = 0.25;   // Übermass der Klemmrippen im Lager (nach Ausgleich)

/* [Motor N20 ohne Encoder, nachgemessen] */
mot_w        = 12;
mot_h        = 10;   // Abflachungen oben/unten = Verdrehsicherung im Zapfen
mot_len      = 24.2; // Getriebe + Motor
mot_boss_d   = 5;
mot_boss_h   = 1.1;
mot_shaft_d  = 3;
mot_shaft_D  = 2.5;  // Mass über Abflachung
mot_shaft_len= 1.1 + 5;   // ab Getriebefläche: Bund 1.1 + 5 mm freie Welle

/* [Motorriegel: U-Klammer hinter dem Motor, hält ihn auch ohne Adapter im Fach] */
stop_t       = 3;    // Dicke entlang der Achse
stop_win     = 8.4;  // Breite der Öffnung oben: Lötfahnen und Kabel des Motors
stop_bot     = 2.4;  // Steg unten
stop_rib     = 0.25; // Übermass der Klemmrippen je Seite

/* [Kartusche] */
cart_od    = ridge_d - 0.8;  // rund, ohne Stegnuten: sie hängt am Kopf und dreht mit ihm
cart_flat  = 0.4;
front_bay  = tail_l; // Bohrung für den Adapter
elec_w     = 16.6;
elec_floor = -4;
cell_d     = 18.4;
cell_len   = 65;
cell_nub   = 0.5;
cell_fit   = 0.2;
con_w      = 12;
con_t      = 0.3;
con_tab    = 7;      // Lötfahne in voller Länge, an der Plattenkante 90° von der Zelle weg umgebogen
con_bend   = 1;      // Platz für die Biegung über der Plattenkante
con_spring = 5.5;
con_dome   = 1;
con_slot   = 0.5;
con_lip    = 0.8;
con_lap    = 1;
wire_d     = 0.9;
bay_d      = cell_d + 2*cell_fit;
cell_bay   = con_t + con_spring + cell_len + con_dome + con_t;   // Federplatte (Modulseite) bis Knopfplatte
bulk_t     = 2;
end_t      = 3;
cell_z     = 0;

// ---------- abgeleitete Masse ----------
W        = recess_w - fit_gap;
r_roll   = roll_d/2;
y_wall   = r_roll + back_gap;
// Kopf, u = 0 an der Stirnseite (Wand)
hex_ac   = hex_af / cos(30);                   // Mass über Ecken
bore_d   = hex_ac + 2*clr;                     // Kopf dreht sich um den Stab
board_z  = bore_d/2 + floor_t;                 // Unterseite Super Mini
win_hw   = esp_w/2 + mod_clr;
u_w1     = esp_x0 + esp_l + wire_room;         // Ende Fenster
cp_l     = hex_in + 1 + (mot_shaft_len - mot_boss_h + 0.5);
u_cp     = u_w1 + 0.5;                         // Kupplung
u_mf     = u_cp + cp_l + mot_boss_h + 0.5;     // Getriebefläche
u_s0     = u_mf + mot_len + stop_t;            // Motorende + Riegel = Beginn Innengewinde
head_l   = u_s0 + th_l;
th_lead  = th_p * th_starts;
th_crest = th_p/2 - th_h;
u_t      = nose_l;                             // Rohrende
hex_len  = (pocket_d - 0.2) + collar_t + key_gap + u_cp + hex_in - 0.5;
// Kartusche
u_d0     = front_bay;
u_p0     = u_d0 + drv_l + mod_gap;
x_bat    = u_p0 + tp_l + mod_gap + bulk_t;
cart_len = x_bat + cell_bay + end_t;
// Lage im Einbau
x_h      = br_t + collar_t + key_gap;
x_tube0  = x_h + u_t;
x_c0     = x_h + head_l + sh_t;
x_tube1  = W - br_t - 1.5;
tube_len = x_tube1 - x_tube0;

echo(str("Rohrlänge: ", tube_len, " mm"));
echo(str("Stoffbreite max.: ", tube_len - 4, " mm"));
echo(str("Ausserhalb des Rohrs: Halter ", br_t, " + ", collar_t + key_gap + nose_l, " mm, Kopf im Rohr: ", head_l - nose_l, " mm"));
echo(str("Kartuschenlänge: ", cart_len, " mm, Gewinde ", th_l / th_lead, " Umdrehungen"));
echo(str("Sechskantstab ", hex_af, " mm SW, Länge ", hex_len, " mm"));
echo(str("Super Mini ausserhalb des Rohrs: ", nose_l - esp_x0, " mm"));

assert(arm_h <= wp_h && wp_h <= 25, "Halter an der Wand höher als 25 mm");
assert(y_wall - wp_t - gus_l >= r_roll + 10, "Dreieck am Halter reicht bis an den Stoff");
assert(drop + (tenon + 0.4)/2 <= arm_h/2 - 2, "Keilsitz zu nah an der Armkante");
assert(collar_t + key_gap + nose_l <= 5, "Mehr als 5 mm ausserhalb des Rohrs");
assert(sqrt(pow(win_hw, 2) + pow(board_z + esp_pcb, 2)) <= tube_id/2 - 0.5, "Super Mini stösst am Rohr an");
assert(sqrt(pow(4.5, 2) + pow(board_z + esp_pcb + esp_top, 2)) <= tube_id/2 - 0.5, "USB-C des Super Mini stösst am Rohr an");
assert(board_z - 0.5 >= ridge_w/2 + 0.3, "Platine liegt auf Höhe der Stege");
assert(cp_d <= mot_h + 0.4 - 0.4, "Kupplung geht nicht durchs Motorfach");
assert(cp_d + 2*cp_clr <= mot_w - 1.5, "Getriebe hat keinen Anschlag an der Kupplungsbohrung");
assert(th_d/2 - th_h > sqrt(pow(mot_w, 2) + pow(mot_h, 2))/2 + 0.3, "Motor geht nicht durchs Innengewinde");
assert(ridge_d/2 - 0.3 - th_d/2 >= 0.8, "Kopf zu dünn zwischen Gewinde und Stegnut");
assert(th_d/2 - th_h - th_gap - ad_id/2 >= 1.2, "Adapter zu dünn");
assert(tail_od/2 - ad_id/2 >= 1.2 && tail_pin_y < tail_od/2 && tail_pin_y + pin_hole/2 > tail_od/2 + clr && tail_pin_y - pin_hole/2 >= ad_id/2 + 0.1, "Stifte treffen den Adapter nicht richtig");
assert(th_crest > 0, "Gewindegänge zu hoch für die Steigung");
function mod_fits(w, pcb, top) =
    w/2 + mod_clr <= ridge_d/2 - 0.4 - 0.5
    && sqrt(pow(w/2 + mod_clr, 2) + pow(max(abs(mod_z), abs(mod_z + pcb)), 2)) <= cart_od/2 - kapton
    && sqrt(pow(4.5, 2) + pow(mod_z + pcb + top, 2)) <= cart_od/2 - kapton - wire_d;
assert(mod_fits(drv_w, drv_pcb, drv_top), "DRV8833 passt nicht ins Rohr");
assert(mod_fits(tp_w, tp_pcb, tp_top), "TP4056 passt nicht ins Rohr");
assert(cart_od/2 - cell_z - cell_d/2 >= wire_d + kapton, "Kein Platz für das Pluskabel über der Zelle");
assert(cell_z + con_w/2 + con_bend + con_t <= cart_od/2 - 0.5, "Umgebogene Lötfahne reibt am Rohr");
assert(mod_z + tp_pcb + tp_top < cell_z + con_w/2 - 0.3, "Lötfahne der Federplatte liegt auf dem TP4056");

// ---------- Hilfsmodule ----------

module xcyl(d, h) { rotate([0, 90, 0]) cylinder(d = d, h = h); }

// Kegel entlang +X
module xcone(r1, r2, l) { rotate([0, 90, 0]) cylinder(r1 = r1, r2 = r2, h = l); }

// Nuten für die beiden Stege des Rohrs, entlang +X
module ridge_grooves(l, r0) {
    for (s = [0, 1]) mirror([0, s, 0])
        translate([-1, r0, -(ridge_w + 0.6)/2]) cube([l + 2, tube_id, ridge_w + 0.6]);
}

// Stopfen mit Klemmrippen fürs Rohr, Rippen nur zwischen den Stegnuten
module ribbed_plug(l) {
    difference() {
        union() {
            xcyl(tube_id - 0.3, l);
            for (a = [0 : 45 : 359]) if (a % 180 != 90)
                rotate([a, 0, 0]) translate([0, -0.6, 0]) cube([l, 1.2, tube_id/2 + rib_i]);
        }
        ridge_grooves(l, ridge_d/2 - 0.3);
    }
}

// Kartusche: läuft mit den Stegen in den Nuten, also dreht sie mit dem Rohr. Unten flach zum Drucken.
module cart_profile(l) {
    difference() {
        intersection() {
            xcyl(cart_od, l);
            translate([-1, -cart_od, -cart_od/2 + cart_flat]) cube([l + 2, 2*cart_od, cart_od]);
        }
        ridge_grooves(l, ridge_d/2 - 0.4);
    }
}

module mod_slot(u0, l, w, pcb) {
    translate([u0, -(w/2 + mod_clr), mod_z - 0.1]) cube([l, w + 2*mod_clr, cart_od]);
}

// Gewinde entlang +X, im Koordinatensystem des Kopfs: Kopf und Adapter nehmen dieselbe Phase, also passen sie.
// Trapezgang mit 45°-Flanken, th_starts Gänge. c = Spiel (negativ am Adapter).
function th_r(a, c) = let(t = ((a * th_lead / 360) % th_p + th_p) % th_p)
    th_d/2 - th_h + c + min(th_h, max(0, th_crest/2 + th_h - abs(t - th_p/2)));
module th_solid(u0, len, c) {
    n = 96;
    translate([u0, 0, 0]) rotate([0, 90, 0]) rotate(-u0 * 360 / th_lead)
        linear_extrude(height = len, twist = 360 * len / th_lead, slices = ceil(len / th_lead * 120), convexity = 6)
            polygon([for (i = [0 : n - 1]) let(a = i * 360 / n) th_r(a, c) * [cos(a), sin(a)]]);
}

// D-Bohrung für die N20-Welle, ab x = 0 entlang -X, Tiefe d
module d_bore(d) {
    translate([-d, 0, 0]) intersection() {
        xcyl(mot_shaft_d + 0.15, d + eps);
        translate([0, -mot_shaft_d, -mot_shaft_d])
            cube([d + eps, 2*mot_shaft_d, mot_shaft_d + (mot_shaft_D - mot_shaft_d/2) + 0.05]);
    }
}

// ---------- Teile ----------

// Halter: Wandplatte mit VHB an die Rückwand (+Y), Arm (br_t × arm_h) bis über die Achse, ein Dreieck neben
// dem Arm (Richtung Rohr, hinter dem Stoff) verbindet ihn mit der breiten Platte. Alles gleich hoch (wp_h),
// damit der Halter an der Wand nicht höher als 25 mm wird. Aussenseite x = 0 darf an der Seitenwand anliegen.
// z = 0 und y = 0 auf der Achse. Flach liegend gedruckt.
module bracket() {
    s = tenon + 0.4;
    tip = arm_h/2;
    difference() {
        union() {
            translate([0, y_wall - wp_t, -wp_h/2]) cube([wp_w, wp_t, wp_h]);
            translate([0, -tip, -arm_h/2]) cube([br_t, y_wall - wp_t + tip + eps, arm_h]);
            y_p = y_wall - wp_t + eps;
            g = [[br_t - eps, y_p], [wp_w, y_p], [br_t - eps, y_p - gus_l]];
            // Nur die Schräge: Arm und Wandplatte sind schon da, sie brauchen keinen eigenen Steg
            translate([0, 0, -wp_h/2]) linear_extrude(wp_h) difference() {
                polygon(g);
                hull() for (dx = [0, -gus_t], dy = [0, gus_t]) translate([dx, dy]) offset(delta = -gus_t) polygon(g);
            }
        }
        translate([br_t - pocket_d, -s/2, -s/2]) cube([pocket_d + eps, s, s]);
        translate([br_t - pocket_d, -tip - eps, drop - s/2]) cube([pocket_d + eps, tip + s/2 + eps, s]);
        // Rautenfenster quer durch den Arm: Fachwerk aus Gurten und 45°-Streben
        r = arm_h/2 - arm_fl;                       // halbe Rautenhöhe = halbe Breite
        pitch = 2*r + arm_web*sqrt(2);
        y_a = s/2 + 3 + r;                          // erste Mitte: hinter dem Keilsitz
        y_b = y_wall - wp_t - 3 - r;                // letzte Mitte: vor der Wandplatte
        n = floor((y_b - y_a)/pitch) + 1;
        y_0 = (y_a + y_b)/2 - (n - 1)*pitch/2;
        for (i = [0 : n - 1])
            translate([br_t/2, y_0 + i*pitch, 0]) rotate([45, 0, 0])
                cube([br_t + 2*eps, r*sqrt(2), r*sqrt(2)], center = true);
    }
}

module hex(af, l) { rotate([0, 90, 0]) rotate([0, 0, 30]) cylinder(d = af / cos(30), h = l, $fn = 6); }

// Gedruckter Sechskantstab statt Stahl: liegt beim Drucken auf einer Fläche, Lagen entlang der Achse.
// Etwas schmaler (rod_shrink) gegen den Elefantenfuss, Fasen an den Enden zum Einfädeln.
rod_shrink = 0.05;
rod_chamfer = 0.5;
module hex_rod() {
    af = hex_af - rod_shrink;
    ac = af / cos(30);
    intersection() {
        hex(af, hex_len);
        hull() {
            xcone(ac/2 - rod_chamfer, ac/2, rod_chamfer);
            translate([hex_len - rod_chamfer, 0, 0]) xcone(ac/2, ac/2 - rod_chamfer, rod_chamfer);
        }
    }
}

// Schlüssel, x = 0 an der Halterfläche: Vierkant im Halter | Bund. Der Sechskantstab steckt stramm darin.
// Steht still. Druckt auf dem Vierkant stehend.
module key() {
    difference() {
        union() {
            translate([-(pocket_d - 0.2), -tenon/2, -tenon/2]) cube([pocket_d - 0.2 + eps, tenon, tenon]);
            xcyl(collar_d, collar_t);
        }
        translate([-(pocket_d - 0.2) - eps, 0, 0]) hex(hex_af + hex_fit, pocket_d - 0.2 + collar_t + 2*eps);
    }
}

// Kupplung, x = 0 auf der Stabseite: Sechskant für den Stab | Steg | D-Bohrung für die Motorwelle.
// Dreht nicht (steht mit dem Stab still). Druckt auf der Motorseite stehend.
module coupler() {
    difference() {
        xcyl(cp_d, cp_l);
        translate([-eps, 0, 0]) hex(hex_af + hex_slide, hex_in + eps);
        translate([cp_l + eps, 0, 0]) d_bore(cp_l - hex_in - 1);
    }
}

// Kopf, u = 0 an der Stirnseite: Nase (ausserhalb) | Fenster für den Super Mini | Kupplung | Motor.
// Im Rohr mit Klemmrippen und Stegnuten, dreht mit dem Rohr. Druckt auf der Stirnseite stehend.
// Einbau: Kupplung auf die Motorwelle, dann beide von der Rohrseite ins Motorfach schieben, Kupplung voran,
// bis das Getriebe an der Stufe ansteht. Die Kartusche dahinter hält den Motor.
module head() {
    difference() {
        union() {
            xcyl(tube_od, nose_l);
            translate([nose_l - eps, 0, 0]) ribbed_plug(head_l - nose_l + eps);
        }
        // Bohrung für den Stab, dann Raum für die Kupplung
        translate([-eps, 0, 0]) xcyl(bore_d, u_cp + 2*eps);
        // Die Ecken der Getriebefläche liegen auf der Stufe zum Motorfach: das ist der Anschlag des Motors
        translate([u_cp, 0, 0]) xcyl(cp_d + 2*cp_clr, u_mf - u_cp + eps);
        // Fenster: Super Mini von oben einlegen, Bauteile oben, Antenne zur Wand. Das Rohr deckt es ab,
        // in der Nase bleibt es offen
        translate([esp_x0, -win_hw, board_z]) cube([u_w1 - esp_x0, 2*win_hw, tube_od]);
        // Kabel über Kupplung und Motor in die Kartusche
        translate([u_w1 - eps, -3, (mot_h + 0.4)/2 - eps]) cube([head_l - u_w1 + 2*eps, 6, tube_id]);
        // Motorfach von der Rohrseite, Welle zeigt zur Wand
        translate([u_mf, -(mot_w + 0.4)/2, -(mot_h + 0.4)/2]) cube([mot_len + stop_t + eps, mot_w + 0.4, mot_h + 0.4]);
        // Innengewinde für den Adapter, Einlauf an der Öffnung
        th_solid(u_s0 - eps, th_l + 2*eps, 0);
        translate([head_l - th_h - 0.4, 0, 0]) xcone(th_d/2 - th_h, th_d/2 + 0.4, th_h + 0.4 + eps);
    }
}

// Motorriegel, x = 0 an der Motorrückseite. U offen nach oben: Lötfahnen und Kabel gehen
// oben hinaus in den Kabelkanal. Die Schenkel federn, die Rippen klemmen ihn im Motorfach.
// Hinter den Motor drücken, bis er anliegt. Druckt flach liegend.
module motor_stop() {
    pw = mot_w + 0.4 - 0.2;   // 0.1 Spiel je Seite, die Rippen klemmen
    ph = mot_h + 0.4 - 0.2;
    difference() {
        translate([0, -pw/2, -ph/2]) cube([stop_t, pw, ph]);
        translate([-eps, -stop_win/2, -ph/2 + stop_bot]) cube([stop_t + 2*eps, stop_win, ph]);
    }
    for (s = [-1, 1], z = [-ph/2 + 1.5, ph/2 - 1.5])
        intersection() {
            translate([0, s * (pw/2 + 0.1 + stop_rib - 0.5), z]) xcyl(1, stop_t);
            translate([0, s > 0 ? pw/2 - eps : -pw/2 - 1, -ph/2]) cube([stop_t, 1 + eps, ph]);
        }
}

// Adapter, im Koordinatensystem des Kopfs: Aussengewinde in den Kopf | Bund | Zapfen in die Kartusche.
// Zwei Filament-Stifte halten die Kartusche drauf. Hohl für Kabel und Encoder; die Stirnseite des Gewindes
// hält den Motor im Kopf. Druckt auf dem Zapfen stehend, Gewinde oben.
module adapter() {
    r_root = th_d/2 - th_h - th_gap;
    x_tail = head_l + sh_t;
    difference() {
        union() {
            // Gewinde, an der Spitze vom Grund bis zum Kamm angefast
            intersection() {
                th_solid(u_s0 + 0.2, th_l - 0.2 + eps, -th_gap);
                union() {
                    translate([u_s0 + 0.2, 0, 0]) xcone(r_root, r_root + th_h + 0.01, th_h);
                    translate([u_s0 + 0.2 + th_h - eps, 0, 0]) xcyl(th_d + 1, th_l);
                }
            }
            translate([u_s0 + 0.2, 0, 0]) xcyl(2*r_root + 0.02, th_l - 0.2 + eps);
            // Bund: oben flach am Kopf, unten 45° zum Zapfen
            translate([head_l - eps, 0, 0]) xcyl(cart_od, sh_t - (cart_od - tail_od)/2 + eps);
            translate([x_tail - (cart_od - tail_od)/2, 0, 0]) xcone(cart_od/2, tail_od/2, (cart_od - tail_od)/2 + eps);
            translate([x_tail - eps, 0, 0]) xcyl(tail_od, tail_l - 0.3 + eps);
        }
        translate([u_s0, 0, 0]) xcyl(ad_id, th_l + sh_t + tail_l + 1);
        for (s = [-1, 1]) translate([x_tail + tail_l/2, s*tail_pin_y, 0]) cylinder(d = pin_hole, h = cart_od, center = true);
    }
}

// Feststehende Achse Lagerseite: Keil | Bund | Ø8 ins 608 (sitzt direkt im Rohr).
module idle_axle() {
    translate([-(pocket_d - 0.2), -tenon/2, -tenon/2]) cube([pocket_d - 0.2 + eps, tenon, tenon]);
    xcyl(11, 1.5);
    // Zapfen ins 608: Kern knapp, sechs Rippen klemmen den Innenring. Fase an der Spitze zum Einfädeln.
    translate([1.5 - eps, 0, 0]) intersection() {
        union() {
            xcyl(brg_id - 0.1 + brg_comp, brg_w);
            for (a = [0 : 60 : 300]) rotate([a, 0, 0])
                translate([0, 0, (brg_id + brg_comp)/2 + brg_rib - 0.6]) xcyl(1.2, brg_w);
        }
        hull() {
            xcyl(brg_id + 2, brg_w - 0.8);
            xcyl(brg_id - 1, brg_w);
        }
    }
}

// Sitz für eine Kontaktplatte, wie im Ventilkopf. x0 = Rückseite der Platte, dir = zur Zelle.
module contact_seat(x0, dir) {
    l = con_slot + con_lip;
    for (s = [0, 1]) mirror([0, s, 0]) difference() {
        translate([min(x0 - dir*eps, x0 + dir*l), con_w/2 - con_lap, -cart_od]) cube([l + eps, cart_od, 2*cart_od]);
        translate([min(x0 - dir, x0 + dir*con_slot), -1, cell_z - con_w/2]) cube([con_slot + 1, con_w/2 + 0.15 + 1, cart_od]);
    }
}

// Kartusche: Kabelfach | DRV8833 | TP4056 | Schott | Federplatte │ 18650 │ Knopfplatte | Boden.
// Module und Zelle von oben einlegen, eine Lage Kapton darum. Druckt auf der Abflachung liegend.
module cartridge() {
    difference() {
        union() {
            difference() {
                cart_profile(cart_len);
                translate([-eps, 0, 0]) xcyl(tail_od + 2*clr, front_bay + 2*eps);
                mod_slot(u_d0, drv_l, drv_w, drv_pcb);
                mod_slot(u_p0, tp_l, tp_w, tp_pcb);
                translate([-eps, -wire_ch[0]/2, mod_z - wire_ch[1]]) cube([u_p0 + tp_l + eps, wire_ch[0], wire_ch[1] + eps]);
                translate([x_bat, 0, cell_z]) {
                    xcyl(bay_d, cell_bay);
                    translate([0, -bay_d/2, 0]) cube([cell_bay, bay_d, cart_od]);
                }
            }
            intersection() {
                cart_profile(cart_len);
                union() {
                    contact_seat(x_bat, 1);                 // Federplatte, Minuspol
                    contact_seat(x_bat + cell_bay, -1);     // Knopfplatte, Pluspol
                }
            }
        }
        // Stifte durch Kartusche und Adapter, senkrecht (Kartusche druckt liegend)
        for (s = [-1, 1]) translate([tail_l/2, s*tail_pin_y, 0]) cylinder(d = pin_hole, h = 2*cart_od, center = true);
        // Kabelkanal oben durch das Schott
        translate([u_p0, -4, 4]) cube([x_bat - u_p0 + con_slot + con_lip + 1, 8, cart_od]);
        // Lötfahne der Knopfplatte: umgebogen durch einen Schlitz im Boden nach hinten
        translate([x_bat + cell_bay - eps, -2, cell_z + con_w/2 - 0.5]) cube([end_t + 2*eps, 4, cart_od]);
        // Pluszeichen oben auf dem Boden, neben dem Schlitz: hier kommt der Pluspol hin
        translate([cart_len - end_t/2, 6, sqrt(pow(cart_od/2, 2) - 49) - 0.8]) {
            translate([-1.2, -0.5, 0]) cube([2.4, 1, 2]);
            translate([-0.5, -1.2, 0]) cube([1, 2.4, 2]);
        }
    }
}

// ---------- Zusammenbau ----------

module tube() {
    color([0.8, 0.8, 0.85, 0.35]) translate([x_tube0, 0, 0]) difference() {
        xcyl(tube_od, tube_len);
        translate([-1, 0, 0]) xcyl(tube_id, tube_len + 2);
    }
    color([0.8, 0.8, 0.85, 0.35]) for (s = [0, 1]) mirror([0, s, 0])
        translate([x_tube0, ridge_d/2, -ridge_w/2]) cube([tube_len, (tube_id - ridge_d)/2 + eps, ridge_w]);
}

module mod_ghost(u0, l, w, pcb, top, z, c) {
    color(c) translate([u0, -w/2, z]) cube([l, w, pcb]);
    color("Black") translate([u0 + 2, -w/2 + 3, z + pcb]) cube([l - 4, w - 6, top]);
}

// Koordinaten wie head
module head_ghost() {
    mod_ghost(esp_x0, esp_l, esp_w, esp_pcb, esp_top, board_z, "RoyalBlue");
    color("Silver") translate([u_mf, -mot_w/2, -mot_h/2]) cube([mot_len, mot_w, mot_h]);
    color("Silver") translate([u_mf - mot_boss_h, 0, 0]) xcyl(mot_boss_d, mot_boss_h + eps);
    color("Silver") translate([u_mf - mot_shaft_len, 0, 0]) xcyl(mot_shaft_d, mot_shaft_len);
    color("OrangeRed") translate([u_mf + mot_len, 0, 0]) motor_stop();
    color("DimGray") translate([-(pocket_d - 0.2) - collar_t - key_gap, 0, 0]) hex(hex_af, hex_len);
}

// Koordinaten wie cartridge
module cart_ghost() {
    mod_ghost(u_d0, drv_l, drv_w, drv_pcb, drv_top, mod_z, "MediumPurple");
    mod_ghost(u_p0, tp_l, tp_w, tp_pcb, tp_top, mod_z, "DodgerBlue");
    color("Blue") translate([x_bat + con_t + con_spring, 0, cell_z]) xcyl(cell_d, cell_len);
    for (x = [x_bat, x_bat + cell_bay - con_t]) color("Silver") {
        translate([x, -con_w/2, cell_z - con_w/2]) cube([con_t, con_w, con_w]);
    }
    // Lötfahnen umgebogen, von der Zelle weg
    color("Silver") for (t = [[x_bat + con_t, -1], [x_bat + cell_bay - con_t, 1]])
        translate([t[0] + (t[1] < 0 ? -con_tab : 0), -1.5, cell_z + con_w/2 + con_bend - con_t]) cube([con_tab, 3, con_t]);
    color("Silver") translate([x_bat + con_t, 0, cell_z]) xcyl(7, con_spring);
    color("Silver") translate([x_bat + cell_bay - con_t - con_dome, 0, cell_z]) xcyl(6, con_dome);
}

module assembly() {
    color("SteelBlue") bracket();
    color("SteelBlue") translate([W, 0, 0]) mirror([1, 0, 0]) bracket();
    color("LimeGreen")  translate([br_t, 0, 0]) key();
    color("LightSkyBlue") translate([x_h, 0, 0]) head();
    color("LimeGreen")  translate([x_h + u_cp, 0, 0]) coupler();
    color("Orange")     translate([x_h, 0, 0]) adapter();
    color("Khaki")      translate([x_c0, 0, 0]) cartridge();
    color("Gold")       translate([W - br_t, 0, 0]) mirror([1, 0, 0]) idle_axle();
    tube();
    translate([x_h, 0, 0]) head_ghost();
    translate([x_c0, 0, 0]) cart_ghost();
    color("DimGray") translate([x_tube1 - brg_w, 0, 0]) difference() { xcyl(brg_d, brg_w); translate([-1, 0, 0]) xcyl(brg_id, brg_w + 2); }
    %translate([x_tube0 + 2, 0, 0]) xcyl(2*r_roll, tube_len - 4);
    %translate([x_tube0 + 2, r_roll - 0.2, -150]) cube([tube_len - 4, 0.4, 150]);
    %translate([0, y_wall, -150]) cube([W, 2, 250]);
}

// ---------- Ausgabe (druckfertig orientiert) ----------

if      (part == "assembly")      assembly();
else if (part == "section")       intersection() { assembly(); translate([0, 0, -100]) cube([x_c0 + cart_len + 10, 100, 200]); }
else if (part == "bracket_motor") translate([0, 0, wp_h/2]) bracket();                       // liegt flach
else if (part == "bracket_idle")  translate([0, 0, wp_h/2]) mirror([1, 0, 0]) bracket();
else if (part == "key")           translate([0, 0, pocket_d - 0.2]) rotate([0, -90, 0]) key();
else if (part == "hex_rod")       translate([0, 0, (hex_af - rod_shrink)/2]) hex_rod();
else if (part == "head")          rotate([0, -90, 0]) head();
else if (part == "coupler")       translate([0, 0, cp_l]) rotate([0, 90, 0]) coupler();
else if (part == "motor_stop")    rotate([0, -90, 0]) motor_stop();
else if (part == "adapter")       translate([0, 0, head_l + sh_t + tail_l - 0.3]) rotate([0, 90, 0]) adapter();
else if (part == "cartridge")     translate([0, 0, cart_od/2 - cart_flat]) cartridge();
else if (part == "idle_axle")     translate([0, 0, pocket_d - 0.2]) rotate([0, -90, 0]) idle_axle();

// ============================================================
//  Motorrollo – Version "Schale": wie der Schlitten (rollo.scad, Branch pcb-designs), aber weniger Gefummel.
//
//  Vorher im Rohr bzw. davor: Schlitten + Kupplung + Sechskantstab + Schlüssel = 4 Teile, und der Stab musste
//  blind durch die Nase in die Kupplung finden.
//  Jetzt:  Schale (ein Druckteil, keine Stützen)  +  Antriebsschlüssel (ein Druckteil).
//
//  Der Antriebsschlüssel ist Vierkant | Bund | Welle Ø7.6 mit D-Bohrung in einem Stück. Er steckt durch die
//  Nase direkt auf der Motorwelle und steht still, die Schale dreht mit dem Rohr um ihn. Er bleibt ein eigenes
//  Teil, weil er stillsteht, während die Schale dreht – und weil er zum Laden herausgezogen wird.
//
//  Alles andere liegt exakt wie beim Schlitten: Motor, Platine (48.7 × 17), Fächer, Zelle, Kontaktplatten.
//  Die geroutete Platine passt also unverändert. Halter und Achse Lagerseite bleiben aus rollo.scad.
//
//  Einbau:
//   1. Motor von oben ins Fach, die Welle taucht dabei durch den Schlitz oben in die Bohrung ein.
//   2. Motordrähte, Platine in die Tasche, Kontaktplatten, Pluskabel, Zelle – wie bisher.
//   3. Kapton herum, ins Rohr schieben.
//   4. Antriebsschlüssel durch die Nase einschieben, drehen bis die D-Bohrung auf der Welle einrastet,
//      bis zum Bund hineinschieben. Fertig.
//  Laden: Rollo aushängen, Schlüssel herausziehen, USB-C in die Nase.
//
//    openscad -D 'part="tray"'      -o tray.stl      rollo_tray.scad   // liegt auf der Abflachung
//    openscad -D 'part="drive_key"' -o drive_key.stl rollo_tray.scad   // steht auf dem Vierkant
//    openscad -D 'part="plate"'     -o plate.stl     rollo_tray.scad   // beide zusammen auf einer Platte
// ============================================================

part = "assembly"; // [assembly, section, tray, drive_key, plate]

$fn = 96;
eps = 0.01;

/* [IKEA-Rohr – nachmessen!] */
tube_id    = 22.4;
ridge_d    = 21.5;
ridge_w    = 1.0;
tube_od    = 25;
slot_w     = 2.0;
slot_d     = 0.8;

/* [Toleranzen] */
clr      = 0.3;
rib_i    = 0.3;
tube_lim = 0.5;

/* [Halter-Seite] */
pocket_d  = 4.8;    // Tiefe des Vierkantsitzes im Halter (rollo.scad)
tenon     = 10;
collar_d  = 11;
collar_t  = 0.8;
key_gap   = 0.2;

/* [Antriebsschlüssel] */
dk_d      = 7.6;    // Welle: dreht in der Bohrung der Schale, D-Bohrung für die Motorwelle am Ende
dk_clr    = 0.3;    // Luft je Seite in der Bohrung
dk_bore   = 5;      // Tiefe der D-Bohrung
dk_ch     = 0.6;    // Fase an der Spitze: fädelt ein

/* [Schale] */
nose_l    = 4;
sled_od   = tube_id - 0.6;
sled_flat = 0.4;
mot_clr   = 0.4;
mot_end   = 0.3;
back_t    = 1.5;
tab_win   = 8.4;
tab_bot   = 2.4;
bay_l     = 5;
bulk_t    = 2;
end_t     = 3;
kapton    = 0.1;
wire_d    = 0.9;
shaft_slot = 5.6;   // Schlitz oben in der Bohrung: Motorwelle samt Bund taucht beim Einlegen hindurch

/* [Platine – unverändert] */
pcb_t     = 0.8;
pcb_w     = 17;
pcb_x0    = 0.6;
pcb_clr   = 0.2;
pcb_air   = 0.2;
ledge     = 1.2;
top_w     = 15;
top_h     = 1.3;
mid_w     = 13;
mid_h     = 2.0;
bot_h     = 2.6;
usb_w     = 8.94;
usb_d     = 6.5;
usb_h     = 1.56;
usb_dn    = 0.8;
usb_off   = 2.0;
usb_leg   = 5.62;
plug_w    = 12.4;
plug_h    = 6.6;

/* [Motor N20 ohne Encoder] */
mot_w        = 12;
mot_h        = 10;
mot_len      = 24.2;
mot_boss_d   = 5;
mot_boss_h   = 1.1;
mot_shaft_d  = 3;
mot_shaft_D  = 2.5;
mot_shaft_len= 1.1 + 5;

/* [Zelle und Kontaktplatten] */
cell_d     = 18.4;
cell_len   = 65;
cell_fit   = 0.2;
con_w      = 12;
con_t      = 0.3;
con_tab    = 7;
con_bend   = 1;
con_spring = 5.5;
con_dome   = 1;
con_slot   = 0.5;
con_lip    = 0.8;
con_lap    = 1;
bay_d      = cell_d + 2*cell_fit;
cell_bay   = con_t + con_spring + cell_len + con_dome + con_t;
cell_z     = 0;

// ---------- abgeleitete Masse ----------
lim      = tube_id/2 - tube_lim;
mot_top  = (mot_h + mot_clr)/2;
pcb_z    = mot_top + pcb_air;
pcb_top  = pcb_z + pcb_t;
pcb_hw   = pcb_w/2 + pcb_clr;
cav_hw   = pcb_w/2 - ledge;

// Getriebefläche wie beim Schlitten (dort: Nase + Kupplung), damit die Platine unverändert passt
u_mf     = (nose_l + 0.5) + (6 + 1 + (mot_shaft_len - mot_boss_h + 0.5)) + mot_boss_h + 0.5;
u_me     = u_mf + mot_len + mot_end;
u_e0     = u_me + back_t;
u_e1     = u_e0 + bay_l;
x_bat    = u_e1 + bulk_t;
sled_l   = x_bat + cell_bay + end_t;
pcb_l    = u_e1 - 0.3 - pcb_x0;
bay_floor= pcb_z - bot_h - 0.2;
usb_z    = (pcb_top + usb_h + pcb_z - usb_dn)/2;

dk_hole  = dk_d + 2*dk_clr;
u_tip    = u_mf - mot_boss_h - 0.5;           // Spitze des Schlüssels, 0.5 vor dem Getriebebund
dk_shaft = key_gap + u_tip;                    // Welle ab Bund
dk_len   = (pocket_d - 0.2) + collar_t + dk_shaft;

// Torsion: Schlüssel steht beim Drucken, die Lagen liegen quer zur Achse
dk_T     = 0.3;                                // Nm, Motor
dk_tau   = 16 * dk_T * 1000 * dk_d / (PI * (pow(dk_d, 4) - pow(mot_shaft_d + 0.15, 4)));

echo(str("Schale: ", sled_l, " mm, Platine ", pcb_l, " × ", pcb_w, " mm (wie Schlitten)"));
echo(str("Antriebsschlüssel: ", dk_len, " mm, Torsion in der Lagenfuge ", round(dk_tau*10)/10, " MPa bei ", dk_T, " Nm"));

assert(abs(pcb_l - 48.7) < 0.01, "Platinenlänge weicht von der gerouteten Platine ab");
assert(dk_hole/2 <= pcb_z - usb_dn - 0.4, "USB-C-Buchse unter der Platine trifft die Bohrung");
assert(dk_hole/2 + 0.8 <= pcb_z, "Zu wenig Decke über der Bohrung");
assert(shaft_slot >= mot_boss_d + 0.4 && shaft_slot <= dk_d - 1.5, "Schlitz: Bund geht nicht durch, oder Schlüssel fällt heraus");
assert(dk_hole < mot_h, "Getriebefläche hat keinen Anschlag");
assert(u_mf - mot_shaft_len + dk_bore >= u_tip - 0.01, "Welle reicht nicht in die D-Bohrung");
assert(dk_tau <= 8, "Antriebsschlüssel zu dünn für die Lagenhaftung");
assert(sqrt(pow(pcb_hw, 2) + pow(pcb_top, 2)) <= lim, "Platine stösst am Rohr an");
assert(sqrt(pow(usb_off + usb_w/2, 2) + pow(pcb_top + usb_h + kapton, 2)) <= lim, "USB-C stösst am Rohr an");

// ---------- Hilfsmodule ----------

module xcyl(d, h) { rotate([0, 90, 0]) cylinder(d = d, h = h); }
module xcone(r1, r2, l) { rotate([0, 90, 0]) cylinder(r1 = r1, r2 = r2, h = l); }

module ridge_grooves(l, r0) {
    for (s = [0, 1]) mirror([0, s, 0])
        translate([-1, r0, -(ridge_w + 0.6)/2]) cube([l + 2, tube_id, ridge_w + 0.6]);
}

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

// D-Bohrung für die N20-Welle, ab x = 0 entlang -X
module d_bore(d) {
    translate([-d, 0, 0]) intersection() {
        xcyl(mot_shaft_d + 0.15, d + eps);
        translate([0, -mot_shaft_d, -mot_shaft_d])
            cube([d + eps, 2*mot_shaft_d, mot_shaft_d + (mot_shaft_D - mot_shaft_d/2) + 0.05]);
    }
}

module contact_seat(x0, dir) {
    l = con_slot + con_lip;
    for (s = [0, 1]) mirror([0, s, 0]) difference() {
        translate([min(x0 - dir*eps, x0 + dir*l), con_w/2 - con_lap, -sled_od]) cube([l + eps, sled_od, 2*sled_od]);
        translate([min(x0 - dir, x0 + dir*con_slot), -1, cell_z - con_w/2]) cube([con_slot + 1, con_w/2 + 0.15 + 1, sled_od]);
    }
}

// ---------- Teile ----------

// Antriebsschlüssel, x = 0 an der Halterfläche: Vierkant im Halter | Bund | Welle bis vor den Getriebebund.
module drive_key() {
    difference() {
        union() {
            translate([-(pocket_d - 0.2), -tenon/2, -tenon/2]) cube([pocket_d - 0.2 + eps, tenon, tenon]);
            xcyl(collar_d, collar_t);
            translate([collar_t - eps, 0, 0]) hull() {
                xcyl(dk_d, dk_shaft - dk_ch + eps);
                xcone(dk_d/2, dk_d/2 - dk_ch, dk_shaft + eps);
            }
        }
        translate([collar_t + dk_shaft + eps, 0, 0]) d_bore(dk_bore + 0.5);
        // Einführfase an der D-Bohrung
        translate([collar_t + dk_shaft - 0.8 + eps, 0, 0]) xcone(mot_shaft_d/2 + 0.1, mot_shaft_d/2 + 0.9, 0.8);
    }
}

module tray_body() {
    intersection() {
        union() {
            xcyl(tube_od, nose_l);
            translate([nose_l - eps, 0, 0]) ribbed_plug(u_e0 - nose_l + eps);
            translate([u_e0 - eps, 0, 0]) difference() {
                xcyl(sled_od, sled_l - u_e0 + eps);
                ridge_grooves(sled_l - u_e0 + eps, ridge_d/2 - 0.4);
            }
        }
        translate([-1, -tube_od, -sled_od/2 + sled_flat]) cube([sled_l + 2, 2*tube_od, tube_od]);
    }
}

// Schale, u = 0 an der Stirnseite. Druckt auf der Abflachung liegend, alles von oben offen ausser der Bohrung.
module tray() {
    up = tube_od;
    difference() {
        union() {
            difference() {
                tray_body();
                // Bohrung für den Antriebsschlüssel, von der Stirnseite bis zur Getriebefläche.
                // Oben zur Tropfenform gespitzt (druckt ohne Stütze), Spitze auf 0.5 über dem Kreis gekappt.
                translate([-eps, 0, 0]) intersection() {
                    hull() {
                        xcyl(dk_hole, u_mf + 2*eps);
                        translate([0, 0, dk_hole/2 * sqrt(2)]) rotate([45, 0, 0]) cube([u_mf + 2*eps, 0.1, 0.1]);
                    }
                    translate([0, -dk_hole, -dk_hole]) cube([u_mf + 2*eps, 2*dk_hole, dk_hole * 1.5 + 0.5]);
                }
                // Schlitz oben in der Bohrung, so lang wie die Motorwelle: Welle taucht beim Einlegen ein
                translate([u_mf - mot_shaft_len - 0.6, -shaft_slot/2, 0]) cube([mot_shaft_len + 0.6 + eps, shaft_slot, up]);
                // Motorfach, von oben offen
                translate([u_mf, -(mot_w + mot_clr)/2, -mot_top]) cube([u_me - u_mf, mot_w + mot_clr, up]);
                translate([u_me - eps, -tab_win/2, -mot_top + tab_bot]) cube([back_t + 2*eps, tab_win, up]);
                // Tasche für die Platine
                translate([pcb_x0, -pcb_hw, pcb_z]) cube([u_e1 - pcb_x0, 2*pcb_hw, up]);
                translate([u_e0, -cav_hw, bay_floor]) cube([bay_l, 2*cav_hw, up]);
                // USB-C: Steckeröffnung in der Stirnseite, Raum für die Schirmlaschen
                translate([-eps, usb_off - plug_w/2, usb_z - plug_h/2]) cube([pcb_x0 + 2*eps, plug_w, up]);
                translate([pcb_x0 - eps, usb_off - (usb_leg + 0.9), pcb_z - usb_dn - 0.4]) cube([usb_d + 1.4, 2*(usb_leg + 0.9), up]);
                // Zellenfach
                translate([x_bat, 0, cell_z]) {
                    xcyl(bay_d, cell_bay);
                    translate([0, -bay_d/2, 0]) cube([cell_bay, bay_d, up]);
                }
            }
            intersection() {
                tray_body();
                union() {
                    contact_seat(x_bat, 1);
                    contact_seat(x_bat + cell_bay, -1);
                }
            }
        }
        translate([u_e1 - eps, -2.5, pcb_top]) cube([bulk_t + con_slot + con_lip + 2*eps, 5, up]);
        translate([x_bat + cell_bay - eps, -2, cell_z + con_w/2 - 0.5]) cube([end_t + 2*eps, 4, up]);
        translate([sled_l - end_t/2, 6, sqrt(pow(sled_od/2, 2) - 49) - 0.8]) {
            translate([-1.2, -0.5, 0]) cube([2.4, 1, 2]);
            translate([-0.5, -1.2, 0]) cube([1, 2.4, 2]);
        }
    }
}

// ---------- Zusammenbau ----------

module tube_profile() {
    difference() {
        circle(d = tube_od);
        difference() {
            circle(d = tube_id);
            for (s = [-1, 1]) translate([s*(ridge_d/2 + tube_od/4), 0]) square([tube_od/2, ridge_w], center = true);
        }
        for (s = [-1, 1]) translate([s*(tube_od/2 - slot_d/2 + 0.5), 0]) square([slot_d + 1, slot_w], center = true);
    }
}

module ghost() {
    color("ForestGreen") translate([pcb_x0, -pcb_w/2, pcb_z]) cube([pcb_l, pcb_w, pcb_t]);
    color("Silver") translate([pcb_x0, usb_off - usb_w/2, pcb_z - usb_dn]) cube([usb_d, usb_w, usb_dn + pcb_t + usb_h]);
    color("Silver") translate([u_mf, -mot_w/2, -mot_h/2]) cube([mot_len, mot_w, mot_h]);
    color("Silver") translate([u_mf - mot_boss_h, 0, 0]) xcyl(mot_boss_d, mot_boss_h + eps);
    color("Silver") translate([u_mf - mot_shaft_len, 0, 0]) xcyl(mot_shaft_d, mot_shaft_len);
    color("Blue")   translate([x_bat + con_t + con_spring, 0, cell_z]) xcyl(cell_d, cell_len);
    color([0.8, 0.8, 0.85, 0.35]) translate([nose_l, 0, 0]) rotate([90, 0, 90]) linear_extrude(sled_l) tube_profile();
}

module assembly() {
    color("LightSkyBlue") tray();
    color("LimeGreen") translate([-(collar_t + key_gap), 0, 0]) drive_key();
    ghost();
}

// ---------- Ausgabe ----------

module tray_print()      translate([0, 0, sled_od/2 - sled_flat]) tray();
module drive_key_print() translate([0, 0, pocket_d - 0.2]) rotate([0, -90, 0]) drive_key();

if      (part == "assembly")  assembly();
else if (part == "section")   intersection() { assembly(); translate([-20, 0, -50]) cube([sled_l + 40, 50, 100]); }
else if (part == "tray")      tray_print();
else if (part == "drive_key") drive_key_print();
else if (part == "plate")     { tray_print(); translate([sled_l/2, tube_od/2 + tenon, 0]) drive_key_print(); }

// IKEA KOPPLA Wandhalterung – Steckdosen zeigen nach oben
// Materialsparend: zwei schmale U-Klammern, je eine pro Ende der Leiste.
// Jede Klammer hat einen Endanschlag, damit die Leiste nicht seitlich rausrutscht,
// und eine Senkkopfschraube in der Rückwand.
//
// Voreingestellt für KOPPLA 5-fach mit 2 USB (CH, 903.002.35).
// IKEA gibt nur gerundete Werte an (Länge 0.3 m, Breite 6 cm, Höhe fehlt):
// Länge und Höhe nachmessen!

/* [Masse der Steckerleiste] */
strip_l = 300;   // Länge (ohne Kabel)
strip_w = 60;    // Breite (Wand -> vorne)
strip_h = 40;    // Höhe des Gehäuses (Boden -> Steckdosenfläche), geschätzt

/* [Klammer] */
clearance = 0.5;  // Spiel
t         = 2.4;  // Wandstärke
b         = 14;   // Breite einer Klammer (entlang der Leiste)
lip_h     = 12;   // Höhe der vorderen Lippe
stop_h    = 8;    // Höhe des Endanschlags (0 = kein Anschlag)
tab_h     = 14;   // Rückwand ragt so weit über die Leiste (für die Schraube)
gusset    = 4;    // Verstärkung in den Innenecken

/* [Schraube] */
screw_d      = 4.5;
screw_head_d = 9;

$fn = 40;

// ---------- abgeleitete Masse ----------
in_w   = strip_w + 2*clearance;
back_h = t + strip_h + clearance + tab_h;
screw_z = t + strip_h + clearance + tab_h/2;

// Abstand der Klammer-Aussenkanten an der Wand
echo(str("Aussenkanten-Abstand der Klammern: ", strip_l + 2*clearance + 2*t, " mm"));

module profile() {
    // Querschnitt in X (Wand -> vorne) / Z (hoch)
    union() {
        square([t, back_h]);                                   // Rückwand
        square([in_w + 2*t, t]);                               // Boden
        translate([in_w + t, 0]) square([t, t + lip_h]);       // Lippe
        polygon([[t, t], [t + gusset, t], [t, t + gusset]]);   // Ecke hinten
        polygon([[in_w + t, t], [in_w + t - gusset, t], [in_w + t, t + gusset]]); // Ecke vorne
    }
}

module bracket() {
    difference() {
        union() {
            // U-Profil, entlang Y extrudiert
            rotate([90, 0, 0]) mirror([0, 0, 1]) linear_extrude(b) profile();
            // Endanschlag an der Aussenseite (y = 0)
            if (stop_h > 0)
                cube([in_w + 2*t, t, t + stop_h]);
        }
        // Senkloch, Kopf auf der Innenseite
        translate([0, b/2, screw_z]) rotate([0, 90, 0]) {
            translate([0, 0, -1]) cylinder(d=screw_d, h=t + 2);
            translate([0, 0, t - (screw_head_d - screw_d)/2])
                cylinder(d1=screw_d, d2=screw_head_d, h=(screw_head_d - screw_d)/2 + 0.01);
        }
    }
}

print_orientation = true; // false = Ansicht wie montiert

if (print_orientation) {
    // Beide Klammern flach liegend (Endanschlag auf dem Bett), keine Stützen.
    // Die zweite ist gespiegelt: eine für links, eine für rechts.
    rotate([90, 0, 0]) bracket();
    translate([-8, 0, 0]) mirror([1, 0, 0]) rotate([90, 0, 0]) bracket();
} else {
    gap = strip_l + 2*clearance;
    translate([0, -t, 0]) bracket();
    translate([0, gap + t, 0]) mirror([0, 1, 0]) bracket();
    %translate([t + clearance, 0, t]) cube([strip_w, gap, strip_h]);  // Leiste (nur Vorschau)
}

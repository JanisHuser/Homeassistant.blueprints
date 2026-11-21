// ============================================================
//  Motorrollo auf Basis IKEA LÅNGDANS  –  Matter über Thread
//  Version "Schlitten": ein Druckteil im Rohr trägt Motor, eine lange Platine und die Zelle. Alles dreht
//  mit dem Rohr. Fest steht nur der Schlüssel: er sitzt mit dem Vierkant im Halter, die Motorwelle treibt
//  ihn über Sechskantstab und Kupplung, also dreht sich der Motor samt Rohr darum.
//
//  Aufbau (Achse = X, Motorseite links bei x = 0 = Wand):
//   [Halter]─[Schlüssel]─[Nase]═ Schlitten: Kupplung │ N20 │ Fach │ Schott │ 18650 ═[608]─[Achse]─[Halter]
//                         └── Platine liegt flach über Kupplung, Motor und Fach, von der Nase bis zum Schott
//
//  Die Platine (ESP32-H2 als Chip, Laderegler, Schutz, DRV8833; KiCad-Projekt in pcb/) liegt in einer Tasche oben im Schlitten,
//  das Rohr deckt sie ab. Ihr vorderes Ende mit der Chip-Antenne liegt in der Nase ausserhalb des Alu-Rohrs.
//  Alle Bauteile sitzen oben (am Rand flach, top_w × top_h, in der Mitte bis mid_h); unten im Fach hinter dem
//  Motor sind nur die Lötpunkte für die Motordrähte.
//  Fast keine Kabel: der Motor hat zwei kurze Drähte von seinen Lötfahnen durchs Fenster hinter ihm auf zwei
//  Lötpunkte der Platine, die Lötfahne der Federplatte (Minus) liegt über dem Schott flach auf der Platine,
//  und der Pluspol am hinteren Ende hat ein Kabel über der Zelle zur Platine.
//  USB-C (Laden und Flashen) sitzt vorne auf der Platine, Öffnung zur Wand, über dem Sechskantstab. Zum Laden das
//  Rollo aus den Haltern heben und den Schlüssel samt Stab aus der Nase ziehen: dann geht der Stecker in die Nase.
//
//  Einbau: Kupplung auf die Motorwelle, Motor samt Kupplung von oben ins Fach. Zwei kurze Drähte an die
//  Lötfahnen des Motors, Platine in die Tasche, Drähte an die Lötpunkte. Kontaktplatten in ihre Sitze, Lötfahnen anlöten, Pluskabel legen, Zelle
//  von oben einlegen. Eine Lage Kapton um den Schlitten, dann mit den Nuten auf die Stege ins Rohr schieben.
//
//  Vor dem Druck nachmessen: tube_id, ridge_*, tube_od, Motor (mot_*), Kontaktplatten und Zelle (con_*, cell_*).
//
//  Rohrstück mit echtem Querschnitt (ID, Stege, Schlitze) zum Testen des Schlittens: part = "tube_section".
//
//  Einzelteil wählen:  part = "...";   oder
//    openscad -D 'part="sled"' -o sled.stl rollo.scad
//  Umriss der Platine für KiCad (Edge.Cuts):  openscad -D 'part="pcb_outline"' -o pcb_outline.dxf rollo.scad
//  Alle Teile sind fürs Drucken bereits richtig orientiert.
// ============================================================

part = "assembly"; // [assembly, section, tube_section, bracket_motor, bracket_idle, key, hex_rod, coupler, sled, idle_axle, pcb_outline]

$fn = 96;
eps = 0.01;

/* [Einbau] */
recess_w = 850;     // lichte Breite zwischen den Wänden
fit_gap  = 2;       // Luft gesamt

/* [IKEA-Rohr – nachmessen!] */
tube_id    = 22.4;  // LÅNGDANS, gemessen
ridge_d    = 21.5;  // zwei Stege innen, gegenüber (±Y): Ø über die Stegspitzen
ridge_w    = 1.0;   // Stegbreite. Der Schlitten hat Nuten dafür: die Stege nehmen das Drehmoment
tube_od    = 25;    // Annahme
slot_w     = 2.0;   // Schlitze aussen an den Seiten (±Y), über den Stegen: Breite – nachmessen!
slot_d     = 0.8;   // ... Tiefe ab Aussendurchmesser – nachmessen!
roll_d     = 40;    // Stoffwickel aufgerollt, gemessen
tsec_l     = 25;    // Rohrstück zum Testen (part = "tube_section"): Länge
tsec_comp  = 0;     // ... Innenmasse so viel grösser drucken, falls Löcher zu klein herauskommen

/* [Toleranzen] */
clr      = 0.3;
rib_i    = 0.3;     // Übermass der Klemmrippen im Rohr
tube_lim = 0.5;     // Abstand aller Teile zur Rohrwand

/* [Halter: Haken hinter die Täferverkleidung] */
// Seitenansicht: Arm von der Achse waagrecht zur Rückwand, oben bündig mit der Unterkante der Verkleidung.
// Am Wandende steigt eine Nase br_nud_h hoch in den Spalt zwischen Wand und Verkleidung (genagelt).
// Kraftfluss: das Gewicht will den Halter kippen (Arm runter). Die Nase stemmt sich gegen die Rückseite der
// Verkleidung, der Fuss unten gegen die Wand: ein Druckpaar über die ganze Höhe, kein Schälen am Klebeband.
// Senkrecht hält Reibung, und die klemmt sich selbst: die Andruckkräfte wachsen mit der Last.
// Nach oben (Einhängen) stösst der Arm an die Unterkante der Verkleidung. Das VHB am Fuss hält nur die Lage.
br_t      = 10;     // Arm, Dicke entlang der Achse = Innenfläche (Anlage Schlüsselbund) ab Aussenseite
br_h      = 25;     // Arm, Höhe, mittig zur Achse. Oberkante = Unterkante der Verkleidung
sh_gap    = 5;      // Spalt zwischen Wand und Rückseite der Verkleidung – nachmessen!
br_nud_t  = sh_gap - 0.6;   // Nase, Dicke: 0.3 Luft auf jeder Seite
br_nud_h  = 15;     // Nase, so weit hinter die Verkleidung
br_nud_ch = 1.5;    // Fase vorne an der Nasenspitze: fädelt ein
br_ft_t   = 6;      // Fuss an der Wand, Dicke (unterhalb der Verkleidung)
br_ft_w   = 50;     // Fuss und Nase, Breite entlang der Achse nach innen (hinter dem Stoff): trägt die Nase
br_gus_l  = 25;     // Zwickel in der Draufsicht vom Arm zum breiten Fuss
br_chord  = 3;      // Arm als Fachwerk: Gurt oben und unten ...
br_web    = 2.5;    // ... Diagonalen (ca. 60°, druckt ohne Stütze: Fenster gehen quer durch, Halter liegt auf der Seite)
fil_r     = 4;      // Ausrundung der Innenecken in der Draufsicht
// Nachweis (Echo unten): Zug am Stoff zusammen mit dem Motormoment
br_F      = 30;     // N  vertikal an der Achse: Gewicht + kräftiges Ziehen am Stoff
br_T      = 0.3;    // Nm Drehmoment des Motors, abgestützt über den Vierkant
br_mu     = 0.3;    // Reibwert PETG auf Farbe/Holz, vorsichtig
br_sig    = 10;     // MPa zulässige Spannung (PETG in Lagenrichtung, ~4-fache Sicherheit)
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

/* [Schlitten] */
nose_l    = 4;      // ausserhalb des Rohrs. Mit collar_t + key_gap höchstens 5 mm
cp_d      = 9.6;    // Kupplung Stab ↔ Motorwelle
cp_clr    = 0.4;
sled_od   = tube_id - 0.6;   // hinter dem Motor, ohne Klemmrippen
sled_flat = 0.4;    // unten flach zum Drucken
mot_clr   = 0.4;    // Motorfach grösser als der Motor
mot_end   = 0.3;    // Luft hinter dem Motor
back_t    = 1.5;    // Wand hinter dem Motor
tab_win   = 8.4;    // Fenster in der Wand: Motordrähte nach oben zur Platine
tab_bot   = 2.4;    // Steg unten im Fenster
bay_l     = 5;      // Fach hinter dem Motor: Motordrähte an die Lötpunkte unten auf der Platine
bulk_t    = 2;      // Schott Fach ↔ Zelle
end_t     = 3;
kapton    = 0.1;
wire_d    = 0.9;    // Pluskabel über der Zelle

/* [Platine] */
pcb_t     = 0.8;
pcb_w     = 17;
pcb_x0    = 0.6;    // Vorderkante (Antenne) ab Stirnseite
pcb_clr   = 0.2;    // Tasche je Seite
pcb_air   = 0.2;    // Luft zwischen Motorfach und Platine
ledge     = 1.2;    // Auflage je Seite im Fach
top_w     = 15;     // Bauteile oben: höchstens so breit verteilt ...
top_h     = 1.3;    // ... und so hoch (QFN, Quarz, Chip-Antenne, 0402)
mid_w     = 13;     // in der Mitte ist mehr Platz: Bauteile so breit verteilt ...
mid_h     = 2.0;    // ... dürfen so hoch sein (Taster, SOT-23)
bot_h     = 2.6;    // Platz unter der Platine im Fach: Lötstellen der Motordrähte
usb_w     = 8.94;   // USB-C-Buchse (G-Switch GT-USB-7014C, sitzt versenkt in einer Aussparung der Platine): Breite
usb_d     = 6.5;    // ... Tiefe entlang der Achse ab Vorderkante
usb_h     = 1.56;   // ... Höhe über der Platine
usb_dn    = 0.8;    // ... ragt so weit unter die Platine (versenkt 1.6 mm, Platine 0.8 mm)
usb_off   = 2.0;    // ... Mitte so weit zur +Y-Seite, weg von der Antenne
usb_leg   = 5.62;   // ... Schirmlaschen quer ab ihrer Mitte
plug_w    = 12.4;   // Stecker-Umspritzung: Öffnung in der Stirnseite
plug_h    = 6.6;

/* [Lager 608 Lagerseite (direkt im Rohr)] */
brg_d  = 22;
brg_w  = 7;
brg_id = 8;
brg_comp = 0.3;    // stehend gedruckte Zapfen kommen so viel dünner heraus (gemessen: 7.9 → 7.6)
brg_rib  = 0.25;   // Übermass der Klemmrippen im Lager (nach Ausgleich)

/* [Motor N20 ohne Encoder, nachgemessen] */
mot_w        = 12;
mot_h        = 10;   // Abflachungen oben/unten = Verdrehsicherung im Fach
mot_len      = 24.2; // Getriebe + Motor
mot_boss_d   = 5;
mot_boss_h   = 1.1;
mot_shaft_d  = 3;
mot_shaft_D  = 2.5;  // Mass über Abflachung
mot_shaft_len= 1.1 + 5;   // ab Getriebefläche: Bund 1.1 + 5 mm freie Welle

/* [Zelle und Kontaktplatten, wie beim Ventilkopf] */
cell_d     = 18.4;
cell_len   = 65;
cell_nub   = 0.5;
cell_fit   = 0.2;
con_w      = 12;
con_t      = 0.3;
con_tab    = 7;      // Lötfahne in voller Länge
con_bend   = 1;      // Platz für die Biegung über der Plattenkante
con_spring = 5.5;
con_dome   = 1;
con_slot   = 0.5;
con_lip    = 0.8;
con_lap    = 1;
bay_d      = cell_d + 2*cell_fit;
cell_bay   = con_t + con_spring + cell_len + con_dome + con_t;   // Federplatte (Platinenseite) bis Knopfplatte
cell_z     = 0;

// ---------- abgeleitete Masse ----------
W        = recess_w - fit_gap;
r_roll   = roll_d/2;
y_wall   = r_roll + back_gap;
lim      = tube_id/2 - tube_lim;               // so weit darf alles von der Achse weg

hex_ac   = hex_af / cos(30);                   // Mass über Ecken
bore_d   = hex_ac + 2*clr;                     // Schlitten dreht sich um den Stab

// Schlitten, u = 0 an der Stirnseite (Wand)
mot_top  = (mot_h + mot_clr)/2;
pcb_z    = mot_top + pcb_air;                  // Unterseite Platine
pcb_top  = pcb_z + pcb_t;
pcb_hw   = pcb_w/2 + pcb_clr;
cav_hw   = pcb_w/2 - ledge;
cp_l     = hex_in + 1 + (mot_shaft_len - mot_boss_h + 0.5);
u_cp     = nose_l + 0.5;                       // Kupplung
u_mf     = u_cp + cp_l + mot_boss_h + 0.5;     // Getriebefläche
u_me     = u_mf + mot_len + mot_end;           // Ende Motorfach
u_e0     = u_me + back_t;                      // Fach hinter dem Motor
u_e1     = u_e0 + bay_l;
x_bat    = u_e1 + bulk_t;                      // Federplatte
sled_l   = x_bat + cell_bay + end_t;
pcb_l    = u_e1 - 0.3 - pcb_x0;
bay_floor= pcb_z - bot_h - 0.2;
usb_z    = (pcb_top + usb_h + pcb_z - usb_dn)/2;   // Mitte der Buchse
u_t      = nose_l;                             // Rohrende
hex_len  = (pocket_d - 0.2) + collar_t + key_gap + u_cp + hex_in - 0.5;

// Lage im Einbau
x_h      = br_t + collar_t + key_gap;
x_tube0  = x_h + u_t;
x_tube1  = W - br_t - 1.5;
tube_len = x_tube1 - x_tube0;

echo(str("Rohrlänge: ", tube_len, " mm"));
echo(str("Stoffbreite max.: ", tube_len - 4, " mm"));
echo(str("Schlitten: ", sled_l, " mm, davon ", nose_l, " mm Nase ausserhalb des Rohrs"));
echo(str("Sechskantstab ", hex_af, " mm SW, Länge ", hex_len, " mm"));
// Platinenkoordinaten: x ab Vorderkante (Antenne), y = 0 auf der Achse
echo(str("Platine: ", pcb_l, " × ", pcb_w, " × ", pcb_t, " mm, Unterseite ", pcb_z, " mm über der Achse"));
echo(str("Platine: ausserhalb des Rohrs (Antenne) x = 0 bis ", nose_l - pcb_x0));
echo(str("Platine: Getriebefläche bei x = ", u_mf - pcb_x0, ", Motorrückseite bei x = ", u_mf + mot_len - pcb_x0));
echo(str("Platine: unten nur die Lötpunkte für den Motor, x = ", u_e0 - pcb_x0, " bis ", pcb_l, ", |y| <= ", cav_hw));
echo(str("Platine: USB-C in einer Aussparung ", usb_w + 0.3, " × 6.7 mm an der Vorderkante, Mitte bei y = ", usb_off, "; Antenne bei -y"));
echo(str("Platine: oben Bauteile höchstens ", top_h, " mm bei |y| <= ", top_w/2, ", ", mid_h, " mm bei |y| <= ", mid_w/2));
echo(str("Platine: Lötfahne Federplatte (Minus) an der Hinterkante, |y| <= 1.5"));

assert(br_h <= 25, "Halter höher als 25 mm");
assert(y_wall - br_ft_t - br_gus_l >= r_roll + 10, "Zwickel am Halter reicht bis an den Stoff");
assert(drop + (tenon + 0.4)/2 <= br_h/2 - 2, "Keilsitz zu nah an der Armkante");
assert(br_nud_t <= sh_gap - 0.4, "Nase passt nicht in den Spalt hinter der Verkleidung");
assert(collar_t + key_gap + nose_l <= 5, "Mehr als 5 mm ausserhalb des Rohrs");
assert(sqrt(pow(pcb_hw, 2) + pow(pcb_top, 2)) <= lim, "Platine stösst am Rohr an");
assert(sqrt(pow(top_w/2, 2) + pow(pcb_top + top_h + kapton, 2)) <= lim, "Bauteile oben stossen am Rohr an");
assert(sqrt(pow(mid_w/2, 2) + pow(pcb_top + mid_h + kapton, 2)) <= lim, "Hohe Bauteile in der Mitte stossen am Rohr an");
assert(sqrt(pow(pcb_hw, 2) + pow(pcb_z, 2)) <= sled_od/2 - 0.4, "Keine Auflage für die Platine");
assert(cp_d/2 + cp_clr <= pcb_z - 0.2, "Kupplung streift die Platine");
assert(cp_d <= mot_h + mot_clr - 0.4, "Kupplung geht nicht ins Motorfach");
assert(cp_d + 2*cp_clr <= mot_w - 1.5, "Getriebe hat keinen Anschlag an der Kupplungsbohrung");
assert(sqrt(pow(usb_off + usb_w/2, 2) + pow(pcb_top + usb_h + kapton, 2)) <= lim, "USB-C stösst am Rohr an");
assert(usb_off + usb_leg + 0.5 <= pcb_w/2 - 0.25, "Schirmlaschen der USB-C-Buchse zu nah am Platinenrand");
assert(pcb_z - usb_dn - 0.4 >= bore_d/2 + 0.6, "USB-C-Buchse unter der Platine trifft die Bohrung für den Stab");
assert(cell_z + con_w/2 <= pcb_top, "Federplatte ragt über die Platine: Lötfahne liegt nicht flach auf");
assert(tube_id/2 - cell_d/2 - cell_fit >= wire_d + kapton + 0.3, "Kein Platz für das Pluskabel über der Zelle");
assert(ridge_d/2 - 0.4 - bay_d/2 >= 0.8, "Wand ums Zellenfach an den Stegnuten zu dünn");

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

// D-Bohrung für die N20-Welle, ab x = 0 entlang -X, Tiefe d
module d_bore(d) {
    translate([-d, 0, 0]) intersection() {
        xcyl(mot_shaft_d + 0.15, d + eps);
        translate([0, -mot_shaft_d, -mot_shaft_d])
            cube([d + eps, 2*mot_shaft_d, mot_shaft_d + (mot_shaft_D - mot_shaft_d/2) + 0.05]);
    }
}

// ---------- Teile ----------

// ---------- Halter ----------
// Seitenansicht (y zur Wand, z hoch, Achse bei y = z = 0):
//
//          Verkleidung │ │   ┌─ Nase br_nud_h hoch im Spalt sh_gap
//   ───────────────────┘ │ ┌─┤
//   ┌─────────────────────┬┘ │ Wand
//   │ ▢ Vierkant  /\/\/\/\  Fuss│
//   └──────────────────────────┘
//
//  - Arm br_t dick (ganze Dicke, Aussenseite x = 0 flach), br_h hoch, als Fachwerk: zwei Gurte, Diagonalen.
//  - Fuss und Nase breit (br_ft_w) entlang der Achse, hinter dem Stoff. Ein Zwickel in der Draufsicht führt
//    das Moment vom schmalen Arm in die Breite.
//  - Vierkantsitz unverändert: von vorne eingefädelt, um drop abgesenkt, Dach über dem Schlitz.
//  - Gedruckt auf der Aussenseite liegend: alle Biegespannungen liegen in den Lagen, Fenster gehen senkrecht
//    durch, der Vierkantsitz öffnet nach oben.
//  - Montage: VHB nur auf die untere Hälfte der Fussrückseite, Schutzfolie mit Zuglasche nach unten dranlassen.
//    Nase von unten hinter die Verkleidung schieben bis der Arm anstösst, Folie herausziehen, Fuss andrücken.
br_y_tr0 = (tenon + 0.4)/2 + 3;                  // Fachwerk: ab hinter dem Vierkantsitz ...
br_y_tr1 = y_wall - br_ft_t - br_gus_l;          // ... bis zum Zwickel
br_zc    = br_h/2 - br_chord/2;                  // Gurtmitte
br_n     = max(1, round((br_y_tr1 - br_y_tr0) / (2*br_zc*tan(30))));   // Felder, Diagonalen ~60°
br_step  = (br_y_tr1 - br_y_tr0) / br_n;

module bracket_truss_windows() {
    zi = br_h/2 - br_chord;
    offset(r = 1) offset(delta = -1) difference() {
        translate([br_y_tr0, -zi]) square([br_y_tr1 - br_y_tr0, 2*zi]);
        for (i = [0 : br_n - 1]) hull() for (j = [i, i + 1])
            translate([br_y_tr0 + j*br_step, (j % 2 == 0 ? -1 : 1) * br_zc]) circle(d = br_web, $fn = 24);
        for (y = [br_y_tr0, br_y_tr1]) translate([y - br_web/2, -br_h/2]) square([br_web, br_h]);
    }
}

module bracket() {
    s = tenon + 0.4;
    tip = br_h/2;
    y_f = y_wall - br_ft_t;                       // Vorderseite Fuss
    difference() {
        union() {
            // Draufsicht: Arm, Fuss, Zwickel – alle br_h hoch
            translate([0, 0, -br_h/2]) linear_extrude(br_h) offset(r = -fil_r) offset(r = fil_r) union() {
                translate([0, -tip]) square([br_t, y_wall + tip]);
                translate([0, y_f]) square([br_ft_w, br_ft_t]);
                polygon([[br_t - eps, y_f - br_gus_l], [br_t - eps, y_f + eps], [br_ft_w, y_f + eps]]);
            }
            // Nase hinter die Verkleidung, Rückseite bündig an der Wand, vorne angefast
            rotate([90, 0, 90]) linear_extrude(br_ft_w) polygon([
                [y_wall - br_nud_t, tip - eps], [y_wall - br_nud_t, tip + br_nud_h - br_nud_ch],
                [y_wall - br_nud_t + br_nud_ch, tip + br_nud_h], [y_wall, tip + br_nud_h], [y_wall, tip - eps]]);
        }
        // Vierkantsitz, von vorne eingefädelt und um drop abgesenkt
        translate([br_t - pocket_d, -s/2, -s/2]) cube([pocket_d + eps, s, s]);
        translate([br_t - pocket_d, -tip - eps, drop - s/2]) cube([pocket_d + eps, tip + s/2 + eps, s]);
        // Fachwerkfenster quer durch den Arm
        rotate([90, 0, 90]) translate([0, 0, -1]) linear_extrude(br_t + 2) bracket_truss_windows();
    }
}

// Nachweis von Hand (N, mm, MPa). Moment an der Wand: Zug mal Hebel plus Motormoment
br_M     = br_F * y_wall + br_T * 1000;
br_Nn    = br_M / (br_h + br_nud_h);             // Andruck an der Nase, ungünstig: trägt nur an der Spitze
br_s_nud = 6 * br_Nn * br_nud_h / (br_ft_w * br_nud_t * br_nud_t);
br_mu_req= br_F * (br_h + br_nud_h) / (2 * (br_F * y_wall - br_T * 1000));   // Reibung an Nase + Fuss, Moment gegenläufig
br_Ma    = br_F * br_y_tr1 + br_T * 1000;        // Arm am Ende des Fachwerks
br_s_ch  = br_Ma / (br_h - br_chord) / (br_chord * br_t);
br_s_cr  = PI * PI * 2000 * br_chord * br_chord / (12 * pow(2 * br_step, 2));   // Gurt knickt zwischen den Knoten (PETG E 2000)
echo(str("Halter: Moment an der Wand ", br_M/1000, " Nm, Andruck Nase/Fuss ", round(br_Nn), " N (bei ", br_F, " N Zug)"));
echo(str("Halter: Nase ", br_s_nud, " MPa, Gurt ", br_s_ch, " MPa (knickt bei ", br_s_cr, "), nötiger Reibwert ", br_mu_req));
assert(br_s_nud <= br_sig, "Nase zu schwach: br_ft_w oder br_nud_t grösser");
assert(br_s_ch <= br_sig && br_s_ch <= br_s_cr/2, "Arm zu schwach: br_chord grösser");
assert(br_mu_req <= br_mu, "Halter rutscht: Reibung reicht nicht");

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
        translate([min(x0 - dir*eps, x0 + dir*l), con_w/2 - con_lap, -sled_od]) cube([l + eps, sled_od, 2*sled_od]);
        translate([min(x0 - dir, x0 + dir*con_slot), -1, cell_z - con_w/2]) cube([con_slot + 1, con_w/2 + 0.15 + 1, sled_od]);
    }
}

// Schlitten, u = 0 an der Stirnseite: Nase | Kupplung | Motorfach | Fach | Schott | Zellenfach | Boden.
// Vorne (bis hinter den Motor) mit Klemmrippen, hinten glatt; durchgehend Nuten für die Stege, also dreht er mit
// dem Rohr. Oben die Tasche für die Platine, alles von oben eingelegt. Druckt auf der Abflachung liegend.
module sled_body() {
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

module sled() {
    up = tube_od;   // "bis oben hinaus": das Rohr ist der Deckel
    difference() {
        union() {
            difference() {
                sled_body();
                // Bohrung für den Stab, dann die Kupplung: von oben offen
                translate([-eps, 0, 0]) xcyl(bore_d, u_cp + 2*eps);
                translate([u_cp, 0, 0]) xcyl(cp_d + 2*cp_clr, u_mf - u_cp + eps);
                translate([u_cp, -(cp_d/2 + cp_clr), 0]) cube([u_mf - u_cp + eps, cp_d + 2*cp_clr, up]);
                // Motorfach, von oben offen. Die Ecken der Getriebefläche liegen auf der Stufe zur Kupplung
                translate([u_mf, -(mot_w + mot_clr)/2, -mot_top]) cube([u_me - u_mf, mot_w + mot_clr, up]);
                // Fenster in der Wand hinter dem Motor: Motordrähte hoch zur Platine
                translate([u_me - eps, -tab_win/2, -mot_top + tab_bot]) cube([back_t + 2*eps, tab_win, up]);
                // Tasche für die Platine, von der Nase bis zum Schott
                translate([pcb_x0, -pcb_hw, pcb_z]) cube([u_e1 - pcb_x0, 2*pcb_hw, up]);
                // Fach unter der Platine: Motordrähte
                translate([u_e0, -cav_hw, bay_floor]) cube([bay_l, 2*cav_hw, up]);
                // Öffnung für den USB-C-Stecker in der Stirnseite, Raum unter der Buchse für ihre Schirmlaschen
                translate([-eps, usb_off - plug_w/2, usb_z - plug_h/2]) cube([pcb_x0 + 2*eps, plug_w, up]);
                translate([pcb_x0 - eps, usb_off - (usb_leg + 0.9), pcb_z - usb_dn - 0.4]) cube([usb_d + 1.4, 2*(usb_leg + 0.9), up]);
                // Zellenfach, von oben offen
                translate([x_bat, 0, cell_z]) {
                    xcyl(bay_d, cell_bay);
                    translate([0, -bay_d/2, 0]) cube([cell_bay, bay_d, up]);
                }
            }
            intersection() {
                sled_body();
                union() {
                    contact_seat(x_bat, 1);                 // Federplatte, Minuspol
                    contact_seat(x_bat + cell_bay, -1);     // Knopfplatte, Pluspol
                }
            }
        }
        // Lötfahne der Federplatte: über das Schott flach auf die Platine
        translate([u_e1 - eps, -2.5, pcb_top]) cube([bulk_t + con_slot + con_lip + 2*eps, 5, up]);
        // Lötfahne der Knopfplatte: umgebogen durch einen Schlitz im Boden nach hinten
        translate([x_bat + cell_bay - eps, -2, cell_z + con_w/2 - 0.5]) cube([end_t + 2*eps, 4, up]);
        // Pluszeichen oben auf dem Boden, neben dem Schlitz: hier kommt der Pluspol hin
        translate([sled_l - end_t/2, 6, sqrt(pow(sled_od/2, 2) - 49) - 0.8]) {
            translate([-1.2, -0.5, 0]) cube([2.4, 1, 2]);
            translate([-0.5, -1.2, 0]) cube([1, 2.4, 2]);
        }
    }
}

// ---------- Zusammenbau ----------

// Querschnitt des IKEA-Rohrs in der XY-Ebene, Stege und Schlitze auf ±X (wird zu ±Y gedreht).
// comp vergrössert die Innenmasse (Bohrung und Abstand der Stege) für den Druck.
module tube_profile(comp = 0) {
    difference() {
        circle(d = tube_od);
        difference() {
            circle(d = tube_id + comp);
            // Stege innen, gegenüber
            for (s = [-1, 1]) translate([s*((ridge_d + comp)/2 + tube_od/4), 0])
                square([tube_od/2, ridge_w - comp], center = true);
        }
        // Schlitze aussen über den Stegen
        for (s = [-1, 1]) translate([s*(tube_od/2 - slot_d/2 + 0.5), 0])
            square([slot_d + 1, slot_w], center = true);
    }
}

module tube() {
    color([0.8, 0.8, 0.85, 0.35]) translate([x_tube0, 0, 0]) rotate([90, 0, 90])
        linear_extrude(tube_len) tube_profile();
}

// Koordinaten wie sled
module sled_ghost() {
    // Platine mit Chip-Antenne vorne, ESP32-H2 dahinter, alle Bauteile oben, USB-C
    color("ForestGreen") translate([pcb_x0, -pcb_w/2, pcb_z]) cube([pcb_l, pcb_w, pcb_t]);
    color("Silver")  translate([pcb_x0, usb_off - usb_w/2, pcb_z - usb_dn]) cube([usb_d, usb_w, usb_dn + pcb_t + usb_h]);
    color("White")   translate([pcb_x0 + 0.7, -8.0, pcb_top]) cube([3.2, 1.6, top_h]);
    color("Black")   translate([pcb_x0 + 11.5, -2, pcb_top]) cube([4, 4, 0.9]);
    color("Black")   translate([pcb_x0 + 26, -mid_w/2, pcb_top]) cube([16, mid_w, mid_h]);
    // Motor, zwei Drähte hoch zu den Lötpunkten
    color("Silver") translate([u_mf, -mot_w/2, -mot_h/2]) cube([mot_len, mot_w, mot_h]);
    color("Silver") translate([u_mf - mot_boss_h, 0, 0]) xcyl(mot_boss_d, mot_boss_h + eps);
    color("Silver") translate([u_mf - mot_shaft_len, 0, 0]) xcyl(mot_shaft_d, mot_shaft_len);
    color("Red")    for (s = [-1, 1]) translate([u_mf + mot_len, s*2.6 - 0.3, 1]) cube([0.6, 0.6, pcb_top - 1]);
    color("DimGray") translate([-(pocket_d - 0.2) - collar_t - key_gap, 0, 0]) hex(hex_af, hex_len);
    // Zelle und Kontaktplatten
    color("Blue") translate([x_bat + con_t + con_spring, 0, cell_z]) xcyl(cell_d, cell_len);
    for (x = [x_bat, x_bat + cell_bay - con_t]) color("Silver")
        translate([x, -con_w/2, cell_z - con_w/2]) cube([con_t, con_w, con_w]);
    color("Silver") translate([x_bat + con_t - con_tab, -1.5, pcb_top]) cube([con_tab, 3, con_t]);
    color("Silver") translate([x_bat + cell_bay - con_t, -1.5, cell_z + con_w/2 + con_bend - con_t]) cube([con_tab, 3, con_t]);
    color("Silver") translate([x_bat + con_t, 0, cell_z]) xcyl(7, con_spring);
    color("Silver") translate([x_bat + cell_bay - con_t - con_dome, 0, cell_z]) xcyl(6, con_dome);
    // Pluskabel über der Zelle zur Platine
    color("Red") translate([u_e1 - 2, -0.45, cell_d/2 + cell_fit + kapton]) cube([x_bat + cell_bay - u_e1 + 2, wire_d, wire_d]);
}

module assembly() {
    color("SteelBlue") bracket();
    color("SteelBlue") translate([W, 0, 0]) mirror([1, 0, 0]) bracket();
    color("LimeGreen")  translate([br_t, 0, 0]) key();
    color("LightSkyBlue") translate([x_h, 0, 0]) sled();
    color("LimeGreen")  translate([x_h + u_cp, 0, 0]) coupler();
    color("Gold")       translate([W - br_t, 0, 0]) mirror([1, 0, 0]) idle_axle();
    tube();
    translate([x_h, 0, 0]) sled_ghost();
    color("DimGray") translate([x_tube1 - brg_w, 0, 0]) difference() { xcyl(brg_d, brg_w); translate([-1, 0, 0]) xcyl(brg_id, brg_w + 2); }
    %translate([x_tube0 + 2, 0, 0]) xcyl(2*r_roll, tube_len - 4);
    %translate([x_tube0 + 2, r_roll - 0.2, -150]) cube([tube_len - 4, 0.4, 150]);
    %translate([0, y_wall, -150]) cube([W, 2, 250]);
    %translate([0, y_wall - sh_gap - 12, br_h/2]) cube([W, 12, 60]);       // Täferverkleidung, Unterkante bündig mit dem Arm
}

// ---------- Ausgabe (druckfertig orientiert) ----------

if      (part == "assembly")      assembly();
else if (part == "section")       intersection() { assembly(); translate([0, 0, -100]) cube([x_h + sled_l + 10, 100, 200]); }
else if (part == "tube_section")  linear_extrude(tsec_l) tube_profile(tsec_comp);            // Rohrstück, stehend: Schlitten zur Probe hineinschieben
else if (part == "bracket_motor") rotate([0, -90, 0]) bracket();                             // liegt auf der Aussenseite
else if (part == "bracket_idle")  rotate([0, 90, 0]) mirror([1, 0, 0]) bracket();
else if (part == "key")           translate([0, 0, pocket_d - 0.2]) rotate([0, -90, 0]) key();
else if (part == "hex_rod")       translate([0, 0, (hex_af - rod_shrink)/2]) hex_rod();
else if (part == "coupler")       translate([0, 0, cp_l]) rotate([0, 90, 0]) coupler();
else if (part == "sled")          translate([0, 0, sled_od/2 - sled_flat]) sled();             // liegt auf der Abflachung
else if (part == "idle_axle")     translate([0, 0, pocket_d - 0.2]) rotate([0, -90, 0]) idle_axle();
else if (part == "pcb_outline")   difference() {                                                // x ab Antennenkante
    translate([0, -pcb_w/2]) square([pcb_l, pcb_w]);
    translate([-1, usb_off - (usb_w + 0.3)/2]) square([6.7 + 1, usb_w + 0.3]);                      // Aussparung USB-C
}

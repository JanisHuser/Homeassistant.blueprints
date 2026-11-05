// =====================================================================
//  Automatische USB-C Kabeltrommel (2 m) – modular für Montageplatte
//  - Federrückzug (Stahl-Spiralfeder) wie beim Staubsauger
//  - Ratsche + Taste: Kabel bleibt stehen, Taste drücken = einziehen
//  - Zentraler, feststehender USB-C Anschluss unten
//  - Schleifring MSC-22, 3 Kanäle, 10 A (VBUS / GND / CC)
//  - In der Trommel: USB-C Buchse -> normales, unverändertes USB-C Kabel
//  - Bajonett-Fuss mit Rastnase: in Platte einsetzen, 30° drehen, klick
//  - Kabelauszug nur in eine Richtung (+X)
//
//  Einheiten: mm.  Export einzelner Teile:  part = "base" usw.
// =====================================================================

/* [Ansicht / Export] */
part = "assembly"; // [assembly, cutaway, exploded, plate_assembly, base, foot, drum, slot_plug, drum_cap, pawl, button, lid, plate]

/* [Kabel (normales USB-C Kabel)] */
cable_d   = 3.5;    // Kabel-Aussendurchmesser (nachmessen!)
cable_len = 1950;   // nutzbar bei einem 2 m Kabel
plug_w    = 12.5;   // Steckergehäuse Breite
plug_t    = 7;      // Steckergehäuse Dicke
plug_len  = 28;     // Steckergehäuse + Knickschutz

/* [Trommel] */
hub_d     = 76;     // Wickelkern-Ø (innen liegt der Adapter)
drum_w    = 18;     // Wickelbreite
flange_d  = 100;    // Ratschenrad / Flansch-Ø
teeth_n   = 24;
tooth_h   = 2.5;

/* [Feder (Stahl-Spiralfeder, gekauft)] */
spring_w   = 10;
spring_t   = 0.3;
spring_len = 2000;
arbor_d    = 18;

/* [Schleifring MSC-22 3CH 10A (Händler-Zeichnung)] */
sr_d       = 21.7;  // Körper-Ø (Stator)
sr_len     = 26.4;  // Körperlänge L (3 Kanäle)
sr_fl_d    = 44;    // Flansch-Ø
sr_fl_t    = 2.3;
sr_fl_pos  = 2.7;   // Abstand Rotorseite-Stirnfläche -> Flansch
sr_bc      = 34.9;  // Lochkreis
sr_hole_d  = 5.2;
sr_rot_d   = 7.8;   // Rotor-Ø
sr_rot_len = 9;     // Rotor-Überstand
sr_z0      = -2;    // Unterkante Körper (Stator-Litzen unten)

/* [USB-C Platine 20x14 mm (beide Seiten)] */
pcb_w  = 20;     // Breite (Buchsenkante)
pcb_l  = 14;     // Tiefe
pcb_t  = 1.5;
sock_h = 3.2;    // Buchse über Platine
sock_w = 8.9;
pcb_hole_dx = 3.5;   // Lochmitte ab Buchsenkante
pcb_hole_sp = 15;    // Lochabstand

/* [Montageplatte] */
plate_nx  = 2;
plate_ny  = 1;
plate_t   = 5;
plate_gap = 2;

/* [Allgemein] */
wall     = 2.4;
corner_r = 6;
$fn = 96;

// ------------------------- abgeleitete Masse -------------------------
R  = flange_d/2;
W  = R + 7.6;             // halbe Innenweite
H  = W + wall;            // halbe Aussenweite
pitch = 2*H + plate_gap;

floor_t = 2.4;
df_t    = 5;              // Trommelboden (mit Lagernut)
groove_h = 4;             // Lagernut-Tiefe
cap_t   = 4;
lid_t   = 3;
spring_h = spring_w + 1.5;

// Bajonett-Fuss / feste Hülse um den Schleifring
lug_t   = 2.5;
foot_r  = 25;
lug_r   = foot_r + 3.5;
lug_w   = 24;
lug_angles = [90, 210, 330];
lock_rot = 30;
key_r   = foot_r + 1.8;
key_w   = 6;
z_foot0 = -(plate_t + 0.2 + lug_t);
bot_t   = 1.2;
z_bot1  = z_foot0 + bot_t;
tube_ir = sr_fl_d/2 + 1;           // Hülse innen (Flansch Ø44 passt durch)
tube_or = foot_r;                  // im Plattenloch
tube_or2 = tube_or + 2;            // oberhalb der Platte
collar_ri = tube_or2 + 0.2;        // Kragen im Gehäuseboden
collar_ro = collar_ri + 3.3;
collar_h  = 10;
foot_screw_a = [60, 180, 300];
det_r = 38; det_a = 0;

// Schleifring
z_front = sr_z0 + sr_len;           // Rotorseite
z_flt   = z_front - sr_fl_pos;      // Flansch oben
z_flb   = z_flt - sr_fl_t;          // Flansch unten = Auflage
sr_post_a = [0, 120, 240];

// Trommel
z_df0  = z_front + 1;
z_df1  = z_df0 + df_t;
z_tube1 = z_df0 + groove_h - 0.1;  // Hülse läuft in der Nut des Trommelbodens
z_hub1 = z_df1 + drum_w;
z_cap1 = z_hub1 + cap_t;
z_ch0  = z_cap1 + 0.6;
z_lid0 = z_ch0 + spring_h;
z_lid1 = z_lid0 + lid_t;
rc = hub_d/2 - wall;                // Trommel-Innenraum

// Adapter in der Trommel (Platine liegt, Stecker auf einer Sehne)
ad_d  = 18;                         // Sehnenabstand von der Mitte (y = -ad_d)
ad_xm = -5;                         // Buchsenmündung
z_sc  = z_df1 + 2 + pcb_t + sock_h/2;   // Steckermitte
ex_p1 = [sqrt(rc*rc - ad_d*ad_d) - 3, -ad_d];
ex_p2 = ex_p1 + [11, 7];

// Stator-Platine (stehend neben dem Schleifring, Buchse nach unten)
sb_front = -(sr_d/2 + 1 + sock_h);  // Platinen-Vorderseite (x)
sb_back  = sb_front - pcb_t;

// Sperrklinke
P = [R + 2, 20];
pawl_pin_d = 5;
z_pw0 = z_hub1 + 0.3;
z_pw1 = z_cap1 - 0.3;
b_y = 36;  b_z = (z_pw0 + z_pw1)/2;

// Kabelausgang
ex_y1 = -(hub_d/2 - 6);
ex_y0 = -(R - 2);
ex_yc = (ex_y0 + ex_y1)/2;
ex_zc = (z_df1 + z_hub1)/2;
ex_w  = cable_d + 1.5;

cb = W - 3.6;
cap_screw_r = rc - 3.1;
cap_screw_a = [30, 90, 150];
ch_ri = R - 3;

// ------------------------- Berechnungen -------------------------
n_layer = floor(drum_w / cable_d);
function turn_len(k) = PI*(hub_d + cable_d*(2*k+1));
function turns_for(L,k=0)  = L <= n_layer*turn_len(k) ? L/turn_len(k) : n_layer + turns_for(L - n_layer*turn_len(k), k+1);
function layers_for(L,k=0) = L <= n_layer*turn_len(k) ? k+1 : layers_for(L - n_layer*turn_len(k), k+1);
drum_turns = turns_for(cable_len);
pack_d     = hub_d + 2*cable_d*layers_for(cable_len);
sp_lt = spring_len*spring_t/PI;
sp_r1 = sqrt(pow(arbor_d/2,2) + sp_lt);
sp_r2 = sqrt(max(0, pow(ch_ri,2) - sp_lt));
spring_turns = ((sp_r1 - arbor_d/2) - (ch_ri - sp_r2)) / spring_t;

echo(str("Trommel-Umdrehungen für ", cable_len, " mm: ", drum_turns));
echo(str("Wickelpaket-Ø: ", pack_d, " mm (Flansch-Ø ", flange_d-4, ")"));
echo(str("Feder: nutzbare Umdrehungen ≈ ", spring_turns, "  (benötigt ≥ ", drum_turns+2.5, ")"));
echo(str("Gehäuse: ", 2*H, " x ", 2*H, " x ", z_lid1, " mm (+", -z_foot0, " Fuss), Raster: ", pitch, " mm"));
assert(pack_d < flange_d - 6, "Kabel passt nicht auf die Trommel");
assert(spring_turns > drum_turns + 2, "Feder zu kurz / zu dick");
assert(norm([ad_xm - pcb_l, -(ad_d + pcb_w/2)]) < rc - 0.5, "Adapter-Platine passt nicht in die Trommel");
assert(norm([ad_xm + plug_len, -(ad_d + plug_w/2)]) < rc - 0.5, "Stecker passt nicht in die Trommel");
assert(sqrt(pow(sb_back,2) + pow(pcb_w/2,2)) < tube_ir - 0.5, "Stator-Platine passt nicht in die Hülse");

// ------------------------- Helfer -------------------------
module house2d(o=0) offset(r=corner_r+o) square(2*(H-corner_r), center=true);
module wedge(r, a0, a1) polygon(concat([[0,0]], [for(i=[0:16]) let(a=a0+(a1-a0)*i/16) r*[cos(a),sin(a)]]));
module ratchet2d() {
    p = 360/teeth_n;
    polygon([for(i=[0:teeth_n-1]) each [
        R*[cos(i*p), sin(i*p)],
        (R-tooth_h)*[cos((i+1)*p-0.3), sin((i+1)*p-0.3)] ]]);
}
module csk(d=3.3, D=6.4, h=1.8) { cylinder(d=d, h=50, center=true); translate([0,0,-h]) cylinder(d1=d, d2=D, h=h+0.01); }
module ring(ri, ro, h) difference() { cylinder(r=ro, h=h); translate([0,0,-1]) cylinder(r=ri, h=h+2); }
// Kabelkanal in der Trommelwand, nach oben offen (Kabel wird eingelegt)
module hub_slot(d, z0, z1) hull() for (p=[ex_p1, ex_p2]) translate([p.x, p.y, z0]) cylinder(d=d, h=z1-z0, $fn=32);

// =====================================================================
//  GEHÄUSE-UNTERTEIL: Bajonett-Fuss, Schleifring-Aufnahme, Stator-Buchse
// =====================================================================
module base() {
    difference() {
        union() {
            difference() { linear_extrude(floor_t) house2d(); translate([0,0,-1]) cylinder(r=collar_ri, h=floor_t+2); }
            linear_extrude(z_lid0) difference() { house2d(); house2d(-wall); }
            translate([0,0,0]) ring(collar_ri, collar_ro, collar_h);
            // Deckelschrauben, Klinkensockel + Stift
            for (sx=[-1,1], sy=[-1,1]) translate([sx*cb, sy*cb, 0]) cylinder(r=3.5, h=z_lid0);
            translate(P) cylinder(r=4, h=z_pw0-0.1);
            translate(P) cylinder(d=pawl_pin_d, h=z_lid0+1.0);
            // Kabelausgang-Block
            translate([R-2, ex_y0, 0]) cube([W-(R-2)+0.01, ex_y1-ex_y0, z_lid0]);
            translate([H-0.01, b_y, b_z]) rotate([0,90,0]) cylinder(d=10, h=2);
        }
        // Schrauben Fuss (M3, radial)
        for (a = foot_screw_a) rotate(a) translate([collar_ri-1, 0, collar_h/2]) rotate([0,90,0]) cylinder(d=3.4, h=10, $fn=24);
        // Kabeltrichter + nach oben offener Schlitz zum Einlegen des Kabels
        hull() {
            translate([R-2.1, ex_y0+2, z_df1+0.5]) cube([0.1, ex_y1-ex_y0-4, drum_w-1]);
            translate([H-3, ex_yc, ex_zc]) rotate([0,90,0]) cylinder(d=ex_w, h=0.1);
        }
        translate([H-3.1, ex_yc, ex_zc]) rotate([0,90,0]) cylinder(d=ex_w, h=5);
        translate([H-1, ex_yc, ex_zc]) rotate([0,90,0]) cylinder(d1=ex_w, d2=cable_d+4, h=1.02);
        translate([R-2.1, ex_yc-ex_w/2, ex_zc]) cube([H-R+5, ex_w, z_lid0]);
        // Tastenloch, M3-Vorbohrungen, Rastmulde
        translate([W-1, b_y, b_z]) rotate([0,90,0]) cylinder(d=6.4, h=wall+5);
        for (sx=[-1,1], sy=[-1,1]) translate([sx*cb, sy*cb, z_lid0-12]) cylinder(d=2.6, h=13);
        rotate(det_a) translate([det_r, 4, 0]) sphere(d=3, $fn=32);
    }
}

// =====================================================================
//  FUSS: Bajonett, Hülse, Schleifring-Säulen, Stator-Buchse (eigenes Teil)
// =====================================================================
module foot() {
    difference() {
        union() {
            translate([0,0,z_foot0]) ring(tube_ir, tube_or, -z_foot0+0.01);
            difference() {
                union() {
                    cylinder(r1=tube_or, r2=tube_or2, h=2);
                    translate([0,0,1.99]) cylinder(r=tube_or2, h=z_tube1-1.99);
                }
                translate([0,0,-1]) cylinder(r=tube_ir, h=z_tube1+2);
            }
            translate([0,0,z_foot0]) cylinder(r=tube_ir+0.01, h=bot_t);
            for (a = lug_angles) translate([0,0,z_foot0]) linear_extrude(lug_t) wedge(lug_r, a-lug_w/2, a+lug_w/2);
            translate([0,0,-plate_t]) linear_extrude(plate_t+0.01) wedge(key_r, lug_angles[0]-key_w/2, lug_angles[0]+key_w/2);
            for (a = sr_post_a) rotate(a) translate([sr_bc/2, 0, z_bot1-0.01]) cylinder(r=4.5, h=z_flb-z_bot1);
            translate([sb_back-1.8, -pcb_hole_sp/2-2, z_bot1-0.01]) cube([1.81, pcb_hole_sp+4, pcb_l]);
        }
        for (a = sr_post_a) rotate(a) translate([sr_bc/2, 0, z_flb-12]) cylinder(d=3.3, h=13, $fn=24);
        for (s=[-1,1]) translate([sb_back+0.01, s*pcb_hole_sp/2, z_bot1+pcb_hole_dx]) rotate([0,-90,0]) cylinder(d=1.7, h=5, $fn=16);
        translate([sb_front + sock_h/2, 0, z_foot0-1]) hull() for (s=[-1,1])
            translate([0, s*(sock_w+0.7-sock_h-0.6)/2, 0]) cylinder(d=sock_h+0.6, h=bot_t+2, $fn=24);
        for (a = foot_screw_a) rotate(a) translate([tube_ir+0.5, 0, collar_h/2]) rotate([0,90,0]) cylinder(d=2.6, h=10, $fn=24);
    }
}

// =====================================================================
//  TROMMEL: Boden mit Rotor-Klemmung, Lagerschürze, Adapter-Raum
// =====================================================================
module drum() {
    pcb_x0 = ad_xm - pcb_l;
    difference() {
        union() {
            translate([0,0,z_df0]) cylinder(r=R-2, h=df_t);
            translate([0,0,z_df1-0.01]) ring(rc, hub_d/2, drum_w+0.01);
            // Rotor-Klemmnabe
            translate([0,0,z_df1-0.01]) cylinder(r=7, h=(z_front+sr_rot_len+1)-z_df1);
            for (a=cap_screw_a) rotate(a) translate([cap_screw_r,0,z_df1-0.01]) cylinder(r=3.2, h=drum_w);
            // Adapter: Platinen-Abstandshalter, Auflagesteg, Steckerauflage, Kabelbinder-Öse
            intersection() {
                cylinder(r=rc+0.01, h=200);
                translate([0,0,z_df1-0.01]) union() {
                    for (s=[-1,1]) translate([ad_xm-pcb_hole_dx, -ad_d+s*pcb_hole_sp/2, 0]) cylinder(r=2.5, h=2, $fn=24);
                    translate([pcb_x0+1, -ad_d-8, 0]) cube([2, 16, 2]);
                    translate([ad_xm+1, -ad_d-plug_w/2+1, 0]) cube([plug_len-4, plug_w-2, z_sc-plug_t/2-z_df1-0.2]);
                    translate([ad_xm+plug_len, -ad_d-4, 0]) cube([4, 8, z_sc-cable_d/2-z_df1]);
                }
            }
        }
        // Lagernut (läuft auf der Hülse)
        translate([0,0,z_df0-1]) ring(tube_ir-0.3, tube_or2+0.4, groove_h+1);
        // Rotor-Bohrung + M3-Klemmschraube
        translate([0,0,z_df0-1]) cylinder(d=sr_rot_d+0.3, h=40, $fn=48);
        translate([0,0,z_front+sr_rot_len/2+1]) rotate([0,90,0]) cylinder(d=2.5, h=10, $fn=16);
        // Schraubdome Deckel
        for (a=cap_screw_a) rotate(a) translate([cap_screw_r,0,z_hub1-12]) cylinder(d=2.6, h=13, $fn=24);
        // M2-Löcher Adapter-Platine
        for (s=[-1,1]) translate([ad_xm-pcb_hole_dx, -ad_d+s*pcb_hole_sp/2, z_df1-1]) cylinder(d=1.7, h=4, $fn=16);
        // Kabelbinder-Tunnel
        translate([ad_xm+plug_len+0.6, -ad_d-5, z_df1+0.6]) cube([2.8, 10, 1.4]);
        // Kabelkanal durch die Wand (oben offen, Deckel-Zunge schliesst ihn)
        hub_slot(cable_d+1, z_sc-(cable_d+1)/2, z_hub1+1);
        translate([ex_p1.x, ex_p1.y, z_sc]) sphere(d=cable_d+1, $fn=24);
        translate([ex_p2.x, ex_p2.y, z_sc]) sphere(d=cable_d+1, $fn=24);
    }
}

// =====================================================================
//  KANAL-STOPFEN: schliesst den Kabelkanal in der Trommelwand über dem Kabel
// =====================================================================
module slot_plug() intersection() {
    hub_slot(cable_d+0.4, z_sc+cable_d/2+0.4, z_hub1-0.1);
    translate([0,0,z_df1]) ring(rc-2, hub_d/2-0.1, drum_w+1);
}

// =====================================================================
//  TROMMELDECKEL = Ratschenrad + Federkern
// =====================================================================
module drum_cap() {
    difference() {
        union() {
            translate([0,0,z_hub1]) linear_extrude(cap_t) ratchet2d();
            translate([0,0,z_cap1-0.01]) cylinder(d=arbor_d, h=z_lid0-0.4-z_cap1);
            translate([0,0,z_lid0-0.41]) cylinder(d=8, h=2.2);
        }
        translate([arbor_d/2-3.5, -0.7, z_ch0]) cube([5, 1.4, spring_h+1]);
        for (a=cap_screw_a) rotate(a) translate([cap_screw_r,0,z_cap1]) csk();
    }
}

// =====================================================================
//  SPERRKLINKE (mit Blattfeder) + TASTE
// =====================================================================
module pawl2d() {
    difference() {
        union() {
            translate(P) circle(r=4);
            translate([R+1, 3]) square([3, P.y-3]);
            hx = sqrt(pow(R-2,2) - 64);
            polygon([[R+1.01, 9.5], [hx, 8], [hx+1.6, 3.5], [R+1.01, 3]]);
            hull() { translate(P) circle(r=2); translate([W-1.5-0.3-2, b_y]) circle(r=2); }
            pts = [[R+4, 15], [R+5.8, 10.5], [W+0.4, 6.5]];
            for (i=[0:len(pts)-2]) hull() { translate(pts[i]) circle(r=0.6, $fn=16); translate(pts[i+1]) circle(r=0.6, $fn=16); }
        }
        translate(P) circle(d=pawl_pin_d+0.5);
    }
}
module pawl() translate([0,0,z_pw0]) linear_extrude(z_pw1-z_pw0) pawl2d();
module button() translate([W-1.5, b_y, b_z]) rotate([0,90,0]) {
    cylinder(d=10, h=1.5);
    cylinder(d=6, h=1.5 + wall + 2 + 3);
}

// =====================================================================
//  DECKEL mit Federkammer und Zunge für den Kabelausgang
// =====================================================================
module lid() {
    difference() {
        union() {
            translate([0,0,z_lid0]) linear_extrude(lid_t) house2d();
            translate([0,0,z_ch0]) ring(ch_ri, ch_ri+2, spring_h+0.01);
            translate([-(ch_ri+4.5), -4, z_ch0]) cylinder(r=1.8, h=spring_h+0.01, $fn=24);
            translate([H-3.6, ex_yc-ex_w/2+0.2, ex_zc+ex_w/2+0.2]) cube([3.6, ex_w-0.4, z_lid0-ex_zc-ex_w/2]);
        }
        translate([-(ch_ri+3), -0.75, z_ch0-1]) cube([4, 1.5, spring_h+1]);
        translate([0,0,z_lid0-1]) cylinder(d=8.6, h=1+2.0);
        translate([P.x, P.y, z_lid0-1]) cylinder(d=pawl_pin_d+0.4, h=2.4);
        for (sx=[-1,1], sy=[-1,1]) translate([sx*cb, sy*cb, z_lid1]) csk();
        translate([22, 0, z_lid1-0.6]) linear_extrude(1) polygon([[0,-6],[14,0],[0,6],[3,0]]);
    }
}

// =====================================================================
//  MONTAGEPLATTE
// =====================================================================
function slot_pos(i,j) = [pitch*(i+0.5), pitch*(j+0.5)];
module plate_cut2d() {
    circle(r=foot_r+0.3);
    for (a = lug_angles) wedge(lug_r+0.5, a-lock_rot-lug_w/2-1, a-lock_rot+lug_w/2+1);
    wedge(key_r+0.4, lug_angles[0]-lock_rot-key_w/2-1, lug_angles[0]+key_w/2+0.3);
}
module plate() {
    difference() {
        translate([0,0,-plate_t]) linear_extrude(plate_t) offset(r=5) offset(delta=-5) square([plate_nx*pitch, plate_ny*pitch]);
        for (i=[0:plate_nx-1], j=[0:plate_ny-1]) translate(slot_pos(i,j)) {
            translate([0,0,-plate_t-1]) linear_extrude(plate_t+2) plate_cut2d();
            rotate(det_a) translate([det_r, 0, 0]) {
                translate([0,0,-plate_t-1]) linear_extrude(plate_t+2) difference() {
                    translate([-3.8, -6]) square([7.6, 12.8]);
                    translate([-3, -7]) square([6, 13]);
                }
                translate([-3, -6, -plate_t-1]) cube([6, 12, plate_t-1.6+1]);
            }
        }
        for (x=[0:plate_nx], y=[0,plate_ny]) translate([x*pitch, y*pitch, 0])
            translate([x==0?8:(x==plate_nx?-8:0), y==0?8:-8, 0]) csk(4.5, 9, 2.5);
    }
    for (i=[0:plate_nx-1], j=[0:plate_ny-1]) translate(slot_pos(i,j))
        rotate(det_a) translate([det_r, 4, 0]) intersection() {
            sphere(d=2.6, $fn=32); translate([-2,-2,-0.01]) cube([4,4,0.7]);
        }
}

// =====================================================================
//  Darstellung
// =====================================================================
module spring_vis() {
    N=14; ri=arbor_d/2+0.4; ro=ch_ri-0.4;
    translate([0,0,z_ch0+0.5]) linear_extrude(spring_w) polygon(concat(
        [for(t=[0:6:360*N]) (ri+(ro-ri)*t/(360*N)+0.2)*[cos(-t),sin(-t)]],
        [for(t=[360*N:-6:0]) (ri+(ro-ri)*t/(360*N)-0.2)*[cos(-t),sin(-t)]]));
}
module pcb_vis(mouth_down=false) {
    color("darkgreen") cube([pcb_l, pcb_w, pcb_t]);
    color("silver") translate([0, (pcb_w-sock_w)/2, pcb_t]) cube([7.4, sock_w, sock_h]);
}
module cable_vis() {
    for (k=[0:1], i=[0:n_layer-1]) if (k==0 || i<3)
        translate([0,0,z_df1+cable_d*(i+0.5)]) rotate_extrude($fn=64) translate([hub_d/2+cable_d*(k+0.5),0]) circle(d=cable_d, $fn=12);
    // innen: Stecker A in der Adapterbuchse
    translate([ad_xm, -ad_d-plug_w/2, z_sc-plug_t/2]) cube([plug_len, plug_w, plug_t]);
    hull() { translate([ad_xm+plug_len, -ad_d, z_sc]) sphere(d=cable_d,$fn=12); translate([ex_p1.x, ex_p1.y, z_sc]) sphere(d=cable_d,$fn=12); }
    hull() { translate([ex_p1.x, ex_p1.y, z_sc]) sphere(d=cable_d,$fn=12); translate([ex_p2.x, ex_p2.y, z_sc]) sphere(d=cable_d,$fn=12); }
    // aussen: zum Ausgang + Stecker B
    hull() { translate([0, -(hub_d/2+cable_d*1.5), z_df1+cable_d*2.5]) sphere(d=cable_d,$fn=12); translate([H, ex_yc, ex_zc]) sphere(d=cable_d,$fn=12); }
    hull() { translate([H, ex_yc, ex_zc]) sphere(d=cable_d,$fn=12); translate([H+14, ex_yc, ex_zc]) sphere(d=cable_d,$fn=12); }
    translate([H+14, ex_yc-plug_w/2, ex_zc-plug_t/2]) cube([plug_len-6, plug_w, plug_t]);
    translate([H+14+plug_len-6, ex_yc-4.2, ex_zc-1.3]) cube([6.5, 8.4, 2.6]);
}
module slipring_vis() {
    color("#222") {
        translate([0,0,sr_z0]) cylinder(d=sr_d, h=sr_len);
        translate([0,0,z_flb]) difference() {
            cylinder(d=sr_fl_d, h=sr_fl_t);
            for (a=sr_post_a) rotate(a) translate([sr_bc/2,0,-1]) cylinder(d=sr_hole_d, h=5);
        }
    }
    color("#444") translate([0,0,z_front]) cylinder(d=sr_rot_d, h=sr_rot_len);
    // Stator-Platine stehend, Buchse nach unten
    translate([sb_back, -pcb_w/2, z_bot1]) rotate([0,-90,0]) mirror([0,0,1]) translate([0,0,-pcb_t]) pcb_vis();
    // Adapter-Platine in der Trommel
    translate([ad_xm, -ad_d-pcb_w/2, z_df1+2]) mirror([1,0,0]) pcb_vis();
}

module reel(ex=0, show_inner=true) {
    color("#3b4652") base();
    color("#6b7f94") foot();
    color("#e0763a") translate([0,0,ex*1]) drum();
    color("#f0a050") translate([0,0,ex*1.5]) slot_plug();
    color("#f0a050") translate([0,0,ex*2]) drum_cap();
    color("#d94f4f") translate([0,0,ex*2]) pawl();
    color("#d94f4f") translate([ex*0.5,0,0]) button();
    color("#5c6b7a") translate([0,0,ex*3]) lid();
    if (show_inner) {
        slipring_vis();
        color("#9aa5b1") translate([0,0,ex*2.5]) spring_vis();
        color("#222") translate([0,0,ex*1]) cable_vis();
    }
}

// assembly: explode=z    (Montageanleitung auf der Website: Teile vertikal auseinanderziehen)
if (part == "assembly") reel();
else if (part == "exploded") reel(ex=24);
else if (part == "cutaway") difference() { reel(); translate([-200,-200,-50]) cube([200,200,200]); }
else if (part == "plate_assembly") {
    color("#c8ccd0") plate();
    for (i=[0:plate_nx-1], j=[0:plate_ny-1]) translate(slot_pos(i,j)) reel();
}
// ---- Druckteile in Druckorientierung ----
else if (part == "base")     base();
else if (part == "foot")     translate([0,0,-z_foot0]) foot();
else if (part == "drum")     translate([0,0,-z_df0]) drum();
else if (part == "slot_plug") translate([0,0,-(z_sc+cable_d/2+0.4)]) slot_plug();
else if (part == "drum_cap") translate([0,0,-z_hub1]) drum_cap();
else if (part == "pawl")     translate([-P.x,-P.y,-z_pw0]) pawl();
else if (part == "button")   rotate([0,-90,0]) translate([-(W-1.5), -b_y, -b_z]) button();
else if (part == "lid")      rotate([180,0,0]) translate([0,0,-z_lid1]) lid();
else if (part == "plate")    translate([0,0,plate_t]) plate();

# Automatische USB-C Kabeltrommel (2 m), modular

Gehäuse 120 × 120 × 67,5 mm, dazu kommen 7,7 mm Fuss, der in der Platte steckt. Raster auf der Platte: 122 mm.

- **Ziehen:** Das Kabel zieht man nach vorne (+X) heraus. Die Ratsche hält es in jeder Position fest.
- **Einziehen:** Rote Taste drücken, dann zieht die Feder das Kabel ein (wie beim Staubsauger).
- **Anschluss:** Unten im Fuss sitzt eine feststehende USB-C-Buchse.
- **Kabel:** In der Trommel steckt ein **normales, unverändertes USB-C-Kabel** (2 m) in einer zweiten Buchse. Abschneiden oder Löten am Kabel ist nicht nötig.
- **Montage:** Die Trommel steckt man mit einem Bajonett in die Platte: einsetzen, 30° gegen den Uhrzeigersinn drehen, bis es klickt.

## Aufbau

```
Deckel        Federkammer (Stahl-Spiralfeder)
Trommeldeckel Ratschenrad + Federkern + Zunge über dem Kabelkanal
Trommel       Wickelkern Ø76 mit Adapter innen:
                USB-C-Platine (Rotorseite) ← Stecker A des normalen Kabels
              Boden: Klemmnabe für den Schleifring-Rotor, Lagernut auf der Hülse
Fuss          Hülse + 3 Säulen für den Schleifring-Flansch (Stator)
              stehende USB-C-Platine, Buchse zeigt nach unten durch die Platte
Platte        Bajonett-Aufnahme + Rastzunge
```

## Druckteile (`stl/`)

Alle Teile liegen bereits in Druckausrichtung und sind ohne Stützen gedacht. Einzige Ausnahme ist die schräge Decke im Kabeltrichter des Gehäuses: Wenn sie unschön wird, dort Stützen nur für den Trichter aktivieren.

| Datei | Hinweis |
|---|---|
| base.stl | Gehäuse, Boden auf dem Druckbett |
| foot.stl | Bajonett-Fuss mit Schleifring-Aufnahme |
| drum.stl | Trommel, Boden auf dem Druckbett |
| slot_plug.stl | Kanal-Stopfen, schliesst den Kabelkanal in der Trommelwand |
| drum_cap.stl | Ratschenrad + Federkern |
| lid.stl | Deckel mit Federkammer |
| pawl.stl | Sperrklinke: **PETG**, 100 % Infill |
| button.stl | Taste |
| plate.stl | Montageplatte, Standard 2 × 1 Plätze, 244 × 122 mm |

Empfehlung: PETG, 0,2 mm Schichthöhe, 4 Wände.

## Kaufteile

| Teil | Menge |
|---|---|
| Schleifring **MSC-22, 3 Kanäle, 10 A** (Körper Ø 21,7 × 26,4, Flansch Ø 44) | 1 |
| USB-C-Buchsenplatine **20 × 14 mm** mit 5,1-kΩ-Widerständen („512“) | 2 |
| USB-C-Kabel C-auf-C, **2 m**, rund und dünn (Ø ≤ 3,5 mm), höchstens 3 A | 1 |
| Spiralfeder (Triebfeder) aus Stahl, ca. 10 × 0,3 mm, ca. 2 m | 1 |
| M3×10 Senkkopf (Deckel 4×, Trommeldeckel 3×), M3×8 (Fuss 3×) | 10 |
| M4×10 selbstschneidend + Unterlegscheibe (Schleifring-Flansch) | 3 |
| M2×5 selbstschneidend (Platinen) | 4 |
| M3 Madenschraube 4 mm (Rotor-Klemmung) | 1 |
| Kabelbinder 2,5 mm | 1 |

## ⚠️ Wichtig: Widerstände auf den Platinen entfernen

Auf beiden Platinen sitzen zwei 5,1-kΩ-Widerstände („512“) zwischen CC1/CC2 und GND. Damit melden sich die Platinen beim Ladegerät als angeschlossenes Gerät. Bei uns geht die CC-Leitung aber durch den Schleifring vom Ladegerät bis zum Endgerät, und das Endgerät meldet sich selbst. Mit den Widerständen hingen bis zu 3 Pull-down-Widerstände parallel. Dann erkennt das Ladegerät den Anschluss falsch, oder Power Delivery funktioniert nicht.

**→ Auf beiden Platinen die zwei Widerstände „512“ ablöten** (Lötkolben oder Seitenschneider). Danach mit dem Multimeter prüfen: CC1 → GND sollte jetzt offen sein, also nicht 5,1 kΩ.

## Verdrahtung

| Schleifring-Ring | Stator-Platine (unten, fest) | Rotor-Platine (in der Trommel) |
|---|---|---|
| 1 | VBUS | VBUS |
| 2 | GND | GND |
| 3 | CC1 **und** CC2 gebrückt | CC1 **und** CC2 gebrückt |

- D+, D− und SBU bleiben frei. **Es gibt keine Datenübertragung**, nur Laden.
- Laden mit Power Delivery bis **20 V / 3 A = 60 W**.
- CC1 und CC2 zu brücken funktioniert in der Praxis mit passiven Kabeln, entspricht aber nicht der USB-Spezifikation. Vor dem ersten Einstecken auf Kurzschluss prüfen: VBUS ↔ GND muss offen sein.
- Die 10-A-Litzen auf ca. 4 cm kürzen, verzinnen und auf die Pads löten. Die Pads sind klein, die Litzen dick: am besten erst ein kurzes Stück dünneren Draht (AWG 22) auf das Pad löten und dann daran die dicke Litze.
- Welche Litzenfarbe zu welchem Ring gehört, mit dem Durchgangsprüfer feststellen. Die Farben sind auf Stator- und Rotorseite gleich.

## Zusammenbau

1. **Fuss vorbereiten:** Die Stator-Platine verdrahten (siehe oben). Dann die Platine stehend an die Rückwand im Fuss schrauben (2 × M2), Buchse nach unten in die Öffnung.
2. **Schleifring einsetzen:** Den Körper in den Fuss senken, den Rotor nach oben. Den Flansch mit 3 × M4 auf die Säulen schrauben.
3. **Fuss ins Gehäuse:** Den Fuss von unten durch den Kragen im Gehäuseboden stecken und mit 3 × M3 radial verschrauben.
4. **Trommel aufsetzen:** Die Ringnut im Trommelboden läuft auf der Hülse des Fusses, der Rotor steckt durch die Mittelbohrung. Die Madenschraube in der Nabe vorsichtig anziehen. Der Rotor ist aus Kunststoff, also nur so fest, dass er mitdreht.
5. **Adapter:** Die Rotor-Litzen oben aus der Nabe an die Rotor-Platine löten. Die Platine mit 2 × M2 auf die Abstandshalter schrauben, die Buchsenöffnung zeigt Richtung Kabelkanal.
6. **Kabel einlegen:** Stecker A in die Buchse stecken. Das Kabel hinter dem Stecker mit einem Kabelbinder an der Öse fixieren, das ist die Zugentlastung. Dann das Kabel von oben in den Kanal der Trommelwand legen.
7. Den Kanal-Stopfen von oben in den Kabelkanal über das Kabel drücken. Dann den Trommeldeckel aufsetzen und mit 3 × M3 verschrauben. Der Deckel hält den Stopfen fest.
8. **Kabel aufwickeln:** Von oben gesehen dreht die Trommel **im Uhrzeigersinn** = einziehen. Stecker B bleibt draussen.
9. Das Kabel **von oben in den Schlitz des Kabelausgangs legen**. Stecker B muss durch kein Loch, der Deckel schliesst den Schlitz später mit seiner Zunge.
10. Sperrklinke auf den Stift setzen, die Taste von innen ins Loch stecken.
11. **Feder einsetzen:** das innere Ende in den Schlitz am Federkern, das äussere durch den Schlitz der Federkammer und um den Anker biegen. Beim Herausziehen des Kabels muss sich die Feder spannen.
12. Deckel aufsetzen und verschrauben.
13. **Vorspannung:** Wenn das Kabel ganz ausgezogen ist, sollte die Feder noch **2–3 Umdrehungen Reserve** haben.
14. **Auf die Platte:** Die Trommel 30° im Uhrzeigersinn verdreht einsetzen, dann gegen den Uhrzeigersinn drehen, bis es klickt.

## Werte (Standard-Parameter)

- 1950 mm nutzbares Kabel → 7,6 Trommelumdrehungen, Wickelpaket Ø 90 mm (Flansch Ø 96 mm)
- Feder 10 × 0,3 × 2000 mm → ca. 18 nutzbare Umdrehungen (nötig sind 10,1)
- Stecker-Annahme: 12,5 × 7 × 28 mm inkl. Knickschutz. Deinen Stecker messen und die Werte `plug_*` in der SCAD-Datei anpassen. Die Konsole meldet per `assert`, wenn etwas nicht passt.
- Die Masse des Schleifrings stammen aus einer kleinen Händler-Zeichnung. Nach Erhalt nachmessen (`sr_*`).

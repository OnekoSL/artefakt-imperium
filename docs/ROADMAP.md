# Ausbauplan für Artefakt Imperium

**Stand:** 12. September 2026

**Ausbau 0.3 umgesetzt:** sechs Schulen, 156 Forschungen, praktische Durchbrüche, zwei Forschungsteams, wechselbarer Schwerpunkt, Unternehmensstufen und drei fortsetzbare Siegpfade. Maßgeblicher Stand und Referenzläufe: [Forschung und Unternehmensfortschritt](FORSCHUNG_UND_FORTSCHRITT.md). Die nachfolgenden ursprünglichen Phasen bleiben eine Sammlung weiterer Ausbauziele; Grundstücke, Rohstoffquellen und Kundenansehen sind ebenfalls bereits vorhanden.
**Planungsbasis:** vorhandener vertikaler Schnitt und die in `tycoon.txt` beschriebenen Systeme.

## Zielbild

Der nächste Ausbau soll einen spielbaren Beginn von ungefähr 10 bis 20 Spieltagen liefern. Der Spieler übernimmt eine kleine Werkstatt, löst konkrete Kundenprobleme mit selbst entworfenen Artefakten und entwickelt dabei eine erkennbare Handwerkstradition.

Der zu beweisende Kernloop lautet:

> Problem verstehen → Lösung entwerfen → Material und Personal einsetzen → herstellen → Ergebnis und Folgen erleben → Bauplan verbessern oder automatisieren

Forschung, Markt und Konkurrenz bleiben wichtig, sollen diesen Loop aber unterstützen und nicht von ihm ablenken.

## Phase 0 – Vorhandene Basis

Der aktuelle Prototyp enthält bereits:

- feste Stunden-Ticks, Pause und Geschwindigkeiten,
- sechs Forschungsdisziplinen mit je 20 Projekten bis Stufe 8 und zwölf allgemeinen Forschungen,
- 21 Paarhybrid-Projekte, drei Konvergenzen und sichtbare Technologierennen,
- modularen Artefaktbau aus Grundkörper, Effekt, Material und Modifikatoren,
- gespeicherte Baupläne, stationsgebundene kontinuierliche Produktionslinien und Warenbestand,
- offenen Markt, 36 reguläre Aufträge und separate Abschlussprojekte,
- sechs Kundengruppen und zwei Konkurrenten,
- Räume, Stationen und ein Werkstattraster,
- 24 Spezialisten mit Fachgebiet, Werten, Lohn und Zuweisung,
- Ereignisse, laufende Kosten, Kredit, Insolvenz sowie drei Siegpfade,
- deterministische Simulation, Speicherstände, Modpakete und Headless-Tests.

Diese Basis wird erweitert, nicht neu gebaut.

## Phase 1 – Spielbarer Werkstattbeginn

**Priorität:** als Nächstes  
**Ziel:** Ein vollständiger, verständlicher Ablauf mit wenigen, aber gut verzahnten Inhalten.

### Inhalt

- Wahl eines Startgrundstücks; für den ersten Test Stadtrand, Friedhof oder tiefer Wald,
- drei funktionale Basisgebäude: Wohnhaus, Grundwerkstatt und Lagerhaus,
- vier ortsspezifische Basisrohstoffquellen für Holz, Wasser, Kräuter und Geisteressenz,
- drei klar unterscheidbare Anfangspersonen: Handwerker, Lehrling und ein wählbarer Fachspezialist,
- fünf problemorientierte Einstiegsaufträge,
- ein kleiner Satz universeller Materialeigenschaften, etwa Licht, Wärme, Bindung, Speicherung, Reinheit, Stabilität und Geisterabwehr,
- Auftragsauswertung nach geforderten Eigenschaften statt nur nach einem Produkt-Tag,
- mindestens zwei gültige Lösungswege für drei der fünf Probleme,
- lesbare Vorschau: erwartete Wirkung, Stabilität, Sicherheit, Kosten, Zeit und mögliches Risiko,
- Ergebnisbericht mit Begründung, Geld, Bekanntheit und gegebenenfalls Fraktionswirkung,
- geführter Ersteinstieg ohne starres Tutorialfenster.

### Beispielaufträge

| Problem | Mögliche Lösungen | Strategischer Unterschied |
|---|---|---|
| Hühner verschwinden aus verschlossener Scheune | Wahrnehmungsrune, Tierabwehr-Totem oder Geisterfalle | sichere Diagnose, günstige Abwehr oder riskante Bindung |
| Häuser frieren trotz voller Feuerstellen | Wärmestein oder verzauberte Ofenplatte | flexible Einzelware oder teure dauerhafte Installation |
| Lehrlinge verlieren beim Zaubern die Konzentration | Fokusstab oder beruhigendes Amulett | hohe Leistung für Magier oder sichere, breitere Nutzung |
| Etwas klopft nachts aus dem Brunnen | Schutzsiegel oder Geisterlaterne | Problem aussperren oder sichtbar und verhandelbar machen |
| Erntegut verdirbt im Lager | Konservierungsrune oder kühlende Truhe | billige Serienlösung oder hochwertiger Großauftrag |

### Abnahmekriterien

- Ein neuer Spieler kann ohne Vorwissen den ersten Auftrag annehmen, eine passende Lösung entwerfen, produzieren und abgeben.
- Vor- und Nachteil des gewählten Grundstücks werden innerhalb der ersten fünf Spieltage sichtbar.
- Die Auswertung erklärt, warum eine Lösung funktioniert oder scheitert.
- Mindestens eine frühe Entscheidung verändert den späteren Zugang zu Auftrag, Personal oder Material.
- Ein gespeicherter Bauplan kann nach einem Einzelauftrag als Produktlinie weiterverwendet werden.
- Der Ablauf ist deterministisch testbar und Speicherstände bleiben kompatibel oder werden migriert.

## Phase 2 – Produktlinien und wachsende Werkstatt

**Ziel:** Wachstum soll neue Planung ermöglichen, ohne Routinearbeit zu vervielfachen.

### Inhalt

- Mindestbestand und automatische Nachproduktion pro Bauplan,
- Produktvarianten und Modellfolge, etwa „Wärmestein I–III“,
- allgemeine Räume: Werkstatt, Lager, Laden, Schreibstube und Garten,
- fachspezifische Räume/Anlagen für Arkane Magie, Hexenkunst und Runenkunde,
- Stations-, Lager- und Personalplätze als verständliche Kapazitätsgrenzen,
- Personalgewinnung, Könnensstufen und zwei bis drei folgenreiche Eigenschaften,
- Marktberichte nach Produktlinie und Kundengruppe,
- Wartung und Qualitätsrisiko nur dort, wo beides Entscheidungen verändert.

### Abnahmekriterien

- Ein Betrieb mit drei Produktlinien kann mehrere Tage ohne wiederholte Einzelbefehle laufen.
- Raum-, Stations- und Personalentscheidung begrenzen unterschiedliche Teile des Betriebs.
- Eine kleine Qualitätswerkstatt und eine größere Serienwerkstatt sind beide wirtschaftlich tragfähig.

## Phase 3 – Ruf, Fraktionen und Konsequenzen

**Ziel:** Jede Werkstatt erhält eine gesellschaftliche Position, nicht nur einen höheren Zahlenwert.

### Inhalt

- Bekanntheit als Reichweitenwert für Bewerber, Händler, Grundstücke und größere Aufträge,
- Fraktionsruf bei Bevölkerung, Magiergilde, Hexenzirkel, Kirche, Händlern und später Druiden/Adel,
- Zugangsschwellen, Rabatte, exklusive Materialien und Konflikte zwischen Fraktionen,
- Auftragsfolgen, Rückrufe, Untersuchungen und freiwillige Wiedergutmachung,
- Ereignisse mit Vorwarnung, Spielerentscheidung und Nachwirkung,
- sichtbare Reaktionen von Rivalen auf Markt- und Rufpositionen.

### Abnahmekriterien

- Derselbe Auftrag kann zwei Fraktionen unterschiedlich beeinflussen.
- Ruf öffnet konkrete Optionen und schließt zeitweise andere, ohne dauerhafte Sackgassen zu erzeugen.
- Ein Unfall ist auf vorher sichtbare Risiken zurückführbar und bietet mindestens eine Reaktionsmöglichkeit.

## Phase 4 – Grundstücke und magische Traditionen

**Ziel:** Die physische Werkstatt spiegelt Forschungsgeschichte und Geschäftsmodell wider.

### Inhalt

- kaufbare Nachbargrundstücke mit Merkmalen wie Straße, Wald, Quelle, Hügel, Fels, Ruine und Friedhof,
- Außenanlagen mit Geländeanforderungen,
- Hybridanlagen als Ergebnis kombinierter Forschung, zum Beispiel Runengewächshaus oder gebundener Ritualhof,
- seltene Hinweise und verborgene Hybridforschung durch Orte, Personal und Aufträge,
- weitere Schulen erst einzeln und mit eigenem Marktprofil: Naturmagie, Sakralmagie, danach Alchemie,
- Personalbeziehungen als kleiner Satz stabiler Synergien und Konflikte.

### Abnahmekriterien

- Die Grundstückswahl verändert mindestens Gebäude, Beschaffung und erreichbare Aufträge.
- Eine Hybridanlage erzeugt eine neue Regel oder Lieferkette statt nur einen Produktionsbonus.
- Die Werkstatt eines Spezialisten ist auf einen Blick von einem Mischbetrieb unterscheidbar.

## Phase 5 – Langfristiges Spiel und alternative Größe

**Ziel:** Mehrere Unternehmensfantasien bleiben bis zum Ende konkurrenzfähig.

### Pfade

- **Der Meister:** wenige extrem hochwertige Artefakte, Großmeisterwissen, Prestige und exklusive Aufträge.
- **Der Kaufmann:** standardisierte Produktlinien, mehrere Märkte, hohe Logistik- und Produktionseffizienz.
- **Der Forscher:** schwer kopierbare Hybride, Entdeckungen und neue Marktsegmente.

### Inhalt

- abgestufte Unternehmensmeilensteine vom Dorfbastler bis zur legendären Werkstatt,
- Szenarien mit unterschiedlichen Grundstücken, Rivalen und Marktbedingungen,
- überarbeitete Siegbedingungen für Meisterschaft, Wirtschaft, Hybridinnovation und gesellschaftlichen Einfluss,
- Endspielereignisse, welche die gewählte Tradition prüfen,
- Balancing, damit Unternehmensgröße kein automatischer Siegwert ist.

## Reihenfolge innerhalb der nächsten Umsetzung

1. Auftragsschema von Produkt-Tags auf Probleme und Eigenschaftsanforderungen erweitern.
2. Material- und Komponentenwerte auf ein gemeinsames, erklärbares Eigenschaftsvokabular bringen.
3. Vorschau und Ergebnisbericht für Aufträge entwerfen.
4. Fünf Einstiegsaufträge samt mindestens acht passenden Komponenten/Bauweisen erstellen.
5. Bekanntheit und zwei frühe Fraktionsrufwerte als Folgen anbinden.
6. Bauplan-Wiederverwendung als Übergang vom Einzelauftrag zur Produktlinie zeigen.
7. Den Ablauf automatisiert testen und anschließend Spieltempo sowie Wirtschaft balancieren.

## Noch nicht im nächsten Meilenstein

- der spätere Kauf zusätzlicher Grundstücke und Außenposten,
- vollständige Personalbeziehungen,
- Natur-, Sakral- und Alchemieschulen,
- komplexe Lieferketten,
- politische Verbote und umfassendes Rechtssystem,
- Kampagne und vollständiges Endspiel.

Diese Punkte bleiben Teil der Vision, würden den Nachweis des Kernloops derzeit aber unnötig verzögern.

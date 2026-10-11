# Forschung und Unternehmensfortschritt 0.3

Stand: 21. September 2026. Implementierter Ausbau; bestehende Partien benötigen einen Neustart.

## Materialverwaltung ab 0.3.1

Elara, Selin und Torben starten bereits an Forschung, Produktion und Lager. Jeder Grundkörper legt über `base_material_id` sein einziges Material fest; der Verbrauch beträgt zwei Einheiten pro Artefakt. Materialwahl und Zusatzmaterial entfallen. Die Forschung Komplexe Baupläne ermöglicht weiterhin Sekundäreffekte; Effekte und Modifikatoren ändern das Basismaterial nicht.

Der Lagerist beschafft fehlendes Produktionsmaterial und sammelt aus den Grundstücksquellen. Nur neue Ernte, die nicht mehr ins Lager passt, wird automatisch verkauft. Vorhandene Bestände bleiben erhalten; manuelle Handelsaktionen entfallen. Ohne Lagerbesetzung kann aus vorhandenen Vorräten produziert werden, aber Beschaffung, Ernte und Überschussverkauf ruhen.

## Forschungsumfang

156 Projekte: sechs Schulen mit jeweils 20 Projekten, zwölf allgemeine Forschungen, 15 Paarhybride, sechs vertiefte Paarhybride und drei Konvergenzen. Jede Schule besitzt sechs Kernstufen, zwei Fachrichtungen auf Stufe 2–7 und je ein Meisterprojekt auf Stufe 8. Alle sechs Grundlagen sind von Beginn an sichtbar und erreichbar. Höhere Projekte bleiben zur Planung sichtbar, auch wenn Voraussetzungen fehlen.

Arkane Magie, Hexenkunst und Runenkunde werden durch Naturmagie, Alchemie und Sakralmagie ergänzt. Neue Schulen erhalten sechs Warenklassen, vier Fachkräfte und sechs reguläre Aufträge. Druiden, Apotheker und Tempel bilden zusätzliche Kundengruppen. Erlernte Grundlagen öffnen ihre jeweiligen Fachaufträge unabhängig von der ursprünglichen Werkstattprofession.

Hybride kombinieren maximal drei Schulen. Paarhybride benötigen beide Kernstufen 3; Vertiefungen außerdem Kernstufe 5 und den einfachen Hybrid. Konvergenzen verbinden Arkane/Hexen/Runen, Natur/Alchemie/Sakral oder Arkane/Runen/Sakral. Andere Dreifachkombinationen und mehr als drei Schulen pro Artefakt sind nicht freigegeben.

## Teams, Schwerpunkt und Durchbrüche

Ein Team erhält die Leistung der besetzten Forschertische, die ihm zugewiesen sind. Anfangs gehören alle Tische zu Team 1. Unternehmensstufe 3 und die Forschung Zweites Forschungsteam eröffnen Team 2. Personal liefert nie gleichzeitig Leistung an beide Teams; ein Projekt kann nur einem Team zugewiesen sein. Pause und Wechsel erhalten Fortschritt. Die Anlaufzeit beträgt zwölf Arbeitsstunden und sinkt durch das Projektarchiv auf acht.

Ein Betriebsschwerpunkt gibt 20 % Forschungsleistung auf genau eine Fachrichtung einschließlich ihres Meisterprojekts. Die erste Wahl nach Abschluss ihres Einstiegsprojekts ist ab Unternehmensstufe 2 kostenlos. Ein Wechsel verbraucht 2.000 Gold und bindet ein ausgewähltes Team für 288 Forschungsarbeit. Der alte Bonus endet sofort, der neue beginnt nach Fertigstellung; andere Freischaltungen gehen nicht verloren. Das zweite Team kann währenddessen forschen.

Kernstufe 4 und 6, Meisterprojekte und alle Hybride verlangen nach abgeschlossener Theorie Prototypen. Theorieabschluss gibt das Team frei, aber noch keine Freischaltung. Die allgemeine Prototypenprüfung verlangt ebenfalls zwei Artefakte ab Qualität 55: Dieser frühe Nachweis ermöglicht den zweiten Durchbruch für reine Spezialisten vor Unternehmensstufe 4.

Die Warenauswahl nennt Qualität, Menge, Klassen, Schulabdeckung und gegebenenfalls Artefaktwerte. Der Spieler wählt Baupläne und Mengen aus. Alle Anforderungen müssen gemeinsam erfüllt sein; die Simulation prüft den gesamten Lagerverbrauch, bevor sie Ware abbucht. Doppelte Einträge, Mehrfachverwendung desselben Bestands und Teilabgaben werden ohne Zustandsänderung abgewiesen. Es gilt die bestehende durchschnittliche Qualität pro Bauplanbestand.

## Unternehmensstufen

| Stufe | Voraussetzungen | Forschung |
|---|---|---|
| Kleine Werkstatt | Start | bis Stufe 2 |
| Etablierter Betrieb | eine Grundlage, zehn verkaufte Artefakte | bis Stufe 3, Schwerpunkt |
| Anerkannte Werkstatt | sechs Forschungen, drei reguläre Aufträge | bis Stufe 5, zweites Team erforschbar |
| Bedeutende Werkstatt | 14 Forschungen, zehn reguläre Aufträge, zwei praktische Durchbrüche | bis Stufe 8, Lebenswerke |
| Legendäre Werkstatt | ein Siegpfad abgeschlossen | weitere Lebenswerke bleiben offen |

Alle erreichten Stufen bleiben erhalten. Wiederholte reguläre Aufträge zählen jeweils als Erfüllung. Allgemeine Forschung zählt zum Forschungsfortschritt; Unternehmensgröße, Personalzahl und Schulbreite sind keine Aufstiegsbedingungen.

## Lebenswerke

- **Meister:** Fachrichtungsabschluss erforschen, fünf Artefakte mit dessen Meistereffekt ab Qualität 85 abgeben und zehn weitere Artefakte dieser Familie innerhalb von 30 Spieltagen verkaufen. Der Effekt darf primär oder sekundär enthalten sein. Nach Ablauf kann das Verkaufsfenster ohne erneute Meisterwerkabgabe gestartet werden.
- **Kaufmann:** Nach Handelsmeisterschaft zählt ein rollendes Fenster von 30 aufeinanderfolgenden Tagesabschlüssen. Es verlangt insgesamt mindestens 30.000 Gold Artefaktumsatz, ein positives gesamtes Betriebsergebnis, drei Kundengruppen mit jeweils mindestens 30 verkauften Artefakten und am Abschluss 30.000 Gold nach Abzug der Kreditschuld. Das Betriebsergebnis ist der bestehende Tages-Cashflow einschließlich Rohstoffhandel; Rohstoffumsatz erfüllt nicht den geforderten Artefaktumsatz.
- **Forscher:** Eine Konvergenz abschließen, drei passende Artefakte ab Qualität 80 demonstrieren und anschließend zehn weitere ab Qualität 75 für einen garantierten Folgeauftrag abgeben. Dieser Auftrag hat keinen zufälligen Angebotsplatz und keine Ablaufzeit.

Jeder Sieg wird einmal gespeichert. Ein neuer Sieg pausiert die Partie; Weiterspielen setzt sie fort. Ein Forschungsabschluss allein beendet keine Partie. Insolvenz bleibt ein endgültiges Spielende.

## Balance und Prüfverfahren

Unverändert: eine Spielstunde pro Tick, 1,25 Sekunden pro Tick bei 1×. Die 4–8 Stunden sind ein Ziel für eine Partie, keine Mindestdauer. 4× darf entsprechend schneller sein. Das offene Marktsystem begrenzt Nachfrage weiterhin je Segment; der globale Rufanteil am Absatzwert wird für lange Partien bei Ruf 100 gedeckelt, während zusätzlicher Ruf weiterhin erfasst wird.

`tests/test_progression_balance.gd` führt reproduzierbare Partien ohne geschenktes Kapital, freigeschaltete Forschung oder erzeugte Testware aus. Die Teststrategie erledigt zuerst zehn Aufträge, investiert in Produktionskapazität und finanziert spätere Forschung durch Serienware. Die Niederlagen früher unfinanzierter Strategien sind kein Grund, Forschungs- oder Herstellungskosten abzuschalten.

Erneut erfolgreich mit festen Basismaterialien in 0.3.1 (Seed 20260912, Stadtrand): Meister Tag 648, Kaufmann Tag 486, Forscher Tag 810. Das entspricht 5,39 / 4,04 / 6,74 Stunden reiner Simulation bei 1×. Meister und Kaufmann verwenden eine Schule, der Forscher drei. Diese Werte sind keine menschlichen Spieltests und keine Aussage über alle möglichen Strategien. Die hohen späten Geldbestände zeigen weiteren Spielraum für wirtschaftliches Feintuning; zusätzliche künstliche Wartezeiten wurden nicht eingeführt.

Die Headless-Suite prüft zusätzlich alle 18 Kombinationen aus Grundstück und erster Schule, Vorläufer-Baupläne für sämtliche Durchbrüche, atomare Abgaben, unabhängige Teams, Schwerpunktwechsel, Siegfortsetzung und beschädigte Speicherzustände. Der gerenderte UI-Test prüft 1280 × 720, beide Sprachen, Teamstart, Prototypenauswahl und den Weiterspielen-Dialog.

## Daten und Versionen

Sichtbare Version 0.3.1; Speicherformat 11; Grundpaket 0.3.0; Content-Kompatibilität und mitgelieferte Manifeste 0.3.0. Paket- und Versionslisten werden weiterhin exakt geprüft. Alte Dateien bleiben erhalten; neue UI-Speicherslots tragen `_0_3_1`.

Forschungseinträge erweitern die bisherigen Felder um `track`, `branch`, lokalisierte Fachrichtungsnamen, `min_company_level`, `proofs`, `benefits`, `hybrid_coverage`, `capstone`, `convergence` und `family_effect`. Unternehmensstufen, Schwerpunktkosten und Siegschwellen liegen im Szenario. Neue Stationen können einen sichtbaren Qualitätsbonus besitzen. Die Simulation und ihr Befehlsmodell bleiben die einzige Quelle für Voraussetzungen und Abgaben; Mods enthalten weiterhin ausschließlich Daten und Assets.

## Projektkatalog

| ID | Forschung | Stufe | Art |
|---|---|---:|---|
| `base:alchemy_core_1` | Alchemie: Grundlagen | 1 | core |
| `base:alchemy_core_2` | Alchemie: Werkstoffkunde | 2 | core |
| `base:alchemy_purity_2` | Reinheit und Stabilisierung – Anwendung | 2 | branch |
| `base:alchemy_transmutation_2` | Katalyse und Transmutation – Anwendung | 2 | branch |
| `base:alchemy_core_3` | Alchemie: Meisterwissen | 3 | core |
| `base:alchemy_purity_3` | Reinheit und Stabilisierung – Abstimmung | 3 | branch |
| `base:alchemy_transmutation_3` | Katalyse und Transmutation – Abstimmung | 3 | branch |
| `base:alchemy_core_4` | Alchemie: Werkstattverfahren | 4 | core |
| `base:alchemy_purity_4` | Reinheit und Stabilisierung – Träger | 4 | branch |
| `base:alchemy_sacred_hybrid` | Alchemie / Sakralmagie | 4 | hybrid |
| `base:alchemy_transmutation_4` | Katalyse und Transmutation – Träger | 4 | branch |
| `base:alchemy_core_5` | Alchemie: Resonanzkörper | 5 | core |
| `base:alchemy_purity_5` | Reinheit und Stabilisierung – Fortgeschrittene Wirkung | 5 | branch |
| `base:alchemy_transmutation_5` | Katalyse und Transmutation – Fortgeschrittene Wirkung | 5 | branch |
| `base:alchemy_core_6` | Alchemie: Hochmagie | 6 | core |
| `base:alchemy_purity_6` | Reinheit und Stabilisierung – Spezialwerkstatt | 6 | branch |
| `base:alchemy_sacred_advanced` | Vertiefte Verbindung: Alchemie / Sakralmagie | 6 | hybrid |
| `base:alchemy_transmutation_6` | Katalyse und Transmutation – Spezialwerkstatt | 6 | branch |
| `base:alchemy_purity_7` | Reinheit und Stabilisierung – Vollendung | 7 | branch |
| `base:alchemy_transmutation_7` | Katalyse und Transmutation – Vollendung | 7 | branch |
| `base:alchemy_purity_8` | Reinheit und Stabilisierung – Meisterwerk | 8 | branch |
| `base:alchemy_transmutation_8` | Katalyse und Transmutation – Meisterwerk | 8 | branch |
| `base:arcane_foundations` | Arkane Grundlagen | 1 | core |
| `base:arcane_precision_2` | Präzision und Verstärkung – Anwendung | 2 | branch |
| `base:arcane_resonance` | Arkane Resonanz | 2 | core |
| `base:arcane_storage_2` | Speicherung und Autonomie – Anwendung | 2 | branch |
| `base:arcane_mastery` | Arkane Meisterschaft | 3 | core |
| `base:arcane_precision_3` | Präzision und Verstärkung – Abstimmung | 3 | branch |
| `base:arcane_storage_3` | Speicherung und Autonomie – Abstimmung | 3 | branch |
| `base:arcane_alchemy_hybrid` | Arkane Magie / Alchemie | 4 | hybrid |
| `base:arcane_core_4` | Arkane Magie: Werkstattverfahren | 4 | core |
| `base:arcane_nature_hybrid` | Arkane Magie / Naturmagie | 4 | hybrid |
| `base:arcane_precision_4` | Präzision und Verstärkung – Träger | 4 | branch |
| `base:arcane_sacred_hybrid` | Arkane Magie / Sakralmagie | 4 | hybrid |
| `base:arcane_storage_4` | Speicherung und Autonomie – Träger | 4 | branch |
| `base:crystal_hex` | Hexenkristall | 4 | hybrid |
| `base:runic_manufactory` | Runische Manufaktur | 4 | hybrid |
| `base:arcane_core_5` | Arkane Magie: Resonanzkörper | 5 | core |
| `base:arcane_precision_5` | Präzision und Verstärkung – Fortgeschrittene Wirkung | 5 | branch |
| `base:arcane_storage_5` | Speicherung und Autonomie – Fortgeschrittene Wirkung | 5 | branch |
| `base:arcane_core_6` | Arkane Magie: Hochmagie | 6 | core |
| `base:arcane_precision_6` | Präzision und Verstärkung – Spezialwerkstatt | 6 | branch |
| `base:arcane_runes_advanced` | Vertiefte Verbindung: Arkane Magie / Runenkunde | 6 | hybrid |
| `base:arcane_storage_6` | Speicherung und Autonomie – Spezialwerkstatt | 6 | branch |
| `base:arcane_witchcraft_advanced` | Vertiefte Verbindung: Arkane Magie / Hexenkunst | 6 | hybrid |
| `base:arcane_precision_7` | Präzision und Verstärkung – Vollendung | 7 | branch |
| `base:arcane_storage_7` | Speicherung und Autonomie – Vollendung | 7 | branch |
| `base:arcane_precision_8` | Präzision und Verstärkung – Meisterwerk | 8 | branch |
| `base:arcane_storage_8` | Speicherung und Autonomie – Meisterwerk | 8 | branch |
| `base:convergent_mastery` | Konvergente Meisterschaft | 8 | hybrid |
| `base:sanctuary_convergence` | Ewiges Heiligtum | 8 | hybrid |
| `base:nature_core_1` | Naturmagie: Grundlagen | 1 | core |
| `base:nature_core_2` | Naturmagie: Werkstoffkunde | 2 | core |
| `base:nature_growth_2` | Wachstum und Regeneration – Anwendung | 2 | branch |
| `base:nature_symbiosis_2` | Symbiose und Naturabwehr – Anwendung | 2 | branch |
| `base:nature_core_3` | Naturmagie: Meisterwissen | 3 | core |
| `base:nature_growth_3` | Wachstum und Regeneration – Abstimmung | 3 | branch |
| `base:nature_symbiosis_3` | Symbiose und Naturabwehr – Abstimmung | 3 | branch |
| `base:nature_alchemy_hybrid` | Naturmagie / Alchemie | 4 | hybrid |
| `base:nature_core_4` | Naturmagie: Werkstattverfahren | 4 | core |
| `base:nature_growth_4` | Wachstum und Regeneration – Träger | 4 | branch |
| `base:nature_sacred_hybrid` | Naturmagie / Sakralmagie | 4 | hybrid |
| `base:nature_symbiosis_4` | Symbiose und Naturabwehr – Träger | 4 | branch |
| `base:nature_core_5` | Naturmagie: Resonanzkörper | 5 | core |
| `base:nature_growth_5` | Wachstum und Regeneration – Fortgeschrittene Wirkung | 5 | branch |
| `base:nature_symbiosis_5` | Symbiose und Naturabwehr – Fortgeschrittene Wirkung | 5 | branch |
| `base:nature_alchemy_advanced` | Vertiefte Verbindung: Naturmagie / Alchemie | 6 | hybrid |
| `base:nature_core_6` | Naturmagie: Hochmagie | 6 | core |
| `base:nature_growth_6` | Wachstum und Regeneration – Spezialwerkstatt | 6 | branch |
| `base:nature_sacred_advanced` | Vertiefte Verbindung: Naturmagie / Sakralmagie | 6 | hybrid |
| `base:nature_symbiosis_6` | Symbiose und Naturabwehr – Spezialwerkstatt | 6 | branch |
| `base:nature_growth_7` | Wachstum und Regeneration – Vollendung | 7 | branch |
| `base:nature_symbiosis_7` | Symbiose und Naturabwehr – Vollendung | 7 | branch |
| `base:living_convergence` | Lebendige Dreieinigkeit | 8 | hybrid |
| `base:nature_growth_8` | Wachstum und Regeneration – Meisterwerk | 8 | branch |
| `base:nature_symbiosis_8` | Symbiose und Naturabwehr – Meisterwerk | 8 | branch |
| `base:rune_foundations` | Runen-Grundformen | 1 | core |
| `base:rune_arrays` | Verbundene Runenfelder | 2 | core |
| `base:runes_industry_2` | Serienfertigung und Flächenwirkung – Anwendung | 2 | branch |
| `base:runes_protection_2` | Schutz und Dauerhaftigkeit – Anwendung | 2 | branch |
| `base:rune_mastery` | Ewige Inschrift | 3 | core |
| `base:runes_industry_3` | Serienfertigung und Flächenwirkung – Abstimmung | 3 | branch |
| `base:runes_protection_3` | Schutz und Dauerhaftigkeit – Abstimmung | 3 | branch |
| `base:runes_alchemy_hybrid` | Runenkunde / Alchemie | 4 | hybrid |
| `base:runes_core_4` | Runenkunde: Werkstattverfahren | 4 | core |
| `base:runes_industry_4` | Serienfertigung und Flächenwirkung – Träger | 4 | branch |
| `base:runes_nature_hybrid` | Runenkunde / Naturmagie | 4 | hybrid |
| `base:runes_protection_4` | Schutz und Dauerhaftigkeit – Träger | 4 | branch |
| `base:runes_sacred_hybrid` | Runenkunde / Sakralmagie | 4 | hybrid |
| `base:runes_core_5` | Runenkunde: Resonanzkörper | 5 | core |
| `base:runes_industry_5` | Serienfertigung und Flächenwirkung – Fortgeschrittene Wirkung | 5 | branch |
| `base:runes_protection_5` | Schutz und Dauerhaftigkeit – Fortgeschrittene Wirkung | 5 | branch |
| `base:runes_core_6` | Runenkunde: Hochmagie | 6 | core |
| `base:runes_industry_6` | Serienfertigung und Flächenwirkung – Spezialwerkstatt | 6 | branch |
| `base:runes_protection_6` | Schutz und Dauerhaftigkeit – Spezialwerkstatt | 6 | branch |
| `base:runes_industry_7` | Serienfertigung und Flächenwirkung – Vollendung | 7 | branch |
| `base:runes_protection_7` | Schutz und Dauerhaftigkeit – Vollendung | 7 | branch |
| `base:runes_industry_8` | Serienfertigung und Flächenwirkung – Meisterwerk | 8 | branch |
| `base:runes_protection_8` | Schutz und Dauerhaftigkeit – Meisterwerk | 8 | branch |
| `base:sacred_core_1` | Sakralmagie: Grundlagen | 1 | core |
| `base:sacred_banishment_2` | Reinigung und Bann – Anwendung | 2 | branch |
| `base:sacred_blessing_2` | Segen und Bewahrung – Anwendung | 2 | branch |
| `base:sacred_core_2` | Sakralmagie: Werkstoffkunde | 2 | core |
| `base:sacred_banishment_3` | Reinigung und Bann – Abstimmung | 3 | branch |
| `base:sacred_blessing_3` | Segen und Bewahrung – Abstimmung | 3 | branch |
| `base:sacred_core_3` | Sakralmagie: Meisterwissen | 3 | core |
| `base:sacred_banishment_4` | Reinigung und Bann – Träger | 4 | branch |
| `base:sacred_blessing_4` | Segen und Bewahrung – Träger | 4 | branch |
| `base:sacred_core_4` | Sakralmagie: Werkstattverfahren | 4 | core |
| `base:sacred_banishment_5` | Reinigung und Bann – Fortgeschrittene Wirkung | 5 | branch |
| `base:sacred_blessing_5` | Segen und Bewahrung – Fortgeschrittene Wirkung | 5 | branch |
| `base:sacred_core_5` | Sakralmagie: Resonanzkörper | 5 | core |
| `base:sacred_banishment_6` | Reinigung und Bann – Spezialwerkstatt | 6 | branch |
| `base:sacred_blessing_6` | Segen und Bewahrung – Spezialwerkstatt | 6 | branch |
| `base:sacred_core_6` | Sakralmagie: Hochmagie | 6 | core |
| `base:sacred_banishment_7` | Reinigung und Bann – Vollendung | 7 | branch |
| `base:sacred_blessing_7` | Segen und Bewahrung – Vollendung | 7 | branch |
| `base:sacred_banishment_8` | Reinigung und Bann – Meisterwerk | 8 | branch |
| `base:sacred_blessing_8` | Segen und Bewahrung – Meisterwerk | 8 | branch |
| `base:witch_foundations` | Rituelle Grundlagen | 1 | core |
| `base:witch_transformations` | Wandelrituale | 2 | core |
| `base:witchcraft_binding_2` | Geister und Bindung – Anwendung | 2 | branch |
| `base:witchcraft_change_2` | Wandel und Anpassung – Anwendung | 2 | branch |
| `base:witch_mastery` | Großes Hexenwerk | 3 | core |
| `base:witchcraft_binding_3` | Geister und Bindung – Abstimmung | 3 | branch |
| `base:witchcraft_change_3` | Wandel und Anpassung – Abstimmung | 3 | branch |
| `base:bound_covenant` | Gebundener Zirkelpakt | 4 | hybrid |
| `base:witchcraft_alchemy_hybrid` | Hexenkunst / Alchemie | 4 | hybrid |
| `base:witchcraft_binding_4` | Geister und Bindung – Träger | 4 | branch |
| `base:witchcraft_change_4` | Wandel und Anpassung – Träger | 4 | branch |
| `base:witchcraft_core_4` | Hexenkunst: Werkstattverfahren | 4 | core |
| `base:witchcraft_nature_hybrid` | Hexenkunst / Naturmagie | 4 | hybrid |
| `base:witchcraft_sacred_hybrid` | Hexenkunst / Sakralmagie | 4 | hybrid |
| `base:witchcraft_binding_5` | Geister und Bindung – Fortgeschrittene Wirkung | 5 | branch |
| `base:witchcraft_change_5` | Wandel und Anpassung – Fortgeschrittene Wirkung | 5 | branch |
| `base:witchcraft_core_5` | Hexenkunst: Resonanzkörper | 5 | core |
| `base:witchcraft_binding_6` | Geister und Bindung – Spezialwerkstatt | 6 | branch |
| `base:witchcraft_change_6` | Wandel und Anpassung – Spezialwerkstatt | 6 | branch |
| `base:witchcraft_core_6` | Hexenkunst: Hochmagie | 6 | core |
| `base:witchcraft_runes_advanced` | Vertiefte Verbindung: Hexenkunst / Runenkunde | 6 | hybrid |
| `base:witchcraft_binding_7` | Geister und Bindung – Vollendung | 7 | branch |
| `base:witchcraft_change_7` | Wandel und Anpassung – Vollendung | 7 | branch |
| `base:witchcraft_binding_8` | Geister und Bindung – Meisterwerk | 8 | branch |
| `base:witchcraft_change_8` | Wandel und Anpassung – Meisterwerk | 8 | branch |
| `base:complex_blueprints` | Komplexe Baupläne | 2 | general |
| `base:project_archive` | Projektarchiv | 2 | general |
| `base:research_planning` | Forschungsplanung | 2 | general |
| `base:prototype_testing` | Prototypenprüfung | 3 | general |
| `base:workshop_expansion` | Werkstattausbau | 3 | general |
| `base:laboratory_organisation` | Labororganisation | 4 | general |
| `base:second_team` | Zweites Forschungsteam | 4 | general |
| `base:serial_processes` | Serienverfahren | 4 | general |
| `base:trade_analysis` | Handelsauswertung | 4 | general |
| `base:precision_instruments` | Präzisionsinstrumente | 5 | general |
| `base:quality_control` | Qualitätskontrolle | 5 | general |
| `base:trade_mastery` | Handelsmeisterschaft | 8 | general |

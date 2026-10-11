# Arbeitsanweisungen für Artefakt Imperium

## Projekt und Orientierung

- Dieses Projekt ist ein datengetriebener Fantasy-Tycoon in Godot mit GDScript. Verwende die in `.godot-version` festgelegte Engine, derzeit **4.7.1**. Die mitgelieferte Mono-Engine bedeutet nicht, dass das Projekt C# verwendet.
- Antworte dem Nutzer auf Deutsch. Behalte englische Codebezeichner und den bestehenden Stil bei.
- Lies zunächst `README.md` und anschließend nur die für den Auftrag relevanten Dateien. Suche gezielt mit `rg`, statt große Dateien vollständig auszugeben.
- `ARTEFAKT_IMPERIUM_CONCEPT.md` beschreibt das Zielbild; `docs/ROADMAP.md` den Ausbauplan. Ergänzende Designentscheidungen stehen in `docs/IDEENBEWERTUNG.md` und `docs/GRUNDSTUECKE_UND_ROHSTOFFE.md`; `tycoon.txt` enthält ursprüngliche Ideen. Planungsdokumente können dem implementierten Stand hinterherhinken: Prüfe Verhalten in Code und Tests, bevor du ein System als fehlend behandelst.
- Entwickle die vorhandene Basis weiter. Halte Änderungen auf den Auftrag begrenzt und vermeide beiläufige Komplettumbauten oder Neuformatierungen.

## Wo Änderungen hingehören

| Bereich | Einstieg |
| --- | --- |
| Spielregeln, Wirtschaft, Forschung, Produktion, Personal und Stunden-Ticks | `src/core/game_simulation.gd` |
| Typisierte Spielbefehle und ihre Payloads | `src/core/game_command.gd` |
| Paketladen, Namespaces und Referenzvalidierung | `src/core/content_registry.gd` |
| Deterministische Zufallszahlen | `src/core/deterministic_rng.gd` |
| Spielstanddateien | `src/core/save_system.gd` |
| Spielstandvalidierung und gemeinsame JSON-Typprüfung | `src/core/save_validation.gd`, `src/core/data_schema.gd` |
| Serialisierung und Spielstandmigrationen | `serialize()`, `restore()` und Migrationsfunktionen in `src/core/game_simulation.gd` |
| Programmatisch aufgebaute Oberfläche und Sprachumschaltung | `src/ui/main.gd` |
| Werkstattraster, Darstellung und Platzierungseingaben | `src/ui/workshop_grid.gd` |
| Einstiegsszene | `scenes/main.tscn` |
| Spielinhalte und Balancewerte | `content/base/data.json`, `content/base/manifest.json` |
| Beispiel für Datenmods | `mods/example/data.json`, `mods/example/manifest.json` |
| Integrationstests und Regressionen | `tests/test_runner.gd`, `tests/test_safety.gd`, `tests/test_research_expansion.gd` |
| Befehlsgesteuerte Aufstiegs- und Balancepartien | `tests/test_progression_balance.gd` |
| Gerenderte UI-Abläufe und Kontrollbilder | `tests/test_ui_smoke.gd` |

## Architekturregeln

- Halte die Fachlogik in der szenenunabhängigen `GameSimulation` (`RefCounted`). UI und Werkstattraster dürfen keine zweite Implementierung der Spielregeln bekommen.
- Führe neue Spielaktionen über `GameCommand` und die Befehlsverarbeitung der Simulation. Validiere Voraussetzungen dort; UI-Sperren allein reichen nicht aus.
- Ein Tick entspricht einer Spielstunde. Die Geschwindigkeit verändert die Häufigkeit der Ticks in Echtzeit, nicht deren wirtschaftliche Ergebnisse.
- Bewahre Determinismus: gleicher Seed und gleiche Befehlsfolge müssen denselben Simulationszustand ergeben. Verwende die vorhandenen `DeterministicRng`-Ströme statt globalem Zufall oder Uhrzeit; berücksichtige Zufallszustände beim Speichern und Laden.
- Jeder Grundkörper benötigt eine gültige `base_material_id`; pro Artefakt werden zwei Einheiten verbraucht. Einkauf, Quellensammlung und Ernteüberschussverkauf erfordern einen zugeordneten Lageristen. Manuelle Rohstoffhandelsbefehle sind stillgelegt.
- Pflege Inhalte und Balancewerte möglichst im Datenpaket. IDs sind stabile, namespaced Referenzen (`base:…`, `example:…`); bei Änderungen alle Verwendungen prüfen.
- Erweitere bei neuen Inhaltskategorien oder Referenzen auch die Validierung in `ContentRegistry`. Mods bleiben Daten-/Asset-Pakete; lade keinen ausführbaren Modcode.
- Achtung: `load_all(false)` schaltet nur `user://mods` aus. Projektmods unter `res://mods` werden weiterhin geladen.
- Seit Version 0.3.1 gelten Speicherformat 11 und Content-Kompatibilität 0.3.0; frühere Partien werden bewusst abgewiesen. Neue UI-Speicherslots tragen `_0_3_1`. Der aktuelle Forschungsstand steht in `docs/FORSCHUNG_UND_FORTSCHRITT.md`.
- Prüfe bei neuen Zustandsfeldern Initialisierung, Serialisierung, Wiederherstellung und ältere Spielstände gemeinsam. Passe `SAVE_VERSION` und Migrationen an, wenn das Speicherformat dies erfordert. Die Prüfung der exakten Paket-/Versionsliste bleibt erhalten.
- Verwechsle die sichtbare Spielversion in `project.godot` nicht mit dem Content-Kompatibilitätswert `SUPPORTED_GAME_VERSION` und den Manifestfeldern `game_version`. Diese Werte werden derzeit getrennt verwendet.
- Folge dem bestehenden typisierten GDScript-Stil: Tabs zur Einrückung, `snake_case` für Funktionen und Variablen, `PascalCase` für Klassen und explizite Typen bei unklaren `Variant`-Werten. JSON bleibt gültig und ohne Kommentare.
- Berücksichtige bei UI-Texten Deutsch und Englisch; nutze die bestehenden Lokalisierungswege (`UI_TEXT`, `_t()` und lokalisierte Inhaltsfelder).

## Lokale Befehle (PowerShell im Projektordner)

Die lokale Konsolen-Engine ist vorhanden; ein globaler `godot`-Befehl wird nicht vorausgesetzt:

```powershell
$godotExe = Join-Path (Get-Location) 'Godot_v4.7.1-stable_mono_win64/Godot_v4.7.1-stable_mono_win64_console.exe'
```

Nach frischem Checkout, fehlendem Klassen-Cache oder neuen globalen GDScript-Klassen zuerst importieren:

```powershell
& $godotExe --headless --path . --import
```

Headless-Tests:

```powershell
& $godotExe --headless --path . --script tests/test_runner.gd
```

Die Suite beendet sich mit `quit(failures)`. Prüfe `$LASTEXITCODE` und die Ausgabe auf Parser-/Skriptfehler. Sie schreibt einen Testspielstand im Slot `automated_test` unter `user://saves`; ein vorhandener Slot dieses Namens wird überschrieben. Nutzer-Mods können den Lauf beeinflussen.

Kurzer Startcheck der Hauptszene ohne Fenster:

```powershell
& $godotExe --headless --path . --quit-after 5
```

Dieser Startcheck ersetzt keine Sichtprüfung. Für UI-Änderungen das Projekt im Editor oder direkt aus den Quellen starten und den betroffenen Ablauf bei 1280 × 720 sowie mit Sprachumschaltung prüfen.

Windows-Export, wenn der Auftrag einen aktualisierten Build umfasst (passende Export-Templates erforderlich):

```powershell
& $godotExe --headless --path . --export-release 'Windows Desktop' 'build/Artefakt Imperium.exe'
```

`Artefakt Imperium starten.bat` startet den exportierten Build. Quellcodeänderungen erscheinen dort erst nach erneutem Export.

## Prüfung und Abschluss

- Führe bei Änderungen an Simulation, Befehlen, Content oder Speicherständen die Headless-Suite aus. Ergänze bei Verhaltensänderungen und Fehlerbehebungen gezielte Regressionen im vorhandenen Test-Runner; prüfe beobachtbares Verhalten, nicht bloß Implementierungsdetails.
- Bei UI-/Szenenänderungen prüfe Start und betroffenen Bedienablauf; bei Änderungen mit Fachlogik zusätzlich die Suite. Für reine Dokumentationsänderungen genügen Inhalts-, Pfad- und Befehlsprüfung.
- Durchsuche normalerweise `src`, `tests`, `content`, `mods`, `scenes` und `docs`. Spare `.godot`, `.test_user`, `build`, das Engine-Verzeichnis und das Engine-ZIP bei Quelltextsuche aus.
- Bearbeite generierte Caches, Engine-Binärdateien und Exportartefakte nicht manuell. Erhalte bestehende `.uid`-Referenzen. Überschreibe keine fremden Änderungen oder echten Spielstände für Tests.
- Aktualisiere betroffene Dokumentation, wenn Bedienung, Architektur oder Arbeitsbefehle sich ändern. Halte diese Datei knapp und korrigiere sie bei Änderungen der hier beschriebenen Projektstruktur.
- Berichte am Ende kurz, was geändert wurde und welche Prüfungen tatsächlich liefen. Kennzeichne nicht ausgeführte Prüfungen und verbleibende Probleme klar.

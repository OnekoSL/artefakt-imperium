# Artefakt Imperium

Spielbarer vertikaler Schnitt eines datengetriebenen Fantasy-Tycoons für **Godot 4.7.1**.

## Design-Dokumente

- [Grundkonzept](ARTEFAKT_IMPERIUM_CONCEPT.md)
- [Bewertung der zusätzlichen Ideen](docs/IDEENBEWERTUNG.md)
- [Priorisierter Ausbauplan](docs/ROADMAP.md)
- [Grundstücke und Rohstoffquellen](docs/GRUNDSTUECKE_UND_ROHSTOFFE.md)

## Start

### Direkt unter Windows

Wenn ein lokaler Windows-Build vorhanden ist, `Artefakt Imperium starten.bat` doppelklicken. Der Build liegt im Ordner `build`.

Das Repository enthält Quellcode, Spielinhalte, Tests und Dokumentation. Godot, exportierte Builds und lokale Testspielstände werden nicht mit versioniert. Nach dem Klonen Godot 4.7.1 installieren und das Projekt im Editor öffnen. Die PowerShell-Beispiele setzen die entpackte Windows-Engine im angegebenen Projekt-Unterordner voraus; bei anderer Installation `$godotExe` entsprechend anpassen.

### Im Godot-Editor

1. Godot 4.7.1 öffnen.
2. `project.godot` importieren.
3. Projekt mit `F6`/`F5` starten.

Die Simulation läuft in festen Stunden-Ticks. Pause und 1×/2×/4× befinden sich rechts oben. Der erste sinnvolle Ablauf ist:

1. Eine Grundlagenforschung starten.
2. Nach Abschluss im Bauplan-Editor ein Artefakt entwerfen.
3. Einen Bauplan einer besetzten Werkbank zuweisen, die kontinuierliche Produktion starten und die Ware am Markt anbieten.
4. Aufträge, Rivalen und die drei Siegpfade beobachten.

## Headless-Tests

```powershell
$godotExe = Join-Path (Get-Location) 'Godot_v4.7.1-stable_mono_win64/Godot_v4.7.1-stable_mono_win64_console.exe'
# Nur für diese PowerShell-Sitzung: eigene Testspielstände und keine Nutzermods.
$env:APPDATA = Join-Path (Get-Location) '.test_user\local_tests'
$env:LOCALAPPDATA = Join-Path $env:APPDATA 'local'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA | Out-Null
& $godotExe --headless --path . --import
& $godotExe --headless --path . --script tests/test_runner.gd
# Exitcode 0 und keine Parser-/Skriptfehler erwarten.
$LASTEXITCODE
```

Die Tests prüfen Contentvalidierung, deterministische Simulation, Forschung, Freischaltungen, Baupläne, Produktion, Markt, Spielstand-Roundtrip und Werkstattkollisionen. `tests/test_safety.gd` ergänzt Regressionen für beschädigte Spielstände und Mods, Wiederherstellung nach Speicherfehlern, begrenzte Nachfrage und reservierte Herstellungskosten. Projektmods unter `res://mods` werden weiterhin geladen.

Für einen gerenderten UI-Test mit Bauplanerstellung, Produktionsstart, Speichern/Laden und Sprachumschaltung in derselben isolierten Sitzung:

```powershell
& $godotExe --path . --script tests/test_ui_smoke.gd
```

Der UI-Test benötigt einen Grafikrenderer, prüft bei 1280 × 720 und schreibt sechs Kontrollbilder nach `user://ui_smoke`; die vollständigen Pfade stehen in der Ausgabe. Die Bilder anschließend auf Lesbarkeit prüfen. Die Test-PowerShell danach schließen, damit spätere normale Spielstarts wieder das übliche Benutzerverzeichnis verwenden.

## Produktionskosten und Markt

Pro begonnenem Stück werden Material und Herstellungskosten gemeinsam reserviert. Herstellungskosten ergeben sich aus Grundkörper, Effekten und Modifikatoren; vorhandenes Material wird nicht noch einmal bezahlt. Ein Lagerarbeiter kann fehlendes Material zusätzlich einkaufen. Reicht das Gold für Beschaffung und Herstellung zusammen nicht aus, beginnt das Stück nicht und der Bestand bleibt unverändert.

Pause erhält die Reservierung. Ein Produktwechsel erstattet Material und Herstellungskosten des unfertigen Stücks einmalig; gekaufte Rohstoffe bleiben dabei Rohstoffe. Nach Fertigstellung sind die Herstellungskosten verbraucht. Die Bauplananzeige trennt Herstellung und Materialwert zu aktuellen Einkaufspreisen. Der Tagesabschluss enthält Herstellungsausgaben abzüglich Erstattungen; die Prognose schätzt sie anhand des letzten Tages.

Kaufbereitschaft sinkt bei hohen Preisen weiter bis zu ausbleibenden Verkäufen. Alle Angebote teilen sich die Tagesnachfrage eines Kundensegments; der Marktanteil kann 100 % nicht überschreiten.

## Spielstände und Wiederherstellung

Speicherformat **9** lädt weiterhin gültige ältere Spielstände mit exakt passender Paket-/Versionsliste. Bereits angefangene Stücke aus älteren Versionen erhalten keine nachträglichen Herstellungskosten und keine Gold-Erstattung für zuvor unbezahlte Arbeit.

Beim Speichern wird zuerst eine temporäre Datei geschrieben und zurückgelesen. Vor dem Ersetzen bleibt die letzte geprüfte Fassung als `<slot>.json.bak` erhalten. Fehlt die Hauptdatei oder ist sie beschädigt, lädt das Spiel diese Sicherung und meldet die Wiederherstellung. Temporäre Dateien werden nicht als Spielstände geladen. Bei inkompatiblen Paketen oder Speicherformaten erfolgt kein stiller Rückgriff auf einen älteren Stand. Ein abgelehnter Ladevorgang verändert die laufende Partie nicht.

Die Speicherung ist mit Wiederherstellung abgesichert; eine atomare Dateiersetzung oder Schutz gegen beliebige Datenträgerfehler wird nicht zugesichert.

## Architektur

- `src/core/content_registry.gd`: Paket-, Mod- und Referenzvalidierung.
- `src/core/game_simulation.gd`: Godot-szenenunabhängige Tick-Simulation und Fachsysteme.
- `src/core/game_command.gd`: typisierte Eingabebefehle.
- `src/core/save_system.gd`: geprüfte Spielstanddateien mit Sicherung und Wiederherstellung.
- `src/core/save_validation.gd`, `src/core/data_schema.gd`: Struktur-, Werte- und Referenzprüfung vor Spielstandmigrationen sowie gemeinsame Datentypprüfung für Content.
- `src/ui/main.gd`: zweisprachige Managementoberfläche.
- `content/base`: Grundspiel als Datenpaket.
- `mods/example`: ausführbares Beispiel für ein reines Daten-/Asset-Mod.

## Modpakete

Mods können unter `res://mods/<paket>` oder `user://mods/<paket>` liegen. Ein Paket benötigt `manifest.json` und `data.json`. IDs müssen mit dem Paketnamespace beginnen, beispielsweise `mein_mod:neuer_effekt`. Abhängigkeiten, Priorität und ausdrücklich erlaubte Überschreibungen stehen im Manifest. GDScript aus Mods wird nicht geladen.

Der Spielstand enthält die exakte Paket- und Versionsliste. Bei einer abweichenden Modliste wird das Laden sicher verweigert.

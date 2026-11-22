# My Paint

[Português (Brasil)](../../README.md) · [English](en.md) · [Español](es.md) · [Français](fr.md) · **Deutsch** · [Italiano](it.md) · [日本語](ja.md) · [한국어](ko.md)

Ein einfacher Bildeditor für macOS nach dem Vorbild von Paint aus Windows 7. Öffne ein Bild, zeichne mit Stift, Pinseln, Formen und Text und sichere als PNG, JPEG, BMP oder GIF – mit den Tastenkürzeln, die du schon kennst.

## Download für macOS

- **[Für Apple Silicon (M-Serie) herunterladen](https://github.com/leoars/my-paint/releases/download/0.1.1/My-Paint-0.1.1-arm64.pkg)**
- **[Für Intel herunterladen](https://github.com/leoars/my-paint/releases/download/0.1.1/My-Paint-0.1.1-x86_64.pkg)**

Erfordert macOS 12 oder neuer. [Zur neuesten Version](https://github.com/leoars/my-paint/releases/latest)

![My-Paint-Fenster auf Deutsch mit dem Tab „Start“ und leerer Zeichenfläche.](../screenshots/de-window.png)

## Warum gibt es dieses Projekt?

My Paint entstand aus derselben Sehnsucht wie My Notepad. Nach dem Wechsel von Windows zum Mac fehlte uns ein Bildeditor, der nichts weiter braucht als ein Fenster, ein Menüband mit Werkzeugen und eine leere Zeichenfläche. Das Projekt holt diese Arbeitsweise mit Swift und AppKit zurück, ohne externe Abhängigkeiten. Titelleiste und Menüleiste stammen von macOS; vom Menüband abwärts folgt alles dem Paint aus Windows 7. Symbole, Texturen und Texte wurden von Grund auf neu gezeichnet und geschrieben.

## Im Alltag

- **Werkzeuge:** Stift, Radierer, Mit Farbe füllen, Farbpipette, Lupe und Text. Die linke Taste malt mit Farbe 1, die rechte mit Farbe 2.
- **Pinsel:** Pinsel, Kalligrafiepinsel 1 und 2, Airbrush, Ölpinsel, Wachsmalstift, Marker, Natürlicher Bleistift und Aquarellpinsel, jeweils mit eigenen Größen.
- **Formen:** alle 23 aus der Galerie, von Linien und Kurven bis zu Pfeilen, Sternen, Sprechblasen, Herz und Blitz. Wähle Umriss und Füllung (Volltonfarbe oder Textur), passe die Form an den Griffen an und klicke daneben, um sie festzulegen. Halte `Shift` gedrückt, um Seitenverhältnis oder Winkel beizubehalten.
- **Auswahl:** rechteckig oder als Freihandform, mit transparenter Auswahl, Bewegen, Duplizieren, Ausschneiden, Kopieren und Einsetzen zwischen Apps. Zuschneiden, Größe ändern und neigen, Drehen oder Spiegeln und Farben umkehren gelten für die Auswahl oder das ganze Bild.
- **Ansicht:** Zoom von 12,5 % bis 800 %, Lineale, Gitternetz, Vollbild, Miniatur und Statusleiste.
- **Drucken, Bildeigenschaften, Farben bearbeiten** (mit 10 eigenen Plätzen in der Palette), zuletzt verwendete Bilder und **Als Schreibtischhintergrund festlegen**.
- **Textgröße der Oberfläche** in vier Stufen für hochauflösende Displays, im Tab „Ansicht“ und unter **My Paint → Einstellungen …**.
- Verfügbar auf Portugiesisch, Englisch, Spanisch, Französisch, Deutsch, Italienisch, Japanisch und Koreanisch.

![Geöffnete Formengalerie mit allen 23 Formen.](../screenshots/shapes.jpg)

### Nützliche Tastenkürzel

Kürzel mit `Strg` (`Ctrl`) funktionieren wie unter Windows, die Entsprechungen mit `Cmd` ebenfalls.

| Tasten | Aktion |
| --- | --- |
| `Strg+Z` · `Strg+Y` | Widerrufen und Wiederholen (50 Schritte) |
| `Strg+A` · `Strg+C` · `Strg+X` · `Strg+V` | Alles auswählen, Kopieren, Ausschneiden und Einsetzen |
| `Strg+W` | Größe ändern und neigen |
| `Strg+Shift+X` · `Strg+Shift+I` | Zuschneiden und Farben umkehren |
| `Strg++` / `Strg+-` | Strichstärke erhöhen oder verringern |
| `Strg+B` · `Strg+I` · `Strg+U` | Fett, kursiv und unterstrichen im Text |
| `Strg+R` · `Strg+G` · `F11` | Lineale, Gitternetz und Vollbild |
| `Strg+E` · `Strg+P` | Bildeigenschaften und Drucken |
| `Shift+F10` | Kontextmenü |

## Auf dem Mac kompilieren und installieren

Zum Kompilieren brauchst du Apples Entwicklerwerkzeuge mit dem Swift-Compiler. Führe im Projektordner Folgendes aus:

```sh
./build.sh
open "My Paint.app"
```

So startest du die automatischen Tests:

```sh
./test.sh
```

Mit dem folgenden Befehl erzeugst du beide Installationspakete. Wähle in `dist/` das Paket `arm64` für Apple Silicon oder `x86_64` für Intel. Öffne die `.pkg`-Datei, um die App in `/Applications` zu installieren.

```sh
./package.sh
```

Das Symbol wird von `Tools/icon.swift` im Code gezeichnet; mit `swift Tools/icon.swift Resources/MyPaint.icns` erzeugst du es neu.

## Mitwirken

Werkzeuge, Menüband und Dialoge sind in [Swift](../../Sources) geschrieben, die Tests liegen in [Tests](../../Tests). Die [Übersetzungen](../../Resources) liegen in `.lproj`-Ordnern, einer pro Sprache. Nenne bei einer Fehlermeldung bitte die macOS-Version, das verwendete Werkzeug und, wenn möglich, ein kleines Bild, das den Fall reproduziert.

## Lizenz

Der ursprüngliche Code und die Dokumentation stehen unter der [Apache License 2.0](../../LICENSE). Paint, Windows und Microsoft sind Marken der Microsoft Corporation; dieses Projekt steht in keiner Verbindung zu ihr. Siehe [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md).

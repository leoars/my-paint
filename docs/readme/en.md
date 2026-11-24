# My Paint

[Português (Brasil)](../../README.md) · **English** · [Español](es.md) · [Français](fr.md) · [Deutsch](de.md) · [Italiano](it.md) · [日本語](ja.md) · [한국어](ko.md)

**My suite:** [My Explorer](https://github.com/leoars/my-explorer/blob/main/README.md) · [My Notepad](https://github.com/leoars/My-Notepad/blob/main/docs/readme/en.md) · **My Paint**

A simple image editor for macOS. Open a picture, draw with the pencil, brushes, shapes and text, and save as PNG, JPEG, BMP or GIF with the shortcuts your hands already know.

## Download for macOS

- **[Download for Apple Silicon (M-series)](https://github.com/leoars/my-paint/releases/download/1.0.1/My-Paint-1.0.1-arm64.pkg)**
- **[Download for Intel](https://github.com/leoars/my-paint/releases/download/1.0.1/My-Paint-1.0.1-x86_64.pkg)**

Requires macOS 12 or later. [View the latest release](https://github.com/leoars/my-paint/releases/latest)

To install My Explorer, My Notepad and My Paint in one go, use the [My suite installer](https://github.com/leoars/my-suite/blob/main/docs/readme/en.md).

![The My Paint window in English, with the Home tab and a blank canvas.](../screenshots/en-window.png)

## Why My Paint?

My Paint was born from the same idea as My Notepad: an image editor that asks for nothing but a window, a ribbon of tools and a blank canvas. The project delivers that way of working in Swift and AppKit, with no external dependencies. Icons, textures and text were drawn and written from scratch.

## Features

### File and formats

- **New**, **Open…**, **Save** and **Save As…**, plus **Save a copy in another format**.
- Opens and saves PNG, JPEG, BMP, GIF and TIFF. Opens pictures from the Finder.
- **Recent pictures** with up to 9 files, which can be pinned to the list.
- **Image Properties**: size, units (inches, centimeters or pixels), color or black and white, date and size on disk.
- **Set as desktop background**: fill, tile or center.

### Tools

- **Pencil**, **Eraser**, **Fill with Color**, **Color Picker**, **Magnifier** and **Text**.
- The left button paints with Color 1 and the right button with Color 2.
- **Size** sets the line width of each tool.

### Brushes

- Nine brushes: Brush, Calligraphy brushes 1 and 2, Airbrush, Oil brush, Crayon, Marker, Natural pencil and Watercolor brush, each with four sizes.

### Shapes

- All 23 shapes in the gallery: line, curve, oval, rectangle, rounded rectangle, polygon, triangles, diamond, pentagon, hexagon, arrows, four-, five- and six-point stars, callouts, heart and lightning.
- **Outline** and **Fill** in a solid color or a texture (crayon, marker, oil, natural pencil and watercolor).
- Adjust the shape with its handles before committing it. Hold `Shift` to keep the proportions or the angle.

![The shapes gallery open, showing all 23 shapes.](../screenshots/shapes.jpg)

### Colors

- **Color 1** and **Color 2**, with the 20-color palette and 10 slots for custom colors.
- **Edit Colors**: 48 basic colors, 16 custom colors, and adjustment by hue, saturation and luminosity or by red, green and blue.
- In black-and-white mode, the palette and the drawing use only the two colors.

### Selection and clipboard

- **Rectangular selection** and **Free-form selection**, **Select all**, **Invert selection** and **Transparent selection**.
- Move, duplicate (by dragging with `Ctrl`), stretch with the handles or nudge one pixel at a time with the arrow keys.
- **Cut**, **Copy** and **Paste** between apps, and **Paste From…** to bring in a file.

### Image

- **Crop** to the selection.
- **Resize and Skew** by percentage or pixels, with or without keeping the aspect ratio.
- **Rotate** right or left 90° and 180°; **Flip** vertical or horizontal.
- **Invert color**.
- These apply to the selection or to the whole picture. The canvas can also be resized with its handles.

### Text

- **Text Tools** tab with font family and size, bold, italic, underline and strikethrough.
- Opaque or transparent background.
- Works with the Japanese and Korean input methods.

### View

- Zoom from 12.5% to 800%, from the keyboard or with the slider in the status bar.
- **Rulers**, **Gridlines**, **Status bar**, **Full screen** and **Thumbnail**.
- **Interface Text Size** in four levels for high-resolution displays, on the View tab and in **My Paint → Settings…**.

### Print

- **Print…**, **Page Setup…** (fit to a number of pages and center) and **Print Preview**.

### Interface and languages

- Menus inside the window, above the ribbon, in addition to the macOS menu bar.
- A ribbon with the **Home** and **View** tabs, which can be minimized, and a quick access toolbar with Save, Undo and Redo.
- Undo and redo with 50 levels.
- Available in Portuguese, English, Spanish, French, German, Italian, Japanese and Korean.
- **Check for Updates…** in the My Paint menu, and a check when the app opens, at most once a day, which you can turn off in **Settings…**. A new version is downloaded only when you agree, is checked (the developer's signature and Apple's notarization) and opens in the macOS Installer; My Paint opens again when the Installer closes.

### Keyboard shortcuts

Shortcuts with `Ctrl` work the way you already know; the `Cmd` equivalents work too.

| Keys | Action |
| --- | --- |
| `Ctrl+N` · `Ctrl+O` · `Ctrl+S` · `F12` | New, open, save and save as |
| `Ctrl+Z` · `Ctrl+Y` | Undo and redo (50 levels) |
| `Ctrl+A` · `Ctrl+C` · `Ctrl+X` · `Ctrl+V` | Select all, copy, cut and paste |
| `Ctrl+W` | Resize and Skew |
| `Ctrl+Shift+X` · `Ctrl+Shift+I` | Crop and invert color |
| `Ctrl++` / `Ctrl+-` | Increase or decrease the line width |
| `Ctrl+Page Up` / `Ctrl+Page Down` | Zoom in or out |
| `Ctrl+B` · `Ctrl+I` · `Ctrl+U` | Bold, italic and underline in text |
| `Ctrl+R` · `Ctrl+G` · `F11` | Rulers, gridlines and full screen |
| `Ctrl+E` · `Ctrl+P` | Image properties and print |
| `Ctrl+F1` | Minimize the ribbon |
| `Shift+F10` | Context menu |
| `Esc` · `Enter` · `Delete` | Cancel the action, commit the shape and delete the selection |

## Part of the My suite

My Paint is part of the My suite: three simple, straightforward apps for macOS, with the menus and shortcuts you already know.

- **My Paint** (this repository): a simple image editor.
- **[My Explorer](https://github.com/leoars/my-explorer/blob/main/README.md)**: a file manager with a folder tree, tabs and a command bar. With My Paint installed, the My Explorer context menu gains **Edit with My Paint** for pictures.
- **[My Notepad](https://github.com/leoars/My-Notepad/blob/main/docs/readme/en.md)**: a simple text editor.

## Build and install on Mac

To build on your Mac, you need Apple’s developer tools with the Swift compiler. From the project root, run:

```sh
./build.sh
open "My Paint.app"
```

To run the automated tests:

```sh
./test.sh
```

To build both installers, run the command below. In `dist/`, choose the `arm64` package for Apple Silicon or `x86_64` for Intel. Open the `.pkg` to install the app in `/Applications`.

```sh
./package.sh
```

The icon is drawn in code by `Tools/icon.swift`; to regenerate it, run `swift Tools/icon.swift Resources/MyPaint.icns`.

## Contributing

The tools, the ribbon and the dialogs are written in [Swift](../../Sources), with the tests in [Tests](../../Tests). The [translations](../../Resources) live in one `.lproj` directory per language. When reporting a problem, include your macOS version, the tool you were using and, if possible, a small picture that reproduces it.

## License

Original code and documentation are distributed under the [Apache License 2.0](../../LICENSE). See [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md).

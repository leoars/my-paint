# My Paint

[Português (Brasil)](../../README.md) · [English](en.md) · **Español** · [Français](fr.md) · [Deutsch](de.md) · [Italiano](it.md) · [日本語](ja.md) · [한국어](ko.md)

Un editor de imágenes sencillo para macOS inspirado en el Paint de Windows 7. Abre una imagen, dibuja con el lápiz, los pinceles, las formas y el texto, y guarda en PNG, JPEG, BMP o GIF con los atajos que ya conoces.

## Descargar para macOS

- **[Descargar para Apple Silicon (serie M)](https://github.com/leoars/my-paint/releases/download/0.1.0/My-Paint-0.1.0-arm64.pkg)**
- **[Descargar para Intel](https://github.com/leoars/my-paint/releases/download/0.1.0/My-Paint-0.1.0-x86_64.pkg)**

Requiere macOS 12 o posterior. [Ver la última versión](https://github.com/leoars/my-paint/releases/latest)

![Ventana de My Paint en español, con la pestaña Inicio y el lienzo en blanco.](../screenshots/es-window.png)

## ¿Por qué existe este proyecto?

My Paint nace de la misma nostalgia que dio origen a My Notepad. Al pasar de Windows al Mac, echábamos de menos un editor de imágenes que solo pide una ventana, una cinta de herramientas y un lienzo en blanco. El proyecto recupera esa forma de trabajar en Swift y AppKit, sin dependencias externas. La barra de título y la barra de menús son de macOS; de la cinta de opciones hacia abajo, todo sigue el Paint de Windows 7. Los iconos, las texturas y los textos se dibujaron y escribieron desde cero.

## En el día a día

- **Herramientas:** Lápiz, Borrador, Rellenar con color, Selector de color, Lupa y Texto. El botón izquierdo pinta con Color 1 y el derecho con Color 2.
- **Pinceles:** Pincel, Pinceles caligráficos 1 y 2, Aerógrafo, Pincel de óleo, Crayón, Marcador, Lápiz natural y Pincel de acuarela, cada uno con sus tamaños.
- **Formas:** las 23 de la galería, desde líneas y curvas hasta flechas, estrellas, globos, un corazón y un rayo. Elige Contorno y Relleno (color sólido o textura), ajusta con los controladores y haz clic fuera para fijar. Mantén pulsada `Shift` para conservar la proporción o el ángulo.
- **Selección:** rectangular o de forma libre, con selección transparente, mover, duplicar, cortar, copiar y pegar entre aplicaciones. Recortar, Cambiar tamaño e inclinar, Girar o voltear e Invertir colores se aplican a la selección o a toda la imagen.
- **Vista:** zoom del 12,5 % al 800 %, reglas, cuadrícula, pantalla completa, miniatura y barra de estado.
- **Imprimir, Propiedades de la imagen, Editar colores** (con 10 posiciones personalizadas en la paleta), imágenes recientes y **Establecer como fondo de escritorio**.
- **Tamaño del texto de la interfaz** en cuatro niveles, para pantallas de alta resolución, en la pestaña Vista y en **My Paint → Ajustes…**.
- Disponible en portugués, inglés, español, francés, alemán, italiano, japonés y coreano.

![Galería de formas abierta con las 23 formas.](../screenshots/shapes.jpg)

### Atajos que conviene conocer

Los atajos con `Ctrl` funcionan como en Windows; los equivalentes con `Cmd`, también.

| Teclas | Acción |
| --- | --- |
| `Ctrl+Z` · `Ctrl+Y` | Deshacer y rehacer (50 niveles) |
| `Ctrl+A` · `Ctrl+C` · `Ctrl+X` · `Ctrl+V` | Seleccionar todo, copiar, cortar y pegar |
| `Ctrl+W` | Cambiar tamaño e inclinar |
| `Ctrl+Shift+X` · `Ctrl+Shift+I` | Recortar e invertir colores |
| `Ctrl++` / `Ctrl+-` | Aumentar o reducir el grosor |
| `Ctrl+B` · `Ctrl+I` · `Ctrl+U` | Negrita, cursiva y subrayado en el texto |
| `Ctrl+R` · `Ctrl+G` · `F11` | Reglas, cuadrícula y pantalla completa |
| `Ctrl+E` · `Ctrl+P` | Propiedades de la imagen e imprimir |
| `Shift+F10` | Menú contextual |

## Compilar e instalar en el Mac

Para compilar, usa las herramientas de desarrollo de Apple con el compilador de Swift. En la raíz del proyecto, ejecuta:

```sh
./build.sh
open "My Paint.app"
```

Para ejecutar las pruebas automáticas:

```sh
./test.sh
```

Para generar los dos instaladores, ejecuta el comando siguiente. En `dist/`, elige el paquete `arm64` para Apple Silicon o `x86_64` para Intel. Abre el archivo `.pkg` para instalar la aplicación en `/Applications`.

```sh
./package.sh
```

El icono se dibuja por código en `Tools/icon.swift`; para generarlo de nuevo, ejecuta `swift Tools/icon.swift Resources/MyPaint.icns`.

## Cómo contribuir

Las herramientas, la cinta de opciones y los cuadros de diálogo están en [Swift](../../Sources), y las pruebas en [Tests](../../Tests). Las [traducciones](../../Resources) están en carpetas `.lproj`, una por idioma. Al informar de un problema, incluye la versión de macOS, la herramienta que usabas y, si es posible, una imagen pequeña que lo reproduzca.

## Licencia

El código y la documentación originales se distribuyen bajo la [Apache License 2.0](../../LICENSE). Paint, Windows y Microsoft son marcas de Microsoft Corporation; este proyecto no tiene relación con ella. Consulta [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md).

# My Paint

[Português (Brasil)](../../README.md) · [English](en.md) · [Español](es.md) · [Français](fr.md) · [Deutsch](de.md) · **Italiano** · [日本語](ja.md) · [한국어](ko.md)

**Suite My:** [My Explorer](https://github.com/leoars/my-explorer/blob/main/README.it.md) · [My Notepad](https://github.com/leoars/My-Notepad/blob/main/docs/readme/it.md) · **My Paint**

Un semplice editor di immagini per macOS. Apri un’immagine, disegna con matita, pennelli, forme e testo e salva in PNG, JPEG, BMP o GIF con le scorciatoie che conosci già.

## Scarica per macOS

- **[Scarica per Apple Silicon (serie M)](https://github.com/leoars/my-paint/releases/download/1.0/My-Paint-1.0-arm64.pkg)**
- **[Scarica per Intel](https://github.com/leoars/my-paint/releases/download/1.0/My-Paint-1.0-x86_64.pkg)**

Richiede macOS 12 o successivo. [Vedi la versione più recente](https://github.com/leoars/my-paint/releases/latest)

![Finestra di My Paint in italiano, con la scheda Home e l’area di disegno vuota.](../screenshots/it-window.png)

## Perché esiste questo progetto?

My Paint nasce dalla stessa idea di My Notepad: un editor di immagini che non chiede altro che una finestra, una barra multifunzione di strumenti e un’area di disegno vuota. Il progetto offre quel modo di lavorare in Swift e AppKit, senza dipendenze esterne. Icone, texture e testi sono stati disegnati e scritti da zero.

## Funzionalità

### File e formati

- **Nuovo**, **Apri…**, **Salva** e **Salva con nome…**, con **Salva una copia in un altro formato**.
- Apre e salva PNG, JPEG, BMP, GIF e TIFF. Apre le immagini dal Finder.
- **Immagini recenti** con un massimo di 9 file, che si possono fissare nell’elenco.
- **Proprietà immagine**: dimensioni, unità (pollici, centimetri o pixel), colore o bianco e nero, data e dimensioni su disco.
- **Imposta come sfondo della scrivania**: riempi, affianca o centra.

### Strumenti

- **Matita**, **Gomma**, **Riempi con colore**, **Selettore colore**, **Lente** e **Testo**.
- Il pulsante sinistro dipinge con Colore 1 e il destro con Colore 2.
- **Dimensioni** imposta lo spessore di ogni strumento.

### Pennelli

- Nove pennelli: Pennello, Pennelli calligrafici 1 e 2, Aerografo, Pennello a olio, Pastello a cera, Evidenziatore, Matita naturale e Pennello ad acquerello, ciascuno in quattro dimensioni.

### Forme

- Le 23 forme della galleria: linea, curva, ovale, rettangolo, rettangolo arrotondato, poligono, triangoli, rombo, pentagono, esagono, frecce, stelle a quattro, cinque e sei punte, fumetti, cuore e fulmine.
- **Contorno** e **Riempimento** a colore pieno o con texture (pastello a cera, evidenziatore, olio, matita naturale e acquerello).
- Regola la forma con le maniglie prima di confermarla. Tieni premuto `Shift` per mantenere le proporzioni o l’angolo.

![Galleria delle forme aperta, con tutte le 23 forme.](../screenshots/shapes.jpg)

### Colori

- **Colore 1** e **Colore 2**, con la tavolozza di 20 colori e 10 posizioni per i colori personalizzati.
- **Modifica colori**: 48 colori di base, 16 personalizzati e regolazione per tonalità, saturazione e luminosità oppure per rosso, verde e blu.
- In modalità bianco e nero, la tavolozza e il disegno usano solo i due colori.

### Selezione e appunti

- **Selezione rettangolare** e **Selezione a mano libera**, **Seleziona tutto**, **Inverti selezione** e **Selezione trasparente**.
- Sposta, duplica (trascinando con `Ctrl`), allunga con le maniglie o sposta di un pixel alla volta con le frecce.
- **Taglia**, **Copia** e **Incolla** tra le app, e **Incolla da…** per inserire un file.

### Immagine

- **Ritaglia** sulla selezione.
- **Ridimensiona e inclina** in percentuale o in pixel, mantenendo o meno le proporzioni.
- **Ruota** di 90° a destra o a sinistra e di 180°; **Capovolgi** verticalmente o orizzontalmente.
- **Inverti colori**.
- Valgono per la selezione o per l’intera immagine. Anche l’area di disegno si ridimensiona con le maniglie.

### Testo

- Scheda **Strumenti testo** con tipo e dimensione del carattere, grassetto, corsivo, sottolineato e barrato.
- Sfondo opaco o trasparente.
- Supporta i metodi di input del giapponese e del coreano.

### Visualizza

- Zoom dal 12,5% all’800%, da tastiera o con il cursore nella barra di stato.
- **Righelli**, **Griglia**, **Barra di stato**, **Schermo intero** e **Miniatura**.
- **Dimensione testo dell’interfaccia** su quattro livelli, per i monitor ad alta risoluzione, nella scheda Visualizza e in **My Paint → Impostazioni…**.

### Stampa

- **Stampa…**, **Formato di stampa…** (adatta a un numero di pagine e centra) e **Anteprima di stampa**.

### Interfaccia e lingue

- Menu nella finestra, sopra la barra multifunzione, oltre alla barra dei menu di macOS.
- Barra multifunzione con le schede **Home** e **Visualizza**, che si può ridurre a icona, e barra di accesso rapido con Salva, Annulla e Ripeti.
- Annulla e ripeti con 50 livelli.
- Disponibile in portoghese, inglese, spagnolo, francese, tedesco, italiano, giapponese e coreano.

### Scorciatoie

Le scorciatoie con `Ctrl` funzionano come le conosci già; anche gli equivalenti con `Cmd`.

| Tasti | Azione |
| --- | --- |
| `Ctrl+N` · `Ctrl+O` · `Ctrl+S` · `F12` | Nuovo, apri, salva e salva con nome |
| `Ctrl+Z` · `Ctrl+Y` | Annulla e ripeti (50 livelli) |
| `Ctrl+A` · `Ctrl+C` · `Ctrl+X` · `Ctrl+V` | Seleziona tutto, copia, taglia e incolla |
| `Ctrl+W` | Ridimensiona e inclina |
| `Ctrl+Shift+X` · `Ctrl+Shift+I` | Ritaglia e inverti colori |
| `Ctrl++` / `Ctrl+-` | Aumenta o riduci lo spessore |
| `Ctrl+Page Up` / `Ctrl+Page Down` | Ingrandisci o riduci lo zoom |
| `Ctrl+B` · `Ctrl+I` · `Ctrl+U` | Grassetto, corsivo e sottolineato nel testo |
| `Ctrl+R` · `Ctrl+G` · `F11` | Righelli, griglia e schermo intero |
| `Ctrl+E` · `Ctrl+P` | Proprietà immagine e stampa |
| `Ctrl+F1` | Riduci a icona la barra multifunzione |
| `Shift+F10` | Menu contestuale |
| `Esc` · `Enter` · `Delete` | Annulla l’azione, conferma la forma ed elimina la selezione |

## Parte della suite My

My Paint fa parte della suite My: tre app per macOS semplici e dirette, con i menu e le scorciatoie di sempre.

- **My Paint** (questo repository): un semplice editor di immagini.
- **[My Explorer](https://github.com/leoars/my-explorer/blob/main/README.it.md)**: gestore di file con albero delle cartelle, schede e barra dei comandi. Con My Paint installato, il menu contestuale di My Explorer offre **Modifica con My Paint** per le immagini.
- **[My Notepad](https://github.com/leoars/My-Notepad/blob/main/docs/readme/it.md)**: un semplice editor di testo.

## Compilare e installare sul Mac

Per compilare, usa gli strumenti di sviluppo di Apple con il compilatore Swift. Nella cartella principale del progetto, esegui:

```sh
./build.sh
open "My Paint.app"
```

Per eseguire i test automatici:

```sh
./test.sh
```

Per generare i due programmi di installazione, esegui il comando qui sotto. In `dist/`, scegli il pacchetto `arm64` per Apple Silicon o `x86_64` per Intel. Apri il file `.pkg` per installare l’app in `/Applications`.

```sh
./package.sh
```

L’icona è disegnata dal codice di `Tools/icon.swift`; per rigenerarla, esegui `swift Tools/icon.swift Resources/MyPaint.icns`.

## Come contribuire

Gli strumenti, la barra multifunzione e le finestre di dialogo sono scritti in [Swift](../../Sources), e i test si trovano in [Tests](../../Tests). Le [traduzioni](../../Resources) sono in cartelle `.lproj`, una per lingua. Quando segnali un problema, indica la versione di macOS, lo strumento usato e, se possibile, una piccola immagine che lo riproduca.

## Licenza

Il codice e la documentazione originali sono distribuiti con la [Apache License 2.0](../../LICENSE). Vedi [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md).

# My Paint

**Português (Brasil)** · [English](docs/readme/en.md) · [Español](docs/readme/es.md) · [Français](docs/readme/fr.md) · [Deutsch](docs/readme/de.md) · [Italiano](docs/readme/it.md) · [日本語](docs/readme/ja.md) · [한국어](docs/readme/ko.md)

**Suíte My:** [My Explorer](https://github.com/leoars/my-explorer/blob/main/README.pt-BR.md) · [My Notepad](https://github.com/leoars/My-Notepad) · **My Paint** · [My Calc](https://github.com/leoars/my-calc)

Um editor de imagens simples para macOS. Abra uma imagem, desenhe com lápis, pincéis, formas e texto, e salve em PNG, JPEG, BMP ou GIF com os atalhos que suas mãos já conhecem.

## Baixar para macOS

- **[Baixar para Apple Silicon (série M)](https://github.com/leoars/my-paint/releases/download/1.0.2/My-Paint-1.0.2-arm64.pkg)**
- **[Baixar para Intel](https://github.com/leoars/my-paint/releases/download/1.0.2/My-Paint-1.0.2-x86_64.pkg)**

Requer macOS 12 ou posterior. [Ver a versão mais recente](https://github.com/leoars/my-paint/releases/latest)

Para instalar o My Explorer, o My Notepad, o My Paint e o My Calc de uma vez, use o [instalador da suíte My](https://github.com/leoars/my-suite).

![Janela do My Paint em português, com a guia Início e a tela em branco.](docs/screenshots/pt-BR-window.png)

## Por que este projeto existe?

O My Paint nasceu da mesma ideia do My Notepad: um editor de imagens que não pede nada além de uma janela, uma faixa de ferramentas e a tela em branco. O projeto entrega esse jeito de trabalhar em Swift e AppKit, sem dependências externas. Ícones, texturas e textos foram desenhados e escritos do zero.

## Funcionalidades

### Arquivo e formatos

- **Novo**, **Abrir…**, **Salvar** e **Salvar como…**, com **Salvar uma cópia em outro formato**.
- Abre e salva PNG, JPEG, BMP, GIF e TIFF. Abre imagens pelo Finder.
- **Imagens recentes** com até 9 arquivos, que podem ser fixados na lista.
- **Propriedades da imagem**: tamanho, unidades (polegadas, centímetros ou pixels), cores ou preto e branco, data e tamanho em disco.
- **Definir como plano de fundo da área de trabalho**: preencher, lado a lado ou centralizar.

### Ferramentas

- **Lápis**, **Borracha**, **Preencher com cor**, **Selecionador de cor**, **Lupa** e **Texto**.
- O botão esquerdo pinta com a Cor 1 e o direito com a Cor 2.
- **Tamanho** define a espessura de cada ferramenta.

### Pincéis

- Nove pincéis: pincel, caligráficos 1 e 2, spray, óleo, giz de cera, marcador, lápis natural e aquarela, cada um com quatro tamanhos.

### Formas

- As 23 formas da galeria: linha, curva, oval, retângulo, retângulo arredondado, polígono, triângulos, losango, pentágono, hexágono, setas, estrelas de 4, 5 e 6 pontas, balões, coração e raio.
- **Contorno** e **Preenchimento** em cor sólida ou em textura (giz de cera, marcador, óleo, lápis natural e aquarela).
- Ajuste a forma pelas alças antes de fixá-la. Segure `Shift` para manter a proporção ou o ângulo.

![Galeria de formas aberta com as 23 formas.](docs/screenshots/shapes.jpg)

### Cores

- **Cor 1** e **Cor 2**, com a paleta de 20 cores e 10 posições para cores personalizadas.
- **Editar cores**: 48 cores básicas, 16 personalizadas e ajuste por matiz, saturação e luminosidade ou por vermelho, verde e azul.
- No modo preto e branco, a paleta e o desenho usam só as duas cores.

### Seleção e área de transferência

- **Seleção retangular** e **de forma livre**, **Selecionar tudo**, **Inverter seleção** e **Seleção transparente**.
- Mova, duplique (arrastando com `Ctrl`), estique pelas alças ou desloque um pixel por vez com as setas.
- **Recortar**, **Copiar** e **Colar** entre aplicativos, e **Colar de…** para trazer um arquivo.

### Imagem

- **Cortar** na seleção.
- **Redimensionar e inclinar** por porcentagem ou pixels, mantendo ou não a proporção.
- **Girar** 90° para a direita ou para a esquerda e 180°; **Inverter** na vertical ou na horizontal.
- **Inverter cor**.
- Valem para a seleção ou para a imagem inteira. A tela também pode ser redimensionada pelas alças.

### Texto

- Guia **Ferramentas de Texto** com família e tamanho da fonte, negrito, itálico, sublinhado e tachado.
- Fundo opaco ou transparente.
- Aceita os métodos de entrada do japonês e do coreano.

### Exibir

- Zoom de 12,5% a 800%, pelo teclado ou pelo controle na barra de status.
- **Réguas**, **Linhas de grade**, **Barra de status**, **Tela inteira** e **Miniatura**.
- **Tamanho do texto da interface** em quatro níveis, para monitores de resolução alta, na guia Exibir e em **My Paint → Ajustes…**.

### Imprimir

- **Imprimir…**, **Configurar página…** (ajustar a um número de páginas e centralizar) e **Visualizar impressão**.

### Interface e idiomas

- Menus dentro da janela, acima da faixa de opções, além da barra de menus do macOS.
- Faixa de opções com as guias **Início** e **Exibir**, que pode ser minimizada, e barra de acesso rápido com Salvar, Desfazer e Refazer.
- Desfazer e refazer com 50 níveis.
- Disponível em português, inglês, espanhol, francês, alemão, italiano, japonês e coreano.
- **Verificar atualizações…** no menu My Paint, e uma verificação ao abrir, no máximo uma vez por dia, que pode ser desligada em **Ajustes…**. A versão nova só é baixada com a sua confirmação, é conferida (assinatura do desenvolvedor e notarização da Apple) e abre no Instalador do macOS; o My Paint reabre quando o Instalador termina.

### Atalhos

Os atalhos com `Ctrl` funcionam como você já conhece; os equivalentes com `Cmd` também.

| Teclas | Ação |
| --- | --- |
| `Ctrl+N` · `Ctrl+O` · `Ctrl+S` · `F12` | Novo, abrir, salvar e salvar como |
| `Ctrl+Z` · `Ctrl+Y` | Desfazer e refazer (50 níveis) |
| `Ctrl+A` · `Ctrl+C` · `Ctrl+X` · `Ctrl+V` | Selecionar tudo, copiar, recortar e colar |
| `Ctrl+W` | Redimensionar e inclinar |
| `Ctrl+Shift+X` · `Ctrl+Shift+I` | Cortar e inverter cor |
| `Ctrl++` / `Ctrl+-` | Aumentar ou diminuir a espessura |
| `Ctrl+Page Up` / `Ctrl+Page Down` | Ampliar ou reduzir o zoom |
| `Ctrl+B` · `Ctrl+I` · `Ctrl+U` | Negrito, itálico e sublinhado no texto |
| `Ctrl+R` · `Ctrl+G` · `F11` | Réguas, linhas de grade e tela inteira |
| `Ctrl+E` · `Ctrl+P` | Propriedades da imagem e imprimir |
| `Ctrl+F1` | Minimizar a faixa de opções |
| `Shift+F10` | Menu de contexto |
| `Esc` · `Enter` · `Delete` | Cancelar a ação, fixar a forma e excluir a seleção |

## Parte da suíte My

O My Paint faz parte da suíte My: quatro aplicativos para macOS simples e diretos, com os menus e os atalhos de sempre.

- **My Paint** (este repositório): editor de imagens simples.
- **[My Explorer](https://github.com/leoars/my-explorer/blob/main/README.pt-BR.md)**: gerenciador de arquivos com árvore de pastas, abas e barra de comandos. Com o My Paint instalado, o menu de contexto do My Explorer ganha **Editar com o My Paint** para as imagens.
- **[My Notepad](https://github.com/leoars/My-Notepad)**: editor de texto simples.
- **[My Calc](https://github.com/leoars/my-calc)**: calculadora simples.
- **[My Suite](https://github.com/leoars/my-suite)**: o instalador que reúne os quatro aplicativos, com a escolha de quais instalar.

## Compilar e instalar no Mac

Para compilar, use as ferramentas de desenvolvimento da Apple com o compilador Swift. Na raiz do projeto, execute:

```sh
./build.sh
open "My Paint.app"
```

Para rodar os testes automáticos:

```sh
./test.sh
```

Para gerar os dois instaladores, execute o comando abaixo. Em `dist/`, escolha o pacote `arm64` para Apple Silicon ou `x86_64` para Intel. Abra o arquivo `.pkg` para instalar o aplicativo em `/Applications`.

```sh
./package.sh
```

O ícone é desenhado em código por `Tools/icon.swift`; para gerá-lo de novo, execute `swift Tools/icon.swift Resources/MyPaint.icns`.

## Como contribuir

As ferramentas, a faixa de opções e os diálogos ficam em [Swift](Sources), e os testes em [Tests](Tests). As [traduções](Resources) estão em pastas `.lproj`, uma por idioma. Ao relatar um problema, inclua a versão do macOS, a ferramenta usada e, se possível, uma imagem curta que reproduza o caso.

## Licença

O código e a documentação originais são distribuídos sob a [Apache License 2.0](LICENSE). Veja [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

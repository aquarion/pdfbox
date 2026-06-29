# aquarion/pdfbox

A Docker image for [Apache PDFBox](https://pdfbox.apache.org/) with full image codec support.

The latest PDFBox 3.x release is fetched from Apache at build time. The following optional image codecs are bundled so that PDFs containing JBIG2, JPEG2000, or specialised JPEG images are handled correctly:

- [jbig2-imageio](https://github.com/levigo/jbig2-imageio) — JBIG2 support
- [jai-imageio-core](https://github.com/jai-imageio/jai-imageio-core) — JAI ImageIO core
- [jai-imageio-jpeg2000](https://github.com/jai-imageio/jai-imageio-jpeg2000) — JPEG2000 support
- [TwelveMonkeys imageio-jpeg](https://github.com/haraldk/TwelveMonkeys) — extended JPEG support

## Usage

Mount your working directory to `/home` and pass PDFBox commands and arguments as normal.

```sh
docker run --rm -v "$(pwd):/home" aquarion/pdfbox <command> [options]
```

### Examples

See https://pdfbox.apache.org/3.0/commandline.html for the full reference

Extract images from a PDF:

```sh
docker run --rm -v "$(pwd):/home" aquarion/pdfbox export:images --input=document.pdf
```

Convert a PDF to text:

```sh
docker run --rm -v "$(pwd):/home" aquarion/pdfbox export:text --input=document.pdf
```

Render pages as images:

```sh
docker run --rm -v "$(pwd):/home" aquarion/pdfbox render --input=document.pdf
```

Print available commands:

```sh
docker run --rm aquarion/pdfbox --help
```

## Image verification

The PDFBox jar is verified against its SHA-512 checksum and PGP signature from the canonical Apache download server before being included in the image.

## Codec dependency versions

jbig2-imageio and the JAI ImageIO jars aren't fetched as "whatever is latest" — they're resolved by a small Maven build stage (see `bin/codecs-pom.xml.tmpl`) that inherits from PDFBox's own `pdfbox-parent` POM, picking up the exact `jbig2-imageio`/`jai-imageio` versions that the resolved PDFBox release was built and tested against.

TwelveMonkeys isn't a PDFBox dependency, so there's no upstream version to track — its version is pinned manually in the same template and bumped deliberately.

## Future

* Specifying a PDFBox version (currently always the latest 3.x release)
* Options for additional JARs to include
* IDK. Patches welcome. 
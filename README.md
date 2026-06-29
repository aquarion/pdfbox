# aquarion/pdfbox

A Docker image for [Apache PDFBox](https://pdfbox.apache.org/) with full image codec support.

The latest PDFBox 3.x release is fetched from Apache at build time. The following optional image codecs are bundled so that PDFs containing JBIG2 or specialised JPEG images are handled correctly:

- [jbig2-imageio](https://github.com/levigo/jbig2-imageio) — JBIG2 support
- [TwelveMonkeys imageio-jpeg](https://github.com/haraldk/TwelveMonkeys) — extended JPEG support
- [TwelveMonkeys imageio-tiff](https://github.com/haraldk/TwelveMonkeys) — TIFF support
- [TwelveMonkeys imageio-webp](https://github.com/haraldk/TwelveMonkeys) — WebP support

JPEG2000 support is not currently included due to a revoked signing key on the last jai-imageio release. See [issue #2](https://github.com/aquarion/pdfbox/issues/2).

## Usage

Mount your working directory to `/opt/pdfbox/data` and pass PDFBox commands and arguments as normal.

```sh
docker run --rm -v "$(pwd):/opt/pdfbox/data" aquarion/pdfbox <command> [options]
```

### Examples

See https://pdfbox.apache.org/3.0/commandline.html for the full reference

Extract images from a PDF:

```sh
docker run --rm -v "$(pwd):/opt/pdfbox/data" aquarion/pdfbox export:images --input=document.pdf
```

Convert a PDF to text:

```sh
docker run --rm -v "$(pwd):/opt/pdfbox/data" aquarion/pdfbox export:text --input=document.pdf
```

Render pages as images:

```sh
docker run --rm -v "$(pwd):/opt/pdfbox/data" aquarion/pdfbox render --input=document.pdf
```

Print available commands:

```sh
docker run --rm aquarion/pdfbox --help
```

## Building

### File permissions

The container runs as a non-root user with UID 1000. On single-user Linux systems this typically matches the host user, avoiding volume permission issues. If your UID differs, override it at build time:

```sh
docker build --build-arg PDFBOX_UID=$(id -u) -t aquarion/pdfbox .
```

### Pinning a PDFBox version

By default the image builds the latest PDFBox 3.x release. To pin an exact version instead:

```sh
docker build --build-arg PDFBOX_VERSION=3.0.7 -t aquarion/pdfbox .
```

Pinned versions are fetched from `archive.apache.org`, which retains every release indefinitely, rather than `dlcdn.apache.org`/`downloads.apache.org`, which only mirror the current release. The codec jars still resolve correctly against a pinned version, since the codecs stage inherits whatever version is resolved here.

## Image verification

The PDFBox jar is verified against its SHA-512 checksum and PGP signature from the canonical Apache download server.

The codec jars (jbig2-imageio, JAI ImageIO, TwelveMonkeys) are resolved by Maven rather than hand-fetched (see below), and are PGP-verified once resolved: jbig2-imageio against the canonical PDFBox KEYS file, and the jai-imageio/TwelveMonkeys jars against pinned fingerprints fetched from `keyserver.ubuntu.com` (falling back to `keys.openpgp.org`/`pgp.mit.edu`).

## Codec dependency versions

jbig2-imageio and the JAI ImageIO jars aren't fetched as "whatever is latest" — they're resolved by a small Maven build stage (see `bin/codecs-pom.xml.tmpl`) that inherits from PDFBox's own `pdfbox-parent` POM, picking up the exact `jbig2-imageio`/`jai-imageio` versions that the resolved PDFBox release was built and tested against. Maven also pulls in the correct transitive dependencies (e.g. TwelveMonkeys' `imageio-metadata`), which the old hand-fetch list silently missed.

TwelveMonkeys isn't a PDFBox dependency, so there's no upstream version to track — its version is pinned manually in the same template and bumped deliberately.

## Future

* Options for additional JARs to include
* IDK. Patches welcome.

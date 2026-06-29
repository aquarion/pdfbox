# aquarion/pdfbox

A Docker image for [Apache PDFBox](https://pdfbox.apache.org/) with full image codec support.

The latest PDFBox 3.x release is fetched from Apache at build time. The following optional image codecs are bundled:

- [jbig2-imageio](https://github.com/levigo/jbig2-imageio) — JBIG2 support
- [TwelveMonkeys imageio-jpeg](https://github.com/haraldk/TwelveMonkeys) — extended JPEG support
- [TwelveMonkeys imageio-tiff](https://github.com/haraldk/TwelveMonkeys) — TIFF support
- [TwelveMonkeys imageio-webp](https://github.com/haraldk/TwelveMonkeys) — WebP support

A separate `-jpeg2000` variant adds JPEG2000 (JP2/JPX) support via [jai-imageio](https://github.com/jai-imageio). See [JPEG2000 variant](#jpeg2000-variant) below.

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

## JPEG2000 variant

Images tagged with `-jpeg2000` (e.g. `latest-jpeg2000`, `3.0.7-jpeg2000`) include two additional codecs:

- [jai-imageio-core](https://github.com/jai-imageio/jai-imageio-core) — base ImageIO framework
- [jai-imageio-jpeg2000](https://github.com/jai-imageio/jai-imageio-jpeg2000) — JPEG2000 (JP2/JPX) support

```sh
docker run --rm -v "$(pwd):/opt/pdfbox/data" ghcr.io/aquarion/pdfbox:latest-jpeg2000 <command> [options]
```

These jars are verified by pinned SHA-256 hashes rather than PGP signature — the signing subkey was revoked by the author after publication and no newer release exists. The hashes were derived from the canonical Maven Central jars at the time of pinning; verification is against the locally-pinned values in this repository. See [issue #2](https://github.com/aquarion/pdfbox/issues/2).

## Published images

Images are published to:

- **GitHub Container Registry**: `ghcr.io/<owner>/<repo>` (mirrors the GitHub repository name) — on every tag push, weekly schedule, and manual dispatch
- **Docker Hub**: `<DOCKERHUB_USERNAME>/<repo>` — when `DOCKERHUB_TOKEN` is configured (see below)

Each publish run builds both the standard and `-jpeg2000` variant; see [JPEG2000 variant](#jpeg2000-variant) for details on the suffixed tags.

Tags applied depend on the trigger:

- **Tag push** (`v*`): semver-derived tags only (`1.2.3`, `1.2`, `1`)
- **Weekly schedule or manual dispatch**: `latest` and the current PDFBox release version tags (`3.0.7`, `3.0`, `3`)

Docker Hub publishing is **opt-in**: if the `DOCKERHUB_TOKEN` secret is absent the workflow skips Docker Hub and only pushes to GHCR. Forks work out of the box without any Docker Hub credentials. If `DOCKERHUB_TOKEN` is set but `DOCKERHUB_USERNAME` is not, the workflow fails with a clear error rather than pushing to a malformed image path.

To enable Docker Hub publishing, add these to the repo's Actions configuration:

| Type | Name | Value |
|------|------|-------|
| Variable | `DOCKERHUB_USERNAME` | Your Docker Hub username |
| Secret | `DOCKERHUB_TOKEN` | A Docker Hub access token with read/write scope |

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

The codec jars (jbig2-imageio, TwelveMonkeys) are resolved by Maven rather than hand-fetched (see below), and are PGP-verified once resolved: jbig2-imageio against the canonical PDFBox KEYS file, and TwelveMonkeys jars against a pinned fingerprint fetched from `keyserver.ubuntu.com` (falling back to `keys.openpgp.org`/`pgp.mit.edu`).

In the `-jpeg2000` variant, jai-imageio jars are verified by pinned SHA-256 hashes instead of PGP, since the signing subkey was revoked.

## Codec dependency versions

jbig2-imageio and jai-imageio aren't fetched as "whatever is latest" — they're resolved by a small Maven build stage (see `bin/codecs-pom.xml.tmpl`) that inherits from PDFBox's own `pdfbox-parent` POM, picking up the exact `jbig2-imageio`/`jai-imageio` versions that the resolved PDFBox release was built and tested against. Maven also pulls in the correct transitive dependencies (e.g. TwelveMonkeys' `imageio-metadata`), which the old hand-fetch list silently missed.

TwelveMonkeys isn't a PDFBox dependency, so there's no upstream version to track — its version is pinned manually in the same template and bumped deliberately.

## Future

* Options for additional JARs to include
* IDK. Patches welcome.

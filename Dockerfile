FROM alpine:3.24 AS pdfbox-jar

# Leave empty to build the latest 3.x release; set to pin an exact version
# (e.g. --build-arg PDFBOX_VERSION=3.0.7)
ARG PDFBOX_VERSION=""
ENV PDFBOX_VERSION=${PDFBOX_VERSION}

WORKDIR /home

RUN apk add --no-cache \
    bash \
    jq \
    gnupg \
    curl

# PDFBox jar (latest 3.x via Apache projects API, unless PDFBOX_VERSION pins
# one), verified against its SHA-512 checksum and PGP signature from the
# canonical Apache download server
RUN mkdir -p /opt/pdfbox-installer
COPY bin/* /opt/pdfbox-installer/

RUN mkdir -p /opt/pdfbox \
    && bash /opt/pdfbox-installer/install.bash /opt/pdfbox \
    && rm -rf /opt/pdfbox-installer


FROM maven:3.9-eclipse-temurin-21-alpine AS codecs

WORKDIR /build

RUN apk add --no-cache gnupg curl

# Optional image codec jars (jbig2, JAI ImageIO, TwelveMonkeys) are resolved
# via Maven rather than hand-fetched, so jbig2-imageio/jai-imageio land on the
# exact versions the resolved PDFBox release was tested against. The resolved
# jars' PGP signatures are then checked against the same pinned fingerprints
# used elsewhere in this image. See bin/codecs-pom.xml.tmpl and
# bin/resolve-codecs.bash.
COPY --from=pdfbox-jar /opt/pdfbox-version.txt ./pdfbox-version.txt
COPY bin/codecs-pom.xml.tmpl ./codecs-pom.xml.tmpl
COPY bin/codecs-jpeg2000-pom.xml.tmpl ./codecs-jpeg2000-pom.xml.tmpl
COPY bin/resolve-codecs.bash ./resolve-codecs.bash
COPY bin/lib/hash_functions.lib.bash bin/lib/fingerprints.lib.bash ./lib/

# Set JPEG2000=true at build time to include jai-imageio-core and
# jai-imageio-jpeg2000 (verified by SHA-256 hash; see issue #2).
ARG JPEG2000=false
RUN if [ "$JPEG2000" = "true" ]; then \
        bash resolve-codecs.bash codecs-jpeg2000-pom.xml.tmpl pdfbox-version.txt /opt/codecs; \
    else \
        bash resolve-codecs.bash codecs-pom.xml.tmpl pdfbox-version.txt /opt/codecs; \
    fi


FROM alpine:3.24 AS alpine-base

LABEL org.opencontainers.image.authors="Nicholas Avenell <nicholas@istic.net>"
LABEL org.opencontainers.image.url="aquarion/pdfbox"
LABEL org.opencontainers.image.documentation="https://github.com/aquarion/pdfbox"
LABEL org.opencontainers.image.source="https://github.com/aquarion/pdfbox"

ARG PDFBOX_UID=1000
ENV PDFBOX_UID=${PDFBOX_UID}


# System dependencies
RUN apk add --no-cache \
    bash \
    unzip \
    openjdk21-jre \
    ghostscript \
    ghostscript-fonts

COPY --from=pdfbox-jar /opt/pdfbox/pdfbox.jar /opt/pdfbox/pdfbox.jar
COPY --from=codecs /opt/codecs/ /opt/pdfbox/

# Don't run as root; UID matches the host user on single-user Linux systems, which typically avoids volume mount permission issues
RUN mkdir -p /opt/pdfbox/data \
    && adduser -D -s /bin/bash -u $PDFBOX_UID pdfbox \
    && chown -R pdfbox:pdfbox /opt/pdfbox

USER pdfbox
WORKDIR /opt/pdfbox/data

# Set the entrypoint to run PDFBox commands
ENTRYPOINT ["java", "-cp", "/opt/pdfbox/*", "org.apache.pdfbox.tools.PDFBox"]

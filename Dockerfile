FROM alpine:3.24 AS pdfbox-jar

WORKDIR /home

RUN apk add --no-cache \
    bash \
    jq \
    gnupg \
    curl

# PDFBox jar (latest 3.x via Apache projects API), verified against its
# SHA-512 checksum and PGP signature from the canonical Apache download server
RUN mkdir -p /opt/pdfbox-installer
COPY bin/install.bash /opt/pdfbox-installer/install.bash
COPY bin/lib/ /opt/pdfbox-installer/lib/

RUN mkdir -p /opt/pdfbox \
    && bash /opt/pdfbox-installer/install.bash /opt/pdfbox \
    && rm -rf /opt/pdfbox-installer


FROM maven:3.9-eclipse-temurin-21-alpine AS codecs

WORKDIR /build

# Optional image codec jars (jbig2, JAI ImageIO, TwelveMonkeys) are resolved
# via Maven rather than hand-fetched, so jbig2-imageio/jai-imageio land on the
# exact versions the resolved PDFBox release was tested against. See
# bin/codecs-pom.xml.tmpl.
COPY --from=pdfbox-jar /opt/pdfbox-version.txt ./pdfbox-version.txt
COPY bin/codecs-pom.xml.tmpl ./codecs-pom.xml.tmpl
COPY bin/resolve-codecs.bash ./resolve-codecs.bash

RUN bash resolve-codecs.bash codecs-pom.xml.tmpl pdfbox-version.txt /opt/codecs


FROM alpine:3.24 AS alpine-base

WORKDIR /home

# System dependencies
RUN apk add --no-cache \
    bash \
    unzip \
    openjdk21-jre \
    ghostscript \
    ghostscript-fonts

COPY --from=pdfbox-jar /opt/pdfbox/pdfbox.jar /opt/pdfbox/pdfbox.jar
COPY --from=codecs /opt/codecs/ /opt/pdfbox/

ENTRYPOINT ["java", "-cp", "/opt/pdfbox/*", "org.apache.pdfbox.tools.PDFBox"]

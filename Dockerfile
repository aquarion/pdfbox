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
    jq \
    gnupg \
    unzip \
    curl \
    openjdk21-jre \
    ghostscript \
    ghostscript-fonts

# PDFBox jar (latest 3.x via Apache projects API)
RUN mkdir -p /opt/pdfbox-installer

COPY bin/* /opt/pdfbox-installer/

RUN mkdir -p /opt/pdfbox \
    && bash /opt/pdfbox-installer/install.bash /opt/pdfbox \
    && rm -rf /opt/pdfbox-installer


# Don't run as root; UID matches the host user on single-user Linux systems, which typically avoids volume mount permission issues
RUN mkdir -p /opt/pdfbox/data \
    && adduser -D -s /bin/bash -u $PDFBOX_UID pdfbox \
    && chown -R pdfbox:pdfbox /opt/pdfbox

USER pdfbox
WORKDIR /opt/pdfbox/data

# Set the entrypoint to run PDFBox commands
ENTRYPOINT ["java", "-cp", "/opt/pdfbox/*", "org.apache.pdfbox.tools.PDFBox"]

FROM alpine:3.24 AS alpine-base

WORKDIR /home

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


ENTRYPOINT ["java", "-cp", "/opt/pdfbox/*", "org.apache.pdfbox.tools.PDFBox"]

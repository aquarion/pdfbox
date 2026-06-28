
# Signing key sources and pinned fingerprints for all dependency verification.
# Update these if a project rotates its signing key.

# PDFBox release signing keys — fetched from canonical Apache server (different trust root from CDN).
# Pinning a fingerprint here would break when the release manager changes; the KEYS file is sufficient.
export PDFBOX_KEYS_URL="https://downloads.apache.org/pdfbox/KEYS"

# Apache Maven release signing keys (not currently used — jbig2-imageio uses the PDFBox KEYS file)
# https://downloads.apache.org/maven/KEYS
export MAVEN_KEYS_URL="https://downloads.apache.org/maven/KEYS"

# jai-imageio-core, jai-imageio-jpeg2000
# Stian Soiland-Reyes <soiland-reyes@manchester.ac.uk>
export JAI_IMAGEIO_FPR="DDDEE87612E9FB95F5C8D91E411063A3A0FFD119"

# TwelveMonkeys (common-lang, common-io, common-image, imageio-core, imageio-jpeg)
# Harald Kuhr <haraldk@haraldk.com>
export TWELVEMONKEYS_FPR="453EA31328DE7D8AAA55AD4ED56C721C1CFF1424"

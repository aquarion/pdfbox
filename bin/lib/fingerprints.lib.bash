
# Signing key sources and pinned fingerprints for all dependency verification.
# Update these if a project rotates its signing key.

# PDFBox release signing keys — fetched from canonical Apache server (different trust root from CDN).
# Pinning a fingerprint here would break when the release manager changes; the KEYS file is sufficient.
# Also used for jbig2-imageio, which is a PDFBox project artifact signed by PDFBox committers.
export PDFBOX_KEYS_URL="https://downloads.apache.org/pdfbox/KEYS"

# jai-imageio-core 1.4.0 / jai-imageio-jpeg2000 1.4.0 — SHA-256 hash pinning.
# PGP verification is not possible: the signing subkey (Stian Soiland-Reyes
# <soiland-reyes@manchester.ac.uk>, fpr DDDEE87612E9FB95F5C8D91E411063A3A0FFD119)
# was revoked after publication and no newer release exists.
# Hashes computed from the canonical jars on Maven Central; see issue #2.
export JAI_IMAGEIO_CORE_SHA256="8ad3c68e9efffb10ac87ff8bc589adf64b04a729c5194c079efd0643607fd72a"
export JAI_IMAGEIO_JPEG2000_SHA256="07fb6e3a3040122b846c5e52520033175c3251e2ec8830df82f87cb21f388bb1"

# TwelveMonkeys (common-lang, common-io, common-image, imageio-core, imageio-jpeg)
# Harald Kuhr <haraldk@haraldk.com>
export TWELVEMONKEYS_FPR="453EA31328DE7D8AAA55AD4ED56C721C1CFF1424"

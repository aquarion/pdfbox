#!/bin/bash

#### <Safety Net>
set -o errexit # Exit immediately if a pipeline returns non-zero.
trap 'echo "Aborting due to errexit on line $LINENO. Exit code: $?" >&2' ERR # Print a helpful message if that happens
set -o errtrace # Allow the above trap be inherited by all functions in the script.
set -o pipefail # Return code of a pipeline is the right-most failure. 0 if none.
#### </Safety Net>

##### Setup Environment Variables

EXTRA_JAVA_LIBS_LOC=${1:-"/opt/pdfbox"}
PDFBOX_LOC="${EXTRA_JAVA_LIBS_LOC}/pdfbox.jar"
PDFBOX_MAJOR_VERSION=3


###################### Load helper functions from libraries ######################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/hash_functions.lib.bash"
source "${SCRIPT_DIR}/maven_functions.lib.bash"
source "${SCRIPT_DIR}/apache_org_functions.lib.bash"
source "${SCRIPT_DIR}/fingerprints.lib.bash"


####################### Check for required dependencies ######################

SCRIPT_DEPENDS=("curl" "jq" "gpg" "sha512sum")
for dep in "${SCRIPT_DEPENDS[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        echo "ERROR: Required dependency '$dep' is not installed." >&2
        exit 1
    fi
done

####################### Main Script Logic ######################

VERSION=$(get_most_recent_pdfbox_for_version "$PDFBOX_MAJOR_VERSION")
CDN_BASE="https://dlcdn.apache.org/pdfbox/${VERSION}"
CANONICAL_BASE="https://downloads.apache.org/pdfbox/${VERSION}"

JAR_FILE=$(download_pdfbox_jar "$VERSION" "$PDFBOX_LOC")
EXPECTED_HASH=$(get_expected_sha512 "${CDN_BASE}/${JAR_FILE}")
verify_sha512 "${PDFBOX_LOC}" "${EXPECTED_HASH}"

verify_pgp_key "${CANONICAL_BASE}/${JAR_FILE}.asc" "$PDFBOX_KEYS_URL" "${PDFBOX_LOC}"

# Apache PDFBox artifact — signed with PDFBox committer key, use PDFBox KEYS file
get_latest_and_download "org.apache.pdfbox" "jbig2-imageio" "$EXTRA_JAVA_LIBS_LOC" "$PDFBOX_KEYS_URL"

# jai-imageio artifacts — both signed by Stian Soiland-Reyes
get_latest_and_download "com.github.jai-imageio" "jai-imageio-core" "$EXTRA_JAVA_LIBS_LOC" "" "$JAI_IMAGEIO_FPR"
get_latest_and_download "com.github.jai-imageio" "jai-imageio-jpeg2000" "$EXTRA_JAVA_LIBS_LOC" "" "$JAI_IMAGEIO_FPR"

# TwelveMonkeys artifacts — all signed by Harald Kuhr
get_latest_and_download "com.twelvemonkeys.common" "common-lang" "$EXTRA_JAVA_LIBS_LOC" "" "$TWELVEMONKEYS_FPR"
get_latest_and_download "com.twelvemonkeys.common" "common-io" "$EXTRA_JAVA_LIBS_LOC" "" "$TWELVEMONKEYS_FPR"
get_latest_and_download "com.twelvemonkeys.common" "common-image" "$EXTRA_JAVA_LIBS_LOC" "" "$TWELVEMONKEYS_FPR"
get_latest_and_download "com.twelvemonkeys.imageio" "imageio-core" "$EXTRA_JAVA_LIBS_LOC" "" "$TWELVEMONKEYS_FPR"
get_latest_and_download "com.twelvemonkeys.imageio" "imageio-jpeg" "$EXTRA_JAVA_LIBS_LOC" "" "$TWELVEMONKEYS_FPR"

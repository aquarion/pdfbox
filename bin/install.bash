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

# Resolved version is handed off to the Maven-based codec resolver stage so it
# can pull jbig2-imageio/jai-imageio at the exact versions this PDFBox release
# was tested against (see bin/codecs-pom.xml.tmpl). That stage also verifies
# the resolved jars' PGP signatures using the fingerprints above.
echo "$VERSION" > "$(dirname "$EXTRA_JAVA_LIBS_LOC")/pdfbox-version.txt"

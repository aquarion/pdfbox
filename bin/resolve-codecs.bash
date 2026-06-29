#!/bin/bash

#### <Safety Net>
set -o errexit # Exit immediately if a pipeline returns non-zero.
trap 'echo "Aborting due to errexit on line $LINENO. Exit code: $?" >&2' ERR # Print a helpful message if that happens
set -o errtrace # Allow the above trap be inherited by all functions in the script.
set -o pipefail # Return code of a pipeline is the right-most failure. 0 if none.
#### </Safety Net>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/hash_functions.lib.bash"
source "${SCRIPT_DIR}/lib/fingerprints.lib.bash"

POM_TEMPLATE="$1"
PDFBOX_VERSION_FILE="$2"
OUTPUT_DIR="$3"

PDFBOX_VERSION=$(cat "$PDFBOX_VERSION_FILE")

sed "s/@PDFBOX_VERSION@/${PDFBOX_VERSION}/" "$POM_TEMPLATE" > pom.xml

mkdir -p "$OUTPUT_DIR"
mvn -B -ntp dependency:copy-dependencies -DoutputDirectory="$OUTPUT_DIR" -DincludeScope=runtime

####################### Verify PGP signatures of resolved jars #######################
# Maven Central's checksum proves a jar matches what's published there, not who
# published it. Re-derive each resolved artifact's group:artifact:version via
# `dependency:list` (copy-dependencies' jar filenames don't carry the groupId)
# and verify against the same pinned fingerprints used for hand-fetched jars.

MAVEN_CENTRAL="https://repo1.maven.org/maven2"
DEPS_FILE="deps.txt"

mvn -B -ntp dependency:list -DincludeScope=runtime -Dsort=true -DoutputFile="$DEPS_FILE" > /dev/null

grep -E '^[[:space:]]+[^[:space:]]+:[^[:space:]]+:[^[:space:]]+:[^[:space:]]+:[^[:space:]]+' "$DEPS_FILE" \
    | sed -E 's/^[[:space:]]+//' \
    | while IFS=: read -r group_id artifact_id _packaging version _rest; do
        jar_file="${artifact_id}-${version}.jar"
        jar_path="${OUTPUT_DIR}/${jar_file}"
        [[ -f "$jar_path" ]] || continue

        group_path="${group_id//.//}"
        jar_url="${MAVEN_CENTRAL}/${group_path}/${artifact_id}/${version}/${jar_file}"

        case "$group_id" in
            org.apache.pdfbox)
                verify_pgp_key "${jar_url}.asc" "$PDFBOX_KEYS_URL" "$jar_path"
                ;;
            com.github.jai-imageio)
                verify_pgp_key_keyserver "${jar_url}.asc" "$jar_path" "$JAI_IMAGEIO_FPR"
                ;;
            com.twelvemonkeys.*)
                verify_pgp_key_keyserver "${jar_url}.asc" "$jar_path" "$TWELVEMONKEYS_FPR"
                ;;
        esac
    done

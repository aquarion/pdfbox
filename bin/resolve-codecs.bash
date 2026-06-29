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
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+--.*$//' \
    | while IFS= read -r dep_line; do
        # Format is groupId:artifactId:packaging[:classifier]:version:scope —
        # the classifier field is optional, so take version/scope from the end
        # rather than by fixed position.
        IFS=: read -ra fields <<< "$dep_line"
        field_count=${#fields[@]}
        group_id="${fields[0]}"
        artifact_id="${fields[1]}"
        version="${fields[$((field_count - 2))]}"

        jar_file="${artifact_id}-${version}.jar"
        jar_path="${OUTPUT_DIR}/${jar_file}"
        [[ -f "$jar_path" ]] || continue

        group_path="${group_id//.//}"
        jar_url="${MAVEN_CENTRAL}/${group_path}/${artifact_id}/${version}/${jar_file}"

        case "$group_id" in
            org.apache.pdfbox)
                verify_pgp_key "${jar_url}.asc" "$PDFBOX_KEYS_URL" "$jar_path"
                ;;
            com.twelvemonkeys.*)
                verify_pgp_key_keyserver "${jar_url}.asc" "$jar_path" "$TWELVEMONKEYS_FPR"
                ;;
            com.github.jai-imageio)
                # PGP verification not possible: the signing subkey was revoked.
                # Content integrity is verified against pinned SHA-256 hashes instead.
                # See https://github.com/aquarion/pdfbox/issues/2
                case "$artifact_id" in
                    jai-imageio-core)     verify_sha256 "$jar_path" "$JAI_IMAGEIO_CORE_SHA256" ;;
                    jai-imageio-jpeg2000) verify_sha256 "$jar_path" "$JAI_IMAGEIO_JPEG2000_SHA256" ;;
                    *)
                        echo "ERROR: No SHA-256 pin for jai-imageio artifact '${artifact_id}:${version}' — refusing to ship an unverified jar." >&2
                        exit 1
                        ;;
                esac
                ;;
            *)
                echo "ERROR: No PGP verification rule for resolved dependency '${group_id}:${artifact_id}:${version}' — refusing to ship an unverified jar." >&2
                exit 1
                ;;
        esac
    done

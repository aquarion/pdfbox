#!/bin/bash

#### <Safety Net>
set -o errexit # Exit immediately if a pipeline returns non-zero.
trap 'echo "Aborting due to errexit on line $LINENO. Exit code: $?" >&2' ERR # Print a helpful message if that happens
set -o errtrace # Allow the above trap be inherited by all functions in the script.
set -o pipefail # Return code of a pipeline is the right-most failure. 0 if none.
#### </Safety Net>

POM_TEMPLATE="$1"
PDFBOX_VERSION_FILE="$2"
OUTPUT_DIR="$3"

PDFBOX_VERSION=$(cat "$PDFBOX_VERSION_FILE")

sed "s/@PDFBOX_VERSION@/${PDFBOX_VERSION}/" "$POM_TEMPLATE" > pom.xml

mkdir -p "$OUTPUT_DIR"
mvn -B -ntp dependency:copy-dependencies -DoutputDirectory="$OUTPUT_DIR" -DincludeScope=runtime

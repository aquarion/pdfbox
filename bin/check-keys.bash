#!/bin/bash
# Checks PGP signing keys used during image builds for upcoming expiry.
# Run on a CI schedule to get advance warning before a key rotation breaks the build.
#
# Exit codes: 0 = all OK, 1 = warning (expiring within WARNING_DAYS), 2 = expired/error
# Override threshold: WARNING_DAYS=30 ./check-keys.bash

set -o errexit
set -o errtrace
set -o pipefail

# All report output goes to stderr so it remains visible when stdout is redirected
exec 1>&2

WARNING_DAYS="${WARNING_DAYS:-90}"
KEYSERVERS=("hkps://keyserver.ubuntu.com" "hkps://keys.openpgp.org" "hkp://pgp.mit.edu")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/fingerprints.lib.bash"
source "${SCRIPT_DIR}/lib/apache_org_functions.lib.bash"
source "${SCRIPT_DIR}/lib/maven_functions.lib.bash"

GNUPGHOME=$(mktemp -d)
export GNUPGHOME
trap 'rm -rf "$GNUPGHOME"' EXIT

exit_code=0
warning_secs=$(( WARNING_DAYS * 86400 ))
now=$(date +%s)

###################### Helpers ######################

report() {
    local level="$1" label="$2" fpr="$3" msg="$4"
    printf "%-6s %s\n"  "${level}" "${label} — ${msg}"
    printf "       fpr: %s\n" "$fpr"
    case "$level" in
        WARN) [[ $exit_code -ge 1 ]] || exit_code=1 ;;
        FAIL) exit_code=2 ;;
    esac
}

check_expiry() {
    local label="$1" fpr="$2"

    local key_info
    key_info=$(gpg --with-colons --fingerprint "$fpr" 2>/dev/null) || true

    if [[ -z "$key_info" ]]; then
        report FAIL "$label" "$fpr" "key not found in keyring (keyserver fetch may have failed)"
        return
    fi

    local expiry
    expiry=$(echo "$key_info" | awk -F: '/^pub/{print $7; exit}')

    if [[ -z "$expiry" || "$expiry" == "0" ]]; then
        report OK "$label" "$fpr" "no expiry set"
        return
    fi

    local remaining=$(( expiry - now ))
    local days=$(( remaining / 86400 ))

    if (( remaining < 0 )); then
        report FAIL "$label" "$fpr" "EXPIRED $(( -days )) days ago"
    elif (( remaining < warning_secs )); then
        report WARN "$label" "$fpr" "expires in ${days} days"
    else
        report OK   "$label" "$fpr" "expires in ${days} days"
    fi
}

import_keys_file() {
    local url="$1"
    curl --fail -sL "$url" | gpg --quiet --import 2>/dev/null || true
}

import_from_keyserver() {
    local fpr="$1"
    for ks in "${KEYSERVERS[@]}"; do
        if gpg --quiet --keyserver "$ks" --recv-keys "$fpr" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

# Returns the signing key fingerprint embedded in a detached .asc file.
# Tries the v4 issuer fingerprint subpacket first; falls back to resolving
# the key ID against whatever is already in the keyring (needed for old v3 sigs).
get_signing_fpr() {
    local asc_url="$1"
    local asc_file
    asc_file=$(mktemp)
    curl --fail -sL "$asc_url" -o "$asc_file" || { rm -f "$asc_file"; return 1; }

    local fpr
    fpr=$(gpg --list-packets "$asc_file" 2>/dev/null | awk '/issuer fpr v4/{print $NF; exit}' | tr -dc '[:xdigit:]')

    if [[ -z "$fpr" ]]; then
        local keyid
        keyid=$(gpg --list-packets "$asc_file" 2>/dev/null | awk '/issuer key ID/{print $NF; exit}' | tr -dc '[:xdigit:]')
        if [[ -n "$keyid" ]]; then
            fpr=$(gpg --with-colons --fingerprint "$keyid" 2>/dev/null | awk -F: '/^fpr/{print $10; exit}')
        fi
    fi

    rm -f "$asc_file"
    echo "$fpr"
}

###################### Checks ######################

echo "Checking PGP signing keys (warning at ${WARNING_DAYS} days)..."
echo

# PDFBox — key identified from latest release .asc, validated against Apache KEYS file
echo "PDFBox:"
import_keys_file "$PDFBOX_KEYS_URL"
PDFBOX_VERSION=$(get_most_recent_pdfbox_for_version 3 2>/dev/null)
PDFBOX_SIGNING_FPR=$(get_signing_fpr \
    "https://downloads.apache.org/pdfbox/${PDFBOX_VERSION}/pdfbox-app-${PDFBOX_VERSION}.jar.asc")
if [[ -n "$PDFBOX_SIGNING_FPR" ]]; then
    echo "Found signing key for PDFBox ${PDFBOX_VERSION}: $PDFBOX_SIGNING_FPR"
    check_expiry "PDFBox ${PDFBOX_VERSION} release key" "$PDFBOX_SIGNING_FPR"
else
    echo "FAIL   PDFBox — could not determine signing key for ${PDFBOX_VERSION}"
    exit_code=2
fi
echo

# jbig2-imageio — key identified from latest release .asc, validated against Apache Maven KEYS file
echo "jbig2-imageio:"
import_keys_file "$MAVEN_KEYS_URL"
JBIG2_VERSION=$(get_latest_maven_version "org.apache.pdfbox" "jbig2-imageio" 2>/dev/null)
JBIG2_SIGNING_FPR=$(get_signing_fpr \
    "https://repo1.maven.org/maven2/org/apache/pdfbox/jbig2-imageio/${JBIG2_VERSION}/jbig2-imageio-${JBIG2_VERSION}.jar.asc")
if [[ -n "$JBIG2_SIGNING_FPR" ]]; then
    check_expiry "jbig2-imageio ${JBIG2_VERSION} release key" "$JBIG2_SIGNING_FPR"
else
    echo "FAIL   jbig2-imageio — could not determine signing key for ${JBIG2_VERSION}"
    exit_code=2
fi
echo

# jai-imageio — pinned fingerprint, fetched from keyserver
echo "jai-imageio:"
import_from_keyserver "$JAI_IMAGEIO_FPR"
check_expiry "jai-imageio (Stian Soiland-Reyes)" "$JAI_IMAGEIO_FPR"
echo

# TwelveMonkeys — pinned fingerprint, fetched from keyserver
echo "TwelveMonkeys:"
import_from_keyserver "$TWELVEMONKEYS_FPR"
check_expiry "TwelveMonkeys (Harald Kuhr)" "$TWELVEMONKEYS_FPR"
echo

exit $exit_code

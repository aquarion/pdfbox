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
    local tmp
    tmp=$(mktemp)
    if ! curl --fail -sL "$url" -o "$tmp"; then
        echo "ERROR: Failed to fetch KEYS file from $url" >&2
        rm -f "$tmp"
        return 1
    fi
    gpg --quiet --import "$tmp" 2>/dev/null || echo "WARNING: gpg import had errors for keys from $url" >&2
    rm -f "$tmp"
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
if ! import_keys_file "$PDFBOX_KEYS_URL"; then
    echo "FAIL   PDFBox — could not fetch KEYS file" >&2
    exit_code=2
else
    PDFBOX_VERSION=$(get_most_recent_pdfbox_for_version 3)
    if [[ -z "$PDFBOX_VERSION" ]]; then
        echo "FAIL   PDFBox — could not determine latest 3.x version" >&2
        exit_code=2
    else
        PDFBOX_SIGNING_FPR=$(get_signing_fpr \
            "https://downloads.apache.org/pdfbox/${PDFBOX_VERSION}/pdfbox-app-${PDFBOX_VERSION}.jar.asc")
        if [[ -n "$PDFBOX_SIGNING_FPR" ]]; then
            echo "Found signing key for PDFBox ${PDFBOX_VERSION}: $PDFBOX_SIGNING_FPR"
            check_expiry "PDFBox ${PDFBOX_VERSION} release key" "$PDFBOX_SIGNING_FPR"
        else
            echo "FAIL   PDFBox — could not determine signing key for ${PDFBOX_VERSION}" >&2
            exit_code=2
        fi
    fi
fi
echo

# jbig2-imageio — key identified from latest release .asc, validated against PDFBox KEYS file
# (jbig2-imageio is a PDFBox project artifact, signed by PDFBox committers)
echo "jbig2-imageio:"
if ! import_keys_file "$PDFBOX_KEYS_URL"; then
    echo "FAIL   jbig2-imageio — could not fetch KEYS file" >&2
    exit_code=2
else
    JBIG2_VERSION=$(get_latest_maven_version "org.apache.pdfbox" "jbig2-imageio")
    if [[ -z "$JBIG2_VERSION" ]]; then
        echo "FAIL   jbig2-imageio — could not determine latest version" >&2
        exit_code=2
    else
        JBIG2_SIGNING_FPR=$(get_signing_fpr \
            "https://repo1.maven.org/maven2/org/apache/pdfbox/jbig2-imageio/${JBIG2_VERSION}/jbig2-imageio-${JBIG2_VERSION}.jar.asc")
        if [[ -n "$JBIG2_SIGNING_FPR" ]]; then
            check_expiry "jbig2-imageio ${JBIG2_VERSION} release key" "$JBIG2_SIGNING_FPR"
        else
            echo "FAIL   jbig2-imageio — could not determine signing key for ${JBIG2_VERSION}" >&2
            exit_code=2
        fi
    fi
fi
echo

# jai-imageio uses SHA-256 hash pinning (not PGP) in the -jpeg2000 variant — no key to check here.

# TwelveMonkeys — pinned fingerprint, fetched from keyserver
echo "TwelveMonkeys:"
if import_from_keyserver "$TWELVEMONKEYS_FPR"; then
    check_expiry "TwelveMonkeys (Harald Kuhr)" "$TWELVEMONKEYS_FPR"
else
    report FAIL "TwelveMonkeys (Harald Kuhr)" "$TWELVEMONKEYS_FPR" "all keyservers failed — key fetch skipped"
fi
echo

exit $exit_code

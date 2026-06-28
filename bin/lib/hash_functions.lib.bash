
function verify_pgp_key {
    # PGP signature fetched from canonical Apache server (different trust root from CDN mirror above).
    # A temporary GNUPGHOME is used so imported keys do not persist in the system keyring.

    local ASC_URL="$1"
    local KEYS_URL="$2"
    local FILE_LOC="$3"

    if [[ -z "$ASC_URL" || -z "$KEYS_URL" || -z "$FILE_LOC" ]]; then
        echo "ERROR: ASC_URL, KEYS_URL, and FILE_LOC must be provided for PGP verification." >&2
        exit 1
    fi

    local ASC_FILE KEYS_FILE GNUPGHOME
    ASC_FILE=$(mktemp) || { echo "ERROR: Failed to create temp file for ASC." >&2; exit 1; }
    KEYS_FILE=$(mktemp) || { echo "ERROR: Failed to create temp file for KEYS." >&2; exit 1; }
    GNUPGHOME=$(mktemp -d) || { echo "ERROR: Failed to create temp GPG home directory." >&2; exit 1; }
    export GNUPGHOME
    trap 'rm -f "$ASC_FILE" "$KEYS_FILE"; rm -rf "$GNUPGHOME"' EXIT

    echo "Verifying PGP signature for ${FILE_LOC} using keys from ${KEYS_URL}..."
    curl --fail -L "$ASC_URL" -o "$ASC_FILE"
    curl --fail -L "$KEYS_URL" -o "$KEYS_FILE"

    gpg --import "$KEYS_FILE" || {
        echo "ERROR: Failed to import PGP keys from $KEYS_URL." >&2
        exit 1
    }
    gpg --verify "$ASC_FILE" "${FILE_LOC}" || {
        echo "ERROR: PGP signature verification failed — jar may be tampered with." >&2
        rm -f "${FILE_LOC}"
        exit 1
    }

    rm -f "$ASC_FILE" "$KEYS_FILE"
    rm -rf "$GNUPGHOME"
    trap - EXIT
    echo "PGP verification passed."
}


function get_expected_sha512 {
    local jar_url="$1"
    local sha512_url="${jar_url}.sha512"

    local expected_hash
    expected_hash=$(curl --fail -s "$sha512_url") || {
        echo "ERROR: Failed to fetch SHA512 from $sha512_url" >&2
        exit 1
    }
    expected_hash=$(echo "$expected_hash" | awk '{print $1}')

    if [[ -z "$expected_hash" ]]; then
        echo "ERROR: Could not retrieve SHA512 checksum from $sha512_url" >&2
        exit 1
    fi

    echo "$expected_hash"
}

function verify_sha512 {
    local file_path="$1"
    local expected_hash="$2"

    echo "${expected_hash}  ${file_path}" | sha512sum -c - || {
        echo "ERROR: SHA512 checksum verification failed for ${file_path}." >&2
        rm -f "${file_path}"
        exit 1
    }
}

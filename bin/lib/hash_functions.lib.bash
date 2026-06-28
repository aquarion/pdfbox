
function verify_pgp_key {
    # PGP signature fetched from canonical Apache server (different trust root from CDN mirror above)

    ASC_URL=$1
    KEYS_URL=$2
    FILE_LOC=$3

    if [[ -z "$ASC_URL" || -z "$KEYS_URL" || -z "$FILE_LOC" ]]; then
        echo "ERROR: ASC_URL, KEYS_URL, and FILE_LOC must be provided for PGP verification." >&2
        exit 1
    fi

    ASC_FILE=$(mktemp)
    KEYS_FILE=$(mktemp)
    trap 'rm -f "$ASC_FILE" "$KEYS_FILE"' EXIT

    echo "Verifying PGP signature for ${FILE_LOC} using keys from ${KEYS_URL}..."
    curl --fail -L "$ASC_URL" -o "$ASC_FILE"
    curl --fail -L "$KEYS_URL" -o "$KEYS_FILE"

    GNUPGHOME=$(mktemp -d)
    export GNUPGHOME
    gpg --import "$KEYS_FILE"
    gpg --verify "$ASC_FILE" "${FILE_LOC}" || {
        echo "ERROR: PGP signature verification failed — jar may be tampered with." >&2
        rm -f "${FILE_LOC}"
        rm -rf "${GNUPGHOME}"
        exit 1
    }
    rm -rf "${GNUPGHOME}" "$ASC_FILE" "$KEYS_FILE"
    echo "PGP verification passed."

    return 0
}


function get_expected_sha512 {
    local file_path="$1"
    local sha512_url="${file_path}.sha512"

    local expected_hash
    expected_hash=$(curl --fail -s "$sha512_url" | awk '{print $1}')
    
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
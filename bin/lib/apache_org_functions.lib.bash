
function get_most_recent_pdfbox_for_version {
    local PDFBOX_MAJOR_VERSION="$1"
    local API_RESPONSE
    API_RESPONSE=$(curl --fail -s -L https://projects.apache.org/json/projects/pdfbox.json) || {
        echo "ERROR: Failed to contact Apache projects API." >&2
        exit 1
    }

    if [[ -z "$API_RESPONSE" ]]; then
        echo "ERROR: Apache projects API returned an empty response." >&2
        exit 1
    fi

    VERSION=$(echo "$API_RESPONSE" | jq -r "[ .release[] | select(.name == \"Apache PDFBox\" and (.revision|test(\"^$PDFBOX_MAJOR_VERSION\"))).revision ][0]") || {
        echo "ERROR: Failed to parse Apache projects API response." >&2
        echo "$API_RESPONSE" | head -5 >&2
        exit 1
    }

    if [[ -z "$VERSION" || "$VERSION" == "null" ]]; then
        echo "ERROR: Could not determine PDFBox $PDFBOX_MAJOR_VERSION.x version from Apache projects API." >&2
        exit 1
    fi

    echo "Determined PDFBox $PDFBOX_MAJOR_VERSION.x version: _${VERSION}_" >&2
    echo "$VERSION"
    return 0
}


function download_pdfbox_jar {
    local version="$1"
    local output_path="$2"
    local jar_file="pdfbox-app-${version}.jar"
    local jar_url="${CDN_BASE}/${jar_file}"

    echo "Downloading PDFBox ${version} JAR from CDN..." >&2
    curl --fail -L "$jar_url" -o "$output_path" || {
        echo "ERROR: Failed to download $jar_url" >&2
        exit 1
    }

    echo "$jar_file"
}
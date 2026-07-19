
function get_most_recent_pdfbox_for_version {
    local PDFBOX_MAJOR_VERSION="$1"
    local MAVEN_METADATA_URL="https://repo1.maven.org/maven2/org/apache/pdfbox/pdfbox/maven-metadata.xml"
    local METADATA
    METADATA=$(curl --fail -s -L "$MAVEN_METADATA_URL") || {
        echo "ERROR: Failed to contact Maven Central." >&2
        exit 1
    }

    if [[ -z "$METADATA" ]]; then
        echo "ERROR: Maven Central returned an empty response." >&2
        exit 1
    fi

    # Uses awk to parse <version> elements; avoids grep -P which is unavailable in
    # Busybox. Maven lists versions in ascending release order, so the last
    # major-version match is the newest.
    VERSION=$(echo "$METADATA" | awk -F'[<>]' -v major="$PDFBOX_MAJOR_VERSION" '$2 == "version" && index($3, major ".") == 1 {v = $3} END { print v }')

    if [[ -z "$VERSION" ]]; then
        echo "ERROR: Could not determine PDFBox $PDFBOX_MAJOR_VERSION.x version from Maven Central metadata." >&2
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

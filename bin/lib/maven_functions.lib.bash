
function get_latest_maven_version {
    local group_id="$1"
    local artifact_id="$2"
    local maven_metadata_url
    maven_metadata_url="https://repo1.maven.org/maven2/$(echo "$group_id" | tr '.' '/')/$artifact_id/maven-metadata.xml"

    # Uses awk to parse the <latest> element; avoids grep -P which is unavailable in Busybox
    local latest_version
    latest_version=$(curl --fail -s "$maven_metadata_url") || {
        echo "ERROR: Failed to fetch Maven metadata from $maven_metadata_url" >&2
        exit 1
    }
    latest_version=$(echo "$latest_version" | awk -F'[<>]' '/<latest>/{print $3; exit}')

    if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
        echo "ERROR: Could not determine latest version for $group_id:$artifact_id from Maven Central." >&2
        exit 1
    fi
    echo "Latest version of $group_id:$artifact_id is _${latest_version}_" >&2

    echo "$latest_version"
}

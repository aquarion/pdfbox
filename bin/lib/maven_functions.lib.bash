
function get_latest_maven_version {
    local group_id="$1"
    local artifact_id="$2"
    local maven_metadata_url
    maven_metadata_url="https://repo1.maven.org/maven2/$(echo "$group_id" | tr '.' '/')/$artifact_id/maven-metadata.xml"

    # Fetch the Maven metadata and extract the latest version
    # Busybox grep doesn't support Perl regex, so we use a simpler approach to extract the latest version
    local latest_version
    latest_version=$(curl --fail -s "$maven_metadata_url" | awk -F'[<>]' '/<latest>/{print $3; exit}') || {
        echo "ERROR: Failed to fetch Maven metadata from $maven_metadata_url" >&2
        exit 1
    }
    
    if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
        echo "ERROR: Could not determine latest version for $group_id:$artifact_id from Maven Central." >&2
        exit 1
    fi
    echo "Latest version of $group_id:$artifact_id is _${latest_version}_" >&2

    echo "$latest_version"
}

function download_maven_artifact {
    local group_id="$1"
    local artifact_id="$2"
    local version="$3"
    local output_dir="$4"

    local base_url
    base_url="https://repo1.maven.org/maven2/$(echo "$group_id" | tr '.' '/')/$artifact_id/$version"
    local jar_file="${artifact_id}-${version}.jar"
    local jar_url="${base_url}/${jar_file}"

    echo "Downloading $group_id:$artifact_id:$version..."
    curl --fail -L "$jar_url" -o "${output_dir}/${jar_file}" || {
        echo "ERROR: Failed to download $jar_url" >&2
        exit 1
    }
}

function get_latest_and_download {
    local group_id="$1"
    local artifact_id="$2"
    local output_dir="$3"

    local latest_version
    latest_version=$(get_latest_maven_version "$group_id" "$artifact_id")
    if [[ -z "$latest_version" ]]; then
        echo "ERROR: Could not determine latest version for $group_id:$artifact_id" >&2
        exit 1
    fi
    if ! download_maven_artifact "$group_id" "$artifact_id" "$latest_version" "$output_dir"; then
        echo "ERROR: Failed to download $group_id:$artifact_id:$latest_version" >&2
        exit 1
    fi
}

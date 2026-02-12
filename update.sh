# updates a forge version json, with the given info

set -e

json_file="$1"
mc_version_range="$2"
mod_version="$3"
release_type="$4"

# Validate file exists
if [[ ! -f "$json_file" ]]; then
    echo "Error: JSON file '$json_file' not found"
    exit 1
fi

jsonContent=$(cat "$json_file")

# Remove brackets and spaces
range=$(echo "$mc_version_range" | sed 's/[][]//g' | tr -d ' ')

# Detect single version or range
if [[ "$range" == *","* ]]; then
    start_version=$(echo "$range" | cut -d',' -f1)
    end_version=$(echo "$range" | cut -d',' -f2)
else
    start_version="$range"
    end_version="$range"
fi

parse_version() {
    IFS='.' read -r major minor patch <<< "$1"

    if [[ -z "$major" || -z "$minor" ]]; then
        echo "Error: Version must be at least major.minor"
        exit 1
    fi

    if [[ -z "$patch" ]]; then
        patch=0
    fi

    echo "$major" "$minor" "$patch"
}

read start_major start_minor start_patch < <(parse_version "$start_version")
read end_major end_minor end_patch < <(parse_version "$end_version")

# Ensure same major/minor
if [[ "$start_major" != "$end_major" || "$start_minor" != "$end_minor" ]]; then
    echo "Error: Range must stay within same major.minor version"
    exit 1
fi

# Ensure patch does not decrease
if (( end_patch < start_patch )); then
    echo "Error: Patch version cannot decrease ($start_patch → $end_patch)"
    exit 1
fi

for ((patch=start_patch; patch<=end_patch; patch++)); do
    if (( patch == 0 )); then
        version="${start_major}.${start_minor}"
    else
        version="${start_major}.${start_minor}.${patch}"
    fi

    jsonContent=$(echo "$jsonContent" | \
        jq --arg key "${version}-latest" --arg val "$mod_version" \
        '.promos[$key]=$val')

    echo "added ${version}-latest:${mod_version}"

    if [[ "$release_type" == "release" ]]; then
        jsonContent=$(echo "$jsonContent" | \
            jq --arg key "${version}-recommended" --arg val "$mod_version" \
            '.promos[$key]=$val')

        echo "added ${version}-recommended:${mod_version}"
    fi
done

echo "$jsonContent" | jq -S .
echo "$jsonContent" | jq -S . > "$json_file"

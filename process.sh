#!/bin/bash

REPO_DIR="$(dirname "$(readlink -f "$0")")"
COUNTRIES_DIR="$REPO_DIR/lists/countries"
OUTPUT_FILE="$REPO_DIR/lists/original/original.m3u"
mkdir -p "$REPO_DIR/lists/original"
rm -f "$OUTPUT_FILE"
echo "#EXTM3U" > "$OUTPUT_FILE"

for file in "$COUNTRIES_DIR"/*.txt; do
  country="$(basename "$file" .txt)"  # es: italy

  echo "Processing $country..."

  > "/tmp/temp_$country.m3u"  # reset file temporaneo

  while read -r url; do
    [[ -z "$url" ]] && continue
    curl -s "$url" >> "/tmp/temp_$country.m3u"
  done < "$file"

  awk -v output="$OUTPUT_FILE" -v group="$country" '
    BEGIN { RS="\r?\n"; FS="," }
    /^#EXTINF/ {
      name = $2
      if (name ~ /\[COLOR|\[B|\]/ || name == "") next
      getline url
      if (url ~ /^http/) {
        gsub(/\s+$/, "", name)
        printf "#EXTINF:-1 tvg-name=\"%s\" tvg-logo=\"https://img.icons8.com/office40/512/raspberry-pi.png\" tvg-id=\"\" group-title=\"%s\",%s\n%s\n\n", name, group, name, url >> output
      }
    }
  ' "/tmp/temp_$country.m3u"

  rm -f "/tmp/temp_$country.m3u"
done

# Timestamp globale
echo "Last update: $(date '+%H:%M')" > "$REPO_DIR/lists/last_update.txt"

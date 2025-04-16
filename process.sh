#!/bin/bash

REPO_DIR="$(dirname "$(readlink -f "$0")")"
COUNTRIES_DIR="$REPO_DIR/lists/countries"
SRC_DIR="$REPO_DIR/lists/original"
mkdir -p "$SRC_DIR"

# Pulisce le vecchie liste
rm -f "$SRC_DIR"/*.m3u

for file in "$COUNTRIES_DIR"/*.txt; do
  country_name="$(basename "$file" .txt)"          # es. italy
  output_file="$SRC_DIR/$country_name.m3u"
  echo "#EXTM3U" > "$output_file"

  echo "Processing $country_name..."

  while read -r url; do
    [[ -z "$url" ]] && continue
    curl -s "$url" >> "/tmp/temp_$country_name.m3u"
  done < "$file"

  awk -v output="$output_file" -v group="$country_name" '
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
  ' "/tmp/temp_$country_name.m3u"

  rm -f "/tmp/temp_$country_name.m3u"
done

# Scrive la data aggiornamento globale
echo "Last playlist update: $(date '+%Y-%m-%d %H:%M')" > "$REPO_DIR/lists/last_update.txt"

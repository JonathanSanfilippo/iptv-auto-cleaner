#!/bin/bash

CHECK_STREAMS=true
REPO_DIR="$(dirname "$(readlink -f "$0")")"
COUNTRIES_DIR="$REPO_DIR/lists/countries"
ORIGINAL_DIR="$REPO_DIR/lists/original"
SKIPPED_FILE="$REPO_DIR/lists/skipped.m3u"
OUTPUT_FILE="$ORIGINAL_DIR/original.m3u"
INFO_FILE="$REPO_DIR/lists/last_update.txt"

mkdir -p "$ORIGINAL_DIR"
rm -f "$OUTPUT_FILE" "$SKIPPED_FILE"
echo "#EXTM3U" > "$OUTPUT_FILE"
echo "#EXTM3U" > "$SKIPPED_FILE"

total_entries=0
valid_entries=0
skipped_entries=0

for file in "$COUNTRIES_DIR"/*.txt; do
  country_raw="$(basename "$file" .txt)"
  country="$(tr '[:lower:]' '[:upper:]' <<< "${country_raw:0:1}")${country_raw:1}"
  echo "📦 Processing $country..."

  temp_file="/tmp/temp_$country_raw.m3u"
  > "$temp_file"

  while read -r url; do
    [[ -z "$url" ]] && continue
    curl -s "$url" >> "$temp_file"
  done < "$file"

  while IFS= read -r line; do
    if [[ $line == \#EXTINF* ]]; then
      name=$(echo "$line" | cut -d',' -f2)
      logo=$(echo "$line" | grep -o 'tvg-logo="[^"]*"' | cut -d'"' -f2)
      [[ -z "$logo" ]] && logo="https://img.icons8.com/office40/512/raspberry-pi.png"
      read -r url

      if [[ -z "$name" || -z "$url" || "$name" =~ \[COLOR|\[B|\] ]]; then
        continue
      fi

      ((total_entries++))

      if $CHECK_STREAMS; then
        curl -s -L --max-time 5 --head "$url" | grep -iq "^HTTP/.* 2" || {
          printf "#EXTINF:-1 tvg-name=\"%s\" tvg-logo=\"%s\" tvg-id=\"\" group-title=\"%s\",%s\n%s\n\n" "$name" "$logo" "$country" "$name" "$url" >> "$SKIPPED_FILE"
          ((skipped_entries++))
          continue
        }
      fi

      printf "#EXTINF:-1 tvg-name=\"%s\" tvg-logo=\"%s\" tvg-id=\"\" group-title=\"%s\",%s\n%s\n\n" "$name" "$logo" "$country" "$name" "$url" >> "$OUTPUT_FILE"
      ((valid_entries++))
    fi
  done < "$temp_file"

  rm -f "$temp_file"
done

# Scrive log informativo
{
  echo "Last update: $(date '+%H:%M')"
  echo "Total entries: $total_entries"
  echo "Valid channels: $valid_entries"
  echo "Skipped channels: $skipped_entries"
} > "$INFO_FILE"

echo "✅ Completato. Canali validi: $valid_entries / $total_entries"

#!/bin/bash

# === CONFIG ===
CHECK_STREAMS=true  # Imposta su false per saltare il controllo URL
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

# === STATS ===
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

  awk -v output="$OUTPUT_FILE" -v skipped="$SKIPPED_FILE" -v group="$country" -v check="$CHECK_STREAMS" \
      -v total_entries_ref="$REPO_DIR/total" -v valid_ref="$REPO_DIR/valid" -v skipped_ref="$REPO_DIR/skipped" '
    BEGIN {
      RS="\r?\n"; FS=","
      total = 0; valid = 0; invalid = 0
    }
    /^#EXTINF/ {
      name = $2
      logo = ""
      match($0, /tvg-logo="([^"]+)"/, arr)
      if (arr[1] != "") logo = arr[1]
      else logo = "https://img.icons8.com/office40/512/raspberry-pi.png"

      if (name ~ /\[COLOR|\[B|\]/ || name == "") next
      getline url
      if (url ~ /^http/) {
        gsub(/\s+$/, "", name)
        total++

        # Se attivo, controlla se l’URL risponde
        if (check == "true") {
          cmd = "curl -s -L --max-time 5 --head \"" url "\" | grep -i HTTP"
          cmd | getline status_line
          close(cmd)
          if (status_line !~ /^HTTP\\/1\\.[01] 2/) {
            printf "#EXTINF:-1 tvg-name=\"%s\" tvg-logo=\"%s\" tvg-id=\"\" group-title=\"%s\",%s\n%s\n\n", name, logo, group, name, url >> skipped
            invalid++
            next
          }
        }

        # Scrive il canale valido
        printf "#EXTINF:-1 tvg-name=\"%s\" tvg-logo=\"%s\" tvg-id=\"\" group-title=\"%s\",%s\n%s\n\n", name, logo, group, name, url >> output
        valid++
      }
    }
    END {
      # Salva le statistiche per Bash
      printf "%d", total > total_entries_ref
      printf "%d", valid > valid_ref
      printf "%d", invalid > skipped_ref
    }
  ' "$temp_file"

  rm -f "$temp_file"
done

# Leggi le statistiche
total_entries=$(cat "$REPO_DIR/total")
valid_entries=$(cat "$REPO_DIR/valid")
skipped_entries=$(cat "$REPO_DIR/skipped")
rm -f "$REPO_DIR/total" "$REPO_DIR/valid" "$REPO_DIR/skipped"

# Salva log aggiornamento
echo "Last update: $(date '+%Y-%m-%d %H:%M')" > "$INFO_FILE"
echo "Total entries: $total_entries" >> "$INFO_FILE"
echo "Valid channels: $valid_entries" >> "$INFO_FILE"
echo "Skipped channels: $skipped_entries" >> "$INFO_FILE"

echo "✅ Completato. Canali validi: $valid_entries / $total_entries"

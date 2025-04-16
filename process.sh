#!/bin/bash

REPO_DIR="$(dirname "$(readlink -f "$0")")"
SRC_DIR="$REPO_DIR/lists/original"
DEST_DIR="$REPO_DIR/lists/processed"
URLS_FILE="$REPO_DIR/urls.txt"
OUTFILE="$DEST_DIR/altre.m3u"

mkdir -p "$SRC_DIR" "$DEST_DIR"
echo "#EXTM3U" > "$OUTFILE"

# Scarica le liste nella cartella original/
index=1
while read -r url; do
  [[ -z "$url" ]] && continue
  fname="lista${index}.m3u"
  curl -s "$url" -o "$SRC_DIR/$fname"
  ((index++))
done < "$URLS_FILE"

# Estrai i canali e scrivi nella lista "Altre Liste"
for file in "$SRC_DIR"/*.m3u; do
  awk -v output="$OUTFILE" '
    BEGIN { RS="\r?\n"; FS="," }
    /^#EXTINF/ {
      name = $2
      if (name ~ /\[COLOR|\[B|\]/ || name == "") next
      getline url
      if (url ~ /^http/) {
        gsub(/\s+$/, "", name)
        printf "#EXTINF:-1 tvg-name=\"%s\" tvg-logo=\"https://img.icons8.com/office40/512/raspberry-pi.png\" tvg-id=\"\" group-title=\"Altre Liste\",%s\n%s\n\n", name, name, url >> output
      }
    }
  ' "$file"
done


# Scrive un file con l'ultimo aggiornamento
UPDATE_FILE="$REPO_DIR/lists/last_update.txt"
echo "Last Update list: $(date '+%d-%m-%y %H:%M') by <a href="https://github.com/JonathanSanfilippo/iptv-auto-cleaner" target="_blank">
  iptv-auto-cleaner
</a>
" > "$UPDATE_FILE"

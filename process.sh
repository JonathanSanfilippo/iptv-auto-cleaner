#!/bin/bash

REPO_DIR="$(dirname "$(readlink -f "$0")")"
SRC_DIR="$REPO_DIR/lists/original"
DEST_DIR="$REPO_DIR/lists/processed"
URLS_FILE="$REPO_DIR/urls.txt"
SRC_FILE="$SRC_DIR/original.m3u"
OUTFILE="$DEST_DIR/altre.m3u"
UPDATE_FILE="$REPO_DIR/lists/last_update.txt"

# Crea directory se non esistono
mkdir -p "$SRC_DIR" "$DEST_DIR"

# Pulisce eventuali file precedenti
rm -f "$SRC_FILE" "$OUTFILE"

# Scarica tutte le liste IPTV e uniscile in un solo file
> "$SRC_FILE"  # svuota/crea il file

while read -r url; do
  [[ -z "$url" ]] && continue
  curl -s "$url" >> "$SRC_FILE"
done < "$URLS_FILE"

# Crea il file M3U di output
echo "#EXTM3U" > "$OUTFILE"

# Estrai i canali validi da original.m3u e scrivi in altre.m3u
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
' "$SRC_FILE"

# Scrive data/ora aggiornamento
echo "Last update $(date '+%H:%M')" > "$UPDATE_FILE"

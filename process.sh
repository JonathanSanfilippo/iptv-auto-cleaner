#!/bin/bash

REPO_DIR="$(dirname "$(readlink -f "$0")")"
SRC_DIR="$REPO_DIR/lists/original"
DEST_DIR="$REPO_DIR/lists/processed"
URLS_FILE="$REPO_DIR/urls.txt"

mkdir -p "$SRC_DIR" "$DEST_DIR"

# Scarica le liste, confronta e salva se cambiate
while read -r url; do
  [[ -z "$url" ]] && continue
  name=$(basename "$url" | cut -d'.' -f1)
  tmpfile="$(mktemp)"
  target="$SRC_DIR/${name}.m3u"

  curl -s "$url" -o "$tmpfile"
  if ! cmp -s "$tmpfile" "$target"; then
    echo "🔁 Lista aggiornata: $name"
    mv "$tmpfile" "$target"
    CHANGED=true
  else
    echo "✅ Nessun cambiamento: $name"
    rm "$tmpfile"
  fi
done < "$URLS_FILE"

# Se nessun file è cambiato, esci
if [ -z "$CHANGED" ]; then
  echo "Nessuna lista è cambiata, esco."
  exit 0
fi

# Pulisci output precedente
rm -f "$DEST_DIR"/*.m3u

# Parsing
for f in "$SRC_DIR"/*.m3u; do
  fname=$(basename "$f")
  outname="${fname%.*}"
  echo "#EXTM3U" > "$DEST_DIR/$outname.m3u"
  echo "#Ⓖ" >> "$DEST_DIR/$outname.m3u"

  awk '
    BEGIN { RS="\r?\n"; FS="," }
    /^#EXTINF/ {
      match($0, /tvg-name="([^"]*)"/, nameA)
      match($0, /tvg-logo="([^"]*)"/, logoA)
      match($0, /tvg-id="([^"]*)"/, idA)
      match($0, /group-title="([^"]*)"/, groupA)

      name = nameA[1]
      logo = logoA[1]
      id = idA[1]
      group = groupA[1]

      getline url
      if (name != "" && group != "") {
        printf "#EXTINF:-1 tvg-name=\"%s Ⓖ\" tvg-logo=\"%s\" tvg-id=\"%s\" group-title=\"%s\",%s Ⓖ\n%s\n\n", name, logo, id, group, name, url
      }
    }
  ' "$f" >> "$DEST_DIR/$outname.m3u"
done

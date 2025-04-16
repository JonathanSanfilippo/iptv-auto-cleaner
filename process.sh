#!/bin/bash

REPO_DIR="$(dirname "$(readlink -f "$0")")"
SRC_DIR="$REPO_DIR/lists/original"
DEST_DIR="$REPO_DIR/lists/processed"
URLS_FILE="$REPO_DIR/urls.txt"

mkdir -p "$SRC_DIR" "$DEST_DIR"

# Definisci un file di mapping per associare i canali a logo e ID
declare -A channel_mapping
channel_mapping["Rai 1"]="https://i.imgur.com/CAx7yRm.png|Rai1.it"
channel_mapping["Rai 2"]="https://i.imgur.com/YzR7JYA.png|Rai2.it"
channel_mapping["Rai 3"]="https://i.imgur.com/8ZTkdjT.png|Rai3.it"
# Aggiungi qui gli altri canali, nel formato "NomeCanale=Logo|ID"

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

# Processa i file originali in ordine
index=1
for f in "$SRC_DIR"/*.m3u; do
  outname="lista${index}.m3u"
  echo "#EXTM3U" > "$DEST_DIR/$outname"
  echo "#Ⓖ" >> "$DEST_DIR/$outname"

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

      # Se il nome del canale è presente nel mapping, usalo
      if (name in channel_mapping) {
        split(channel_mapping[name], mapping, "|")
        logo = mapping[1]
        id = mapping[2]
        name = name " "
      }

      getline url
      if (name != "" && group != "") {
        printf "#EXTINF:-1 tvg-name=\"%s\" tvg-logo=\"%s\" tvg-id=\"%s\" group-title=\"%s\",%s\\n%s\\n\\n", name, logo, id, group, name, url
      }
    }
  ' "$f" >> "$DEST_DIR/$outname"

  ((index++))
done

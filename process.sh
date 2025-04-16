#!/bin/bash

CHECK_STREAMS=true
REPO_DIR="$(dirname "$(readlink -f "$0")")"
COUNTRIES_DIR="$REPO_DIR/lists/countries"
ORIGINAL_DIR="$REPO_DIR/lists/original"
INFO_DIR="$REPO_DIR/lists/info"
SKIPPED_FILE="$REPO_DIR/lists/skipped.m3u"
OUTPUT_FILE="$ORIGINAL_DIR/original.m3u"
EPG_JSON_FILE="$INFO_DIR/epg.json"

mkdir -p "$ORIGINAL_DIR" "$INFO_DIR"
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
        status=$(curl -s -L -A "Mozilla/5.0" --max-time 5 --head "$url" | grep -i "^HTTP" | head -n 1 | awk '{print $2}')
        if [[ "$status" =~ ^(404|410|500|502|503|000)$ ]]; then
          printf "#EXTINF:-1 tvg-name=\"%s\" tvg-logo=\"%s\" tvg-id=\"\" group-title=\"%s\",%s\n%s\n\n" \
            "$name" "$logo" "$country" "$name" "$url" >> "$SKIPPED_FILE"
          ((skipped_entries++))
          continue
        fi
      fi

      printf "#EXTINF:-1 tvg-name=\"%s\" tvg-logo=\"%s\" tvg-id=\"\" group-title=\"%s\",%s\n%s\n\n" \
        "$name" "$logo" "$country" "$name" "$url" >> "$OUTPUT_FILE"
      ((valid_entries++))
    fi
  done < "$temp_file"

  rm -f "$temp_file"
done

# Mappa country_raw -> identificatore EPG tvkaista.net
get_epg_id_tvkaista() {
  case "$1" in
    italy) echo "superguidatv.it" ;;
    uk) echo "tv24.co.uk" ;;
    fr) echo "programme-tv.net" ;;
    de) echo "web.magentatv.de" ;;
    es) echo "movistarplus.es" ;;
    pt) echo "rtp.pt" ;;
    us) echo "tvguide.com" ;;
    au) echo "ontvtonight.com_au" ;;
    *) echo "" ;;
  esac
}

# Mappa fallback epg.best se tvkaista fallisce
get_epg_fallback_url() {
  case "$1" in
    italy) echo "https://epg.best/it.xml" ;;
    uk) echo "https://epg.best/gb.xml" ;;
    fr) echo "https://epg.best/fr.xml" ;;
    de) echo "https://epg.best/de.xml" ;;
    es) echo "https://epg.best/es.xml" ;;
    pt) echo "https://epg.best/pt.xml" ;;
    us) echo "https://epg.best/us.xml" ;;
    au) echo "https://epg.best/au.xml" ;;
    *) echo "" ;;
  esac
}

EPG_ID=$(get_epg_id_tvkaista "$country_raw")
EPG_XML_FILE="$INFO_DIR/epg.xml"
EPG_XML_URL="https://xmltv.tvkaista.net/guides/${EPG_ID}.xml"

# Step 1: download da tvkaista
if [[ -n "$EPG_ID" ]]; then
  echo "⬇️ Scaricamento EPG per $country_raw da tvkaista.net..."
  if curl -fsSL "$EPG_XML_URL" -o "$EPG_XML_FILE"; then
    echo "✅ EPG scaricato da tvkaista.net ($EPG_XML_URL)"
  else
    echo "⚠️ Errore su tvkaista.net ($EPG_XML_URL)"
  fi
else
  echo "⚠️ Nessun EPG configurato per $country_raw"
fi

# Step 2: fallback da epg.best se necessario
if [[ ! -s "$EPG_XML_FILE" ]]; then
  FALLBACK_URL=$(get_epg_fallback_url "$country_raw")
  if [[ -n "$FALLBACK_URL" ]]; then
    echo "🔁 Provo fallback da epg.best..."
    if curl -fsSL "$FALLBACK_URL" -o "$EPG_XML_FILE"; then
      echo "✅ EPG fallback scaricato da $FALLBACK_URL"
    else
      echo "❌ Fallito anche fallback da epg.best"
    fi
  fi
fi

# Step 3: conversione in JSON (solo se XML valido)
if [[ -s "$EPG_XML_FILE" ]]; then
  echo "📦 Convertendo EPG in JSON..."
  xmllint --format "$EPG_XML_FILE" \
    | grep -E '<programme|<title' \
    | sed 's/<programme /\n{\n  /; s/ channel=/\"channel\":/; s/ start=/, \"start\":/; s/ stop=/, \"stop\":/; s/<title[^>]*>/, \"title\": \"/; s/<\/title>/\"/; s/\">/, \"title\": \"/g; s/\" \//\"/g; s/>.*//' \
    | jq -Rs '[split("\n")[] | select(length > 10)] | map(fromjson?)' > "$EPG_JSON_FILE"
else
  echo "❌ EPG XML non disponibile o vuoto."
fi


# Scrive file informativi separati
echo "$(date '+%d %b %Y %H:%M')" > "$INFO_DIR/last_update.txt"
echo "$total_entries" > "$INFO_DIR/total.txt"
echo "$valid_entries" > "$INFO_DIR/valid.txt"
echo "$skipped_entries" > "$INFO_DIR/skipped.txt"

# Scrive file JSON aggregato
cat <<EOF > "$INFO_DIR/stats.json"
{
  "last_update": "$(date '+%d %b %H:%M')",
  "total": $total_entries,
  "valid": $valid_entries,
  "skipped": $skipped_entries
}
EOF

echo "✅ Completato. Canali validi: $valid_entries / $total_entries"

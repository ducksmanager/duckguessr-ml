#!/bin/bash

subset=$1
[ -z "$subset" ] && echo "Usage: $0 <subset>" && exit 1

cd input || exit 1

subsetDirectory="inducks-drawings-by-artist-$subset"
drawingsZipFileName="$subsetDirectory.zip"
rm -rf "$subsetDirectory" && mkdir -p "$subsetDirectory"

subsetMetadataDirectory="inducks-drawings-by-artist-$subset-metadata"
[ ! -d "$subsetMetadataDirectory" ] && echo "$subsetMetadataDirectory does not exist" && exit 1

drawingsCsv="$subsetMetadataDirectory/drawings.csv"
drawingsPopularCsv="$subsetMetadataDirectory/drawings_popular.csv"
artistsCsv="$subsetMetadataDirectory/artists.csv"
artistsPopularCsv="$subsetMetadataDirectory/artists_popular.csv"

echo 'personcode,name,nationality,drawings' > "$artistsPopularCsv"
tail -n +2 "$artistsCsv" | while IFS=',' read -r personcode _ _; do
  drawingCount=$(grep -Pc "$personcode\$" "$drawingsCsv")
  if [ $((drawingCount)) -ge 200 ]; then
    echo "$(grep "^$personcode," "$artistsCsv"),$((drawingCount))" >> "$artistsPopularCsv"
  fi
done

rm -rf -- *.zip
echo 'url,personcode' > "$drawingsPopularCsv"

i=0
tail -n +2 "$drawingsCsv" | while IFS=',' read -r url personcode; do
  if grep -q "^$personcode," "$artistsPopularCsv"; then
    artistDir="$subsetDirectory/$personcode"
    mkdir -p "$artistDir"
    cp "$(echo $url | sed "s~^~full/~")" "$artistDir"/$i.jpg
    echo "$url,$personcode" >> "$drawingsPopularCsv"
    ((i++))
  fi
done

(cd "$subsetDirectory" && zip -rq "../$drawingsZipFileName" .)

(cd "$subsetMetadataDirectory" && zip "../${drawingsZipFileName/.zip/-metadata.zip}" artists_popular.csv drawings_popular.csv)

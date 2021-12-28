#!/bin/bash

subset=$1
[ -z "$subset" ] && echo "Usage: $0 <subset>" && exit 1

subsetDirectory="inducks-drawings-by-artist-$subset"
[ ! -d "$subsetDirectory" ] && echo "$subsetDirectory does not exist" && exit 1

cd input || exit 1

archiveFileName="$subsetDirectory.zip"

drawingsDir="$subsetDirectory/drawings"
drawingsCsv="$subsetDirectory-metadata/drawings.csv"
drawingsPopularCsv="$subsetDirectory-metadata/drawings_popular.csv"
artistsCsv="$subsetDirectory-metadata/artists.csv"
artistsPopularCsv="$subsetDirectory-metadata/artists_popular.csv"

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
    artistDir="$drawingsDir/$personcode"
    mkdir -p "$artistDir"
    cp "$(echo $url | sed "s~^~full/~")" "$artistDir"/$i.jpg
    echo "$url,$personcode" >> "$drawingsPopularCsv"
    ((i++))
  fi
done

(cd "$subsetDirectory/drawings" && zip -rq "../$archiveFileName" .)

(cd "$subsetDirectory-metadata" && zip "../${archiveFileName/.zip/-metadata.zip}" artists_popular.csv drawings_popular.csv)

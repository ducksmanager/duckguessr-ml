#!/bin/bash

[ -z "$1" ] && echo "Usage: $0 <subset>" && exit 1
[ ! -d "datasets/$1" ] && echo "datasets/$1 does not exist" && exit 1

cd datasets

subset=$1
fileName=inducks-drawings-by-artist-"$subset".zip

drawingsCsv="$subset"/drawings.csv
drawingsPopularCsv="$subset"/drawings_popular.csv
artistsCsv="$subset"/artists.csv
artistsPopularCsv="$subset"/artists_popular.csv

echo 'personcode,name,nationality,drawings' > "$artistsPopularCsv"
tail -n +2 "$artistsCsv" | while IFS=',' read -r artist; do
  personcode=$(echo "$artist" | cut -d',' -f1)
  drawingCount=$(grep -Pc "$personcode\$" "$drawingsCsv")
  if [ $((drawingCount)) -ge 200 ]; then
    echo "$(grep "^$personcode," "$artistsCsv"),$((drawingCount))" >> "$artistsPopularCsv"
  fi
done

rm -f "$fileName"
rm -rf temp && mkdir temp
echo 'url,personcode' > "$drawingsPopularCsv"

i=0
tail -n +2 "$drawingsCsv" | while IFS=',' read -r url personcode; do
  if grep -q "^$personcode," "$artistsPopularCsv"; then
    artistDir=temp/"$personcode"
    mkdir -p "$artistDir"
    cp "$(echo $url | sed "s~^~full/~")" "$artistDir"/$i.jpg
    echo "$url,$personcode" >> "$drawingsPopularCsv"
    ((i++))
  fi
done

(cd temp && zip -rq ../"$fileName" .)

(cd "$subset" && zip "../${fileName/.zip/-metadata.zip}" artists_popular.csv drawings_popular.csv)

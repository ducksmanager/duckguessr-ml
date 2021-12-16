#!/bin/bash

[ -z "$1" ] && echo "Usage: $0 <subset>" && exit 1

subset=$1
fileName=datasets/inducks-drawings-by-artist-"$subset".zip

sed -i 's/,nationality$/,nationality,drawings/' datasets/"$subset"/artists.csv
tail -n +2 "$subset"/artists.csv | while read -r artist; do
  personcode=$(echo "$artist" | cut -d',' -f1)
  sed -i "s/^\($personcode,.\+\)\$/\1,$(grep -Pc "$personcode\$" datasets/"$subset"/drawings.csv)/g" datasets/"$subset"/artists.csv
done

rm -f "$fileName"
rm -rf temp && mkdir temp
i=0
while IFS=',' read -r url personcode; do
  mkdir -p temp/"$personcode"
  cp "$(echo $url | sed "s~^~full/~g")" temp/"$personcode"/$i.jpg
  ((i++))
done < datasets/"$subset"/drawings.csv

python remove_corrupted_images.py

(cd temp && zip -rq ../"$fileName" .)
rm -rf temp

(cd "$subset" && zip "../${fileName/.zip/-metadata.zip}" artists.csv drawings.csv)

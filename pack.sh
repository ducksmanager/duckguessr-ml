#!/bin/bash

[ -z "$1" ] && echo "Usage: $0 <subset>" && exit 1
[ ! -d "datasets/$1" ] && echo "datasets/$1 does not exist" && exit 1

cd datasets

subset=$1
datasetFileName=inducks-drawings-by-artist-"$subset".zip
metadataFileName=${datasetFileName/.zip/-metadata.zip}

drawingsPopularCsv="$subset"/drawings_popular.csv

rm -rf "$datasetFileName" "$metadataFileName"
rm -rf temp && mkdir temp

i=0
tail -n +2 "$drawingsPopularCsv" | while IFS=',' read -r url personcode; do
  artistDir=temp/"$personcode"
  mkdir -p "$artistDir"
  cp "$(echo $url | sed "s~^~full/~")" "$artistDir"/$i.jpg
  ((i++))
done

(cd temp && zip -rq "../$datasetFileName" .)

(cd "$subset" && zip "../$metadataFileName" artists_popular.csv drawings_popular.csv)

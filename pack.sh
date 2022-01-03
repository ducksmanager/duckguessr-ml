#!/bin/bash
subset=$1
[ -z "$subset" ] && echo "Usage: $0 <subset>" && exit 1

cd input || exit 1

datasetFileName=inducks-drawings-by-artist-${subset/_/-}.zip
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

(cd temp && zip -rq "../$datasetFileName" . && rm -rf temp)

(cd "$subset" && zip "../$metadataFileName" artists_popular.csv drawings_popular.csv)

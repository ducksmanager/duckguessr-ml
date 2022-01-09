#!/bin/bash
subset=$1
[ -z "$subset" ] && echo "Usage: $0 <subset>" && exit 1

. .env

cd input || exit 1

drawingsCsv="$subset"/drawings_popular.csv
echo "url,personcode" > "$drawingsCsv"

artistsCsv="$subset"/artists_popular.csv
echo "personcode,name,nationality,drawings" > "$artistsCsv"

dataset_id=$(mysql -uroot -h 127.0.0.1 -p"$MYSQL_PASSWORD" -P33061 -NB duckguessr -e \
  "select id from datasets where name='$subset-ml'")

datasetFileName=inducks-drawings-by-artist-${subset/_/-}.zip
metadataFileName=${datasetFileName/.zip/-metadata.zip}

rm -rf "$datasetFileName" "$metadataFileName"
rm -rf temp && mkdir temp

i=0
mysql -uroot -h 127.0.0.1 -p"$MYSQL_PASSWORD" -P33061 -NB duckguessr -e \
  "select sitecode_url, personcode from datasets_entryurls where dataset_id=$dataset_id" | \
  while read -r sitecode_url personcode; do
    artistDir=temp/"$personcode"
    mkdir -p "$artistDir"
    cp "$(echo $sitecode_url | sed "s~^~full/~")" "$artistDir"/$i.jpg
    echo "$sitecode_url,$personcode" >> "$drawingsCsv"
    ((i++))
  done

mysql -uroot -h 127.0.0.1 -p"$MYSQL_PASSWORD" -P33061 -NB duckguessr -e \
  "select replace(personcode, ' ', '_') as personcode, count(*) as drawings
   from datasets_entryurls
   where dataset_id=$dataset_id
   group by personcode" | \
  while read -r personcode drawings; do
    mysql -uroot -h 127.0.0.1 -p"$MYSQL_PASSWORD" -P64000 -NB coa -e \
      "select replace(personcode, ' ', '_') as personcode,
              replace(fullname, ' ', '_')  as fullname,
              nationalitycountrycode from inducks_person where personcode='$personcode'" | \
      while read -r personcode fullname nationalitycountrycode; do
        echo "${personcode/_/ },$fullname,$nationalitycountrycode,$drawings" >> "$artistsCsv"
      done
  done

(cd temp && zip -rq "../$datasetFileName" . && rm -rf temp)

(cd "$subset" && zip "../$metadataFileName" artists_popular.csv drawings_popular.csv)

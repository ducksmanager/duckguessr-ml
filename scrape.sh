#!/bin/bash
[ -z "$1" ] && echo "Usage: $0 <subset>" && exit 1

subset=$1
subsetDirectory="input/inducks-drawings-by-artist-$subset-metadata"
mkdir -p "$subsetDirectory"

drawingsCsv="$subsetDirectory/drawings.csv"
artistsCsv="$subsetDirectory/artists.csv"

echo "personcode,name,nationality" > "$artistsCsv"
echo "url,personcode" > "$drawingsCsv"

. .env

mysql -uroot -h 127.0.0.1 -p"$MYSQL_PASSWORD" -P64000 -NB coa < query.sql | \
  while read -r url personcode nationality name; do
    personcode=${personcode/_/ }
    name=${name/_/ }
    ! grep -qF "$name" "$artistsCsv" && echo "$personcode,$name,$nationality" >> "$artistsCsv"
    ! grep -qF "$url" "$drawingsCsv" && echo "$url,$personcode" >> "$drawingsCsv"
    ! [ -f input/full/"$url" ] \
      && curl https://res.cloudinary.com/dl7hskxab/image/upload/inducks-covers/"$url" -s --create-dirs -o input/full/"$url" \
      && echo "Downloaded $url" || echo "Skipped $url"
  done

echo "Removing corrupted images..."
python remove_corrupted_images.py

tail -n +2 "$drawingsCsv" | while IFS=',' read -r url _; do
  if [ ! -f "$(echo $url | sed "s~^~input/full/~")" ]; then
    grep -vF "$url" "$drawingsCsv" > "${drawingsCsv}2"
    mv "${drawingsCsv}2" "$drawingsCsv"
  fi
done


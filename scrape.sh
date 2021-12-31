#!/bin/bash
[ -z "$1" ] && echo "Usage: $0 <subset>" && exit 1
[ ! -d "input/$1" ] && echo "input/$1 does not exist" && exit 1

subset=$1

. .env

cd input
drawingsCsv="$subset"/drawings_popular.csv
artistsCsv="$subset"/artists_popular.csv

echo "personcode,name,nationality,drawings" > "$artistsCsv"
echo "url,personcode" > "$drawingsCsv"

imageRoot="https://inducks.org/hr.php?normalsize=1&image=https://outducks.org/"
#imageRoot=https://res.cloudinary.com/dl7hskxab/image/upload/inducks-covers/

mysql -uroot -h 127.0.0.1 -p"$MYSQL_PASSWORD" -P64000 -NB coa < ../query.sql | \
  while read -r personcode name nationality urls drawings; do
    personcode=${personcode/_/ }
    name=${name/_/ }
    ! grep -qF "$name" "$artistsCsv" && echo "$personcode,$name,$nationality,$drawings" >> "$artistsCsv"
    for url in $(echo "$urls" | tr "|" "\n"); do
      ! grep -qF "$url" "$drawingsCsv" && echo "$url,$personcode" >> "$drawingsCsv"
      ! [ -f full/"$url" ] \
        && curl "$imageRoot/$url" -s --create-dirs -o full/"$url" \
        && echo "Downloaded $url" || echo "Skipped $url"
    done
done

echo "Removing corrupted images..."
(cd .. && python remove_corrupted_images.py)

tail -n +2 "$drawingsCsv" | while IFS=',' read -r url _; do
  if [ ! -f "$(echo $url | sed "s~^~full/~")" ]; then
    grep -vF "$url" "$drawingsCsv" > "${drawingsCsv}2"
    mv "${drawingsCsv}2" "$drawingsCsv"
  fi
done

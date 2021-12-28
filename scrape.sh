#!/bin/bash
[ -z "$1" ] && echo "Usage: $0 <subset>" && exit 1

subset=$1
subsetDirectory="input/inducks-drawings-by-artist-$subset-metadata"
mkdir -p "$subsetDirectory"

echo "personcode,name,nationality" > "$subsetDirectory"/artists.csv
echo "url,personcode" > "$subsetDirectory"/drawings.csv

. .env

mysql -uroot -h 127.0.0.1 -p"$MYSQL_PASSWORD" -P64000 -NB coa < query.sql | \
  while read -r url personcode nationality name; do
    personcode=${personcode/_/ }
    name=${name/_/ }
    ! grep -qF "$name" "$subsetDirectory"/artists.csv && echo "$personcode,$name,$nationality" >> "$subsetDirectory"/artists.csv
    ! grep -qF "$url" "$subsetDirectory"/drawings.csv && echo "$url,$personcode" >> "$subsetDirectory"/drawings.csv
    ! [ -f input/full/"$url" ] \
      && curl https://res.cloudinary.com/dl7hskxab/image/upload/inducks-covers/"$url" -s --create-dirs -o input/full/"$url" \
      && echo "Downloaded $url"
done

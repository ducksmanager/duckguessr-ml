#!/bin/bash
[ -z "$1" ] && echo "Usage: $0 <subset>" && exit 1

subset=$1

echo "personcode,name,nationality" > datasets/"$subset"/artists.csv
echo "url,personcode" > datasets/"$subset"/drawings.csv

. .env

mysql -uroot -h 127.0.0.1 -p"$MYSQL_PASSWORD" -P64000 -NB coa < query.sql | \
  while read -r url personcode nationality name; do
    personcode=${personcode/_/ }
    name=${name/_/ }
    ! grep -qF "$name" datasets/"$subset"/artists.csv && echo "$personcode,$name,$nationality" >> datasets/"$subset"/artists.csv
    ! grep -qF "$url" datasets/"$subset"/drawings.csv && echo "$url,$personcode" >> datasets/"$subset"/drawings.csv
    ! [ -f datasets/full/"$url" ] \
      && curl https://res.cloudinary.com/dl7hskxab/image/upload/inducks-covers/"$url" -s --create-dirs -o datasets/full/"$url" \
      && echo "Downloaded $url"
done

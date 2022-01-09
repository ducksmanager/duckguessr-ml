#!/bin/bash
[ -z "$1" ] && echo "Usage: $0 <subset>" && exit 1
[ ! -f "input/$1/query.sql" ] && echo "input/$1/query.sql does not exist" && exit 1

subset=$1

. .env

cd input

dataset_id=$(mysql -uroot -h 127.0.0.1 -p"$MYSQL_PASSWORD" -P33061 -NB duckguessr -e \
  "select id from datasets where name='$subset-ml'")

mysql -uroot -h 127.0.0.1 -p"$MYSQL_PASSWORD" -P33061 -NB duckguessr -e \
  "delete from datasets_entryurls where dataset_id=$dataset_id"

#imageRoot="https://inducks.org/hr.php?normalsize=1&image=https://outducks.org/"
imageRoot=https://res.cloudinary.com/dl7hskxab/image/upload/inducks-covers/

mysql -uroot -h 127.0.0.1 -p"$MYSQL_PASSWORD" -P64000 -NB coa < "$subset/query.sql" | \
  while read -r personcode urls; do
    personcode=${personcode/_/ }
    for url in $(echo "$urls" | tr "|" "\n"); do
      result=$(mysql -uroot -h 127.0.0.1 -p"$MYSQL_PASSWORD" -P33061 -NB duckguessr -e \
        "select decision from entryurl_validations where decision <> 'ok' and sitecode_url='$url'") \
      && [ 'ok' != "$result" ] && [ '' != "$result" ] \
      && echo "Skipped $url (marked as invalid)" \
      && rm -f "full/$url" \
      && continue

      if [ -f full/"$url" ]; then
        echo "Skipped $url (already downloaded)"
      else
        curl "$imageRoot/$url" -s --create-dirs -o full/"$url" \
        && echo "Downloaded $url" \
        || echo "Skipped $url (could not download)" \
        && continue
      fi
      mysql -uroot -h 127.0.0.1 -p"$MYSQL_PASSWORD" -P33061 -NB duckguessr -e \
        "insert ignore into datasets_entryurls(dataset_id, sitecode_url, personcode) VALUES($dataset_id, '$url', '$personcode')"
    done
done

echo "Removing corrupted images..."
(cd .. && python remove_corrupted_images.py \
  | grep -Po '(?<=Removing input/full/).+' \
  | while read -r removedImage; do
    echo "Marking $removedImage as invalid"
    mysql -uroot -h 127.0.0.1 -p"$MYSQL_PASSWORD" -P33061 -NB duckguessr -e \
      "insert ignore into entryurl_validations(sitecode_url, decision) VALUES('$removedImage', 'no_drawing')"
  done
)

mysql -uroot -h 127.0.0.1 -p"$MYSQL_PASSWORD" -P33061 -NB duckguessr -e \
  "delete from datasets_entryurls where dataset_id=$dataset_id and sitecode_url in (select sitecode_url from entryurl_validations where decision='no_drawing')"

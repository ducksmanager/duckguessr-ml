CREATE OR REPLACE VIEW duckguessr_published_fr_recent_game AS
SELECT DISTINCT entryurl.id AS entryurl_id,
                storyjob.personcode
FROM inducks_issue issue
         INNER JOIN inducks_entry entry ON issue.issuecode = entry.issuecode
         INNER JOIN inducks_entryurl entryurl ON entry.entrycode = entryurl.entrycode
         INNER JOIN inducks_storyversion storyversion
                    ON entry.storyversioncode = storyversion.storyversioncode
         INNER JOIN inducks_story story ON storyversion.storycode = story.storycode
         INNER JOIN inducks_storyjob storyjob ON storyversion.storyversioncode = storyjob.storyversioncode
WHERE issue.publicationcode IN ('fr/MP', 'fr/PM', 'fr/SPG')
  AND oldestdate > '2010-00-00'
  AND sitecode = 'thumbnails3'
  AND kind = 'n'
  AND plotwritartink = 'a'
  AND personcode <> '?';

SELECT DISTINCT @dataset_id,
                GROUP_CONCAT(CONCAT(sitecode, '/', url) ORDER BY entryurl.id DESC SEPARATOR '|') AS entryurl_urls,
                storyjob.personcode
FROM duckguessr_published_fr_recent_game entryurl_ids
         INNER JOIN inducks_entryurl entryurl ON entryurl_ids.entryurl_id = entryurl.id
         INNER JOIN
     (SELECT artist_with_20_entries.personcode, nationalitycountrycode, fullname
      FROM duckguessr_published_fr_recent_game artist_with_20_entries
               INNER JOIN inducks_person person ON artist_with_20_entries.personcode = person.personcode
      GROUP BY artist_with_20_entries.personcode
      HAVING COUNT(*) >= 20
     ) AS person ON person.personcode = entryurl_ids.personcode
         INNER JOIN inducks_entry entry ON entryurl.entrycode = entry.entrycode
         INNER JOIN inducks_storyversion storyversion
                    ON entry.storyversioncode = storyversion.storyversioncode
         INNER JOIN inducks_story story ON storyversion.storycode = story.storycode
         INNER JOIN inducks_storyjob storyjob ON storyversion.storyversioncode = storyjob.storyversioncode
GROUP BY personcode;

DROP VIEW duckguessr_published_fr_recent_game;

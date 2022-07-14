CREATE OR REPLACE VIEW duckguessr_published_fr_recent_game_all AS
SELECT DISTINCT entryurl.id AS entryurl_id,
                storyjob.personcode
FROM inducks_issue issue
         INNER JOIN inducks_entry entry ON issue.issuecode = entry.issuecode
         INNER JOIN inducks_entryurl entryurl ON entry.entrycode = entryurl.entrycode
         INNER JOIN inducks_storyversion storyversion
                    ON entry.storyversioncode = storyversion.storyversioncode
         INNER JOIN inducks_storyjob storyjob ON storyversion.storyversioncode = storyjob.storyversioncode
WHERE issue.publicationcode IN ('fr/MP', 'fr/PM', 'fr/SPG', 'fr/JM')
  AND oldestdate >= '2001'
  AND sitecode = 'thumbnails3'
  AND kind = 'n'
  AND plotwritartink = 'a'
  AND 1 = (SELECT COUNT(distinct personcode)
           FROM inducks_storyjob
           WHERE storyversion.storyversioncode = inducks_storyjob.storyversioncode
             AND inducks_storyjob.plotwritartink IN ('a', 'i'))
  AND personcode <> '?';

CREATE OR REPLACE VIEW duckguessr_published_fr_recent_game AS
SELECT DISTINCT storyjob.personcode,
                sitecode,
                url,
                entryurl_id
FROM duckguessr_published_fr_recent_game_all entryurl_ids
         INNER JOIN inducks_entryurl entryurl ON entryurl_ids.entryurl_id = entryurl.id
         INNER JOIN inducks_entry entry USING (entrycode)
         INNER JOIN inducks_storyversion storyversion USING (storyversioncode)
         INNER JOIN inducks_story story ON storyversion.storycode = story.storycode
         INNER JOIN inducks_storyjob storyjob USING (storyversioncode)
         INNER JOIN
     (SELECT artist_with_2000s_entries.personcode, nationalitycountrycode, fullname
      FROM duckguessr_published_fr_recent_game_all artist_with_2000s_entries
               INNER JOIN inducks_person person ON artist_with_2000s_entries.personcode = person.personcode
      GROUP BY artist_with_2000s_entries.personcode
      HAVING COUNT(*) >= 20) AS artist_with_at_least_20_entries
     ON artist_with_at_least_20_entries.personcode = storyjob.personcode;

CREATE OR REPLACE VIEW duckguessr_published_fr_recent_artists AS
SELECT DISTINCT personcode
FROM duckguessr_published_fr_recent_game;

SELECT personcode,
       GROUP_CONCAT(DISTINCT CONCAT(sitecode, '/', url) ORDER BY entryurl_id DESC SEPARATOR '|' LIMIT
                    500) AS entryurl_urls
FROM duckguessr_published_fr_recent_game
GROUP BY personcode;


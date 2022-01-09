CREATE OR REPLACE VIEW duckguessr_us AS
SELECT DISTINCT entryurl.id AS entryurl_id,
                storyjob.personcode
FROM (
         SELECT id, entrycode
         FROM inducks_entryurl
         WHERE sitecode = 'thumbnails3'
     ) AS entryurl
         INNER JOIN inducks_entry entry ON entry.entrycode = entryurl.entrycode
         INNER JOIN inducks_storyversion storyversion
                    ON entry.storyversioncode = storyversion.storyversioncode
         INNER JOIN inducks_story story ON storyversion.storycode = story.storycode
         INNER JOIN inducks_storyjob storyjob ON storyversion.storyversioncode = storyjob.storyversioncode
         INNER JOIN inducks_person person ON storyjob.personcode = person.personcode
WHERE storyjob.plotwritartink = 'a'
  AND person.personcode <> '?'
  AND person.nationalitycountrycode = 'us';

SELECT REPLACE(person.personcode, ' ', '_')                   AS personcode,
       GROUP_CONCAT(CONCAT(sitecode, '/', url) SEPARATOR '|') AS entryurl_urls
FROM duckguessr_us
         INNER JOIN inducks_person person ON duckguessr_us.personcode = person.personcode
         INNER JOIN inducks_entryurl entryurl ON duckguessr_us.entryurl_id = entryurl.id
GROUP BY duckguessr_us.personcode
HAVING COUNT(*) >= 200
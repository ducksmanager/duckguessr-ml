CREATE OR REPLACE VIEW duckguessr_us AS
SELECT DISTINCT storyjob.personcode,
                sitecode,
                url,
                entryurl.id AS entryurl_id
FROM inducks_entryurl entryurl
INNER JOIN inducks_entry entry ON entry.entrycode = entryurl.entrycode
INNER JOIN inducks_storyversion storyversion
        ON entry.storyversioncode = storyversion.storyversioncode
INNER JOIN inducks_storyjob storyjob ON storyversion.storyversioncode = storyjob.storyversioncode
INNER JOIN inducks_person person ON storyjob.personcode = person.personcode
WHERE storyjob.plotwritartink = 'a'
  AND 1 = (SELECT COUNT(distinct personcode)
           FROM inducks_storyjob
           WHERE storyversion.storyversioncode = inducks_storyjob.storyversioncode
             AND inducks_storyjob.plotwritartink IN ('a', 'i'))
  AND person.personcode <> '?'
  AND person.nationalitycountrycode = 'us'
  AND sitecode = 'thumbnails3';

SELECT REPLACE(personcode, ' ', '_')                   AS personcode,
       GROUP_CONCAT(CONCAT(sitecode, '/', url) SEPARATOR '|' LIMIT 500) AS entryurl_urls
FROM duckguessr_us
GROUP BY duckguessr_us.personcode
HAVING COUNT(*) >= 200;
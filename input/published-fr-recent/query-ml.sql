CREATE OR REPLACE VIEW duckguessr_published_fr_recent AS
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
         INNER JOIN (
    SELECT personcode
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
      AND personcode <> '?'
    GROUP BY personcode
    HAVING COUNT(entryurl.id) > 20
) AS artists_published_in_recent_fr_issues ON storyjob.personcode = artists_published_in_recent_fr_issues.personcode
WHERE storyjob.plotwritartink = 'a';

SELECT REPLACE(person.personcode, ' ', '_')                                                       AS personcode,
       GROUP_CONCAT(CONCAT(sitecode, '/', url) ORDER BY entryurl.id DESC SEPARATOR '|' LIMIT 500) AS entryurl_urls
FROM duckguessr_published_fr_recent
         INNER JOIN inducks_person person ON duckguessr_published_fr_recent.personcode = person.personcode
         INNER JOIN inducks_entryurl entryurl ON duckguessr_published_fr_recent.entryurl_id = entryurl.id
GROUP BY duckguessr_published_fr_recent.personcode
HAVING COUNT(*) >= 200;

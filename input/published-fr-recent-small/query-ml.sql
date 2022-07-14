SELECT REPLACE(game_artist.personcode, ' ', '_') AS personcode,
   GROUP_CONCAT(
       DISTINCT CONCAT(sitecode, '/', url)
       ORDER BY entryurl.id DESC
       SEPARATOR '|'
       LIMIT 500
   )
                                                 AS entryurl_urls
FROM duckguessr_published_fr_recent_small_artists as game_artist
INNER JOIN inducks_storyjob storyjob USING (personcode)
INNER JOIN inducks_storyversion storyversion USING (storyversioncode)
INNER JOIN inducks_entry entry ON entry.storyversioncode = storyversion.storyversioncode
INNER JOIN inducks_entryurl entryurl ON entry.entrycode = entryurl.entrycode
WHERE sitecode = 'thumbnails3'
  AND plotwritartink = 'a'
  AND 1 = (SELECT COUNT(personcode)
           FROM inducks_storyjob
           WHERE storyversion.storyversioncode = inducks_storyjob.storyversioncode
             AND inducks_storyjob.plotwritartink IN ('a', 'i'))
  AND kind = 'n'
GROUP BY game_artist.personcode;
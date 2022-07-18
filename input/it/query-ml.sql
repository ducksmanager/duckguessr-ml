SELECT personcode,
       GROUP_CONCAT(DISTINCT CONCAT(sitecode, '/', url) ORDER BY entryurl_id DESC SEPARATOR '|') AS entryurl_urls
FROM duckguessr_it
GROUP BY personcode;
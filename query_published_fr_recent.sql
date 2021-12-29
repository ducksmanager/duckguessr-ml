create or replace view duckguessr_published_fr_recent as
select distinct entryurl.id as entryurl_id,
                storyjob.personcode
from (
         SELECT id, entrycode
         FROM inducks_entryurl
         WHERE sitecode = 'thumbnails3'
     ) as entryurl
         inner join inducks_entry entry on entry.entrycode = entryurl.entrycode
         inner join inducks_storyversion storyversion
                    on entry.storyversioncode = storyversion.storyversioncode
         inner join inducks_story story on storyversion.storycode = story.storycode
         inner join inducks_storyjob storyjob on storyversion.storyversioncode = storyjob.storyversioncode
         inner join (
            select personcode
            from inducks_issue issue
                     inner join inducks_entry entry on issue.issuecode = entry.issuecode
                     inner join inducks_entryurl entryurl on entry.entrycode = entryurl.entrycode
                     inner join inducks_storyversion storyversion
                                on entry.storyversioncode = storyversion.storyversioncode
                     inner join inducks_story story on storyversion.storycode = story.storycode
                     inner join inducks_storyjob storyjob on storyversion.storyversioncode = storyjob.storyversioncode
            where issue.publicationcode IN ('fr/MP', 'fr/PM', 'fr/SPG')
              and oldestdate > '2010-00-00'
              and sitecode = 'thumbnails3'
              and storyjob.plotwritartink = 'a'
              and personcode <> '?'
            group by personcode
        ) as artists_published_in_recent_fr_issues on storyjob.personcode = artists_published_in_recent_fr_issues.personcode
where storyjob.plotwritartink = 'a';

select replace(person.personcode, ' ', '_')                   as personcode,
       replace(person.fullname, ' ', '_')                     as fullname,
       person.nationalitycountrycode                          as nationalitycountrycode,
       group_concat(concat(sitecode, '/', url) separator '|') as entryurl_urls,
       count(*)                                               as drawings
from duckguessr_published_fr_recent
         inner join inducks_person person on duckguessr_published_fr_recent.personcode = person.personcode
         inner join inducks_entryurl entryurl on duckguessr_published_fr_recent.entryurl_id = entryurl.id
group by duckguessr_published_fr_recent.personcode
having count(*) >= 200
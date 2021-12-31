create or replace view duckguessr_us as
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
         inner join inducks_person person on storyjob.personcode = person.personcode
where storyjob.plotwritartink = 'a'
  and person.personcode <> '?'
  and person.nationalitycountrycode = 'us';

select replace(person.personcode, ' ', '_')                   as personcode,
       replace(person.fullname, ' ', '_')                     as fullname,
       person.nationalitycountrycode                          as nationalitycountrycode,
       group_concat(concat(sitecode, '/', url) separator '|') as entryurl_urls,
       count(*)                                               as drawings
from duckguessr_us
         inner join inducks_person person on duckguessr_us.personcode = person.personcode
         inner join inducks_entryurl entryurl on duckguessr_us.entryurl_id = entryurl.id
group by duckguessr_us.personcode
having count(*) >= 200
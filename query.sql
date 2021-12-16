select distinct concat(sitecode, '/', url)    as entryurl_url,
                replace(person.personcode, ' ', '_') as personcode,
                person.nationalitycountrycode as personnationality,
                replace(person.fullname, ' ', '_') as fullname
from (
         SELECT entrycode, url, sitecode, id
         FROM inducks_entryurl
         WHERE sitecode = 'thumbnails3'
     ) as entryurl
         inner join inducks_entry entry on entry.entrycode = entryurl.entrycode
         inner join inducks_storyversion storyversion
                    on entry.storyversioncode = storyversion.storyversioncode
         inner join inducks_story story on storyversion.storycode = story.storycode
         inner join inducks_storyjob storyjob on storyversion.storyversioncode = storyjob.storyversioncode
         inner join inducks_person person on storyjob.personcode = person.personcode
where position like 'p%'
  and person.personcode <> '?'
  and person.nationalitycountrycode = 'us'
  and storyjob.plotwritartink = 'a';

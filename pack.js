const archiver = require('archiver');
const {createObjectCsvWriter} = require('csv-writer');
const fs = require("fs");
const {connect} = require("./connect-to-dbs");

const args = process.argv.slice(2);
if (!args[0]) {
  console.error("Usage: $0 <subset>")
  process.exit(1)
}
const [datasetName] = args

const datasetDir = `input/${datasetName}/dataset`

const drawingsCsv = `input/${datasetName}/drawings_popular.csv`;
const drawingsCsvWriter = createObjectCsvWriter({
  path: drawingsCsv,
  header: [
    {id: 'url', title: 'url'},
    {id: 'personcode', title: 'personcode'}
  ]
});
const artistsCsv = `input/${datasetName}/artists_popular.csv`;
const artistsCsvWriter = createObjectCsvWriter({
  path: artistsCsv,
  header: [
    {id: 'personcode', title: 'personcode'},
    {id: 'name', title: 'name'},
    {id: 'nationality', title: 'nationality'},
    {id: 'drawings', title: 'drawings'}
  ]
});

const datasetFileName = `input/inducks-drawings-by-artist-${datasetName.replace(/_/, '-')}.zip`
const metadataFileName = `${datasetFileName.replace(/.zip/, '-metadata.zip')}`

for (const file of [datasetFileName, metadataFileName]) {
  if (fs.existsSync(file)) {
    fs.unlinkSync(file)
  }
}

if (fs.existsSync(datasetDir)) {
  fs.rmdirSync(datasetDir, {recursive: true})
}
fs.mkdirSync(datasetDir, {recursive: true})

const pack = () => {
  return new Promise(async (resolve) => {
    let i = 0
    const {coaConnection, dgConnection} = await connect()
    const [dataset] = await dgConnection.query(
      "select id from dataset where name=?",
      [`${datasetName}-ml`]
    )
    const datasetId = dataset.id
    const entryUrls = await dgConnection.query(
      ` select sitecode_url AS url, personcode
        from dataset_entryurl
        inner join entryurl_details using (sitecode_url)
        where dataset_id = ?`,
      [datasetId]
    )
    console.log('Copying image files...')
    for (const {url, personcode} of entryUrls) {
      const artistDir = `${datasetDir}/${personcode}`
      if (!fs.existsSync(artistDir)) {
        fs.mkdirSync(artistDir, {recursive: true})
      }
      fs.copyFileSync(`${url.replace(/^/, 'input/full/')}`, `${artistDir}/${i++}.${url.match(/[^.]+$/, '$1')[0]}`)
    }
    console.log('Creating CSVs...')
    await drawingsCsvWriter.writeRecords(entryUrls)

    const drawingsByArtist = (await dgConnection.query(`
        select REPLACE(personcode, ' ', '_') as personcode,
               COUNT(*)                      as drawings
        from dataset_entryurl
        inner join entryurl_details using (sitecode_url)
        where dataset_id = ?
        group by personcode
    `, [datasetId])).reduce((acc, {personcode, drawings}) => ({
      ...acc,
      [personcode]: drawings
    }), {})

    const artistDetails = await coaConnection.query(`
        select REPLACE(personcode, ' ', '_') as personcode,
               REPLACE(fullname, ' ', '_')   as name,
               nationalitycountrycode        AS nationality
        from inducks_person
        where personcode IN (?)
    `, [Object.keys(drawingsByArtist)])

    await artistsCsvWriter.writeRecords(artistDetails.map((artist) => ({
      ...artist,
      drawings: drawingsByArtist[artist.personcode]
    })))

    const doneZips = [];

    console.log('Zipping dataset...')
    const datasetZip = archiver('zip', {zlib: {level: 9}});
    const datasetOutput = fs.createWriteStream(datasetFileName);
    datasetOutput.on('close', function () {
      doneZips.push('dataset')
      if (doneZips.length === 2) {
        resolve('OK')
      }
    });
    datasetZip.pipe(datasetOutput)
    datasetZip.directory(`${datasetDir}/`, false)
    await datasetZip.finalize()

    console.log('Zipping metadata...')
    const metadataZip = archiver('zip', {zlib: {level: 9}});
    const metadataOutput = fs.createWriteStream(metadataFileName);
    metadataOutput.on('close', function () {
      doneZips.push('metadata')
      if (doneZips.length === 2) {
        resolve('OK')
      }
    });
    metadataZip.pipe(metadataOutput)
    metadataZip.file(drawingsCsv, {name: 'drawings_popular.csv'})
    metadataZip.file(artistsCsv, {name: 'artists_popular.csv'})
    await metadataZip.finalize()
  })
}

pack().then(() => {
  process.exit(0)
})

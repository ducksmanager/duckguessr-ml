const fs = require("fs");
const https = require("https");
const mmm = require('mmmagic'),
  Magic = mmm.Magic;
const {connect} = require("./connect-to-dbs");
const magic = new Magic(mmm.MAGIC_MIME_TYPE);

const args = process.argv.slice(2);
if (!args[0]) {
  console.error("Usage: $0 <subset>")
  process.exit(1)
}
const [datasetName] = args

const sqlQueryPath = `input/${datasetName}/query.sql`;
if (!fs.existsSync(sqlQueryPath)) {
  console.error(`${sqlQueryPath} does not exist`)
  process.exit(1)
}
const sqlMlQueryPath = sqlQueryPath.replace(/\.sql$/, '-ml.sql');
if (!fs.existsSync(sqlMlQueryPath)) {
  console.error(`${sqlMlQueryPath} does not exist`)
  process.exit(1)
}

// const imageRoot="https://inducks.org/hr.php?normalsize=1&image=https://outducks.org/"
const imageRoot = 'https://res.cloudinary.com/dl7hskxab/image/upload/inducks-covers/'


let datasetId

const addUrlToDataset = (dgConnection, personcode, url) => {
  const filePath = `input/full/${url}`;
  return new Promise((resolve) => {
    magic.detectFile(filePath, async (err, result) => {
      if (/^image\//.test(result)) {
        await dgConnection.query("insert ignore into datasets_entryurls(dataset_id, sitecode_url, personcode) VALUES(?, ?, ?)", [datasetId, url, personcode])
      } else {
        console.log(`Marking ${filePath} as invalid`)
        await dgConnection.query("insert ignore into entryurl_validations(sitecode_url, decision) VALUES(?, ?)", [url, 'no_drawing']);
        fs.unlinkSync(filePath)
      }
      resolve('OK')
    })
  })
}

const downloadAndAddUrlToDataset = (dgConnection, personcode, url) => {
  return new Promise(async (resolve, reject) => {
    const filePath = `input/full/${url}`;
    const isEntryurlInvalid = (await dgConnection.query("select decision from entryurl_validations where decision <> 'ok' and sitecode_url=?", [url])).length > 0;
    if (isEntryurlInvalid) {
      console.log(`Skipped ${url} (marked as invalid)`)
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath)
      }
      resolve('OK');
      return
    }
    if (fs.existsSync(filePath)) {
      addUrlToDataset(dgConnection, personcode, url).then(() => {
        console.log(`Skipped ${url} (already downloaded)`)
        resolve('OK');
      });
    } else {
      fs.mkdirSync(filePath, {recursive: true})
      fs.rmdirSync(filePath)
      const file = fs.createWriteStream(filePath);
      await https.get(`${imageRoot}/${url}`, async response => {
        response.pipe(file);
        addUrlToDataset(dgConnection, personcode, url).then(() => {
          console.log(`Downloaded ${url}`)
        })
        resolve('OK');
      }).on('error', () => {
        reject(`Skipped ${url} (could not download)`)
      });
    }
  })
}

const downloadDatasetFromQuery = (coaConnection, dgConnection) => {
  return new Promise(async (resolve) => {
    const [, data] = await coaConnection.query(fs.readFileSync(sqlMlQueryPath).toString());
    for (const {personcode, entryurl_urls} of data) {
      const urls = entryurl_urls.split('|')
      for (const url of urls) {
        await downloadAndAddUrlToDataset(dgConnection, personcode, url)
      }
    }
    resolve('OK')
  })
};

const scrape = async () => {
  const {coaConnection, dgConnection} = await connect()
  const [dataset] = await dgConnection.query("select id from datasets where name=?", [`${datasetName}-ml`])
  datasetId = dataset.id
  await dgConnection.query("delete from datasets_entryurls where dataset_id=?", [datasetId])
  await downloadDatasetFromQuery(coaConnection, dgConnection);
  await coaConnection.end();
  await dgConnection.end();
  process.exit(0)
}

scrape()

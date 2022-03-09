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
const [baseDatasetName] = args

for (const datasetSuffix of ['', '-ml']) {
  const sqlQueryPath = `input/${baseDatasetName}/query${datasetSuffix}.sql`;
  if (!fs.existsSync(sqlQueryPath)) {
    console.error(`${sqlQueryPath} does not exist`)
    process.exit(1)
  }
}

// const imageRoot="https://inducks.org/hr.php?normalsize=1&image=https://outducks.org/"
const imageRoot = 'https://res.cloudinary.com/dl7hskxab/image/upload/inducks-covers/'

const filePathRoot = 'input/full/'

const addUrlToDataset = (dgConnection, personcode, url, datasetId) => {
  const filePath = `${filePathRoot}${url}`;
  return new Promise((resolve, reject) => {
    magic.detectFile(filePath, async (err, result) => {
      if (url === 'thumbnails3/webusers/2018/05/fr_mp_0345p174_001.jpg') {
        debugger
      }
      if (/^image\//.test(result)) {
        await dgConnection.query(
          "insert ignore into dataset_entryurl(dataset_id, sitecode_url) VALUES(?, ?)",
          [datasetId, url]
        )
        await dgConnection.query(
          "insert ignore into entryurl_details(sitecode_url, personcode, decision) VALUES(?, ?, ?)",
          [url, personcode, null]
        )

        // Update the entryurl's personcode, in case a previous scrape stored it wrong
        await dgConnection.query(
          "update entryurl_details set personcode=? where sitecode_url = ?",
          [personcode, url]
        )
      } else {
        console.log(`Marking ${filePath.replace(filePathRoot, '')} as invalid`)
        await dgConnection.query(
          "delete from dataset_entryurl where sitecode_url = ?",
          [datasetId, url]
        )
        await dgConnection.query(
          "delete from entryurl_details where sitecode_url = ?",
          [url]
        )
        await dgConnection.query(
          "insert ignore into entryurl_details(sitecode_url, personcode, decision) VALUES(?, ?, ?)",
          [url, personcode, 'no_drawing']
        );
        if (fs.existsSync(filePath)) {
          fs.unlinkSync(filePath)
        }
        reject('Invalid')
      }
      resolve('OK')
    })
  })
}

const downloadAndAddUrlToDataset = (dgConnection, personcode, url, datasetId) => {
  return new Promise(async (resolve, reject) => {
    const filePath = `${filePathRoot}${url}`;
    const isEntryurlInvalid = (await dgConnection.query(
      "select decision from entryurl_details where (decision is not null and decision <> 'ok') and sitecode_url=?",
      [url]
    )).length > 0;
    if (isEntryurlInvalid) {
      console.log(`Skipped ${url} (marked as invalid)`)
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath)
      }
      resolve('OK');
      return
    }
    if (fs.existsSync(filePath)) {
      addUrlToDataset(dgConnection, personcode, url, datasetId).then(() => {
        console.log(`Skipped ${url} (already downloaded)`)
        resolve('OK');
      });
    } else {
      fs.mkdirSync(filePath, {recursive: true})
      fs.rmdirSync(filePath)
      const file = fs.createWriteStream(filePath);
      await https.get(`${imageRoot}/${url}`, async response => {
        response.pipe(file);
        addUrlToDataset(dgConnection, personcode, url, datasetId)
          .then(() => {
            console.log(`Downloaded ${url}`)
          })
          .catch(() => {
          })
          .finally(() => {
            resolve('OK');
          })
      }).on('error', () => {
        reject(`Skipped ${url} (could not download)`)
      });
    }
  })
}

const downloadDatasetFromQuery = (coaConnection, dgConnection, datasetSuffix, datasetId) => {
  return new Promise(async (resolve) => {
    const response = (await coaConnection.query(fs.readFileSync(`input/${baseDatasetName}/query${datasetSuffix}.sql`).toString()));
    const data = response[0].personcode ? response : response[response.length-1]
    for (const {personcode, entryurl_urls} of data) {
      const urls = entryurl_urls.split('|')
      for (const url of urls) {
        await downloadAndAddUrlToDataset(dgConnection, personcode, url, datasetId)
      }
    }
    resolve('OK')
  })
};

const scrape = async () => {
  const {coaConnection, dgConnection} = await connect()
  for (const datasetSuffix of ['', '-ml']) {
    const [dataset] = await dgConnection.query("select id from dataset where name=?", [`${baseDatasetName}${datasetSuffix}`])
    await dgConnection.query("delete from dataset_entryurl where dataset_id=?", [dataset.id])
    await downloadDatasetFromQuery(coaConnection, dgConnection, datasetSuffix, dataset.id);
  }
  await coaConnection.end();
  await dgConnection.end();
  process.exit(0)
}

scrape()

import fs from "fs";
import https from "https";
import mmm from 'mmmagic';
import { PrismaClient } from "~duckguessr";
import { PrismaClient as PrismaCoaClient } from "~prisma-clients/client_coa";

const { Magic, MAGIC_MIME_TYPE } = mmm;

const magic = new Magic(MAGIC_MIME_TYPE);

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

const prisma = new PrismaClient();
const prismaCoa = new PrismaCoaClient();

const imageRoot = 'https://res.cloudinary.com/dl7hskxab/image/upload/inducks-covers/'
const filePathRoot = 'input/full/'

const addUrlToDataset = async (personcode: string, url: string, datasetId: number) => {
  const filePath = `${filePathRoot}${url}`;
  return new Promise<void>((resolve, reject) => {
    magic.detectFile(filePath, async (_err, result) => {
      if (/^image\//.test(result as string)) {
        await prisma.datasetEntryurl.create({
          data: {
            datasetId,
            sitecodeUrl: url
          }
        })
        await prisma.entryurlDetails.upsert({
          where: {
            sitecodeUrl: url
          },
          create: {
            sitecodeUrl: url,
            personcode,
            decision: 'ok'
          },
          update: {
            personcode,
            decision: 'ok'
          }
        });

        // Update the entryurl's personcode, in case a previous scrape stored it wrong
        await prisma.entryurlDetails.update({
          where: {
            sitecodeUrl: url
          },
          data: {
            personcode
          }
        })
      } else {
        console.log(`Marking ${filePath.replace(filePathRoot, '')} as invalid`)
        await prisma.datasetEntryurl.deleteMany({
          where: {
            sitecodeUrl: url
          }
        })
        await prisma.entryurlDetails.deleteMany({
          where: {
            sitecodeUrl: url
          }
        })
        await prisma.entryurlDetails.upsert({
          where: {
            sitecodeUrl: url
          },
          create: {
            sitecodeUrl: url,
            personcode,
            decision: 'no_drawing'
          },
          update: {
            personcode,
            decision: 'no_drawing'
          }
        });
        if (fs.existsSync(filePath)) {
          fs.unlinkSync(filePath)
        }
        reject('Invalid')
      }
      resolve()
    })
  })
}

const downloadAndAddUrlToDataset = async (personcode: string, url: string, datasetId: number) =>
  new Promise<void>(async (resolve, reject) => {
    const filePath = `${filePathRoot}${url}`;
    const isEntryurlInvalid = (await prisma.entryurlDetails.count(
      {
        where: {
          sitecodeUrl: url,
          decision: {
            not: 'ok',
          }
        }
      })) > 0;
    if (isEntryurlInvalid) {
      console.log(`Skipped ${url} (marked as invalid)`)
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath)
      }
      resolve();
      return
    }
    if (fs.existsSync(filePath)) {
      addUrlToDataset(personcode, url, datasetId).then(() => {
        console.log(`Skipped ${url} (already downloaded)`)
        resolve();
      }).catch(() => {
        resolve()
      });
    } else {
      fs.mkdirSync(filePath, { recursive: true })
      fs.rmdirSync(filePath)
      const file = fs.createWriteStream(filePath);
      https.get(`${imageRoot}/${url}`, async response => {
        response.pipe(file);
        response.on('end', () => {
          addUrlToDataset(personcode, url, datasetId)
            .then(() => {
              console.log(`Downloaded ${url}`)
            })
            .catch(() => {
              console.log(`Could not download ${url}`)
            })
            .finally(() => {
              resolve();
            })
        });
      }).on('error', () => {
        reject(`Skipped ${url} (could not download)`)
      });
    }
  });

const downloadDatasetFromQuery = async (datasetSuffix: string, datasetId: number) =>
  new Promise<void>(async (resolve) => {
    const data: { personcode: string, entryurl_urls: string }[] = (await prismaCoa.$queryRawUnsafe(fs.readFileSync(`input/${baseDatasetName}/query${datasetSuffix}.sql`).toString()));
    for (const { personcode, entryurl_urls } of data) {
      const urls = entryurl_urls.split('|')
      for (const url of urls) {
        await downloadAndAddUrlToDataset(personcode, url, datasetId)
      }
    }
    resolve()
  })


const scrape = async () => {
  for (const datasetSuffix of ['', '-ml']) {
    const { id: datasetId } = await prisma.dataset.findFirstOrThrow({
      select: {
        id: true,
      },
      where: {
        name: `${baseDatasetName}${datasetSuffix}`,
      },
    });
    await prisma.datasetEntryurl.deleteMany({
      where: {
        datasetId
      }
    })
    await downloadDatasetFromQuery(datasetSuffix, datasetId);
  }
}

await scrape()

import {
  existsSync,
  unlinkSync,
  mkdirSync,
  rmdirSync,
  readFileSync,
  createWriteStream,
} from "fs";
import { fileTypeFromFile } from "file-type";
import { PrismaClient as PrismaCoaClient } from "~prisma-clients/client_coa";
import { PrismaClient } from "~duckguessr/api/prisma/client_duckguessr";

import { connect } from "http2";
import { pipeline } from "stream";
import { promisify } from "util";

const pipelineAsync = promisify(pipeline);

const args = process.argv.slice(2);
if (!args[0]) {
  console.error(`Usage: ${process.argv[1]} <subset>`);
  process.exit(1);
}
const [baseDatasetName] = args;

for (const datasetSuffix of ["", "-ml"]) {
  const sqlQueryPath = `input/${baseDatasetName}/query${datasetSuffix}.sql`;
  if (!existsSync(sqlQueryPath)) {
    console.error(`${sqlQueryPath} does not exist`);
    process.exit(1);
  }
}

const session = connect("https://res.cloudinary.com");
session.on("error", (err) => console.error(err));

const prisma = new PrismaClient();
const prismaCoa = new PrismaCoaClient();

const imageRoot = "/dl7hskxab/image/upload/inducks-covers/";
const filePathRoot = "input/full/";

const downloadImage = async (url: string, filePath: string) =>
  new Promise<void>((resolve, reject) => {
    const req = session
      .request({ ":path": url })
      .on("response", (headers) => {
        if (headers[":status"] !== 200) {
          reject(new Error(`Failed to get '${url}' (${headers[":status"]})`));
          return;
        }

        pipelineAsync(req, createWriteStream(filePath))
          .then(() => resolve())
          .catch((error) => reject(error));
      })

      .on("error", (error) => reject(error))
      .end();
  });

const addUrlToDataset = async (
  personcode: string,
  url: string,
  datasetId: number,
) =>
   new Promise<void>((resolve, reject) => {
    const filePath = `${filePathRoot}${url}`;
    fileTypeFromFile(filePath).then(async (result) => {
      if (result?.mime && /^image\//.test(result.mime)) {
        await prisma.entryurlDetails.upsert({
          where: {
            sitecodeUrl: url,
          },
          create: {
            sitecodeUrl: url,
            personcode,
            decision: "ok",
          },
          update: {
            personcode,
            decision: "ok",
          },
        });
        await prisma.datasetEntryurl.create({
          data: {
            datasetId,
            sitecodeUrl: url,
          },
        });

        // Update the entryurl's personcode, in case a previous scrape stored it wrong
        await prisma.entryurlDetails.update({
          where: {
            sitecodeUrl: url,
          },
          data: {
            personcode,
          },
        });
      } else {
        console.log(`Marking ${url} as invalid`);
        await prisma.datasetEntryurl.deleteMany({
          where: {
            sitecodeUrl: url,
          },
        });
        await prisma.entryurlDetails.deleteMany({
          where: {
            sitecodeUrl: url,
          },
        });
        await prisma.entryurlDetails.upsert({
          where: {
            sitecodeUrl: url,
          },
          create: {
            sitecodeUrl: url,
            personcode,
            decision: "no_drawing",
          },
          update: {
            personcode,
            decision: "no_drawing",
          },
        });
        if (existsSync(filePath)) {
          unlinkSync(filePath);
        }
        reject("Invalid");
      }
      resolve();
    });
  });

const downloadAndAddUrlToDataset = async (
  personcode: string,
  url: string,
  datasetId: number,
) =>
  new Promise<void>(async (resolve, reject) => {
    const filePath = `${filePathRoot}${url}`;
    const isEntryurlInvalid =
      (await prisma.entryurlDetails.count({
        where: {
          sitecodeUrl: url,
          decision: {
            not: "ok",
          },
        },
      })) > 0;
    if (isEntryurlInvalid) {
      console.log(`Skipped ${url} (marked as invalid)`);
      if (existsSync(filePath)) {
        unlinkSync(filePath);
      }
      resolve();
      return;
    }
    if (existsSync(filePath)) {
      addUrlToDataset(personcode, url, datasetId)
        .then(() => {
          console.log(`Skipped ${url} (already downloaded)`);
          resolve();
        })
        .catch(() => {
          resolve();
        });
    } else {
      mkdirSync(filePath, { recursive: true });
      rmdirSync(filePath);

      downloadImage(`${imageRoot}/${url}`, filePath).then(() => {
        addUrlToDataset(personcode, url, datasetId)
          .then(() => {
            console.log(`Downloaded ${url}`);
          })
          .catch(() => {
            console.log(`Could not download ${url}`);
          })
          .finally(() => {
            resolve();
          });
      });
    }
  });

const downloadDatasetFromQuery = async (
  datasetSuffix: string,
  datasetId: number,
) =>
  new Promise<void>(async (resolve) => {
    console.info(`Downloading dataset ${baseDatasetName}${datasetSuffix}`);
    const sqlQueries = readFileSync(
      `input/${baseDatasetName}/query${datasetSuffix}.sql`,
    )
      .toString()
      .split(";")
      .map((query) => query.replace(/\n/g, " ").trim())
      .filter((query) => !!query);

    let idx = 0;
    let data: { personcode: string; entryurl_urls: string }[] = [];
    for (const sqlQuery of sqlQueries) {
      console.info(`Running query: ${sqlQuery}`);
      const result = await prismaCoa.$queryRawUnsafe(sqlQuery);
      if (idx === sqlQueries.length - 1) {
        data = result as typeof data;
      }
    }
    for (const { personcode, entryurl_urls } of data) {
      const urls = entryurl_urls.split("|");
      for (const url of urls) {
        await downloadAndAddUrlToDataset(personcode, url, datasetId);
      }
    }
    resolve();
  });

const scrape = async () => {
  for (const datasetSuffix of ["", "-ml"]) {
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
        datasetId,
      },
    });
    await downloadDatasetFromQuery(datasetSuffix, datasetId);
  }
  session.close();
};

await scrape();

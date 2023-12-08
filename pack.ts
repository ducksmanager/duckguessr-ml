import archiver from "archiver";
import { createObjectCsvWriter } from "csv-writer";
import { existsSync, mkdirSync, rmdirSync, unlinkSync, copyFileSync, createWriteStream } from "fs";
import { PrismaClient } from "~duckguessr/api/prisma/client_duckguessr";
import { PrismaClient as PrismaCoaClient } from "~prisma-clients/client_coa";

const args = process.argv.slice(2);
if (!args[0]) {
  console.error("Usage: $0 <subset>");
  process.exit(1);
}

const prisma = new PrismaClient();
const prismaCoa = new PrismaCoaClient();

const [datasetName] = args;

const datasetDir = `input/${datasetName}/dataset`;

const drawingsCsv = `input/${datasetName}/drawings_popular.csv`;
const drawingsCsvWriter = createObjectCsvWriter({
  path: drawingsCsv,
  header: [
    { id: "url", title: "url" },
    { id: "personcode", title: "personcode" },
  ],
});
const artistsCsv = `input/${datasetName}/artists_popular.csv`;
const artistsCsvWriter = createObjectCsvWriter({
  path: artistsCsv,
  header: [
    { id: "personcode", title: "personcode" },
    { id: "name", title: "name" },
    { id: "nationality", title: "nationality" },
    { id: "drawings", title: "drawings" },
  ],
});

const datasetFileName = `input/inducks-drawings-by-artist-${datasetName.replace(
  /_/,
  "-"
)}.zip`;
const metadataFileName = `${datasetFileName.replace(/.zip/, "-metadata.zip")}`;

for (const file of [datasetFileName, metadataFileName]) {
  if (existsSync(file)) {
    unlinkSync(file);
  }
}

if (existsSync(datasetDir)) {
  rmdirSync(datasetDir, { recursive: true });
}
mkdirSync(datasetDir, { recursive: true });

const pack = async () => {
  let i = 0;
  const { id: datasetId } = await prisma.dataset.findUniqueOrThrow({
    select: {
      id: true,
    },
    where: {
      name: `${datasetName}-ml`,
    },
  });

  const entryUrls: { url: string; personcode: string }[] =
    await prisma.$queryRaw`
        select sitecode_url AS url, personcode
        from dataset_entryurl
        inner join entryurl_details using (sitecode_url)
        where dataset_id = ${datasetId}`;
  console.log("Copying image files...");
  for (const { url, personcode } of entryUrls) {
    const artistDir = `${datasetDir}/${personcode}`;
    if (!existsSync(artistDir)) {
      mkdirSync(artistDir, { recursive: true });
    }
    copyFileSync(
      `input/full/${url}`,
      `${artistDir}/${i++}.${url.split(".").pop()}`
    );
  }
  console.log("Creating CSVs...");
  await drawingsCsvWriter.writeRecords(entryUrls);

  const drawingsByArtist = (
    (await prisma.$queryRaw`
        select REPLACE(personcode, ' ', '_') as personcode,
               COUNT(*)                      as drawings
        from dataset_entryurl
        inner join entryurl_details using (sitecode_url)
        where dataset_id = ${datasetId}
        group by personcode
    `) as { personcode: string; drawings: number }[]
  ).reduce<Record<string, number>>(
    (acc, { personcode, drawings }) => ({
      ...acc,
      [personcode]: drawings,
    }),
    {}
  );

  const artistDetails = (
    await prismaCoa.inducks_person.findMany({
      select: {
        personcode: true,
        fullname: true,
        nationalitycountrycode: true,
      },
      where: {
        personcode: {
          in: Object.keys(drawingsByArtist),
        },
      },
    })
  ).map((artist) => ({
    personcode: artist.personcode.replace(/ /g, "_"),
    name: artist.fullname?.replace(/ /g, "_"),
    nationality: artist.nationalitycountrycode,
  }));

  await artistsCsvWriter.writeRecords(
    artistDetails.map((artist) => ({
      ...artist,
      drawings: drawingsByArtist[artist.personcode],
    }))
  );

  for (const { name, fileName } of [
    { name: "dataset", fileName: datasetFileName },
    { name: "metadata", fileName: metadataFileName },
  ]) {
    console.log(`Zipping ${name}...`);
    const zip = archiver("zip", { zlib: { level: 9 } });
    const stream = createWriteStream(fileName);
    stream.on("close", () => {
      console.log(`${name} zip size: ${zip.pointer()} total bytes`);
    });
    zip.pipe(stream);

    if (name === "dataset") {
      zip.directory(`${datasetDir}/`, false);
    } else {
      zip.file(drawingsCsv, { name: "drawings_popular.csv" });
      zip.file(artistsCsv, { name: "artists_popular.csv" });
    }

    await zip.finalize();
  }
};

await pack();

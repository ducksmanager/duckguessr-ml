const tf = require("@tensorflow/tfjs");
const tfn = require("@tensorflow/tfjs-node");
const fs = require("fs");
const CsvReadableStream = require('csv-reader');

const dataset = 'published-fr-recent'
const imagePath = 'input/published-fr-recent/dataset/DJi/3201.jpg';

const modelFile = tfn.io.fileSystem(`tfjs_model/${dataset}/model.json`);

let artists = []

fs.createReadStream(`input/${dataset}/artists_popular.csv`, 'utf8')
  .pipe(new CsvReadableStream({parseNumbers: true, parseBooleans: true, trim: true, asObject: true}))
  .on('data', function (row) {
    artists.push(row)
  })
  .on('end', function () {
    tf.loadLayersModel(modelFile).then(model => {
      fs.readFile(imagePath, (_, input) => {
        const buffer = tfn.node.decodeImage(input, 3)
        let image = buffer.resizeBilinear([224, 224]).div(tf.scalar(255))
        image = tf.expandDims(image, 0)
        image = tf.cast(image, 'float32').div(255)
        const prediction = model.predict(image);
        prediction.array().then(([predictionArray]) => {
          const predictionProbability = Math.max(...predictionArray);
          const predictionIndex = predictionArray.indexOf(predictionProbability);
          console.log(`${artists[predictionIndex].personcode}: probability of ${predictionProbability}`)
        })
      })
    })
  });

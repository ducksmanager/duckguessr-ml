const tf = require("@tensorflow/tfjs");
const tfn = require("@tensorflow/tfjs-node");
const sharp = require('sharp');

const modelFile = tfn.io.fileSystem("tfjs_model/us/model.json");

tf.loadLayersModel(modelFile).then(model => {
  sharp('datasets/full/thumbnails3/fr/gb/fr_gb_0004p_001.jpg')
    .rotate()
    .resize(224, 224)
    .toBuffer().then(data => {
    let image = tfn.node.decodeImage(data, 0)
    image = tf.expandDims(image, 0);
    image = tf.cast(image, 'float32').div(255)
    const prediction = model.predict(image);
    prediction.array().then(([predictionArray]) => {
      const predictionProbability = Math.max(...predictionArray);
      const predictionIndex = predictionArray.indexOf(predictionProbability);
      console.log(`${predictionIndex}: probability of ${predictionProbability}`)
    })
  })

})

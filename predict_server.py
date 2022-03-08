from keras.preprocessing import image
from tensorflow import keras
from flask import Flask, request, Response
from urllib import request as urlrequest
from PIL import Image
from io import BytesIO
from waitress import serve

import json
import numpy as np
import pandas as pd
import time

dataset = 'published-fr-recent'

images_dir = f'input/{dataset}/dataset'
artists = pd.read_csv(f'input/{dataset}/artists_popular.csv')
artists_top = artists[artists['drawings'] >= 200]
artists_top_name = artists_top['personcode'].values
model = keras.models.load_model(f'{dataset}.keras')

app = Flask(__name__)

cloudinary_root = 'https://res.cloudinary.com/dl7hskxab/image/upload/v1623338718/inducks-covers/'


@app.route('/', methods=['GET'])
def alive():
    return Response("I''m alive", 200)


@app.route('/predict', methods=['POST'])
def predict():
    start_time = time.time()
    request_data = request.get_json()
    url = request_data["url"]

    if request_data["dataset"] != 'published-fr-recent':
        return Response('Invalid dataset', 400)

    url = f"{cloudinary_root}{url}"
    res = urlrequest.urlopen(url).read()

    test_image = Image.open(BytesIO(res)).resize((224, 224))

    # Predict artist
    test_image = image.img_to_array(test_image)
    test_image /= 255.
    test_image = np.expand_dims(test_image, axis=0)

    prediction = model.predict(test_image)
    prediction_probability = np.amax(prediction)
    prediction_idx = np.argmax(prediction)
    if prediction_idx >= len(artists_top_name):
        message = f'Index {prediction_idx} is not in {artists_top_name}'
        print(message)
        return Response(message, 400)

    predicted_artist = artists_top_name[prediction_idx].replace('_', ' ')

    print(f"Predicted {predicted_artist} in {time.time() - start_time}s")
    return Response(json.dumps({
        "url": url,
        "predicted": predicted_artist,
        "predictionProbability": prediction_probability * 100
    }))


if __name__ == "__main__":
    serve(app, host="0.0.0.0", port=8080)

from keras.preprocessing import *
from tensorflow import keras
import numpy as np
import matplotlib.pyplot as plt
import random
import os
import pandas as pd

artists = pd.read_csv('datasets/us/artists.csv')
artists_top = artists[artists['drawings'] >= 200].reset_index()
artists_top_name = artists_top.personcode.tolist()

images_dir = 'datasets/temp'

n = 3
fig, axes = plt.subplots(1, n, figsize=(25, 10))

model = keras.models.load_model('us.keras')

for i in range(n):
    random_artist = random.choice(artists_top_name)
    random_image = random.choice(os.listdir(os.path.join(images_dir, random_artist)))
    random_image_file = os.path.join(images_dir, random_artist, random_image)

    # Original image

    test_image = image.load_img(random_image_file, target_size=(224, 224))

    # Predict artist
    test_image = image.img_to_array(test_image)
    test_image /= 255.
    test_image = np.expand_dims(test_image, axis=0)

    prediction = model.predict(test_image)
    prediction_probability = np.amax(prediction)
    prediction_idx = np.argmax(prediction)

    title = "Actual artist = {}\nPredicted artist = {}\nPrediction probability = {:.2f} %" \
        .format(random_artist.replace('_', ' '), artists_top_name[prediction_idx].replace('_', ' '),
                prediction_probability * 100)

    # Print image
    axes[i].imshow(plt.imread(random_image_file))
    axes[i].set_title(title)
    axes[i].axis('off')

plt.show()

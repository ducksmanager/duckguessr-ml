import os
import PIL
from pathlib import Path

path = Path("temp").rglob("**/*.jpg")
for img_p in path:
    try:
        img = PIL.Image.open(img_p)
    except PIL.UnidentifiedImageError:
        print("Removing " + img_p.name)
        os.remove(img_p)

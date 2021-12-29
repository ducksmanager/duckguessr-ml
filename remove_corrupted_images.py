import os
from PIL import Image, UnidentifiedImageError
from pathlib import Path

path = Path("datasets/full").rglob("**/*.*")
for img_p in path:
    try:
        img = Image.open(img_p)
    except UnidentifiedImageError:
        print("Removing " + img_p.name)
        os.remove(img_p)

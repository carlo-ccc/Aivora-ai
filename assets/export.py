import io, os, zipfile, sys

MODEL = r"E:\selfGit\Aivora-ai\assets\models\food_classifier.tflite"      # 改成你的真实路径
OUT   = r"E:\selfGit\Aivora-ai\assets\models"        # 导出目录

os.makedirs(OUT, exist_ok=True)

with open(MODEL, "rb") as f:
    data = f.read()

sig = b"PK\x03\x04"  # zip local file header
pos = 0
found = False

while True:
    i = data.find(sig, pos)
    if i < 0:
        break

    bio = io.BytesIO(data[i:])
    if zipfile.is_zipfile(bio):
        with zipfile.ZipFile(bio) as z:
            z.extractall(OUT)
            print("Extracted zip at offset:", i)
            print("Files:", z.namelist())
        found = True
        break

    pos = i + 1

if not found:
    print("No embedded zip found. 该模型可能没有把 labels 打包进 tflite，或打包方式不同。")

import os
import fiftyone as fo
import fiftyone.zoo as foz

# paksa lokasi download di dalam project
os.environ["FIFTYONE_HOME"] = os.path.abspath("ml_training/fiftyone")

classes = [
    "Person",
    "Book",
    "Mobile phone",
    "Laptop",
    "Computer keyboard",
    "Backpack",
    "Suitcase",
    "Bottle",
    "Envelope",
    "Handbag",
    "Plastic bag",
    "Table",
]

dataset = foz.load_zoo_dataset(
    "open-images-v7",
    split="train",
    label_types=["detections"],
    classes=classes,
    max_samples=500,
    dataset_name="open-images-v7-background",
)

output_dir = os.path.abspath("ml_training/dataset/raw/Background")
os.makedirs(output_dir, exist_ok=True)
dataset.export(
    export_dir=output_dir,
    dataset_type=fo.types.ImageDirectory,
    overwrite=True,
)

print("Download selesai")

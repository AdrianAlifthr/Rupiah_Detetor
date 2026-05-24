import os
import random
from pathlib import Path

from PIL import Image
import matplotlib.pyplot as plt


def check_background_dataset(
    folder: str,
    sample_count: int = 24,
    cols: int = 6,
) -> None:
    folder_path = Path(folder)
    if not folder_path.exists():
        raise FileNotFoundError(f"Folder tidak ditemukan: {folder_path}")

    image_exts = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
    files = [p for p in folder_path.iterdir() if p.suffix.lower() in image_exts]

    print(f"Total file gambar: {len(files)}")
    if not files:
        print("Tidak ada gambar untuk dicek.")
        return

    sample_count = min(sample_count, len(files))
    samples = random.sample(files, sample_count)

    # Validate images and collect sizes
    sizes = []
    invalid_files = []
    for p in files:
        try:
            with Image.open(p) as img:
                img.verify()
            with Image.open(p) as img:
                sizes.append(img.size)
        except Exception:
            invalid_files.append(p.name)

    if invalid_files:
        print(f"File rusak/tidak bisa dibaca: {len(invalid_files)}")
        print("Contoh:", ", ".join(invalid_files[:10]))

    if sizes:
        w = [s[0] for s in sizes]
        h = [s[1] for s in sizes]
        print(f"Resolusi min: {min(w)}x{min(h)}")
        print(f"Resolusi max: {max(w)}x{max(h)}")

    # Show sample grid
    rows = (sample_count + cols - 1) // cols
    fig, axes = plt.subplots(rows, cols, figsize=(cols * 2.2, rows * 2.2))
    axes = axes.flatten() if isinstance(axes, (list, tuple)) is False else axes

    for ax, p in zip(axes, samples):
        with Image.open(p) as img:
            ax.imshow(img.convert("RGB"))
        ax.set_title(p.name, fontsize=7)
        ax.axis("off")

    for ax in axes[len(samples) :]:
        ax.axis("off")

    plt.tight_layout()
    output_path = folder_path / "_background_samples_grid.png"
    plt.savefig(output_path, dpi=150)
    print(f"Grid sample disimpan: {output_path}")
    plt.show()


if __name__ == "__main__":
    check_background_dataset("ml_training/dataset/raw/Background")

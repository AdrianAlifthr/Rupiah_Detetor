"""
=============================================================================
FILE: 01_data_preparation.py
FUNGSI: Mempersiapkan dan mengaugmentasi dataset uang rupiah
=============================================================================

CARA PAKAI:
  1. Buat folder: dataset/raw/Rp1000/, dataset/raw/Rp2000/, dst.
  2. Masukkan foto uang ke masing-masing folder
  3. Jalankan: python 01_data_preparation.py
  4. Hasil akan tersimpan di: dataset/processed/

STRUKTUR FOLDER YANG DIBUTUHKAN:
  dataset/
    raw/
      Rp1000/     ← masukkan foto uang Rp1.000 di sini
      Rp2000/
      Rp5000/
      Rp10000/
      Rp20000/
      Rp50000/
      Rp100000/
            Background/ ← foto non-uang (meja, lantai, tangan, dll.)
"""

import os
import shutil
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter
import matplotlib.pyplot as plt

# =============================================================================
# KONFIGURASI — ubah sesuai kebutuhan
# =============================================================================

# Semua kelas (denominasi) yang akan dikenali aplikasi
# Nama folder harus PERSIS sama dengan ini
CLASSES = [
    "Rp1000",
    "Rp2000",
    "Rp5000",
    "Rp10000",
    "Rp20000",
    "Rp50000",
    "Rp100000",
    "Background",
]

# Ukuran gambar yang akan dipakai model (224x224 adalah standar MobileNet)
IMAGE_SIZE = (224, 224)

# Berapa banyak gambar augmentasi per 1 gambar asli
# Jika punya 100 foto, dengan AUGMENT_PER_IMAGE=5 akan jadi 500 foto
AUGMENT_PER_IMAGE = 5

# Pembagian data: 80% training, 20% validasi
TRAIN_SPLIT = 0.8

# Path folder
RAW_DIR = Path("ml_training/dataset/raw")
PROCESSED_DIR = Path("ml_training/dataset/processed")

# =============================================================================
# FUNGSI AUGMENTASI
# =============================================================================


def augment_image(image: Image.Image) -> Image.Image:
    """
    Fungsi ini mengubah 1 gambar menjadi versi yang sedikit berbeda.
    Tujuannya: supaya model belajar dari berbagai kondisi foto.

    Augmentasi yang dilakukan (dipilih secara acak):
    - Rotasi: memutar gambar sedikit (-25 s/d +25 derajat)
    - Kecerahan: membuat gambar lebih terang atau lebih gelap
    - Kontras: mengubah ketajaman warna
    - Flip horizontal: membalik gambar
    - Blur ringan: mensimulasikan foto yang sedikit buram
    """
    # Pilih satu operasi secara acak
    operation = random.choice(
        ["rotate", "brightness", "contrast", "flip", "blur", "combined"]
    )

    if operation == "rotate":
        # Putar gambar -25 sampai +25 derajat
        angle = random.uniform(-25, 25)
        image = image.rotate(angle, expand=False, fillcolor=(0, 0, 0))

    elif operation == "brightness":
        # Ubah kecerahan: 0.5 = gelap, 1.5 = terang
        factor = random.uniform(0.5, 1.5)
        enhancer = ImageEnhance.Brightness(image)
        image = enhancer.enhance(factor)

    elif operation == "contrast":
        # Ubah kontras: 0.5 = pucat, 1.5 = tajam
        factor = random.uniform(0.5, 1.5)
        enhancer = ImageEnhance.Contrast(image)
        image = enhancer.enhance(factor)

    elif operation == "flip":
        # Balik gambar secara horizontal
        image = image.transpose(Image.FLIP_LEFT_RIGHT)

    elif operation == "blur":
        # Tambahkan sedikit blur
        image = image.filter(ImageFilter.GaussianBlur(radius=random.uniform(0.5, 1.5)))

    elif operation == "combined":
        # Gabungan: rotasi + ubah kecerahan
        angle = random.uniform(-15, 15)
        image = image.rotate(angle, expand=False, fillcolor=(0, 0, 0))
        factor = random.uniform(0.7, 1.3)
        enhancer = ImageEnhance.Brightness(image)
        image = enhancer.enhance(factor)

    return image


def process_single_image(img_path: Path, output_path: Path, augment: bool = False):
    """
    Memproses 1 gambar:
    1. Buka gambar
    2. Ubah ke RGB (kalau PNG transparant, dll.)
    3. Resize ke 224x224
    4. Simpan

    Parameter augment=True akan menambahkan variasi sebelum disimpan.
    """
    try:
        with Image.open(img_path) as img:
            # Konversi ke RGB (menghapus channel alpha jika ada)
            img = img.convert("RGB")

            # Augmentasi jika diminta
            if augment:
                img = augment_image(img)

            # Resize ke ukuran standar
            img = img.resize(IMAGE_SIZE, Image.LANCZOS)

            # Simpan
            img.save(output_path, "JPEG", quality=95)

        return True
    except Exception as e:
        print(f"  ⚠️  Gagal proses {img_path.name}: {e}")
        return False


# =============================================================================
# PROSES UTAMA
# =============================================================================


def prepare_dataset():
    """
    Fungsi utama yang memproses semua gambar.

    Langkah-langkah:
    1. Baca semua gambar dari folder raw/
    2. Augmentasi untuk memperbanyak data
    3. Bagi jadi train (80%) dan val (20%)
    4. Simpan ke folder processed/
    """

    print("=" * 60)
    print("  PERSIAPAN DATASET UANG RUPIAH")
    print("=" * 60)

    # Buat folder output
    for split in ["train", "val"]:
        for cls in CLASSES:
            folder = PROCESSED_DIR / split / cls
            folder.mkdir(parents=True, exist_ok=True)

    total_train = 0
    total_val = 0

    # Proses setiap kelas (denominasi)
    for cls in CLASSES:
        raw_folder = RAW_DIR / cls

        # Cek apakah folder ada
        if not raw_folder.exists():
            print(f"\n⚠️  Folder tidak ditemukan: {raw_folder}")
            print(f"   Buat folder dan masukkan foto uang {cls}")
            continue

        # Ambil semua file gambar
        image_files = (
            list(raw_folder.glob("*.jpg"))
            + list(raw_folder.glob("*.jpeg"))
            + list(raw_folder.glob("*.png"))
        )

        if len(image_files) == 0:
            print(f"\n⚠️  Tidak ada gambar di folder {cls}")
            continue

        print(f"\n📁 Memproses {cls}: {len(image_files)} foto asli")

        # Acak urutan file
        random.shuffle(image_files)

        # Bagi jadi train dan validasi
        split_idx = int(len(image_files) * TRAIN_SPLIT)
        train_files = image_files[:split_idx]
        val_files = image_files[split_idx:]

        counter = 0

        # ---- Proses file TRAINING ----
        for img_path in train_files:
            # Simpan gambar asli
            out_path = PROCESSED_DIR / "train" / cls / f"{cls}_{counter:04d}.jpg"
            if process_single_image(img_path, out_path, augment=False):
                counter += 1

            # Buat versi augmentasi
            for aug_idx in range(AUGMENT_PER_IMAGE):
                out_path = (
                    PROCESSED_DIR
                    / "train"
                    / cls
                    / f"{cls}_{counter:04d}_aug{aug_idx}.jpg"
                )
                if process_single_image(img_path, out_path, augment=True):
                    counter += 1

        train_count = counter
        total_train += train_count

        # ---- Proses file VALIDASI (tanpa augmentasi) ----
        val_counter = 0
        for img_path in val_files:
            out_path = PROCESSED_DIR / "val" / cls / f"{cls}_val_{val_counter:04d}.jpg"
            if process_single_image(img_path, out_path, augment=False):
                val_counter += 1

        total_val += val_counter
        print(f"   ✅ Train: {train_count} | Val: {val_counter}")

    # Tampilkan ringkasan
    print("\n" + "=" * 60)
    print("  RINGKASAN DATASET")
    print("=" * 60)
    print(f"  Total Training : {total_train} gambar")
    print(f"  Total Validasi : {total_val} gambar")
    print(f"  Total Semua    : {total_train + total_val} gambar")
    print(f"\n  Dataset tersimpan di: {PROCESSED_DIR.absolute()}")
    print("=" * 60)


def visualize_samples():
    """
    Menampilkan contoh gambar dari setiap kelas.
    Berguna untuk memastikan dataset sudah benar.
    """
    fig, axes = plt.subplots(2, 7, figsize=(20, 6))
    fig.suptitle("Contoh Gambar Dataset", fontsize=14)

    for col, cls in enumerate(CLASSES):
        for row, split in enumerate(["train", "val"]):
            folder = PROCESSED_DIR / split / cls
            images = list(folder.glob("*.jpg"))

            if images:
                img = Image.open(random.choice(images))
                axes[row, col].imshow(img)
                axes[row, col].set_title(f"{cls}\n({split})", fontsize=8)
                axes[row, col].axis("off")

    plt.tight_layout()
    plt.savefig("../output/dataset_samples.png", dpi=150)
    print("\n📊 Contoh gambar disimpan di: output/dataset_samples.png")
    plt.show()


# =============================================================================
# JALANKAN
# =============================================================================

if __name__ == "__main__":
    # Install dependencies jika belum ada:
    # pip install pillow numpy matplotlib

    prepare_dataset()

    # Tampilkan sampel visual (opsional, perlu matplotlib)
    try:
        Path("../output").mkdir(exist_ok=True)
        visualize_samples()
    except Exception as e:
        print(f"\n(Tidak bisa tampilkan visualisasi: {e})")

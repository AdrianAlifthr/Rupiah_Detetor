"""
=============================================================================
FILE: ml_training/scripts/run_full_pipeline.py
FUNGSI: Jalankan SEMUA langkah ML dalam 1 script (all-in-one)

CARA PAKAI (dari folder ml_training/):
  python3 scripts/run_full_pipeline.py

Script ini menggabungkan:
  1. Cek dan validasi dataset
  2. Augmentasi gambar
  3. Training model (2 fase)
  4. Evaluasi + confusion matrix
  5. Export ke TFLite
  6. Panduan copy ke Flutter

Cocok untuk dijalankan setelah dataset sudah ada di dataset/raw/
=============================================================================
"""

import os
import sys
import json
import time
import shutil
import random
import numpy as np
import matplotlib

matplotlib.use("Agg")  # tanpa GUI — aman di semua environment
import matplotlib.pyplot as plt
from pathlib import Path
from PIL import Image, ImageEnhance, ImageFilter

# Tambahkan parent path agar import lebih mudah
sys.path.insert(0, str(Path(__file__).parent))

# =============================================================================
# KONFIGURASI GLOBAL
# =============================================================================

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
IMAGE_SIZE = (224, 224)
BATCH_SIZE = 16  # Turunkan ke 8 jika RAM kurang dari 8GB
AUGMENT_PER = 5  # Variasi augmentasi per foto asli
TRAIN_SPLIT = 0.8
EPOCHS_P1 = 10  # Fase 1: latih lapisan baru
EPOCHS_P2 = 20  # Fase 2: fine-tuning
LR_P1 = 1e-3
LR_P2 = 1e-4
CONF_THRESH = 0.70  # Confidence minimum untuk dianggap "terdeteksi"

# Path — relatif dari folder ml_training/
BASE_DIR = Path(__file__).parent.parent
RAW_DIR = BASE_DIR / "dataset" / "raw"
PROCESSED_DIR = BASE_DIR / "dataset" / "processed"
OUTPUT_DIR = BASE_DIR / "output"

# Warna terminal
R = "\033[31m"
G = "\033[32m"
Y = "\033[33m"
B = "\033[34m"
C = "\033[36m"
BOLD = "\033[1m"
DIM = "\033[2m"
NC = "\033[0m"


def h(title):
    print(f"\n{BOLD}{B}{'━'*56}{NC}")
    print(f"{BOLD}{B}  {title}{NC}")
    print(f"{BOLD}{B}{'━'*56}{NC}")


def ok(msg):
    print(f"{G}  ✓  {msg}{NC}")


def info(msg):
    print(f"{C}  ℹ  {msg}{NC}")


def warn(msg):
    print(f"{Y}  ⚠  {msg}{NC}")


def err(msg):
    print(f"{R}  ✗  {msg}{NC}")
    sys.exit(1)


# =============================================================================
# FASE 0: VALIDASI DATASET
# =============================================================================


def validate_dataset():
    h("FASE 0 — VALIDASI DATASET")

    IMAGE_EXT = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
    counts = {}
    has_error = False

    for cls in CLASSES:
        folder = RAW_DIR / cls
        if not folder.exists():
            warn(f"Folder tidak ada: {folder}")
            counts[cls] = 0
            has_error = True
            continue

        imgs = [f for f in folder.iterdir() if f.suffix.lower() in IMAGE_EXT]
        counts[cls] = len(imgs)

        if len(imgs) == 0:
            warn(f"{cls}: kosong!")
            has_error = True
        elif len(imgs) < 30:
            warn(f"{cls}: hanya {len(imgs)} gambar (minimum 30)")
        else:
            ok(f"{cls}: {len(imgs)} gambar")

    total = sum(counts.values())
    print(f"\n  Total: {BOLD}{total} gambar{NC}")

    if has_error:
        print(f"""
  {Y}Ada kelas yang kosong atau kurang data!{NC}

  Pastikan kamu sudah menjalankan:
    ./scripts/00_setup_kaggle_and_download.sh

  Atau tambahkan foto manual ke:
    dataset/raw/{{nama_kelas}}/
""")
        resp = input("  Lanjutkan training meski ada kelas kosong? (y/n): ")
        if resp.lower() != "y":
            sys.exit(0)

    return counts


# =============================================================================
# FASE 1: AUGMENTASI DATASET
# =============================================================================


def augment_image(img: Image.Image) -> Image.Image:
    """Terapkan 1 operasi augmentasi acak ke gambar"""
    op = random.choice(["rotate", "brightness", "contrast", "flip", "blur", "combined"])

    if op == "rotate":
        img = img.rotate(random.uniform(-25, 25), fillcolor=(0, 0, 0))
    elif op == "brightness":
        img = ImageEnhance.Brightness(img).enhance(random.uniform(0.5, 1.5))
    elif op == "contrast":
        img = ImageEnhance.Contrast(img).enhance(random.uniform(0.5, 1.5))
    elif op == "flip":
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    elif op == "blur":
        img = img.filter(ImageFilter.GaussianBlur(radius=random.uniform(0.5, 1.5)))
    elif op == "combined":
        img = img.rotate(random.uniform(-15, 15), fillcolor=(0, 0, 0))
        img = ImageEnhance.Brightness(img).enhance(random.uniform(0.7, 1.3))

    return img


def prepare_dataset():
    h("FASE 1 — AUGMENTASI DATASET")

    IMAGE_EXT = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
    t0 = time.time()
    total_train, total_val = 0, 0

    for cls in CLASSES:
        raw_folder = RAW_DIR / cls
        if not raw_folder.exists():
            warn(f"Lewati {cls} — folder tidak ada")
            continue

        imgs = [f for f in raw_folder.iterdir() if f.suffix.lower() in IMAGE_EXT]
        if not imgs:
            warn(f"Lewati {cls} — tidak ada gambar")
            continue

        random.shuffle(imgs)
        split_idx = int(len(imgs) * TRAIN_SPLIT)
        train_files = imgs[:split_idx]
        val_files = imgs[split_idx:] or imgs[:1]  # minimal 1 untuk val

        train_dir = PROCESSED_DIR / "train" / cls
        val_dir = PROCESSED_DIR / "val" / cls
        train_dir.mkdir(parents=True, exist_ok=True)
        val_dir.mkdir(parents=True, exist_ok=True)

        counter = 0

        # ── Proses training (asli + augmentasi) ──
        for img_path in train_files:
            try:
                with Image.open(img_path) as im:
                    im = im.convert("RGB").resize(IMAGE_SIZE, Image.LANCZOS)

                    # Simpan gambar asli
                    im.save(train_dir / f"{cls}_{counter:05d}.jpg", quality=92)
                    counter += 1

                    # Buat AUGMENT_PER variasi
                    for _ in range(AUGMENT_PER):
                        aug = augment_image(im.copy())
                        aug.save(train_dir / f"{cls}_{counter:05d}.jpg", quality=92)
                        counter += 1
            except Exception as e:
                warn(f"Gagal proses {img_path.name}: {e}")

        # ── Proses validasi (asli saja, tanpa augmentasi) ──
        val_count = 0
        for img_path in val_files:
            try:
                with Image.open(img_path) as im:
                    im = im.convert("RGB").resize(IMAGE_SIZE, Image.LANCZOS)
                    im.save(val_dir / f"{cls}_val_{val_count:04d}.jpg", quality=92)
                    val_count += 1
            except Exception as e:
                warn(f"Gagal proses {img_path.name}: {e}")

        total_train += counter
        total_val += val_count
        ok(f"{cls}: train={counter}  val={val_count}")

    elapsed = time.time() - t0
    print(f"\n  Total training : {BOLD}{total_train}{NC}")
    print(f"  Total validasi : {BOLD}{total_val}{NC}")
    print(f"  Waktu          : {elapsed:.1f}s")


# =============================================================================
# FASE 2: TRAINING MODEL
# =============================================================================


def train_model():
    h("FASE 2 — TRAINING MODEL (MobileNetV2)")

    # Import TensorFlow di sini — lebih lambat tapi memastikan tidak error
    # jika TF belum terinstall saat script dimuat
    try:
        import tensorflow as tf
        from tensorflow.keras.applications import MobileNetV2
        from tensorflow.keras import layers, models, callbacks
        from tensorflow.keras.preprocessing.image import ImageDataGenerator
    except ImportError:
        err("TensorFlow belum terinstall!\nJalankan: pip3 install tensorflow")

    print(f"  TensorFlow version: {tf.__version__}")

    # ── Load Data ──
    info("Loading dataset...")

    dg = lambda: ImageDataGenerator(rescale=1.0 / 255)
    kw = dict(
        target_size=IMAGE_SIZE,
        batch_size=BATCH_SIZE,
        class_mode="categorical",
        classes=CLASSES,
    )

    train_gen = dg().flow_from_directory(PROCESSED_DIR / "train", shuffle=True, **kw)
    val_gen = dg().flow_from_directory(PROCESSED_DIR / "val", shuffle=False, **kw)

    ok(f"Training: {train_gen.samples} gambar")
    ok(f"Validasi: {val_gen.samples} gambar")

    # Simpan class indices
    OUTPUT_DIR.mkdir(exist_ok=True)
    with open(OUTPUT_DIR / "class_indices.json", "w") as f:
        json.dump({str(v): k for k, v in train_gen.class_indices.items()}, f, indent=2)

    # ── Bangun Model ──
    info("Membangun model MobileNetV2 + Transfer Learning...")

    base = MobileNetV2(
        input_shape=(*IMAGE_SIZE, 3), include_top=False, weights="imagenet"
    )
    base.trainable = False

    model = models.Sequential(
        [
            base,
            layers.GlobalAveragePooling2D(),
            layers.BatchNormalization(),
            layers.Dense(128, activation="relu"),
            layers.Dropout(0.3),
            layers.Dense(len(CLASSES), activation="softmax"),
        ]
    )

    model.compile(
        optimizer=tf.keras.optimizers.Adam(LR_P1),
        loss="categorical_crossentropy",
        metrics=["accuracy"],
    )

    total_params = model.count_params()
    ok(f"Model siap: {total_params:,} parameter")

    # ── Callback Helpers ──
    def make_callbacks(ckpt_name, patience=5):
        return [
            callbacks.ModelCheckpoint(
                str(OUTPUT_DIR / ckpt_name),
                monitor="val_accuracy",
                save_best_only=True,
                verbose=0,
            ),
            callbacks.EarlyStopping(
                monitor="val_accuracy",
                patience=patience,
                restore_best_weights=True,
                verbose=1,
            ),
            callbacks.ReduceLROnPlateau(
                monitor="val_loss", factor=0.5, patience=3, min_lr=1e-7, verbose=1
            ),
        ]

    # ════════════════════════════════════
    # FASE 1: latih hanya lapisan baru
    # ════════════════════════════════════
    print(
        f"\n  {BOLD}[Fase 1/2] Latih lapisan klasifikasi ({EPOCHS_P1} epoch maks){NC}"
    )

    h1 = model.fit(
        train_gen,
        epochs=EPOCHS_P1,
        validation_data=val_gen,
        callbacks=make_callbacks("best_p1.keras", patience=5),
    )

    best_p1 = max(h1.history["val_accuracy"])
    ok(f"Fase 1 selesai — val_accuracy: {best_p1:.2%}")

    # ════════════════════════════════════
    # FASE 2: fine-tune 50 lapisan terakhir
    # ════════════════════════════════════
    print(
        f"\n  {BOLD}[Fase 2/2] Fine-tuning lapisan dalam ({EPOCHS_P2} epoch maks){NC}"
    )

    base.trainable = True
    freeze_until = len(base.layers) - 50
    for i, layer in enumerate(base.layers):
        layer.trainable = i >= freeze_until

    model.compile(
        optimizer=tf.keras.optimizers.Adam(LR_P2),
        loss="categorical_crossentropy",
        metrics=["accuracy"],
    )

    h2 = model.fit(
        train_gen,
        epochs=EPOCHS_P2,
        validation_data=val_gen,
        callbacks=make_callbacks("best_p2.keras", patience=7),
    )

    best_p2 = max(h2.history["val_accuracy"])
    ok(f"Fase 2 selesai — val_accuracy: {best_p2:.2%}")

    # ── Plot Training History ──
    _plot_history(h1, h2)

    return model, h1, h2, val_gen


def _plot_history(h1, h2):
    """Simpan grafik akurasi dan loss"""
    acc = h1.history["accuracy"] + h2.history["accuracy"]
    val_acc = h1.history["val_accuracy"] + h2.history["val_accuracy"]
    loss = h1.history["loss"] + h2.history["loss"]
    val_los = h1.history["val_loss"] + h2.history["val_loss"]
    p1_end = len(h1.history["accuracy"])

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13, 4))

    for ax, y_train, y_val, title in [
        (ax1, acc, val_acc, "Akurasi"),
        (ax2, loss, val_los, "Loss"),
    ]:
        ax.plot(y_train, label="Training", color="#2196F3", lw=2)
        ax.plot(y_val, label="Validasi", color="#FF9800", lw=2)
        ax.axvline(x=p1_end, color="gray", ls="--", label="Mulai Fase 2")
        ax.set_title(title, fontsize=12)
        ax.set_xlabel("Epoch")
        ax.legend()
        ax.grid(alpha=0.3)

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / "training_history.png", dpi=150, bbox_inches="tight")
    ok("Grafik training disimpan: output/training_history.png")
    plt.close()


# =============================================================================
# FASE 3: EXPORT KE TFLITE
# =============================================================================


def export_tflite(model):
    h("FASE 3 — EXPORT KE TFLITE")

    import tensorflow as tf

    info("Mengkonversi model ke format TFLite...")

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    # DEFAULT optimisation = dynamic range quantization
    # Ukuran model berkurang ~4x, kecepatan naik, akurasi hampir sama
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    tflite_model = converter.convert()

    tflite_path = OUTPUT_DIR / "rupiah_model.tflite"
    with open(tflite_path, "wb") as f:
        f.write(tflite_model)

    size_mb = tflite_path.stat().st_size / 1024 / 1024
    ok(f"Model disimpan: {tflite_path}")
    ok(f"Ukuran model  : {size_mb:.2f} MB")

    # Simpan labels.txt
    labels_path = OUTPUT_DIR / "labels.txt"
    labels_path.write_text("\n".join(CLASSES))
    ok(f"Labels disimpan: {labels_path}")


# =============================================================================
# FASE 4: EVALUASI MODEL
# =============================================================================


def evaluate_model(model, val_gen):
    h("FASE 4 — EVALUASI MODEL")

    from sklearn.metrics import classification_report, confusion_matrix
    import seaborn as sns

    info("Menjalankan prediksi pada data validasi...")
    y_prob = model.predict(val_gen, verbose=1)
    y_pred = np.argmax(y_prob, axis=1)
    y_true = val_gen.classes

    acc = np.mean(y_pred == y_true)
    ok(f"Akurasi Keseluruhan: {acc:.2%}")

    # Classification report
    report = classification_report(y_true, y_pred, target_names=CLASSES)
    print("\n  Laporan per Kelas:\n")
    for line in report.split("\n"):
        print(f"    {line}")

    # Simpan laporan
    report_path = OUTPUT_DIR / "evaluation_report.txt"
    report_path.write_text(f"Akurasi: {acc:.2%}\n\n{report}")
    ok(f"Laporan disimpan: {report_path}")

    # Confusion Matrix
    cm = confusion_matrix(y_true, y_pred)
    cm_norm = cm.astype("float") / cm.sum(axis=1, keepdims=True)

    fig, axes = plt.subplots(1, 2, figsize=(16, 6))
    for ax, data, fmt, title in [
        (axes[0], cm, "d", "Confusion Matrix (Jumlah)"),
        (axes[1], cm_norm, ".1%", "Confusion Matrix (Persen)"),
    ]:
        sns.heatmap(
            data,
            annot=True,
            fmt=fmt,
            cmap="Blues",
            xticklabels=CLASSES,
            yticklabels=CLASSES,
            ax=ax,
        )
        ax.set_title(title, fontsize=11)
        ax.set_xlabel("Prediksi")
        ax.set_ylabel("Asli")
        ax.tick_params(axis="x", rotation=45)

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / "confusion_matrix.png", dpi=150, bbox_inches="tight")
    ok("Confusion matrix disimpan: output/confusion_matrix.png")
    plt.close()

    return acc


# =============================================================================
# MAIN — JALANKAN SEMUA FASE
# =============================================================================


def main():
    start = time.time()

    print(f"\n{BOLD}{'═'*56}{NC}")
    print(f"{BOLD}  RUPIAH DETECTOR — FULL ML PIPELINE{NC}")
    print(f"{BOLD}{'═'*56}{NC}")
    print(f"  Dataset  : {RAW_DIR}")
    print(f"  Output   : {OUTPUT_DIR}")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # ── Jalankan semua fase ──
    validate_dataset()
    prepare_dataset()
    model, h1, h2, val_gen = train_model()
    export_tflite(model)
    final_acc = evaluate_model(model, val_gen)

    elapsed = time.time() - start
    mins = int(elapsed // 60)
    secs = int(elapsed % 60)

    h("SELESAI! 🎉")
    print(f"""
  Akurasi akhir : {BOLD}{final_acc:.2%}{NC}
  Total waktu   : {mins}m {secs}s

  File yang dihasilkan:
    output/rupiah_model.tflite   ← model untuk Flutter
    output/labels.txt            ← daftar kelas
    output/training_history.png  ← grafik training
    output/confusion_matrix.png  ← analisis kesalahan
    output/evaluation_report.txt ← laporan akurasi

  {BOLD}Langkah selanjutnya (copy ke Flutter):{NC}
    cp output/rupiah_model.tflite ../../flutter_app/assets/model/
    cp output/labels.txt          ../../flutter_app/assets/model/

  {BOLD}Lalu jalankan Flutter:{NC}
    cd ../../flutter_app
    flutter run
""")


if __name__ == "__main__":
    main()

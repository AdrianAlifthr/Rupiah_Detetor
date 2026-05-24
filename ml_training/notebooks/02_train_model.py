"""
=============================================================================
FILE: 02_train_model.py
FUNGSI: Melatih model CNN untuk mengenali uang rupiah
=============================================================================

CARA PAKAI:
  1. Pastikan 01_data_preparation.py sudah dijalankan
  2. Jalankan: python 02_train_model.py
  3. Model tersimpan di: output/rupiah_model.tflite
  4. Copy file .tflite ke folder Flutter: flutter_app/assets/model/

PENJELASAN SINGKAT MACHINE LEARNING:
  - Kita pakai MobileNetV2: arsitektur CNN yang sudah dilatih 1 juta+ gambar
  - Teknik ini disebut "Transfer Learning" — model tidak belajar dari nol
  - Kita hanya tambahkan lapisan terakhir untuk kenali 7 denominasi rupiah
  - Hasilnya: akurasi tinggi dengan data yang lebih sedikit dan training lebih cepat
"""

import os
import json
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path

# TensorFlow untuk machine learning
import tensorflow as tf

# Tampilkan GPU yang terdeteksi dan aktifkan memory growth jika ada
gpus = tf.config.list_physical_devices("GPU")
if gpus:
    for gpu in gpus:
        try:
            tf.config.experimental.set_memory_growth(gpu, True)
        except RuntimeError:
            # Memory growth harus di-set sebelum GPU dipakai
            pass
    gpu_names = []
    for gpu in gpus:
        details = tf.config.experimental.get_device_details(gpu)
        gpu_names.append(details.get("device_name", gpu.name))
    print("GPU terdeteksi:", ", ".join(gpu_names))
else:
    print("GPU tidak terdeteksi, training akan memakai CPU.")
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras import layers, models, callbacks
from tensorflow.keras.preprocessing.image import ImageDataGenerator

# =============================================================================
# KONFIGURASI TRAINING
# =============================================================================

# Kelas sesuai folder dataset (HARUS sama urutan dengan labels.txt)
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

# Ukuran gambar input (harus 224x224 untuk MobileNetV2)
IMAGE_SIZE = (224, 224)
BATCH_SIZE = 16  # Jumlah gambar per batch. Turunkan ke 8 jika RAM kurang

# Fase 1: Hanya latih lapisan baru (cepat)
EPOCHS_PHASE1 = 10

# Fase 2: Fine-tune lapisan dalam juga (lebih akurat)
EPOCHS_PHASE2 = 20

# Learning rate
LR_PHASE1 = 0.001
LR_PHASE2 = 0.0001  # Lebih kecil untuk fine-tuning

# Path
PROCESSED_DIR = Path("ml_training/dataset/processed")
OUTPUT_DIR = Path("ml_training/output")
OUTPUT_DIR.mkdir(exist_ok=True)

# =============================================================================
# LANGKAH 1: LOAD DATASET
# =============================================================================

print("\n" + "=" * 60)
print("  LANGKAH 1: LOAD DATASET")
print("=" * 60)

# ImageDataGenerator untuk normalisasi gambar
# Rescale 1/255: mengubah nilai pixel dari 0-255 menjadi 0.0-1.0
# Neural network bekerja lebih baik dengan nilai kecil
train_datagen = ImageDataGenerator(rescale=1.0 / 255)
val_datagen = ImageDataGenerator(rescale=1.0 / 255)

# Load gambar dari folder
# class_mode='categorical' = output one-hot encoding (misal [0,1,0,0,0,0,0] untuk Rp2000)
train_generator = train_datagen.flow_from_directory(
    PROCESSED_DIR / "train",
    target_size=IMAGE_SIZE,
    batch_size=BATCH_SIZE,
    class_mode="categorical",
    classes=CLASSES,
    shuffle=True,
)

val_generator = val_datagen.flow_from_directory(
    PROCESSED_DIR / "val",
    target_size=IMAGE_SIZE,
    batch_size=BATCH_SIZE,
    class_mode="categorical",
    classes=CLASSES,
    shuffle=False,
)

# Simpan mapping index -> nama kelas
class_indices = train_generator.class_indices
print(f"\nMapping kelas:")
for name, idx in class_indices.items():
    print(f"  {idx}: {name}")

# Simpan ke file JSON (akan dipakai di Flutter)
with open(OUTPUT_DIR / "class_indices.json", "w") as f:
    json.dump({str(v): k for k, v in class_indices.items()}, f, indent=2)

print(f"\n✅ Training: {train_generator.samples} gambar")
print(f"✅ Validasi : {val_generator.samples} gambar")

# =============================================================================
# LANGKAH 2: BANGUN MODEL
# =============================================================================

print("\n" + "=" * 60)
print("  LANGKAH 2: BANGUN MODEL")
print("=" * 60)

# --- Base Model: MobileNetV2 ---
# include_top=False: hapus lapisan klasifikasi asli (ImageNet 1000 kelas)
# weights='imagenet': muat bobot yang sudah dilatih di ImageNet
# input_shape: ukuran gambar masukan
base_model = MobileNetV2(
    input_shape=(*IMAGE_SIZE, 3), include_top=False, weights="imagenet"
)

# Bekukan semua lapisan base_model dulu
# Artinya: lapisan ini tidak akan berubah saat training fase 1
# Kita hanya latih lapisan baru yang kita tambahkan
base_model.trainable = False

print(f"Base model (MobileNetV2): {base_model.count_params():,} parameter")

# --- Tambahkan Lapisan Klasifikasi ---
# Ini lapisan yang kita latih untuk kenali 7 denominasi + background

model = models.Sequential(
    [
        # 1. Base model (fitur extractor)
        base_model,
        # 2. GlobalAveragePooling2D
        #    Mengubah output feature map (7x7x1280) menjadi vektor (1280,)
        #    Lebih efisien dari Flatten
        layers.GlobalAveragePooling2D(),
        # 3. Batch Normalization
        #    Menstabilkan proses training
        layers.BatchNormalization(),
        # 4. Dense layer pertama (128 neuron)
        #    Belajar kombinasi fitur
        layers.Dense(128, activation="relu"),
        # 5. Dropout (mencegah overfitting)
        #    Saat training, 30% neuron dimatikan secara acak
        #    Memaksa model tidak bergantung pada neuron tertentu
        layers.Dropout(0.3),
        # 6. Output layer (8 neuron = 7 kelas + background)
        #    Softmax: output berupa probabilitas yang jumlahnya = 1
        #    Contoh: [0.01, 0.02, 0.90, 0.03, 0.02, 0.01, 0.01] → prediksi Rp5000
        layers.Dense(len(CLASSES), activation="softmax"),
    ]
)

# Tampilkan arsitektur model
model.summary()

# =============================================================================
# LANGKAH 3: TRAINING FASE 1 (hanya lapisan baru)
# =============================================================================

print("\n" + "=" * 60)
print("  LANGKAH 3: TRAINING FASE 1")
print("  (Hanya melatih lapisan klasifikasi baru)")
print("=" * 60)

# Compile model
# optimizer: Adam — algoritma yang mengupdate bobot neural network
# loss: categorical_crossentropy — fungsi error untuk klasifikasi multi-kelas
# metrics: accuracy — persentase prediksi yang benar
model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=LR_PHASE1),
    loss="categorical_crossentropy",
    metrics=["accuracy"],
)

# Callbacks: fungsi yang dipanggil otomatis selama training

# EarlyStopping: berhenti training jika akurasi validasi tidak naik
# patience=5: toleransi 5 epoch tanpa perbaikan
early_stop = callbacks.EarlyStopping(
    monitor="val_accuracy",
    patience=5,
    restore_best_weights=True,  # Kembalikan ke bobot terbaik
    verbose=1,
)

# ModelCheckpoint: simpan model terbaik
checkpoint = callbacks.ModelCheckpoint(
    filepath=str(OUTPUT_DIR / "best_model_phase1.keras"),
    monitor="val_accuracy",
    save_best_only=True,
    verbose=1,
)

# ReduceLROnPlateau: kurangi learning rate jika stagnan
# Membantu model keluar dari "stuck"
reduce_lr = callbacks.ReduceLROnPlateau(
    monitor="val_loss", factor=0.5, patience=3, min_lr=1e-7, verbose=1  # LR dikali 0.5
)

# Mulai training fase 1
history1 = model.fit(
    train_generator,
    epochs=EPOCHS_PHASE1,
    validation_data=val_generator,
    callbacks=[early_stop, checkpoint, reduce_lr],
)

print(f"\n✅ Fase 1 selesai!")
print(f"   Akurasi Training : {max(history1.history['accuracy']):.2%}")
print(f"   Akurasi Validasi : {max(history1.history['val_accuracy']):.2%}")

# =============================================================================
# LANGKAH 4: TRAINING FASE 2 (fine-tuning)
# =============================================================================

print("\n" + "=" * 60)
print("  LANGKAH 4: TRAINING FASE 2 — FINE-TUNING")
print("  (Melatih ulang bagian akhir base model)")
print("=" * 60)

# Aktifkan lapisan terakhir base_model untuk dilatih ulang
# Kita unfreeze 50 lapisan terakhir
base_model.trainable = True
total_layers = len(base_model.layers)
freeze_until = total_layers - 50  # Bekukan semua kecuali 50 terakhir

for i, layer in enumerate(base_model.layers):
    layer.trainable = i >= freeze_until

print(f"Total lapisan base model: {total_layers}")
print(f"Lapisan yang dibekukan  : {freeze_until}")
print(f"Lapisan yang dilatih    : {total_layers - freeze_until}")

# Re-compile dengan learning rate lebih kecil
model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=LR_PHASE2),
    loss="categorical_crossentropy",
    metrics=["accuracy"],
)

# Checkpoint untuk fase 2
checkpoint2 = callbacks.ModelCheckpoint(
    filepath=str(OUTPUT_DIR / "best_model_phase2.keras"),
    monitor="val_accuracy",
    save_best_only=True,
    verbose=1,
)

early_stop2 = callbacks.EarlyStopping(
    monitor="val_accuracy", patience=7, restore_best_weights=True, verbose=1
)

# Training fase 2
history2 = model.fit(
    train_generator,
    epochs=EPOCHS_PHASE2,
    validation_data=val_generator,
    callbacks=[early_stop2, checkpoint2, reduce_lr],
)

print(f"\n✅ Fase 2 selesai!")
print(f"   Akurasi Training : {max(history2.history['accuracy']):.2%}")
print(f"   Akurasi Validasi : {max(history2.history['val_accuracy']):.2%}")

# =============================================================================
# LANGKAH 5: EXPORT KE TFLITE
# =============================================================================

print("\n" + "=" * 60)
print("  LANGKAH 5: EXPORT KE TFLITE")
print("=" * 60)

# TFLite = versi ringan TensorFlow untuk mobile
# Ukurannya jauh lebih kecil dan lebih cepat di HP

# Konversi model ke format TFLite
converter = tf.lite.TFLiteConverter.from_keras_model(model)

# Optimisasi: mengurangi ukuran model dengan dynamic range quantization
# Ukuran model bisa berkurang ~4x dengan akurasi yang hampir sama
converter.optimizations = [tf.lite.Optimize.DEFAULT]

# Lakukan konversi
tflite_model = converter.convert()

# Simpan file .tflite
tflite_path = OUTPUT_DIR / "rupiah_model.tflite"
with open(tflite_path, "wb") as f:
    f.write(tflite_model)

print(f"✅ Model TFLite disimpan: {tflite_path}")
print(f"   Ukuran model: {os.path.getsize(tflite_path) / 1024 / 1024:.2f} MB")

# =============================================================================
# LANGKAH 6: BUAT FILE LABELS
# =============================================================================

# labels.txt dipakai Flutter untuk tahu nama kelas per index
labels_content = "\n".join(CLASSES)
labels_path = OUTPUT_DIR / "labels.txt"
with open(labels_path, "w") as f:
    f.write(labels_content)

print(f"✅ Labels disimpan: {labels_path}")
print(f"   Isi labels.txt:\n")
for i, cls in enumerate(CLASSES):
    print(f"   {i}: {cls}")

# =============================================================================
# LANGKAH 7: VISUALISASI TRAINING
# =============================================================================


def plot_history(h1, h2):
    """Tampilkan grafik akurasi dan loss selama training"""
    # Gabungkan history fase 1 dan fase 2
    acc = h1.history["accuracy"] + h2.history["accuracy"]
    val_acc = h1.history["val_accuracy"] + h2.history["val_accuracy"]
    loss = h1.history["loss"] + h2.history["loss"]
    val_loss = h1.history["val_loss"] + h2.history["val_loss"]
    phase1_end = len(h1.history["accuracy"])

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))

    # Grafik Akurasi
    ax1.plot(acc, label="Training", color="#2196F3")
    ax1.plot(val_acc, label="Validasi", color="#FF9800")
    ax1.axvline(x=phase1_end, color="gray", linestyle="--", label="Mulai Fase 2")
    ax1.set_title("Akurasi Model", fontsize=13)
    ax1.set_xlabel("Epoch")
    ax1.set_ylabel("Akurasi")
    ax1.legend()
    ax1.grid(alpha=0.3)
    ax1.set_ylim([0, 1])

    # Grafik Loss
    ax2.plot(loss, label="Training", color="#2196F3")
    ax2.plot(val_loss, label="Validasi", color="#FF9800")
    ax2.axvline(x=phase1_end, color="gray", linestyle="--", label="Mulai Fase 2")
    ax2.set_title("Loss (Error) Model", fontsize=13)
    ax2.set_xlabel("Epoch")
    ax2.set_ylabel("Loss")
    ax2.legend()
    ax2.grid(alpha=0.3)

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / "training_history.png", dpi=150, bbox_inches="tight")
    print(f"\n📊 Grafik training disimpan: output/training_history.png")
    plt.show()


plot_history(history1, history2)

# =============================================================================
# RINGKASAN AKHIR
# =============================================================================

print("\n" + "=" * 60)
print("  SELESAI! LANGKAH SELANJUTNYA:")
print("=" * 60)
print("""
  1. Copy file berikut ke folder Flutter:
     
     output/rupiah_model.tflite
     → flutter_app/assets/model/rupiah_model.tflite
     
     output/labels.txt
     → flutter_app/assets/model/labels.txt

  2. Jalankan aplikasi Flutter:
     cd flutter_app
     flutter run

  Akurasi akhir validasi: {:.2%}
""".format(max(history2.history["val_accuracy"])))

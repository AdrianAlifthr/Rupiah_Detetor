"""
=============================================================================
FILE: 03_evaluate_model.py
FUNGSI: Menguji akurasi model dan membuat confusion matrix
=============================================================================

CARA PAKAI:
  Jalankan setelah 02_train_model.py selesai:
  python 03_evaluate_model.py

  Output:
  - output/confusion_matrix.png  → Visualisasi kesalahan prediksi
  - output/evaluation_report.txt → Laporan akurasi per kelas
"""

import json
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path

import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from sklearn.metrics import classification_report, confusion_matrix

# =============================================================================
# KONFIGURASI
# =============================================================================

CLASSES = ['Rp1000', 'Rp2000', 'Rp5000', 'Rp10000', 'Rp20000', 'Rp50000', 'Rp100000']
IMAGE_SIZE = (224, 224)
BATCH_SIZE = 16

PROCESSED_DIR = Path("ml_training/dataset/processed")
OUTPUT_DIR = Path("ml_training/output")

# =============================================================================
# LOAD MODEL DAN DATA
# =============================================================================

print("\n" + "=" * 60)
print("  EVALUASI MODEL")
print("=" * 60)

# Load model terbaik dari fase 2
print("\n📥 Loading model...")
try:
    model = tf.keras.models.load_model(OUTPUT_DIR / 'best_model_phase2.keras')
    print("   ✅ Model berhasil dimuat")
except:
    print("   ⚠️  Model fase 2 tidak ditemukan, coba fase 1...")
    model = tf.keras.models.load_model(OUTPUT_DIR / 'best_model_phase1.keras')

# Load data validasi
val_datagen = ImageDataGenerator(rescale=1./255)
val_generator = val_datagen.flow_from_directory(
    PROCESSED_DIR / 'val',
    target_size=IMAGE_SIZE,
    batch_size=BATCH_SIZE,
    class_mode='categorical',
    classes=CLASSES,
    shuffle=False  # PENTING: jangan diacak saat evaluasi
)

# =============================================================================
# EVALUASI
# =============================================================================

print("\n🔍 Menjalankan evaluasi...")

# Prediksi semua data validasi
y_pred_probs = model.predict(val_generator, verbose=1)
y_pred = np.argmax(y_pred_probs, axis=1)  # Ambil kelas dengan probabilitas tertinggi
y_true = val_generator.classes            # Label asli

# Akurasi keseluruhan
accuracy = np.mean(y_pred == y_true)
print(f"\n✅ Akurasi Keseluruhan: {accuracy:.2%}")

# =============================================================================
# LAPORAN PER KELAS
# =============================================================================

# classification_report menampilkan:
# - precision: dari prediksi Rp5000, berapa % yang benar?
# - recall: dari foto Rp5000, berapa % yang terdeteksi?
# - f1-score: rata-rata harmonis precision dan recall
report = classification_report(y_true, y_pred, target_names=CLASSES)
print("\n📋 Laporan per Kelas:")
print(report)

# Simpan ke file
with open(OUTPUT_DIR / 'evaluation_report.txt', 'w') as f:
    f.write(f"Akurasi Keseluruhan: {accuracy:.2%}\n\n")
    f.write("Laporan per Kelas:\n")
    f.write(report)

# =============================================================================
# CONFUSION MATRIX
# =============================================================================

# Confusion Matrix menunjukkan pola kesalahan model
# Baris = kelas asli, Kolom = kelas prediksi
# Diagonal = prediksi benar
# Off-diagonal = kesalahan

cm = confusion_matrix(y_true, y_pred)

# Normalisasi: ubah ke persentase
cm_normalized = cm.astype('float') / cm.sum(axis=1)[:, np.newaxis]

# Buat visualisasi
fig, axes = plt.subplots(1, 2, figsize=(16, 6))

# Confusion matrix angka absolut
sns.heatmap(cm, annot=True, fmt='d', cmap='Blues',
            xticklabels=CLASSES, yticklabels=CLASSES,
            ax=axes[0])
axes[0].set_title('Confusion Matrix (Jumlah)', fontsize=12)
axes[0].set_xlabel('Prediksi')
axes[0].set_ylabel('Asli')
axes[0].tick_params(axis='x', rotation=45)

# Confusion matrix persentase
sns.heatmap(cm_normalized, annot=True, fmt='.1%', cmap='Blues',
            xticklabels=CLASSES, yticklabels=CLASSES,
            ax=axes[1])
axes[1].set_title('Confusion Matrix (Persentase)', fontsize=12)
axes[1].set_xlabel('Prediksi')
axes[1].set_ylabel('Asli')
axes[1].tick_params(axis='x', rotation=45)

plt.tight_layout()
plt.savefig(OUTPUT_DIR / 'confusion_matrix.png', dpi=150, bbox_inches='tight')
print(f"\n📊 Confusion matrix disimpan: output/confusion_matrix.png")
plt.show()

# =============================================================================
# ANALISIS KESALAHAN
# =============================================================================

print("\n🔎 Analisis kesalahan (kelas yang sering tertukar):")
for i, cls in enumerate(CLASSES):
    row = cm[i]
    row_sum = row.sum()
    if row_sum == 0:
        continue

    wrong = [(j, count) for j, count in enumerate(row) if j != i and count > 0]
    wrong.sort(key=lambda x: x[1], reverse=True)

    if wrong:
        print(f"\n  {cls}:")
        for j, count in wrong[:3]:  # Top 3 kesalahan
            pct = count / row_sum * 100
            print(f"    → Salah prediksi sebagai {CLASSES[j]}: {count}x ({pct:.1f}%)")

# =============================================================================
# UJI TFLITE MODEL
# =============================================================================

print("\n" + "=" * 60)
print("  UJI MODEL TFLITE")
print("=" * 60)

# Load TFLite interpreter
tflite_path = OUTPUT_DIR / 'rupiah_model.tflite'
if tflite_path.exists():
    interpreter = tf.lite.Interpreter(model_path=str(tflite_path))
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print(f"\nInput shape : {input_details[0]['shape']}")
    print(f"Output shape: {output_details[0]['shape']}")

    # Uji dengan beberapa gambar dari dataset
    import random
    from PIL import Image

    print("\nUji prediksi TFLite (5 sampel acak):")
    correct = 0
    total_test = 5

    for test_idx in range(total_test):
        # Ambil gambar acak dari validasi
        true_label_idx = random.randint(0, len(CLASSES) - 1)
        cls = CLASSES[true_label_idx]
        folder = PROCESSED_DIR / 'val' / cls
        images = list(folder.glob("*.jpg"))

        if not images:
            continue

        img_path = random.choice(images)
        img = Image.open(img_path).convert('RGB').resize(IMAGE_SIZE)
        img_array = np.array(img, dtype=np.float32) / 255.0
        img_array = np.expand_dims(img_array, axis=0)

        # Jalankan inferensi
        interpreter.set_tensor(input_details[0]['index'], img_array)
        interpreter.invoke()
        output = interpreter.get_tensor(output_details[0]['index'])

        pred_idx = np.argmax(output[0])
        pred_cls = CLASSES[pred_idx]
        confidence = output[0][pred_idx]

        status = "✅" if pred_idx == true_label_idx else "❌"
        if pred_idx == true_label_idx:
            correct += 1

        print(f"  {status} Asli: {cls:10} | Prediksi: {pred_cls:10} | Confidence: {confidence:.1%}")

    print(f"\n  Akurasi sampel: {correct}/{total_test} = {correct/total_test:.0%}")
else:
    print("  ⚠️  File rupiah_model.tflite tidak ditemukan")
    print("      Jalankan 02_train_model.py terlebih dahulu")

print("\n✅ Evaluasi selesai!")

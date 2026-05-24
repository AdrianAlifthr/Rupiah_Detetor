# Rupiah Detector

Aplikasi identifikasi uang Rupiah untuk membantu pengguna tunanetra.

## Struktur Folder Utama

```text
rupiah_detector/
|-- app/                 # Aplikasi Flutter (mobile)
|-- ml_training/         # Pipeline training model ML
|-- README.md
`-- .gitignore
```

## Penjelasan Folder `app/`

Folder ini berisi aplikasi Flutter yang memakai model TFLite hasil training.

### Tools yang dipakai
- Flutter SDK
- Dart
- Android Studio / VS Code
- Package utama: `camera`, `tflite_flutter`, `flutter_tts`, `permission_handler`

### File penting dan fungsinya
- `app/pubspec.yaml`
  - Daftar dependency Flutter dan registrasi assets model.
- `app/lib/main.dart`
  - Entry point aplikasi.
- `app/lib/screens/home_screen.dart`
  - Layar utama kamera + alur deteksi.
- `app/lib/services/classifier.dart`
  - Load model TFLite dan jalankan inferensi.
- `app/lib/services/tts_service.dart`
  - Ubah hasil deteksi jadi suara (Text-to-Speech).
- `app/lib/widgets/*.dart`
  - Komponen UI overlay hasil, frame kamera, kontrol, dan top bar.
- `app/assets/model/rupiah_model.tflite`
  - Model inferensi di device.
- `app/assets/model/labels.txt`
  - Label kelas sesuai output model.

### Menjalankan app

```bash
cd app
flutter pub get
flutter run
```

## Penjelasan Folder `ml_training/`

Folder ini berisi pipeline data preparation, training, evaluasi, dan export model.

### Tools yang dipakai
- Python 3.9+
- TensorFlow / Keras
- Pillow
- NumPy
- scikit-learn
- matplotlib + seaborn
- (opsional) `fiftyone` untuk dataset background

### File penting dan fungsinya
- `ml_training/requirements.txt`
  - Dependency Python untuk training pipeline.
- `ml_training/scripts/run_full_pipeline.py`
  - Script utama all-in-one:
    1. Validasi dataset raw
    2. Augmentasi dan split train/val
    3. Training model 2 fase (transfer learning + fine-tuning)
    4. Evaluasi + confusion matrix
    5. Export ke `.tflite` + `labels.txt`
- `ml_training/scripts/organize_dataset.py`
  - Utility untuk merapikan struktur dataset.
- `ml_training/scripts/check_background_dataset.py`
  - Cek kualitas/kelengkapan data background.
- `ml_training/scripts/00_setup_kaggle_and_download.sh`
  - Setup + download dataset pendukung dari online source.
- `ml_training/notebooks/`
  - Script lama berbasis notebook style. Saat ini **bukan alur utama**.
- `ml_training/dataset/raw/`
  - Data mentah per kelas (input awal).
- `ml_training/dataset/processed/`
  - Hasil preprocessing/augmentasi (generated).
- `ml_training/output/`
  - Hasil training (model, report, grafik, confusion matrix).

## Alur Training yang Dipakai Sekarang

Training terakhir menggunakan:

```bash
cd ml_training
pip install -r requirements.txt
python scripts/run_full_pipeline.py
```

Bukan lagi dari folder `ml_training/notebooks/`.

## Sinkronisasi Model ke App

Setelah training selesai, copy hasil model ke app:

```bash
copy ml_training\output\rupiah_model.tflite app\assets\model\rupiah_model.tflite
copy ml_training\output\labels.txt app\assets\model\labels.txt
```

Lalu jalankan ulang Flutter:

```bash
cd app
flutter run
```

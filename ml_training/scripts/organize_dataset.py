"""
=============================================================================
FILE: ml_training/scripts/organize_dataset.py
FUNGSI: Mengorganisir dataset yang didownload dari Kaggle ke struktur yang benar

CARA KERJA:
  Script ini secara otomatis:
  1. Scan semua folder dalam dataset yang didownload
  2. Deteksi folder mana yang berisi gambar untuk kelas apa
  3. Copy gambar ke folder raw/{Rp1000, Rp2000, ...}

  Karena setiap dataset Kaggle punya struktur folder yang berbeda-beda,
  script ini mencoba mendeteksi secara otomatis.

DIPANGGIL OLEH:
  00_setup_kaggle_and_download.sh
  (Tidak perlu dijalankan manual)
=============================================================================
"""

import sys
import os
import shutil
from pathlib import Path

# =============================================================================
# KONFIGURASI MAPPING NAMA FOLDER
# =============================================================================

# Semua kemungkinan nama folder yang mewakili setiap denominasi
# Script akan mencari kecocokan dari nama folder dataset Kaggle
LABEL_ALIASES = {
    'Rp1000': [
        '1000', 'rp1000', 'rp_1000', '1rb', '1ribu', 'seribu',
        '1.000', '1000rupiah', 'pecahan_1000', 'rp1k', '1k'
    ],
    'Rp2000': [
        '2000', 'rp2000', 'rp_2000', '2rb', '2ribu', 'duaribu',
        '2.000', '2000rupiah', 'pecahan_2000', 'rp2k', '2k'
    ],
    'Rp5000': [
        '5000', 'rp5000', 'rp_5000', '5rb', '5ribu', 'limaribu',
        '5.000', '5000rupiah', 'pecahan_5000', 'rp5k', '5k'
    ],
    'Rp10000': [
        '10000', 'rp10000', 'rp_10000', '10rb', '10ribu', 'sepuluhribu',
        '10.000', '10000rupiah', 'pecahan_10000', 'rp10k', '10k'
    ],
    'Rp20000': [
        '20000', 'rp20000', 'rp_20000', '20rb', '20ribu', 'duapuluhribu',
        '20.000', '20000rupiah', 'pecahan_20000', 'rp20k', '20k'
    ],
    'Rp50000': [
        '50000', 'rp50000', 'rp_50000', '50rb', '50ribu', 'limapuluhribu',
        '50.000', '50000rupiah', 'pecahan_50000', 'rp50k', '50k'
    ],
    'Rp100000': [
        '100000', 'rp100000', 'rp_100000', '100rb', '100ribu', 'seratusribu',
        '100.000', '100000rupiah', 'pecahan_100000', 'rp100k', '100k',
        '100', 'rp100'
    ],
}

# Format gambar yang diterima
IMAGE_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.bmp', '.webp', '.tiff'}


def find_label_for_folder(folder_name: str) -> str | None:
    """
    Cari kelas yang cocok untuk nama folder tertentu.
    
    Cara kerja:
    1. Ubah nama folder ke lowercase dan hapus spasi
    2. Bandingkan dengan semua alias yang sudah didefinisikan
    3. Return nama kelas jika cocok, None jika tidak
    
    Contoh:
        find_label_for_folder("10000")   → "Rp10000"
        find_label_for_folder("Rp_5rb")  → None (tidak dikenali)
    """
    # Normalisasi: lowercase, hapus spasi dan karakter khusus
    normalized = folder_name.lower().strip()
    normalized = normalized.replace(' ', '').replace('-', '').replace('_', '')

    for label, aliases in LABEL_ALIASES.items():
        for alias in aliases:
            # Normalisasi alias juga
            norm_alias = alias.lower().replace(' ', '').replace('-', '').replace('_', '')
            
            # Cek kecocokan persis
            if normalized == norm_alias:
                return label
            
            # Cek jika nama folder mengandung alias
            # Contoh: "class_1000_rupiah" akan cocok dengan alias "1000"
            if norm_alias in normalized and len(norm_alias) >= 4:
                return label

    return None


def count_images(folder: Path) -> int:
    """Hitung jumlah file gambar dalam folder (rekursif)"""
    count = 0
    for ext in IMAGE_EXTENSIONS:
        count += len(list(folder.rglob(f"*{ext}")))
        count += len(list(folder.rglob(f"*{ext.upper()}")))
    return count


def collect_images_from_folder(source_folder: Path, dest_folder: Path, prefix: str = "") -> int:
    """
    Copy semua gambar dari source_folder ke dest_folder.
    Return jumlah gambar yang berhasil dicopy.
    """
    dest_folder.mkdir(parents=True, exist_ok=True)
    copied = 0

    for ext in IMAGE_EXTENSIONS:
        # Cari semua gambar (lowercase dan uppercase ekstensi)
        for pattern in [f"*{ext}", f"*{ext.upper()}"]:
            for img_path in source_folder.rglob(pattern):
                # Buat nama file unik untuk menghindari konflik
                new_name = f"{prefix}{img_path.stem}_{copied:05d}{img_path.suffix.lower()}"
                dest_path = dest_folder / new_name

                try:
                    shutil.copy2(img_path, dest_path)
                    copied += 1
                except Exception as e:
                    print(f"    ⚠ Gagal copy {img_path.name}: {e}")

    return copied


def organize_dataset(download_dir: Path, raw_dir: Path):
    """
    Fungsi utama: scan semua dataset yang didownload dan organisir ke raw/.
    
    Mendukung berbagai struktur folder Kaggle yang berbeda:
    
    Struktur 1 (flat):
      download/
        1000/ ← langsung ada folder denominasi
        2000/
    
    Struktur 2 (nested):
      download/
        train/
          1000/
          2000/
        test/
          ...
    
    Struktur 3 (very nested):
      download/
        rupiah_dataset/
          train/
            1000/
    """
    
    print("\n" + "=" * 55)
    print("  ORGANISIR DATASET")
    print("=" * 55)

    # Buat folder output
    for label in LABEL_ALIASES.keys():
        (raw_dir / label).mkdir(parents=True, exist_ok=True)

    # Counter hasil
    results = {label: 0 for label in LABEL_ALIASES.keys()}
    unrecognized_folders = []

    # Scan semua subfolder dalam download_dir
    # os.walk() akan menelusuri semua level folder secara rekursif
    for dirpath, dirnames, filenames in os.walk(download_dir):
        current_dir = Path(dirpath)
        
        # Cek apakah folder ini berisi gambar langsung (bukan subfolder)
        has_images = any(
            Path(dirpath, f).suffix.lower() in IMAGE_EXTENSIONS
            for f in filenames
        )

        if not has_images:
            continue

        # Coba identifikasi kelas dari nama folder
        folder_name = current_dir.name
        label = find_label_for_folder(folder_name)

        if label:
            # Cocok! Copy semua gambar ke folder yang sesuai
            dest = raw_dir / label
            
            # Prefix untuk menghindari nama file duplikat antar dataset
            # Ambil 2 karakter pertama nama parent folder sebagai prefix
            parent_prefix = current_dir.parent.name[:3].lower() + "_"
            
            count = collect_images_from_folder(current_dir, dest, prefix=parent_prefix)
            results[label] += count
            
            if count > 0:
                print(f"  ✓ {folder_name:20} → {label} ({count} gambar)")
        else:
            # Tidak dikenali — simpan untuk dilaporkan
            if count_images(current_dir) > 0:
                unrecognized_folders.append(
                    f"{folder_name} ({count_images(current_dir)} gambar)"
                )

    # ── Laporan Hasil ──
    print("\n" + "─" * 55)
    print("  HASIL ORGANISIR:")
    print("─" * 55)

    total = 0
    for label, count in results.items():
        status = "✓" if count > 0 else "✗"
        color = "\033[32m" if count > 0 else "\033[31m"
        reset = "\033[0m"
        print(f"  {color}{status}{reset} {label:12} : {count:4d} gambar")
        total += count

    print("─" * 55)
    print(f"  Total gambar   : {total}")

    # ── Peringatan kelas kosong ──
    empty_classes = [label for label, count in results.items() if count == 0]
    if empty_classes:
        print("\n  ⚠ Kelas berikut TIDAK ADA gambarnya:")
        for cls in empty_classes:
            print(f"    - {cls}")
        print("\n  Solusi:")
        print("  1. Download dataset lain yang punya kelas ini")
        print("  2. Foto manual uang tersebut (minimal 30 foto)")
        print("  3. Letakkan di folder: dataset/raw/{nama_kelas}/")

    # ── Folder yang tidak dikenali ──
    if unrecognized_folders:
        print("\n  ℹ Folder tidak dikenali (diabaikan):")
        for f in unrecognized_folders[:10]:  # Tampilkan max 10
            print(f"    - {f}")

    # ── Saran jika data terlalu sedikit ──
    print("\n  CECK KECUKUPAN DATA:")
    for label, count in results.items():
        if count < 30:
            print(f"  ⚠ {label}: hanya {count} gambar (minimum 30, ideal 100+)")
        elif count < 100:
            print(f"  ℹ {label}: {count} gambar (cukup, tapi 100+ lebih bagus)")
        else:
            print(f"  ✓ {label}: {count} gambar (bagus!)")

    print("\n" + "=" * 55)

    return results


# =============================================================================
# ENTRY POINT
# =============================================================================

if __name__ == "__main__":
    # Argumen dari command line
    if len(sys.argv) >= 3:
        download_dir = Path(sys.argv[1])
        raw_dir = Path(sys.argv[2])
    else:
        # Default path jika tidak ada argumen
        script_dir = Path(__file__).parent
        download_dir = script_dir.parent / "dataset" / "kaggle_downloads"
        raw_dir = script_dir.parent / "dataset" / "raw"

    print(f"  Download dir : {download_dir}")
    print(f"  Raw dir      : {raw_dir}")

    if not download_dir.exists():
        print(f"\n  ✗ Folder tidak ditemukan: {download_dir}")
        print("    Jalankan 00_setup_kaggle_and_download.sh terlebih dahulu")
        sys.exit(1)

    organize_dataset(download_dir, raw_dir)

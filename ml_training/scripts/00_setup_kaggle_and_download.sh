#!/bin/bash
# =============================================================================
# FILE: ml_training/scripts/00_setup_kaggle_and_download.sh
# FUNGSI: Setup Kaggle API + Download dataset rupiah + Siapkan environment
# =============================================================================
#
# CARA PAKAI (jalankan dari folder ml_training/):
#   chmod +x scripts/00_setup_kaggle_and_download.sh
#   ./scripts/00_setup_kaggle_and_download.sh
#
# Script ini akan:
#   1. Install semua dependencies Python
#   2. Bantu setup Kaggle API key
#   3. Download dataset rupiah dari Kaggle
#   4. Siapkan struktur folder yang benar
#
# =============================================================================

set -e

# ── Warna terminal ──
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}  ℹ  $1${NC}"; }
success() { echo -e "${GREEN}  ✓  $1${NC}"; }
warning() { echo -e "${YELLOW}  ⚠  $1${NC}"; }
error()   { echo -e "${RED}  ✗  $1${NC}"; exit 1; }
header()  { echo -e "\n${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; \
            echo -e "${BOLD}${BLUE}  $1${NC}"; \
            echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# Deteksi berada di folder mana
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ML_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo -e "${BOLD}${GREEN}"
echo "  ██████╗ ██╗   ██╗██████╗ ██╗ █████╗ ██╗  ██╗"
echo "  ██╔══██╗██║   ██║██╔══██╗██║██╔══██╗██║  ██║"
echo "  ██████╔╝██║   ██║██████╔╝██║███████║███████║"
echo "  ██╔══██╗██║   ██║██╔═══╝ ██║██╔══██║██╔══██║"
echo "  ██║  ██║╚██████╔╝██║     ██║██║  ██║██║  ██║"
echo "  ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝"
echo ""
echo "     DETECTOR — ML Setup & Dataset Downloader"
echo -e "${NC}"

# =============================================================================
header "LANGKAH 1: INSTALL PYTHON DEPENDENCIES"
# =============================================================================

info "Mengecek Python..."
if ! command -v python3 &>/dev/null; then
    error "Python3 tidak ditemukan. Install dulu: brew install python@3.11"
fi
success "Python: $(python3 --version)"

info "Mengecek pip..."
if ! command -v pip3 &>/dev/null; then
    error "pip3 tidak ditemukan."
fi

# Deteksi chip Mac
ARCH=$(uname -m)
info "Arsitektur Mac: $ARCH"

echo ""
info "Menginstall semua library yang dibutuhkan..."
echo "  (Ini mungkin butuh 2-5 menit pertama kali)"
echo ""

if [ "$ARCH" = "arm64" ]; then
    # Mac Apple Silicon (M1/M2/M3) — gunakan tensorflow-macos
    warning "Apple Silicon terdeteksi → menginstall tensorflow-macos + tensorflow-metal"
    pip3 install --upgrade pip --quiet
    pip3 install tensorflow-macos tensorflow-metal \
                 kaggle pillow numpy matplotlib seaborn \
                 scikit-learn tqdm pathlib 2>&1 | grep -E "(Successfully|already|ERROR)" || true
else
    # Mac Intel
    pip3 install --upgrade pip --quiet
    pip3 install tensorflow \
                 kaggle pillow numpy matplotlib seaborn \
                 scikit-learn tqdm pathlib 2>&1 | grep -E "(Successfully|already|ERROR)" || true
fi

# Verifikasi
python3 -c "import tensorflow as tf; print(f'  TensorFlow: {tf.__version__}')" 2>/dev/null && \
    success "TensorFlow terinstall" || warning "TensorFlow belum terinstall, coba manual: pip3 install tensorflow"

python3 -c "import kaggle" 2>/dev/null && \
    success "Kaggle API terinstall" || warning "Kaggle belum terinstall"

# =============================================================================
header "LANGKAH 2: SETUP KAGGLE API KEY"
# =============================================================================

KAGGLE_DIR="$HOME/.kaggle"
KAGGLE_JSON="$KAGGLE_DIR/kaggle.json"

if [ -f "$KAGGLE_JSON" ]; then
    success "Kaggle API key sudah ada di $KAGGLE_JSON"
else
    echo ""
    echo -e "  ${BOLD}Kaggle API key belum ditemukan.${NC}"
    echo "  Ikuti langkah berikut untuk mendapatkan API key:"
    echo ""
    echo -e "  ${CYAN}1.${NC} Buka browser, pergi ke: ${BOLD}https://www.kaggle.com${NC}"
    echo -e "  ${CYAN}2.${NC} Login atau daftar akun Kaggle (gratis)"
    echo -e "  ${CYAN}3.${NC} Klik foto profil kamu (pojok kanan atas)"
    echo -e "  ${CYAN}4.${NC} Pilih ${BOLD}'Settings'${NC}"
    echo -e "  ${CYAN}5.${NC} Scroll ke bagian ${BOLD}'API'${NC}"
    echo -e "  ${CYAN}6.${NC} Klik ${BOLD}'Create New Token'${NC}"
    echo -e "  ${CYAN}7.${NC} File ${BOLD}kaggle.json${NC} akan terdownload otomatis"
    echo ""
    echo -e "  ${YELLOW}Setelah download kaggle.json, jalankan perintah ini:${NC}"
    echo ""
    echo -e "  ${BOLD}  mkdir -p ~/.kaggle && mv ~/Downloads/kaggle.json ~/.kaggle/ && chmod 600 ~/.kaggle/kaggle.json${NC}"
    echo ""

    read -p "  Sudah punya dan taruh kaggle.json di ~/.kaggle/? (y/n): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "$KAGGLE_JSON" ]; then
            chmod 600 "$KAGGLE_JSON"
            success "Kaggle API key ditemukan!"
        else
            error "File $KAGGLE_JSON tidak ditemukan. Ulangi langkah di atas."
        fi
    else
        echo ""
        warning "Setup Kaggle dibatalkan."
        echo "  Jalankan script ini lagi setelah kaggle.json siap."
        echo ""
        exit 0
    fi
fi

# Pastikan permission benar
chmod 600 "$KAGGLE_JSON"

# Test API key
info "Menguji koneksi Kaggle API..."
if python3 -c "import kaggle; kaggle.api.authenticate()" 2>/dev/null; then
    success "Kaggle API key valid!"
else
    echo ""
    warning "Gagal autentikasi. Pastikan isi kaggle.json benar."
    echo "  Isi yang benar: {\"username\":\"namakamu\",\"key\":\"abc123...\"}"
    exit 1
fi

# =============================================================================
header "LANGKAH 3: PILIH DAN DOWNLOAD DATASET"
# =============================================================================

echo ""
echo "  Ada beberapa dataset rupiah yang tersedia di Kaggle:"
echo ""
echo -e "  ${BOLD}[1]${NC} nurulalfiyyah/rupiah-banknotes"
echo "      ✔ 7 kelas (Rp1000 s/d Rp100000)"
echo "      ✔ Foto dari berbagai sudut"
echo "      ✔ Paling direkomendasikan ⭐"
echo ""
echo -e "  ${BOLD}[2]${NC} anidwiastuti/rupiah-banknotes-dataset"
echo "      ✔ 7 kelas (Rp1000 s/d Rp100000)"
echo "      ✔ Dataset alternatif"
echo ""
echo -e "  ${BOLD}[3]${NC} brotoa/idr-banknotes-dataset"
echo "      ✔ IDR banknotes dataset"
echo "      ✔ Pilihan ketiga"
echo ""
echo -e "  ${BOLD}[4]${NC} Pakai SEMUA dataset (gabungkan — akurasi lebih tinggi)"
echo "      ✔ Lebih banyak data = model lebih robust"
echo "      ⚠ Butuh waktu lebih lama untuk download"
echo ""

read -p "  Pilih dataset (1/2/3/4): " DATASET_CHOICE

# Setup folder download
DOWNLOAD_DIR="$ML_DIR/dataset/kaggle_downloads"
RAW_DIR="$ML_DIR/dataset/raw"
mkdir -p "$DOWNLOAD_DIR"
mkdir -p "$RAW_DIR"

download_dataset() {
    local DATASET_SLUG="$1"
    local DEST_DIR="$2"
    
    info "Mendownload dataset: $DATASET_SLUG"
    mkdir -p "$DEST_DIR"
    
    python3 -c "
import kaggle
kaggle.api.authenticate()
kaggle.api.dataset_download_files(
    '$DATASET_SLUG',
    path='$DEST_DIR',
    unzip=True,
    quiet=False
)
print('Download selesai!')
"
    
    if [ $? -eq 0 ]; then
        success "Dataset $DATASET_SLUG berhasil didownload"
    else
        warning "Gagal download $DATASET_SLUG"
    fi
}

case $DATASET_CHOICE in
    1)
        download_dataset "nurulalfiyyah/rupiah-banknotes" "$DOWNLOAD_DIR/dataset1"
        ;;
    2)
        download_dataset "anidwiastuti/rupiah-banknotes-dataset" "$DOWNLOAD_DIR/dataset2"
        ;;
    3)
        download_dataset "brotoa/idr-banknotes-dataset" "$DOWNLOAD_DIR/dataset3"
        ;;
    4)
        info "Mendownload semua dataset..."
        download_dataset "nurulalfiyyah/rupiah-banknotes" "$DOWNLOAD_DIR/dataset1"
        download_dataset "anidwiastuti/rupiah-banknotes-dataset" "$DOWNLOAD_DIR/dataset2"
        download_dataset "brotoa/idr-banknotes-dataset" "$DOWNLOAD_DIR/dataset3"
        ;;
    *)
        warning "Pilihan tidak valid, menggunakan dataset 1"
        download_dataset "nurulalfiyyah/rupiah-banknotes" "$DOWNLOAD_DIR/dataset1"
        ;;
esac

# =============================================================================
header "LANGKAH 4: ORGANISIR DATASET"
# =============================================================================

info "Mengorganisir dataset ke struktur yang benar..."

# Jalankan script Python untuk organisir
python3 "$SCRIPT_DIR/organize_dataset.py" "$DOWNLOAD_DIR" "$RAW_DIR"

echo ""
success "Dataset siap di: $RAW_DIR"
echo ""

# Hitung jumlah gambar
echo "  Jumlah gambar per kelas:"
for cls in Rp1000 Rp2000 Rp5000 Rp10000 Rp20000 Rp50000 Rp100000; do
    if [ -d "$RAW_DIR/$cls" ]; then
        COUNT=$(find "$RAW_DIR/$cls" -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
        echo -e "    ${cls}: ${BOLD}${COUNT} gambar${NC}"
    else
        echo -e "    ${cls}: ${RED}folder tidak ditemukan${NC}"
    fi
done

# =============================================================================
header "SELESAI! LANGKAH SELANJUTNYA"
# =============================================================================

echo ""
echo "  Jalankan perintah berikut secara berurutan:"
echo ""
echo -e "  ${CYAN}Step 1${NC} — Augmentasi dataset:"
echo -e "  ${BOLD}  cd ml_training/notebooks && python3 01_data_preparation.py${NC}"
echo ""
echo -e "  ${CYAN}Step 2${NC} — Training model (30-90 menit):"
echo -e "  ${BOLD}  python3 02_train_model.py${NC}"
echo ""
echo -e "  ${CYAN}Step 3${NC} — Evaluasi model:"
echo -e "  ${BOLD}  python3 03_evaluate_model.py${NC}"
echo ""
echo -e "  ${CYAN}Step 4${NC} — Copy model ke Flutter:"
echo -e "  ${BOLD}  cp ../output/rupiah_model.tflite ../../flutter_app/assets/model/${NC}"
echo ""
success "Setup selesai!"
echo ""

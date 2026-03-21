#!/bin/bash

DATABASE="data/database.csv"
HISTORY="sampah/history_hapus.csv"
LAPORAN="rekap/laporan_bulanan.txt"
TAGIHAN_LOG="log/tagihan.log"

[ ! -f "$DATABASE" ] && touch "$DATABASE"
[ ! -f "$HISTORY" ] && touch "$HISTORY"

trim() {
    echo "$1" | xargs
}

tambah_penghuni() {
    echo "============================================"
    echo "           TAMBAH PENGHUNI"
    echo "============================================"

    read -p "Masukkan Nama: " nama
    nama=$(trim "$nama")
    read -p "Masukkan Kamar: " kamar
    kamar=$(trim "$kamar")

    if grep -q "^[^,]*,$kamar," "$DATABASE" 2>/dev/null; then
        echo "[!] Kamar $kamar sudah ditempati!"
        read -p "Tekan [ENTER] untuk kembali ke menu..."
        return
    fi

    read -p "Masukkan Harga Sewa: " harga
    harga=$(trim "$harga")
    if ! [[ "$harga" =~ ^[0-9]+$ ]] || [ "$harga" -le 0 ]; then
        echo "[!] Harga sewa harus angka positif!"
        read -p "Tekan [ENTER] untuk kembali ke menu..."
        return
    fi

    read -p "Masukkan Tanggal Masuk (YYYY-MM-DD): " tanggal
    tanggal=$(trim "$tanggal")
    today=$(date +%Y-%m-%d)
    if ! [[ "$tanggal" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || [[ "$tanggal" > "$today" ]]; then
        echo "[!] Format tanggal salah atau melebihi hari ini!"
        read -p "Tekan [ENTER] untuk kembali ke menu..."
        return
    fi

    read -p "Masukkan Status Awal (Aktif/Menunggak): " status
    status=$(trim "$status")
    if [[ "${status,,}" != "aktif" && "${status,,}" != "menunggak" ]]; then
        echo "[!] Status harus Aktif atau Menunggak!"
        read -p "Tekan [ENTER] untuk kembali ke menu..."
        return
    fi
    status=$(echo "$status" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')

    echo "$nama,$kamar,$harga,$tanggal,$status" >> "$DATABASE"
    echo "[√] Penghuni \"$nama\" berhasil ditambahkan ke Kamar $kamar dengan status $status."
    read -p "Tekan [ENTER] untuk kembali ke menu..."
}

hapus_penghuni() {
    echo "============================================"
    echo "           HAPUS PENGHUNI"
    echo "============================================"

    read -p "Masukkan nama penghuni yang akan dihapus: " nama
    nama=$(trim "$nama")

    if ! grep -qi "^$nama," "$DATABASE" 2>/dev/null; then
        echo "[!] Penghuni \"$nama\" tidak ditemukan!"
        read -p "Tekan [ENTER] untuk kembali ke menu..."
        return
    fi

    today=$(date +%Y-%m-%d)
    grep -i "^$nama," "$DATABASE" | while read -r baris; do
        echo "$baris,$today" >> "$HISTORY"
    done

    grep -iv "^$nama," "$DATABASE" > tmp_db.csv && mv tmp_db.csv "$DATABASE"
    echo "[√] Data penghuni \"$nama\" berhasil diarsipkan ke $HISTORY dan dihapus dari sistem."
    read -p "Tekan [ENTER] untuk kembali ke menu..."
}

tampilkan_penghuni() {
    echo "============================================"
    echo "      DAFTAR PENGHUNI KOST SLEBEW"
    echo "============================================"
    printf "%-4s | %-15s | %-6s | %-12s | %-10s\n" "No" "Nama" "Kamar" "Harga Sewa" "Status"
    echo "------------------------------------------------------------"

    no=1
    total_aktif=0
    total_nunggak=0

    while IFS=',' read -r nama kamar harga tanggal status; do
        harga=$(trim "$harga")
        harga_fmt=$(printf "Rp%'.0f" "$harga")
        printf "%-4s | %-15s | %-6s | %-12s | %-10s\n" "$no" "$nama" "$kamar" "$harga_fmt" "$status"
        echo "------------------------------------------------------------"
        if [[ "${status,,}" == "aktif" ]]; then
            total_aktif=$((total_aktif + 1))
        else
            total_nunggak=$((total_nunggak + 1))
        fi
        no=$((no + 1))
    done < "$DATABASE"

    total=$((total_aktif + total_nunggak))
    echo "Total: $total penghuni | Aktif: $total_aktif | Menunggak: $total_nunggak"
    echo "============================================"
    read -p "Tekan [ENTER] untuk kembali ke menu..."
}

update_status() {
    echo "============================================"
    echo "           UPDATE STATUS"
    echo "============================================"

    read -p "Masukkan Nama Penghuni: " nama
    nama=$(trim "$nama")
    read -p "Masukkan Status Baru (Aktif/Menunggak): " status_baru
    status_baru=$(trim "$status_baru")

    if [[ "${status_baru,,}" != "aktif" && "${status_baru,,}" != "menunggak" ]]; then
        echo "[!] Status harus Aktif atau Menunggak!"
        read -p "Tekan [ENTER] untuk kembali ke menu..."
        return
    fi

    status_baru=$(echo "$status_baru" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')

    if ! grep -qi "^$nama," "$DATABASE"; then
        echo "[!] Penghuni \"$nama\" tidak ditemukan!"
        read -p "Tekan [ENTER] untuk kembali ke menu..."
        return
    fi

    awk -F',' -v nama="$nama" -v status="$status_baru" '
    tolower($1) == tolower(nama) { $5=status }
    { OFS=","; print }
    ' "$DATABASE" > tmp_db.csv && mv tmp_db.csv "$DATABASE"

    echo "[√] Status $nama berhasil diubah menjadi: $status_baru"
    read -p "Tekan [ENTER] untuk kembali ke menu..."
}

cetak_laporan() {
    echo "============================================"
    echo "      LAPORAN KEUANGAN KOST SLEBEW"
    echo "============================================"

    total_aktif=0
    total_nunggak=0
    kamar_terisi=0
    daftar_nunggak=""

    while IFS=',' read -r nama kamar harga tanggal status; do
        harga=$(trim "$harga")
        status=$(trim "$status")
        kamar_terisi=$((kamar_terisi + 1))
        if [[ "${status,,}" == "aktif" ]]; then
            total_aktif=$((total_aktif + harga))
        else
            total_nunggak=$((total_nunggak + harga))
            daftar_nunggak="$daftar_nunggak\n  - $nama (Kamar $kamar)"
        fi
    done < "$DATABASE"

    aktif_fmt=$(printf "Rp%'.0f" "$total_aktif")
    nunggak_fmt=$(printf "Rp%'.0f" "$total_nunggak")

    echo " Total pemasukan (Aktif)  : $aktif_fmt"
    echo " Total tunggakan          : $nunggak_fmt"
    echo " Jumlah kamar terisi      : $kamar_terisi"
    echo "--------------------------------------------"
    echo " Daftar penghuni menunggak:"
    if [ -z "$daftar_nunggak" ]; then
        echo "  Tidak ada tunggakan."
    else
        echo -e "$daftar_nunggak"
    fi
    echo "============================================"

    {
        echo "============================================"
        echo "      LAPORAN KEUANGAN KOST SLEBEW"
        echo "============================================"
        echo " Total pemasukan (Aktif)  : $aktif_fmt"
        echo " Total tunggakan          : $nunggak_fmt"
        echo " Jumlah kamar terisi      : $kamar_terisi"
        echo "--------------------------------------------"
        echo " Daftar penghuni menunggak:"
        if [ -z "$daftar_nunggak" ]; then
            echo "  Tidak ada tunggakan."
        else
            echo -e "$daftar_nunggak"
        fi
        echo "============================================"
    } > "$LAPORAN"

    echo "[√] Laporan berhasil disimpan ke $LAPORAN"
    read -p "Tekan [ENTER] untuk kembali ke menu..."
}

check_tagihan() {
    today=$(date +%Y-%m-%d)
    nunggak=$(grep -i ",Menunggak$" "$DATABASE" | awk -F',' '{print $1}')
    if [ -z "$nunggak" ]; then
        echo "[$today] Tidak ada penghuni menunggak." >> "$TAGIHAN_LOG"
    else
        echo "[$today] Penghuni menunggak:" >> "$TAGIHAN_LOG"
        echo "$nunggak" | while read -r nama; do
            echo "  - $nama" >> "$TAGIHAN_LOG"
        done
    fi
}

kelola_cron() {
    while true; do
        echo "=================================="
        echo "        MENU KELOLA CRON"
        echo "=================================="
        echo " 1. Lihat Cron Job Aktif"
        echo " 2. Daftarkan Cron Job Pengingat"
        echo " 3. Hapus Cron Job Pengingat"
        echo " 4. Kembali"
        echo "=================================="
        read -p "Pilih [1-4]: " pilih_cron

        case $pilih_cron in
            1)
                echo "--- Daftar Cron Job Pengingat Tagihan ---"
                crontab -l 2>/dev/null | grep "kost_slebew.sh --check-tagihan" || echo "Tidak ada cron job aktif."
                read -p "Tekan [ENTER] untuk kembali ke menu..."
                ;;
            2)
                read -p "Masukkan Jam (0-23): " jam
                read -p "Masukkan Menit (0-59): " menit
                script_path=$(realpath "$0")
                cron_baru="$menit $jam * * * $script_path --check-tagihan"
                (crontab -l 2>/dev/null | grep -v "kost_slebew.sh --check-tagihan"; echo "$cron_baru") | crontab -
                echo "[√] Cron job berhasil didaftarkan: $cron_baru"
                read -p "Tekan [ENTER] untuk kembali ke menu..."
                ;;
            3)
                crontab -l 2>/dev/null | grep -v "kost_slebew.sh --check-tagihan" | crontab -
                echo "[√] Cron job pengingat tagihan berhasil dihapus."
                read -p "Tekan [ENTER] untuk kembali ke menu..."
                ;;
            4) break ;;
            *) echo "[!] Pilihan tidak valid!" ;;
        esac
    done
}

if [ "$1" == "--check-tagihan" ]; then
    check_tagihan
    exit 0
fi

while true; do
    clear
    cat << 'EOF'
  _  _____  ___  _____    ____  _     _____ ____  _______        __
 | |/ / _ \/ __||_   _|  / ___|| |   | ____|  _ \| ____\ \      / /
 | ' / | | \__ \  | |    \___ \| |   |  _| | |_) |  _|  \ \ /\ / / 
 | . \ |_| |__) | | |     ___) | |___| |___|  _ <| |___  \ V  V /  
 |_|\_\___/|___/  |_|    |____/|_____|_____|_| \_\_____|  \_/\_/   
EOF
    echo "============================================"
    echo "      SISTEM MANAJEMEN KOST SLEBEW"
    echo "============================================"
    printf "%-4s | %-30s\n" "ID" "OPTION"
    echo "--------------------------------------------"
    printf "%-4s | %-30s\n" "1" "Tambah Penghuni Baru"
    printf "%-4s | %-30s\n" "2" "Hapus Penghuni"
    printf "%-4s | %-30s\n" "3" "Tampilkan Daftar Penghuni"
    printf "%-4s | %-30s\n" "4" "Update Status Penghuni"
    printf "%-4s | %-30s\n" "5" "Cetak Laporan Keuangan"
    printf "%-4s | %-30s\n" "6" "Kelola Cron (Pengingat Tagihan)"
    printf "%-4s | %-30s\n" "7" "Exit Program"
    echo "============================================"
    read -p "Enter option [1-7]: " pilihan

    case $pilihan in
        1) tambah_penghuni ;;
        2) hapus_penghuni ;;
        3) tampilkan_penghuni ;;
        4) update_status ;;
        5) cetak_laporan ;;
        6) kelola_cron ;;
        7) echo "Sampai jumpa!"; exit 0 ;;
        *) echo "[!] Pilihan tidak valid!" ;;
    esac
done

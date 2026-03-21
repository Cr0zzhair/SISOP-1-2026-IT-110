BEGIN {
    FS = ","
    pilihan = ARGV[2]
    delete ARGV[2]
}

NR == 1 { next }

pilihan == "a" { count++ }
pilihan == "b" { gerbong[$4]++ }
pilihan == "c" { if ($2 > max) { max = $2; oldest = $1 } }
pilihan == "d" { sum += $2 / 208 }
pilihan == "e" && $3 == "Business" { business++ }

END {
    if (pilihan == "a")
        print "Jumlah seluruh penumpang KANJ adalah " count " orang"

    else if (pilihan == "b")
        print "Jumlah gerbong penumpang KANJ adalah " length(gerbong)

    else if (pilihan == "c")
        print oldest " adalah penumpang kereta tertua dengan usia " max " tahun"

    else if (pilihan == "d")
        printf "Rata rata usia penumpang adalah %.0f tahun\n", sum

    else if (pilihan == "e")
        print "Jumlah penumpang business class ada " business " orang"

    else {
        print "Soal tidak dikenali. Gunakan a, b, c, d, atau e."
        print "Contoh penggunaan: awk -f file.sh data.csv a"
    }
}

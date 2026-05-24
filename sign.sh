#!/usr/bin/env bash

detect_environment() {
    if [[ -d "/data/data/com.termux" ]]; then
        ENV="TERMUX"
        PREFIX_BIN="/data/data/com.termux/files/usr/bin"
        echo -e "${BLUE}📱 Environment: TERMUX detected${NC}"
    else
        ENV="LINUX"
        PREFIX_BIN="/usr/bin"
        echo -e "${BLUE}💻 Environment: LINUX detected${NC}"
    fi
}

# Warna (works di kedua environment)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi

apksigner_sign_secure() {
    local ks_env_val="$1"
    local key_env_val="$2"
    shift 2
    APKSIGNER_KS_PASS="$ks_env_val" APKSIGNER_KEY_PASS="$key_env_val" \
        $APKSIGNER_CMD "$@"
}

apksigner_rotate_secure() {
    local old_pass="$1"
    local new_pass="$2"
    shift 2
    APKSIGNER_OLD_PASS="$old_pass" APKSIGNER_NEW_PASS="$new_pass" \
        $APKSIGNER_CMD rotate \
        --old-signer --ks-pass env:APKSIGNER_OLD_PASS \
        --new-signer --ks-pass env:APKSIGNER_NEW_PASS \
        "$@"
}

# Deteksi OS dan install dependencies otomatis
setup_dependencies() {
    detect_environment
    
    echo -e "${YELLOW}🔧 Checking dependencies...${NC}"
    
    # Cek Java (required untuk keytool)
    if ! command -v java &> /dev/null; then
        echo -e "${YELLOW}⚠️  Java not found! Installing...${NC}"
        if [[ "$ENV" == "TERMUX" ]]; then
            pkg install openjdk-17 -y
        else
            sudo apt update
            sudo apt install default-jdk -y
        fi
    fi
    
    # Cek apksigner
    if ! command -v apksigner &> /dev/null; then
        echo -e "${YELLOW}⚠️  apksigner not found! Installing...${NC}"
        if [[ "$ENV" == "TERMUX" ]]; then
            pkg update && pkg upgrade -y
            pkg install apksigner -y
        else
            apt update && apt upgrade -y
            apt install apksigner -y
        fi
        if ! command -v apksigner &> /dev/null; then
            echo -e "${RED}❌ Gagal install apksigner!${NC}"
            exit 1
        fi
    fi
    
    # Cek keytool
    if ! command -v keytool &> /dev/null; then
        echo -e "${RED}❌ keytool not found! Java installation may be incomplete.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All dependencies ready!${NC}"
}

get_apksigner_path() {
    if command -v apksigner &> /dev/null; then
        echo "apksigner"
    elif [[ -f "$PREFIX_BIN/apksigner" ]]; then
        echo "$PREFIX_BIN/apksigner"
    else
        echo -e "${RED}❌ apksigner not found!${NC}"
        exit 1
    fi
}

ask_output_name() {
    local input_apk="$1"
    local default_suffix="$2"
    local default_name="${input_apk%.apk}_${default_suffix}.apk"
    echo -e "${YELLOW}📝 Output APK [default: $default_name]: ${NC}"
    read custom_name
    if [ -z "$custom_name" ]; then
        out_apk="$default_name"
    else
        out_apk="${custom_name%.apk}.apk"
    fi
}

ask_sign_versions() {
    echo ""
    echo -e "${YELLOW}🔏 Pilih Signature Version yang mau diaktifin:${NC}"
    echo -e "${BLUE}   (ketik angka, pisah spasi, contoh: 1 2 3 atau 2 3)${NC}"
    echo "  [1] V1 - JAR Signing     (support semua Android)"
    echo "  [2] V2 - APK Signing     (Android 7.0+, recommended)"
    echo "  [3] V3 - APK Signing     (Android 9.0+, key rotation)"
    echo "  [4] V4 - APK Signing     (Android 11.0+, incremental)"
    echo ""
    echo -e "${YELLOW}  Contoh kombinasi:${NC}"
    echo "    1 2 3  → V1 + V2 + V3 (paling kompatibel)"
    echo "    2 3    → V2 + V3 only (Android 7.0+)"
    echo "    1 2    → V1 + V2 only"
    echo "    2      → V2 only"
    echo "    3      → V3 only"
    echo ""
    read -p "👉 Pilih version [default: 1 2 3]: " ver_input
    [ -z "$ver_input" ] && ver_input="1 2 3"

    v1_enabled=false
    v2_enabled=false
    v3_enabled=false
    v4_enabled=false

    for v in $ver_input; do
        case $v in
            1) v1_enabled=true;;
            2) v2_enabled=true;;
            3) v3_enabled=true;;
            4) v4_enabled=true;;
            *) echo -e "${YELLOW}⚠️  Version '$v' gak dikenal${NC}";;
        esac
    done

    echo ""
    echo -e "${BLUE}   → V1: $v1_enabled | V2: $v2_enabled | V3: $v3_enabled | V4: $v4_enabled${NC}"

    if [ "$v1_enabled" = false ] && [ "$v2_enabled" = false ] && [ "$v3_enabled" = false ] && [ "$v4_enabled" = false ]; then
        echo -e "${RED}❌ Minimal aktifin satu version!${NC}"
        return 1
    fi
    return 0
}

verify_apk() {
    local apk_file="$1"
    local v1_used="${2:-true}"
    local idsig_file="${apk_file}.idsig"

    local sdk_flag=""
    if [ "$v1_used" = "false" ]; then
        sdk_flag="--min-sdk-version 24"
    fi

    if [ -f "$idsig_file" ]; then
        echo -e "${YELLOW}🔍 File .idsig ditemukan! Verifikasi dengan V4 signature...${NC}"
        echo ""
        $APKSIGNER_CMD verify $sdk_flag -v -v4-signature-file "$idsig_file" "$apk_file" 2>&1
        local result=$?
        echo ""
        if [ $result -eq 0 ]; then
            echo -e "${GREEN}✅ APK valid (V2/V3/V3.1/V4 terdeteksi otomatis)${NC}"
        else
            echo -e "${RED}❌ APK gak valid / gagal verifikasi${NC}"
        fi
    else
        echo -e "${YELLOW}🔍 File .idsig tidak ditemukan, verifikasi standar...${NC}"
        echo ""
        $APKSIGNER_CMD verify $sdk_flag --verbose --print-certs "$apk_file" 2>&1
        local result=$?
        echo ""
        if [ $result -eq 0 ]; then
            echo -e "${GREEN}✅ APK valid${NC}"
        else
            echo -e "${RED}❌ APK gak valid / belum disign${NC}"
        fi
    fi
}

sign_v31_v4_combination() {
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}MODE KOMBINASI: V3.1 (ROTASI) + V4 SIGNING${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}📌 Penjelasan:${NC}"
    echo "   - APK akan di-sign dengan rotasi keystore (V3.1)"
    echo "   - PLUS V4 signing untuk Android 11+"
    echo "   - Hasil: APK dengan lineage rotasi + .idsig file"
    echo ""
    
    # Input Keystore LAMA
    echo -e "${YELLOW}🔑 KEYSTORE LAMA (Existing/Primary)${NC}"
    read -p "Keystore LAMA (.jks/.p12/.bks): " old_ks
    [ ! -f "$old_ks" ] && { echo -e "${RED}❌ Gak ketemu!${NC}"; return 1; }
    read -p "Alias LAMA: " old_alias
    read -sp "Password LAMA: " old_pwd; echo
    
    # Input Keystore BARU
    echo ""
    echo -e "${YELLOW}🔑 KEYSTORE BARU (For Rotation)${NC}"
    read -p "Keystore BARU (.jks/.p12/.bks): " new_ks
    [ ! -f "$new_ks" ] && { echo -e "${RED}❌ Gak ketemu!${NC}"; return 1; }
    read -p "Alias BARU: " new_alias
    read -sp "Password BARU: " new_pwd; echo
    
    # Input APK
    echo ""
    read -p "File APK: " apk_file
    [ ! -f "$apk_file" ] && { echo -e "${RED}❌ APK gak ketemu!${NC}"; return 1; }
    
    # Output name
    ask_output_name "$apk_file" "v31_v4"
    
    # Pilih kombinasi V1/V2/V3 untuk V3.1
    echo ""
    echo -e "${YELLOW}🔏 Pilih signature version untuk V3.1 (minimal V2 atau V3):${NC}"
    echo "  [1] V2 + V3        ✅ Recommended untuk rotasi"
    echo "  [2] V1 + V2 + V3   (paling kompatibel)"
    echo "  [3] V2 only        (Android 7.0+)"
    echo "  [4] V3 only        (Android 9.0+)"
    read -p "Pilih [1-4, default=1]: " v31_ver
    
    case $v31_ver in
        2) v31_v1=true; v31_v2=true; v31_v3=true;;
        3) v31_v1=false; v31_v2=true; v31_v3=false;;
        4) v31_v1=false; v31_v2=false; v31_v3=true;;
        *) v31_v1=false; v31_v2=true; v31_v3=true;;
    esac
    
    echo -e "${BLUE}   → V1:$v31_v1 V2:$v31_v2 V3:$v31_v3${NC}"
    
    # ========= STEP 1: Buat Lineage Rotasi =========
    echo ""
    echo -e "${YELLOW}⏳ Step 1/2: Membuat lineage rotasi...${NC}"
    
    lineage_tmp=$(mktemp)
    APKSIGNER_OLD_PASS="$old_pwd" APKSIGNER_NEW_PASS="$new_pwd" \
        $APKSIGNER_CMD rotate \
        --out "$lineage_tmp" \
        --old-signer --ks "$old_ks" --ks-pass env:APKSIGNER_OLD_PASS \
        --new-signer --ks "$new_ks" --ks-pass env:APKSIGNER_NEW_PASS 2>&1
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Gagal buat lineage!${NC}"
        rm -f "$lineage_tmp"
        return 1
    fi
    echo -e "${GREEN}✅ Lineage rotasi berhasil dibuat${NC}"
    
    # ========= STEP 2: Sign dengan V3.1 + V4 =========
    echo -e "${YELLOW}⏳ Step 2/2: Signing APK dengan V3.1 + V4...${NC}"
    
    cp "$apk_file" "$out_apk"
    
    APKSIGNER_OLD_PASS="$old_pwd" APKSIGNER_NEW_PASS="$new_pwd" \
        $APKSIGNER_CMD sign \
        --ks "$old_ks" \
        --ks-key-alias "$old_alias" --ks-pass env:APKSIGNER_OLD_PASS \
        --next-signer \
        --ks "$new_ks" \
        --ks-key-alias "$new_alias" --ks-pass env:APKSIGNER_NEW_PASS \
        --lineage "$lineage_tmp" \
        --rotation-min-sdk-version 33 \
        --v1-signing-enabled $v31_v1 \
        --v2-signing-enabled $v31_v2 \
        --v3-signing-enabled $v31_v3 \
        --v4-signing-enabled true \
        "$out_apk" 2>&1
    
    sign_exit=$?
    rm -f "$lineage_tmp"
    
    if [ $sign_exit -eq 0 ]; then
        idsig_file="${out_apk}.idsig"
        echo ""
        echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}✅ KOMBINASI V3.1 + V4 SIGNING BERHASIL!${NC}"
        echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}📦 Output APK   : $out_apk${NC}"
        echo -e "${GREEN}📋 V3.1 Mode    : V1:$v31_v1 V2:$v31_v2 V3:$v31_v3${NC}"
        echo -e "${GREEN}🔏 V4           : ENABLED${NC}"
        echo -e "${GREEN}📏 Size APK     : $(du -h "$out_apk" | cut -f1)${NC}"
        if [ -f "$idsig_file" ]; then
            echo -e "${GREEN}📄 File .idsig  : $idsig_file ($(du -h "$idsig_file" | cut -f1))${NC}"
        fi
        echo -e "${GREEN}📁 Path         : $(pwd)/$out_apk${NC}"
        echo ""
        echo -e "${YELLOW}⚠️  Catatan V3.1 + V4:${NC}"
        echo "   - APK support key rotation (ganti keystore di update berikutnya)"
        echo "   - V4 signature membutuhkan file .idsig di folder yang sama"
        echo "   - Minimal Android 11+ untuk V4, rotasi butuh Android 9+"
    else
        echo -e "${RED}❌ Gagal sign V3.1 + V4!${NC}"
        rm -f "$out_apk"
        return 1
    fi
}

# ============= MENU 1 YANG UDAH DIUPDATE =============
create_keystore_menu() {
    echo ""
    read -p "Nama keystore (tanpa ekstensi): " ks_input
    [ -z "$ks_input" ] && { echo -e "${RED}❌ Gak boleh kosong!${NC}"; return 1; }

    echo ""
    echo -e "${YELLOW}📦 Pilih Key Type (Store Type):${NC}"
    echo "  [1] JKS      - Java KeyStore (klasik, luas dipakai)"
    echo "  [2] PKCS12   - Standard modern, lebih aman (.p12)"
    echo "  [3] BKS      - BouncyCastle, buat Android lama"
    read -p "Pilih [1-3, default=1]: " kt_choice
    case $kt_choice in
        2) key_type="PKCS12"; ks_name="${ks_input}.p12";;
        3) key_type="BKS";    ks_name="${ks_input}.bks";;
        *) key_type="JKS";    ks_name="${ks_input}.jks";;
    esac
    echo -e "${GREEN}   → Key Type: $key_type | File: $ks_name${NC}"

    if [ -f "$ks_name" ]; then
        read -p "File $ks_name udah ada. Timpa? (y/N): " overwrite
        [[ ! "$overwrite" =~ ^[Yy]$ ]] && { echo -e "${YELLOW}🚫 Batal bikin keystore.${NC}"; return 1; }
    fi

    read -p "Alias: " ks_alias
    [ -z "$ks_alias" ] && { echo -e "${RED}❌ Alias kosong!${NC}"; return 1; }
    read -sp "Password (min 6): " ks_pwd; echo
    [ ${#ks_pwd} -lt 6 ] && { echo -e "${RED}❌ Min 6 karakter!${NC}"; return 1; }
    read -sp "Konfirmasi password: " ks_pwd2; echo
    [ "$ks_pwd" != "$ks_pwd2" ] && { echo -e "${RED}❌ Gak sama!${NC}"; return 1; }

    echo ""
    echo -e "${YELLOW}🔑 Pilih Key Algorithm:${NC}"
    echo "  [1] RSA  ✅ Paling umum dipakai (default)"
    echo "  [2] EC   🔒 Elliptic Curve, lebih kecil & cepat, pake ECDSA"
    echo "  [3] DSA  ⚠️  Digital Signature Algorithm, legacy"
    read -p "Pilih [1-3, default=1]: " algo_choice

    keyalg=""
    sigalg=""
    case $algo_choice in
        2)
            alg="EC"
            echo -e "${YELLOW}📐 Pilih Elliptic Curve:${NC}"
            echo "  [1] secp256r1 (NIST P-256)  ✅ Recommended, kompatibel luas"
            echo "  [2] secp384r1 (NIST P-384)  🔒 Lebih kuat, ukuran key lebih gede"
            echo "  [3] secp521r1 (NIST P-521)  🔒🔒 Paling kuat, agak lambat"
            echo "  [4] prime256v1 (alias secp256r1)"
            read -p "Pilih [1-4, default=1]: " curve_choice
            case $curve_choice in
                2) curve="secp384r1";;
                3) curve="secp521r1";;
                4) curve="prime256v1";;
                *) curve="secp256r1";;
            esac
            keyalg="-keyalg EC -groupname $curve"
            
            echo ""
            echo -e "${YELLOW}🔐 Pilih Signature Algorithm (untuk EC):${NC}"
            echo "  [1] SHA256withECDSA  ✅ Recommended (default)"
            echo "  [2] SHA384withECDSA  🔒 Lebih kuat"
            echo "  [3] SHA512withECDSA  🔒🔒 Paling kuat"
            read -p "Pilih [1-3, default=1]: " ec_sig_choice
            case $ec_sig_choice in
                2) sigalg="SHA384withECDSA";;
                3) sigalg="SHA512withECDSA";;
                *) sigalg="SHA256withECDSA";;
            esac
            ;;
        3)
            alg="DSA"
            echo -e "${YELLOW}🔢 Ukuran DSA (1024/2048) [default 2048]:${NC}"
            read keysize
            [ -z "$keysize" ] && keysize=2048
            [[ ! "$keysize" =~ ^(1024|2048)$ ]] && { echo -e "${RED}❌ Ukuran gak valid! Pakai 2048.${NC}"; keysize=2048; }
            keyalg="-keyalg DSA -keysize $keysize"
            
            echo ""
            echo -e "${YELLOW}🔐 Pilih Signature Algorithm (untuk DSA):${NC}"
            echo "  [1] SHA256withDSA  ✅ Recommended (default)"
            echo "  [2] SHA224withDSA"
            read -p "Pilih [1-2, default=1]: " dsa_sig_choice
            if [ "$dsa_sig_choice" = "2" ]; then
                sigalg="SHA224withDSA"
            else
                sigalg="SHA256withDSA"
            fi
            ;;
        *)
            alg="RSA"
            echo -e "${YELLOW}🔢 Ukuran RSA (1024/2048/4096/8192) [default 2048]:${NC}"
            read keysize
            [ -z "$keysize" ] && keysize=2048
            [[ ! "$keysize" =~ ^(1024|2048|4096|8192)$ ]] && { echo -e "${RED}❌ Ukuran gak valid! Pakai 2048.${NC}"; keysize=2048; }
            keyalg="-keyalg RSA -keysize $keysize"
            
            echo ""
            echo -e "${YELLOW}🔐 Pilih Signature Algorithm (untuk RSA):${NC}"
            echo "  [1] SHA256withRSA  ✅ Recommended (default)"
            echo "  [2] SHA512withRSA  🔒 Lebih kuat, file lebih besar"
            echo "  [3] SHA384withRSA  🔒 Antara 256 & 512"
            echo "  [4] SHA224withRSA  ⚠️  Jarang dipakai"
            echo "  [5] SHA1withRSA    ⚠️  Lama, hindari kalau bisa"
            echo "  [6] MD5withRSA     ❌ Gak aman, legacy only"
            read -p "Pilih [1-6, default=1]: " rsa_sig_choice
            case $rsa_sig_choice in
                2) sigalg="SHA512withRSA";;
                3) sigalg="SHA384withRSA";;
                4) sigalg="SHA224withRSA";;
                5) sigalg="SHA1withRSA";;
                6) sigalg="MD5withRSA";;
                *) sigalg="SHA256withRSA";;
            esac
            ;;
    esac

    echo -e "${GREEN}   → Key Algorithm: $alg | Signature: $sigalg${NC}"

    echo ""
    echo -e "${YELLOW}📋 Info Sertifikat (DN):${NC}"
    echo -e "${BLUE}   CN  = Common Name    → Nama lu / nama app${NC}"
    echo -e "${BLUE}   OU  = Org Unit       → Divisi/tim (misal: Dev, Android)${NC}"
    echo -e "${BLUE}   O   = Organization   → Nama perusahaan/organisasi${NC}"
    echo -e "${BLUE}   L   = Locality       → Nama kota${NC}"
    echo -e "${BLUE}   ST  = State          → Nama provinsi/negara bagian${NC}"
    echo -e "${BLUE}   C   = Country        → Kode negara 2 huruf (ID=Indonesia, US=Amerika)${NC}"
    echo ""

    while true; do
        read -p "CN - Common Name (wajib): " cn
        [ -n "$cn" ] && break
        echo -e "${RED}❌ CN gak boleh kosong!${NC}"
    done
    read -p "OU - Org Unit      (kosong = Unknown): " ou
    read -p "O  - Organization  (kosong = Unknown): " o
    read -p "L  - Kota          (kosong = Unknown): " l
    read -p "ST - Provinsi      (kosong = Unknown): " st
    read -p "C  - Kode Negara   (kosong = ID): " c
    ou="${ou:-Unknown}"
    o="${o:-Unknown}"
    l="${l:-Unknown}"
    st="${st:-Unknown}"
    c="${c:-ID}"

    if [ ${#c} -ne 2 ]; then
        echo -e "${RED}❌ Kode negara harus 2 huruf!${NC}"
        return 1
    fi

    dname="CN=$cn, OU=$ou, O=$o, L=$l, ST=$st, C=$c"
    echo -e "${BLUE}📄 dname: $dname${NC}"

    echo -e "${YELLOW}⏳ Membuat keystore $ks_name...${NC}"
    keytool -genkey -v \
        -keystore "$ks_name" \
        -storetype "$key_type" \
        $keyalg \
        -sigalg "$sigalg" \
        -validity 36500 \
        -alias "$ks_alias" \
        -storepass "$ks_pwd" \
        -keypass "$ks_pwd" \
        -dname "$dname" \
        -noprompt 2>/dev/null

    if [ -f "$ks_name" ]; then
        echo -e "${GREEN}✅ Keystore berhasil: $ks_name${NC}"
        echo -e "${YELLOW}📁 Lokasi: $(pwd)/$ks_name${NC}"
        echo -e "${BLUE}📋 Summary: Type=$key_type | Algo=$alg | Sig=$sigalg${NC}"
    else
        echo -e "${RED}❌ Gagal!${NC}"
        return 1
    fi
}

# MAIN
setup_dependencies
APKSIGNER_CMD=$(get_apksigner_path)

while true; do
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  APK SIGNER v2.3 (Beta) - [$ENV MODE]"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  [1] Buat keystore (custom algorithm + key size)"
    echo "  [2] Sign APK (V1/V2/V3 - pilih kombinasi)"
    echo "  [3] Sign APK V3.1 (rotasi 2 keystore)"
    echo "  [4] Verifikasi APK (OTOMATIS DETEKSI V4/IDSIG)"
    echo "  [5] Sign APK V4 (jks/p12/bks)"
    echo "  [6] KOMBINASI V3.1 + V4 (ROTASI + V4)"
    echo "  [0] Keluar"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -p "👉 Pilih: " mode

    case $mode in
        1)
            create_keystore_menu
            ;;
        2)
            echo ""
            read -p "File APK: " apk_file
            [ ! -f "$apk_file" ] && { echo -e "${RED}❌ APK gak ketemu!${NC}"; continue; }
            read -p "Keystore (.jks/.p12/.bks): " ks_file
            [ ! -f "$ks_file" ] && { echo -e "${RED}❌ Keystore gak ketemu!${NC}"; continue; }

            case "${ks_file##*.}" in
                p12|pfx) ks_type="PKCS12";;
                bks)     ks_type="BKS";;
                *)       ks_type="JKS";;
            esac
            echo -e "${BLUE}   → Terdeteksi: $ks_type${NC}"

            read -p "Alias: " sign_alias
            read -sp "Password: " sign_pwd; echo

            ask_sign_versions || continue
            ask_output_name "$apk_file" "signed"

            cp "$apk_file" "$out_apk"
            APKSIGNER_KS_PASS="$sign_pwd" \
            $APKSIGNER_CMD sign \
                --ks "$ks_file" \
                --ks-key-alias "$sign_alias" \
                --ks-pass env:APKSIGNER_KS_PASS \
                --key-pass env:APKSIGNER_KS_PASS \
                --v1-signing-enabled $v1_enabled \
                --v2-signing-enabled $v2_enabled \
                --v3-signing-enabled $v3_enabled \
                --v4-signing-enabled $v4_enabled \
                "$out_apk" 2>&1

            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ Signed: $out_apk${NC}"
                echo -e "${GREEN}📋 Mode : V1=$v1_enabled | V2=$v2_enabled | V3=$v3_enabled | V4=$v4_enabled${NC}"
                echo -e "${GREEN}📏 Size : $(du -h "$out_apk" | cut -f1)${NC}"
                echo -e "${GREEN}📁 Path : $(pwd)/$out_apk${NC}"
                verify_apk "$out_apk" "$v1_enabled"
            else
                echo -e "${RED}❌ Gagal sign!${NC}"
                rm -f "$out_apk"
            fi
            ;;

        3)
            echo ""
            echo -e "${YELLOW}🔑 Mode rotasi V3.1 (butuh 2 keystore)${NC}"
            echo ""
            read -p "Keystore LAMA: " old_ks
            [ ! -f "$old_ks" ] && { echo -e "${RED}❌ Gak ketemu!${NC}"; continue; }
            read -p "Alias LAMA: " old_alias
            read -sp "Password LAMA: " old_pwd; echo
            echo ""
            read -p "Keystore BARU: " new_ks
            [ ! -f "$new_ks" ] && { echo -e "${RED}❌ Gak ketemu!${NC}"; continue; }
            read -p "Alias BARU: " new_alias
            read -sp "Password BARU: " new_pwd; echo
            echo ""
            read -p "File APK: " apk_file
            [ ! -f "$apk_file" ] && { echo -e "${RED}❌ APK gak ketemu!${NC}"; continue; }
            ask_sign_versions || continue
            ask_output_name "$apk_file" "v31"

            echo -e "${YELLOW}⏳ Buat lineage rotasi...${NC}"
            lineage_tmp=$(mktemp)
            APKSIGNER_OLD_PASS="$old_pwd" APKSIGNER_NEW_PASS="$new_pwd" \
                $APKSIGNER_CMD rotate \
                --out "$lineage_tmp" \
                --old-signer --ks "$old_ks" --ks-pass env:APKSIGNER_OLD_PASS \
                --new-signer --ks "$new_ks" --ks-pass env:APKSIGNER_NEW_PASS 2>&1

            if [ $? -ne 0 ]; then
                echo -e "${RED}❌ Gagal buat lineage!${NC}"
                rm -f "$lineage_tmp"
                continue
            fi
            echo -e "${GREEN}✅ Lineage dibuat.${NC}"

            echo -e "${YELLOW}⏳ Signing APK V3.1...${NC}"

            cp "$apk_file" "$out_apk"
            APKSIGNER_OLD_PASS="$old_pwd" APKSIGNER_NEW_PASS="$new_pwd" \
                $APKSIGNER_CMD sign \
                --ks "$old_ks" \
                --ks-key-alias "$old_alias" --ks-pass env:APKSIGNER_OLD_PASS \
                --next-signer \
                --ks "$new_ks" \
                --ks-key-alias "$new_alias" --ks-pass env:APKSIGNER_NEW_PASS \
                --lineage "$lineage_tmp" \
                --rotation-min-sdk-version 33 \
                --v1-signing-enabled $v1_enabled \
                --v2-signing-enabled $v2_enabled \
                --v3-signing-enabled $v3_enabled \
                --v4-signing-enabled $v4_enabled \
                "$out_apk" 2>&1

            sign_exit=$?
            rm -f "$lineage_tmp"

            if [ $sign_exit -eq 0 ]; then
                echo -e "${GREEN}✅ V3.1 Signed: $out_apk${NC}"
                echo -e "${GREEN}📋 Mode : V1=$v1_enabled | V2=$v2_enabled | V3=$v3_enabled | V4=$v4_enabled${NC}"
                echo -e "${GREEN}📏 Size : $(du -h "$out_apk" | cut -f1)${NC}"
                echo -e "${GREEN}📁 Path : $(pwd)/$out_apk${NC}"
            else
                echo -e "${RED}❌ Gagal sign V3.1!${NC}"
                rm -f "$out_apk"
            fi
            ;;

        4)
            echo ""
            read -p "File APK: " apk_file
            [ ! -f "$apk_file" ] && { echo -e "${RED}❌ APK gak ketemu!${NC}"; continue; }
            if unzip -l "$apk_file" 2>/dev/null | grep -q "META-INF/MANIFEST.MF"; then
                verify_apk "$apk_file" "true"
            else
                verify_apk "$apk_file" "false"
            fi
            ;;

        5)
            echo ""
            echo -e "${YELLOW}🔐 Mode Sign APK V4${NC}"
            echo -e "${BLUE}   V4 butuh V2 atau V3 juga aktif.${NC}"
            echo ""

            read -p "File APK: " apk_file
            [ ! -f "$apk_file" ] && { echo -e "${RED}❌ APK gak ketemu!${NC}"; continue; }

            read -p "Keystore (.jks/.p12/.bks): " ks_file
            [ ! -f "$ks_file" ] && { echo -e "${RED}❌ Keystore gak ketemu!${NC}"; continue; }

            case "${ks_file##*.}" in
                p12|pfx) ks_type="PKCS12";;
                bks)     ks_type="BKS";;
                *)       ks_type="JKS";;
            esac
            echo -e "${BLUE}   → Terdeteksi: $ks_type${NC}"

            read -p "Alias: " sign_alias
            read -sp "Password: " sign_pwd; echo

            echo ""
            echo -e "${YELLOW}🔏 V4 butuh V2 atau V3. Pilih kombinasi:${NC}"
            echo "  [1] V2 + V3 + V4   ✅ Recommended (default)"
            echo "  [2] V2 + V4        (Android 7.0+)"
            echo "  [3] V3 + V4        (Android 9.0+)"
            echo "  [4] V1 + V2 + V3 + V4  (paling kompatibel)"
            read -p "Pilih [1-4, default=1]: " v4_combo

            case $v4_combo in
                2) v1e=false; v2e=true;  v3e=false; combo_label="V2+V4";;
                3) v1e=false; v2e=false; v3e=true;  combo_label="V3+V4";;
                4) v1e=true;  v2e=true;  v3e=true;  combo_label="V1+V2+V3+V4";;
                *) v1e=false; v2e=true;  v3e=true;  combo_label="V2+V3+V4";;
            esac
            echo -e "${BLUE}   → Mode: $combo_label${NC}"

            ask_output_name "$apk_file" "signed_v4"

            cp "$apk_file" "$out_apk"
            APKSIGNER_KS_PASS="$sign_pwd" \
            $APKSIGNER_CMD sign \
                --ks "$ks_file" \
                --ks-key-alias "$sign_alias" \
                --ks-pass env:APKSIGNER_KS_PASS \
                --key-pass env:APKSIGNER_KS_PASS \
                --v1-signing-enabled $v1e \
                --v2-signing-enabled $v2e \
                --v3-signing-enabled $v3e \
                --v4-signing-enabled true \
                "$out_apk" 2>&1

            if [ $? -eq 0 ]; then
                idsig_file="${out_apk}.idsig"
                echo -e "${GREEN}✅ Signed V4: $out_apk${NC}"
                echo -e "${GREEN}📋 Mode : $combo_label${NC}"
                echo -e "${GREEN}📏 Size APK   : $(du -h "$out_apk" | cut -f1)${NC}"
                if [ -f "$idsig_file" ]; then
                    echo -e "${GREEN}📄 File .idsig: $idsig_file ($(du -h "$idsig_file" | cut -f1))${NC}"
                fi
                echo -e "${GREEN}📁 Path : $(pwd)/$out_apk${NC}"
                echo ""
                echo -e "${YELLOW}⚠️  Catatan: file .idsig harus ada di folder yang sama waktu install!${NC}"
                verify_apk "$out_apk" "$v1e"
            else
                echo -e "${RED}❌ Gagal sign V4!${NC}"
                rm -f "$out_apk"
            fi
            ;;

        6)
            sign_v31_v4_combination
            ;;

        0)
            echo -e "${BLUE}👋 Dadah bangsat!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Pilihan salah!${NC}"
            ;;
    esac
done
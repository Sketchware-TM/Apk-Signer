# Apk Signer V2.4 (Beta)
<p align="center">
  <img src="https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" alt="Bash"/>
  <img src="https://img.shields.io/badge/Termux-Android-000000?style=for-the-badge&logo=android&logoColor=3DDC84" alt="Termux"/>
  <img src="https://img.shields.io/badge/Linux-Compatible-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Linux"/>
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="MIT License"/>
  <img src="https://img.shields.io/badge/version-2.4--beta-f59e0b?style=for-the-badge" alt="Version 2.4 Beta"/>
</p>

Script Bash interaktif untuk signing APK Android. Support semua versi signature (V1–V4), buat keystore baru, key rotation (V3.1), dan verifikasi APK. Jalan di **Termux** (Android) maupun **Linux**.

---

## ✨ Fitur

| Menu | Fungsi |
|------|--------|
| [1] Buat Keystore | RSA / EC / DSA, pilih ukuran & algoritma |
| [2] Sign APK | V1 / V2 / V3 / V4 (kombinasi bebas, custom pilih per version) |
| [3] Sign V3.1 | Key rotation dengan 2 keystore (custom signature version) |
| [4] Verifikasi APK | Auto-deteksi V4 (.idsig) |
| [5] Sign V4 | Butuh V2 atau V3 aktif |
| [6] V3.1 + V4 | Kombinasi rotasi + V4 sekaligus |
| ⏳ Loading Spinner | Indikator proses berjalan di semua operasi sign/rotate/keystore, plus warning highlight otomatis |
| 🧹 Auto Strip Signature | Deteksi & hapus META-INF lama otomatis sebelum signing (dengan konfirmasi) |
| 🔒 DN Escape | Support spasi, koma, dan tanda kurung di Distinguished Name (fix error `Incorrect AVA format`) |

---

## 🔧 Changelog

### v2.4 (Beta)
- **New** Auto-strip signature lama — sebelum signing, script deteksi META-INF di APK, kasih pilihan hapus atau skip (mencegah konflik V2 verify di MT Manager dkk)
- **New** Escape karakter khusus di DN — support spasi, koma `,`, tanda kurung `( )`, dan backslash `\` di CN/OU/O/L/ST (fix `java.io.IOException: Incorrect AVA format`)
- **Fix** Spinner & output handling — command output di-redirect ke temp file, hanya tampil kalau ada error/warning; warning ditampilkan dengan warna merah otomatis
- **Fix** Hapus `eval` di `run_with_spinner` — panggil command langsung pake `"$@"` biar argumen dengan spasi & karakter khusus gak pecah
- **Security** Semua panggilan `apksigner` dan `keytool` pakai `env` untuk password — gak bocor di `ps aux`

### v2.3 (Beta)
- **Fix** Verifikasi APK — tidak error `Missing META-INF/MANIFEST.MF` saat V1 disabled, auto-deteksi V1 via isi APK
- **Fix** `mktemp` pakai default temp directory sistem — fix permission denied di Termux
- **Security** Password signing tidak bocor di `ps aux`, ditangani via environment variable (`env:APKSIGNER_KS_PASS`)
- **Improve** Install `apksigner` via `pkg install` / `apt install` (hapus wget URL)
- **Improve** Auto-verify setelah sign di semua mode

### v2.2 (Beta)
- **Fix** Menu [1] Buat Keystore — sigalg sekarang disesuaikan per key algorithm (RSA → `withRSA`, EC → `withECDSA`, DSA → `withDSA`), sebelumnya selalu `withRSA` dan error kalau pilih EC/DSA
- **Fix** EC keystore — flag `-keysize -curve` yang salah diganti jadi `-groupname <curve>` sesuai syntax keytool yang bener
- **Improve** Menu [1] di-refactor jadi function `create_keystore_menu()` tersendiri
- **Improve** EC sekarang punya menu pilihan curve sendiri (secp256r1 / secp384r1 / secp521r1 / prime256v1)
- **Improve** DSA sekarang punya menu pilihan sigalg sendiri (SHA256withDSA / SHA224withDSA)
- **Improve** Summary keystore di akhir tampilin `Type | Algo | Sig` buat konfirmasi

### v2.1
- **Fix** Menu [2] Sign APK — tambah flag `--v4-signing-enabled` eksplisit supaya V4 gak ikut ke-generate kalau gak dipilih
- **Fix** Menu [3] Sign V3.1 — sebelumnya hardcoded V1+V2+V3=true semua, sekarang pakai `ask_sign_versions` biar bisa custom + tambah flag V4
- **Fix** Echo hasil di menu [3] sekarang tampilin semua versi termasuk V4

### v2.0
- Rilis awal dengan fitur lengkap: buat keystore, sign V1–V4, V3.1 rotation, verifikasi APK
- Support Termux & Linux dengan auto-detect environment
- Auto-install dependencies

---

## 📋 Requirements

- `java` / `keytool` (OpenJDK 17+)
- `apksigner` (Android Build Tools)

> Script otomatis install dependencies kalau belum ada.

---

# 🚀 Cara Pakai

```bash
chmod +x sign.sh
./sign.sh
```

📱 Termux (Android)

```bash
pkg install openjdk-17
./sign.sh
```

💻 Linux (Debian/Ubuntu)

```bash
sudo apt install default-jdk apksigner -y
./sign.sh
```

---

📱 Update & Kontak

Kalau ada kendala, mau lapor bug, langsung aja hubungi di bawah ini:

- **Telegram Personal:** [@SkTeamProject29](https://t.me/SkTeamProject29)  

Atau klik langsung link ini buat chat:  
👉 [https://t.me/SkTeamProject29](https://t.me/SkTeamProject29)

---

⚠️ Catatan V4

File .idsig harus ada di folder yang sama dengan APK waktu install.

---

📄 License

MIT License — bebas dipakai, dimodif, dan didistribusiin asal tetap kasih kredit.
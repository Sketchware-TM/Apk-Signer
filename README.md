# Apk Signer V2.0
<p align="center">
  <img src="https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" alt="Bash"/>
  <img src="https://img.shields.io/badge/Termux-Android-000000?style=for-the-badge&logo=android&logoColor=3DDC84" alt="Termux"/>
  <img src="https://img.shields.io/badge/Linux-Compatible-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Linux"/>
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="MIT License"/>
  <img src="https://img.shields.io/badge/version-2.0-4ade80?style=for-the-badge" alt="Version 2.0"/>
</p>

Script Bash interaktif untuk signing APK Android. Support semua versi signature (V1–V4), buat keystore baru, key rotation (V3.1), dan verifikasi APK. Jalan di **Termux** (Android) maupun **Linux**.

---

## ✨ Fitur

| Menu | Fungsi |
|------|--------|
| [1] Buat Keystore | RSA / EC / DSA, pilih ukuran & algoritma |
| [2] Sign APK | V1 / V2 / V3 (kombinasi bebas) |
| [3] Sign V3.1 | Key rotation dengan 2 keystore |
| [4] Verifikasi APK | Auto-deteksi V4 (.idsig) |
| [5] Sign V4 | Butuh V2 atau V3 aktif |
| [6] V3.1 + V4 | Kombinasi rotasi + V4 sekaligus |

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

### 📱 Termux (Android)

```bash
pkg install openjdk-17
./sign.sh
```

### 💻 Linux (Debian/Ubuntu)

```bash
sudo apt install default-jdk apksigner -y
./sign.sh
```

---

## ⚠️ Catatan V4

File `.idsig` harus ada **di folder yang sama** dengan APK waktu install.

---

## 📄 License
MIT License — bebas dipakai, dimodif, dan didistribusiin asal tetap kasih kredit.

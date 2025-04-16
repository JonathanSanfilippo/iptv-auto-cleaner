# iptv-auto-cleaner

# IPTV Auto Cleaner

An automated system for cleaning, normalizing, and continuously updating IPTV playlists in M3U format. Compatible with public repositories like [Free-TV/IPTV](https://github.com/Free-TV/IPTV).

## 🔧 Features

- ✅ Parses and processes all `.m3u8` playlist files
- 🔄 Converts them into a clean and structured format
- 📦 Automatically saves updated versions
- 🔗 Generates `.txt` files with direct `raw` links per country
- 🧪 Continuous testing via GitHub Actions
- 🌍 Supports over 70 countries

## 📸 Preview

![GitHub Actions: Auto M3U Updater](Screenshot%20From%202025-04-17%2000-48-41.png)

## 🚀 How it works

1. The `process.sh` script reads all `.m3u8` files inside the `playlists/` directory  
2. Each file is validated, cleaned, and rebuilt with consistent group/title/logo fields  
3. Raw links are exported to `.txt` files for easy access  
4. GitHub Actions runs the process automatically on every push  

## 📂 Output

Example of generated files:



#!/bin/bash
set -e

INITRD_ORIG="/srv/tftp/debian-installer/initrd.gz"
PRESEED_DIR="/var/www/html/preseed"
WORKDIR="/tmp/initrd_work"
BACKUP_DIR="/srv/tftp/debian-installer/backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Перевірка initrd.gz
if [ ! -f "$INITRD_ORIG" ]; then
  echo "[❌] Помилка: initrd.gz не знайдено за шляхом $INITRD_ORIG"
  exit 1
fi

# Перевірка preseed.cfg
if [ ! -f "$PRESEED_DIR/debian12.cfg" ]; then
  echo "[❌] Помилка: preseed-файл debian12.cfg не знайдено в $PRESEED_DIR"
  exit 1
fi

# Перевірка, чи є хоч один .cfg файл
CFG_FILES=("$PRESEED_DIR"/*.cfg)
if [ ${#CFG_FILES[@]} -eq 0 ]; then
  echo "[❌] Помилка: у папці $PRESEED_DIR немає .cfg файлів"
  exit 1
fi

echo "[*] Створення бекапу..."
mkdir -p "$BACKUP_DIR"
cp "$INITRD_ORIG" "$BACKUP_DIR/initrd.gz.bak_$TIMESTAMP"
echo "[✔] Бекап збережено в: $BACKUP_DIR/initrd.gz.bak_$TIMESTAMP"

echo "[*] Очистка робочої папки..."
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "[*] Розпаковка initrd.gz..."
gzip -d < "$INITRD_ORIG" | cpio -id --quiet

echo "[*] Копіювання preseed-файлів..."
for file in "$PRESEED_DIR"/*.cfg; do
  cp "$file" "$(basename "$file")"
done

# Основний preseed
cp "$PRESEED_DIR/debian12.cfg" preseed.cfg

echo "[*] Створення нового initrd.gz..."
find . | cpio -o -H newc --quiet | gzip -9 > "$INITRD_ORIG"

echo "[✅] Готово! Новий initrd.gz створено з вбудованими preseed-файлами."
echo "[🛡️] Бекап залишено тут: $BACKUP_DIR"


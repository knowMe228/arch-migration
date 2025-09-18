#!/bin/bash

# Путь к рабочей директории (той же, где находится этот скрипт)
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# URL удаленного репозитория (замените на свой)
GIT_REMOTE_URL="https://github.com/knowMe228/arch-migration.git"

echo "[+] Переход в рабочую директорию: $WORKDIR"
cd "$WORKDIR" || exit 1

# Проверяем, существует ли .git директория, если нет - инициализируем
if [ ! -d ".git" ]; then
    echo "[+] Инициализация git репозитория..."
    git init
    git remote add origin "$GIT_REMOTE_URL"
    git checkout -b main 2>/dev/null || true
fi

# Добавляем все файлы
echo "[+] Добавление файлов в индекс..."
git add .

# Создаем коммит с временной меткой
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
COMMIT_MSG="Backup files - $TIMESTAMP"
echo "[+] Создание коммита: $COMMIT_MSG"
git commit -m "$COMMIT_MSG" 2>/dev/null || echo "[!] Нет изменений для коммита"

# Пытаемся отправить изменения
echo "[+] Отправка в GitHub репозиторий..."
git push -u origin main 2>/dev/null || {
    echo "[+] Создание ветки main на удаленном репозитории..."
    git push -u origin HEAD:main
}

echo "[+] Файлы успешно загружены в GitHub репозиторий"
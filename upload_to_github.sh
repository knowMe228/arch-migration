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

# Проверяем, есть ли что коммитить
if ! git diff --cached --quiet; then
    # Создаем коммит с временной меткой
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    COMMIT_MSG="Backup files - $TIMESTAMP"
    echo "[+] Создание коммита: $COMMIT_MSG"
    git commit -m "$COMMIT_MSG"
    
    # Пытаемся отправить изменения
    echo "[+] Отправка в GitHub репозиторий..."
    if git push -u origin main 2>/dev/null; then
        echo "[+] Файлы успешно загружены в GitHub репозиторий"
    else
        echo "[+] Создание ветки main на удаленном репозитории..."
        git push -u origin HEAD:main
        echo "[+] Файлы успешно загружены в GitHub репозиторий"
    fi
else
    echo "[i] Нет изменений для коммита"
fi

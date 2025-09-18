#!/usr/bin/env python3
import os
import sys
import subprocess
import shutil
import json
from pathlib import Path

# === Настройки ===
# Путь к git-репозиторию для хранения архивов
GIT_REPO_PATH = str(Path.cwd() / "backup_repo")
GIT_REMOTE_URL = "git@github.com:knowMe228/arch-migration.git"  # <-- замените на свой

# Список репозиториев для автоматического клонирования
GITHUB_REPOS = [
    "https://github.com/danielmiessler/SecLists.git",
    # Добавляйте свои ссылки ниже
]
WORKDIR = Path.cwd()
FILES_TO_BACKUP = [
    Path("/home/kali/.zshrc"),
    Path("/home/kali/.config/zellij"),
    Path("/home/kali/.oh-my-zsh"),
    Path("/etc/hosts"),
    Path("/etc/wireguard"),
]

# === Вспомогательные функции ===
def run_cmd(cmd, cwd=None, capture_output=False, check=True, text=True, input=None):
    return subprocess.run(cmd, cwd=cwd, capture_output=capture_output, check=check, text=text, input=input)

def fzf_select(options, prompt):
    try:
        result = run_cmd(
            [
                "fzf",
                "-m",
                "--prompt", f"{prompt} ",
                "--bind", "space:toggle",
                "--marker=✔ ",
                "--bind", "ctrl-b:abort"
            ],
            input="\n".join(options),
            capture_output=True
        )
        return result.stdout.strip().split("\n") if result.stdout.strip() else []
    except subprocess.CalledProcessError:
        return []

def save_list(name, items):
    path = WORKDIR / name
    path.write_text("\n".join(items))
    print(f"[+] Список сохранён: {path}")

def clone_repo():
    repo_dir = Path(GIT_REPO_PATH)
    if not repo_dir.exists():
        run_cmd(["git", "clone", GIT_REMOTE_URL, str(repo_dir)])
    else:
        run_cmd(["git", "pull"], cwd=repo_dir)
    # Копируем архивы и списки из репозитория в рабочую директорию
    for f in repo_dir.iterdir():
        if f.suffix in [".tar.gz", ".7z", ".txt"]:
            shutil.copy2(f, WORKDIR / f.name)
    print("[+] Архивы и списки скопированы из git")


def ensure_tools(tools):
    for tool in tools:
        if shutil.which(tool) is None:
            print(f"[!] Установи: {tool}")
            exit(1)

# === Backup ===
def get_pacman_packages():
    pkgs = run_cmd(["pacman", "-Qqe"], capture_output=True).stdout.splitlines()
    return fzf_select(pkgs, "Выбери pacman пакеты:")

def get_pipx_packages():
    try:
        sudo_user = os.environ.get("SUDO_USER")
        if sudo_user:
            cmd = ["sudo", "-u", sudo_user, "pipx", "list", "--json"]
        else:
            cmd = ["pipx", "list", "--json"]
        raw = run_cmd(cmd, capture_output=True).stdout
        data = json.loads(raw)
        pkgs = list(data.get("venvs", {}).keys())
        return fzf_select(pkgs, "Выбери pipx пакеты:")
    except Exception:
        return []

def get_flatpak_packages():
    try:
        pkgs = run_cmd(["flatpak", "list", "--columns=application"], capture_output=True).stdout.splitlines()
        return fzf_select(pkgs, "Выбери flatpak пакеты:")
    except Exception:
        return []



def copy_configs():
    for item in FILES_TO_BACKUP:
        if item.exists():
            dest_name = item.name.strip("/").replace("/", "_")
            archive_path = WORKDIR / (dest_name + ".tar.gz")
            try:
                if str(item).startswith("/etc/"):
                    run_cmd(["sudo", "tar", "-czf", str(archive_path), "-C", str(item.parent), item.name])
                else:
                    if item.is_dir():
                        run_cmd(["tar", "-czf", str(archive_path), "-C", str(item.parent), item.name])
                    else:
                        run_cmd(["tar", "-czf", str(archive_path), "-C", str(item.parent), item.name])
                print(f"[+] Заархивировано: {item} -> {archive_path}")

                # Проверяем размер архива и делим, если > 50 МБ
                if archive_path.stat().st_size > 50 * 1024 * 1024:
                    # Разделяем архив на тома по 50 МБ
                    run_cmd(["7z", "a", str(archive_path) + ".7z", str(archive_path), "-v50m"])
                    print(f"[+] Архив разделён на тома: {archive_path}.7z.001 ...")
                    archive_path.unlink()  # удаляем исходный tar.gz
            except PermissionError:
                print(f"[!] Нет прав на архивирование {item}, попробуй sudo")
        else:
            print(f"[-] Пропущено: {item}")




def backup():
    ensure_tools(["fzf", "git"])
    pacman_pkgs = get_pacman_packages()
    pipx_pkgs = get_pipx_packages()
    flatpak_pkgs = get_flatpak_packages()
    save_list("pacman_packages.txt", pacman_pkgs)
    save_list("pipx_packages.txt", pipx_pkgs)
    save_list("flatpak_packages.txt", flatpak_pkgs)
    copy_configs()
    upload_archives_with_script()


# === Restore ===

def setup_blackarch():
    HOME = Path("/home/kali")
    strap = HOME / "strap.sh"
    if not strap.exists():
        run_cmd(["curl", "-O", "https://blackarch.org/strap.sh"], cwd=HOME)
        run_cmd(["chmod", "+x", "strap.sh"], cwd=HOME)
        run_cmd(["sudo", "./strap.sh"], cwd=HOME)
    print("[+] BlackArch подключён")
def setup_yay():
    if shutil.which("yay") is None:
        run_cmd(["sudo", "pacman", "-S", "--needed", "git", "base-devel"])
        if not Path("/tmp/yay").exists():
            run_cmd(["git", "clone", "https://aur.archlinux.org/yay.git"], cwd=Path("/tmp"))
        run_cmd(["makepkg", "-si", "--noconfirm"], cwd=Path("/tmp/yay"))
    print("[+] yay установлен")

def install_pacman():
    file = WORKDIR / "pacman_packages.txt"
    if file.exists():
        run_cmd(["sudo", "bash", "-c", f"pacman -S --needed - < {file}"], check=False)
        print("[+] pacman пакеты установлены")

def install_pipx():
    file = WORKDIR / "pipx_packages.txt"
    if file.exists():
        sudo_user = os.environ.get("SUDO_USER")
        for pkg in file.read_text().splitlines():
            if sudo_user:
                run_cmd(["sudo", "-u", sudo_user, "pipx", "install", pkg], check=False)
            else:
                run_cmd(["pipx", "install", pkg], check=False)

def install_flatpak():
    file = WORKDIR / "flatpak_packages.txt"
    if file.exists():
        for pkg in file.read_text().splitlines():
            run_cmd(["flatpak", "install", "-y", pkg], check=False)

def restore_configs():
    # Восстановление архивов 7z
    for item in WORKDIR.iterdir():
        if item.suffix == ".7z.001":
            base_name = item.name.rsplit(".7z", 1)[0]
            try:
                run_cmd(["7z", "x", str(item), f"-o/"], check=False)
                print(f"[+] Восстановлено из томов: {base_name}")
            except PermissionError:
                print(f"[!] Нет прав на восстановление {base_name}, попробуй sudo")
    # Восстановление обычных архивов tar.gz
    for item in WORKDIR.iterdir():
        if item.suffix == ".tar.gz":
            original_name = item.name.replace("_", "/").replace(".tar.gz", "")
            original_path = Path("/" + original_name)
            try:
                run_cmd(["sudo", "tar", "-xzf", str(item), "-C", "/"])
                print(f"[+] Восстановлено: {original_path}")
            except PermissionError:
                print(f"[!] Нет прав на восстановление {original_path}, попробуй sudo")

def restore():
    # Клонирование всех репозиториев в /home/kali/pentest/<repo_name>
    for repo_url in GITHUB_REPOS:
        repo_name = repo_url.rstrip(".git").split("/")[-1]
        dest_dir = f"/home/kali/pentest/{repo_name}"
        if not Path(dest_dir).exists():
            run_cmd(["git", "clone", repo_url, dest_dir])
            print(f"[+] Клонировано: {repo_url} -> {dest_dir}")
        else:
            print(f"[i] Уже существует: {dest_dir}")
    ensure_tools(["git", "curl", "pipx", "flatpak"])
    clone_repo()
    setup_blackarch()
    setup_yay()
    install_pacman()
    install_pipx()
    install_flatpak()
    restore_configs()
    print("\n[✅] Восстановление завершено!")

def upload_archives_with_script():
    # Запускаем скрипт загрузки в GitHub
    upload_script = WORKDIR / "upload_to_github.sh"
    if upload_script.exists():
        result = run_cmd(["bash", str(upload_script)], cwd=WORKDIR, capture_output=True, check=False)
        print(result.stdout)
        if result.returncode == 0:
            print("[+] Файлы успешно загружены в GitHub")
        else:
            print(f"[!] Ошибка при загрузке в GitHub: {result.stderr}")
    else:
        print(f"[!] Скрипт загрузки не найден: {upload_script}")

# === Entry Point ===
def main():
    if len(sys.argv) < 2:
        print("Использование: ./arch_migrate.py [backup|restore]")
        exit(1)
    mode = sys.argv[1]
    if mode == "backup":
        backup()
    elif mode == "restore":
        restore()
    else:
        print("Неизвестная команда")

if __name__ == "__main__":
    main()

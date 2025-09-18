# Arch Migration Tool

A comprehensive tool for backing up and restoring your Arch Linux system configuration, packages, and files.

## Features

- Backup installed packages (pacman, pipx, flatpak)
- Archive configuration files and directories
- Upload backups to GitHub
- Restore packages and configurations on a new system
- Automatic setup of BlackArch and yay
- Clone security repositories (SecLists, etc.)

## Requirements

- Arch Linux
- `fzf` (for package selection)
- `git`
- `curl`
- `pipx`
- `flatpak`
- `7z` (for splitting large archives)
- `sudo` privileges

## Installation

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd arch-migration
   ```

2. Make the script executable:
   ```bash
   chmod +x arch_migrate.py
   chmod +x upload_to_github.sh
   ```

## Usage

### Backup Mode

To create a backup of your current system:

```bash
./arch_migrate.py backup
```

This will:
1. List all installed packages for selection
2. Archive specified configuration files and directories
3. Save package lists to text files
4. Upload everything to your GitHub repository

### Restore Mode

To restore your configuration on a new system:

```bash
./arch_migrate.py restore
```

This will:
1. Clone security repositories
2. Setup BlackArch repository
3. Install yay AUR helper
4. Restore all selected packages
5. Restore configuration files

## Configuration

Edit the script to customize:
- `GIT_REMOTE_URL`: Your GitHub repository URL
- `GITHUB_REPOS`: List of repositories to automatically clone
- `FILES_TO_BACKUP`: Configuration files and directories to archive

## File Structure

After backup, the following files will be created:
- `pacman_packages.txt`: Selected pacman packages
- `pipx_packages.txt`: Selected pipx packages
- `flatpak_packages.txt`: Selected flatpak packages
- `*.tar.gz`: Archived configuration files
- `*.7z.001`: Split archives for large files

## GitHub Integration

The tool automatically uploads backups to your GitHub repository:
- Initializes a git repository if needed
- Commits files with timestamp
- Pushes to the configured remote repository

Note: On Unix-like systems, you may need to make the upload script executable:
```bash
chmod +x upload_to_github.sh
```

## Security

This tool is designed for personal use. Be careful with:
- Sensitive configuration files
- Private keys or passwords
- Personal data in backups
- Always review files before committing to GitHub

A `.gitignore` file is included to prevent accidental committing of sensitive files like SSH keys and password files, but you should still review your backups before pushing to a public repository.

## License

MIT License - see LICENSE file for details.
# Capybara

Capybara keeps your Docker Compose stacks quietly up to date. Run it on a host with running Compose projects and it checks every project for newer images, restarts only the ones that actually changed, and tidies up the leftover old images afterward.


## How It Works

1. **Discover** every Compose project on the host by reading the `com.docker.compose.project` labels Docker already attaches to your containers (no project list to maintain).
2. **Pull** each project's images. A pull only downloads layers when something actually changed, so this doubles as the update check.
3. **Compare** each *running* container's image against the latest image the compose file now resolves to. Projects with no running containers are skipped, so a stack you have deliberately stopped stays stopped.
4. **Recreate** only the projects whose running image is out of date: `docker compose down` followed by `docker compose up -d`.
5. **Prune** the now-dangling old images once, at the very end, and only if at least one project was updated.

Run it with `--dry-run` first to see what would update without recreating or pruning anything.

## Features

- **No dependencies** - just Docker with the Compose v2 plugin and a standard shell.
- **Self-discovering** - finds projects from Docker's own container labels, so there is no config file or hardcoded list to keep in sync.
- **Minimal disruption** - only running projects with an actual image change are restarted; everything else keeps running, and stacks you have stopped are left stopped.
- **Safe to dry-run** - `--dry-run` reports which projects have updates available without recreating any stacks or pruning images. It still pulls images (that is how it checks for updates), but because the check compares against the *running* containers, a later real run correctly recreates the affected projects.
- **Self-cleaning** - prunes dangling images at the end, but only when something was updated.

## Tech Stack

- **Bash** - single POSIX-friendly script using only Docker and coreutils.
- **Docker Compose v2** - all updates go through `docker compose pull / down / up`.

# Getting Started

## Requirements

- A host running **Docker Engine** with the **Docker Compose v2** plugin (`docker compose version` should succeed).
- **Bash** and standard coreutils (`sort`, `dirname`).
- Your services managed as **Docker Compose** projects (containers started with plain `docker run` are intentionally ignored).

## Installation

Clone the repo onto the host that runs your containers (for example, a NAS) and make the script executable:

```bash
git clone https://github.com/skuzniak-ca/capybara.git
cd capybara
chmod +x update-compose-stacks.sh
```

## Usage

Preview which projects have updates available (pulls images, but recreates nothing):

```bash
./update-compose-stacks.sh --dry-run
```

Run it for real:

```bash
./update-compose-stacks.sh
```

### Permissions

The script talks to the Docker daemon socket (`/var/run/docker.sock`), which is owned by `root:docker`. So it needs to run as root or as a user in the `docker` group, otherwise Docker reports that it cannot connect to the API. There are two ways to handle this:

1. **Run it with `sudo`** (or schedule it in root's crontab, where no `sudo` is needed). This is the simplest option, and the most reliable on NAS distributions (Synology, QNAP, Unraid) that do not set up a standard `docker` group.

   ```bash
   sudo ./update-compose-stacks.sh
   ```

2. **Add your user to the `docker` group** so it runs without `sudo`:

   ```bash
   sudo usermod -aG docker $USER
   # log out and back in (or run: newgrp docker) for it to take effect
   ```

   Note: membership in the `docker` group is effectively root access on the host (a container can mount the host filesystem), so prefer this only on a trusted single-user machine.

### Scheduling

Schedule it in **root's** crontab so it runs with the right permissions and no `sudo` prompt:

```bash
sudo crontab -e
```

Then add an entry (this example runs every day at 4am and logs the output):

```cron
0 4 * * * /path/to/capybara/update-compose-stacks.sh >> /var/log/capybara.log 2>&1
```

## Project Structure

```
capybara/
├── update-compose-stacks.sh   # the entire tool: discover, pull, recreate, prune
└── README.md
```

## Acknowledgements

Built with assistance from [Claude](https://claude.ai) by Anthropic.

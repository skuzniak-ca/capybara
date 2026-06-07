# Capybara

Capybara keeps your Docker Compose stacks quietly up to date. Point it at a host running Compose projects and it checks every project for newer images, restarts only the ones that actually changed, and tidies up the leftover old images afterward.

The name fits the job: a capybara is the calm, low-maintenance animal that keeps the whole herd healthy without any fuss. This is a single, dependency-free Bash script meant to run on a home server or NAS - no extra tools to install, no cloud service, nothing to babysit.

## How It Works

1. **Discover** every Compose project on the host by reading the `com.docker.compose.project` labels Docker already attaches to your containers (no project list to maintain).
2. **Pull** each project's images. A pull only downloads layers when something actually changed, so this doubles as the update check.
3. **Compare** each service's image ID from before and after the pull. If nothing changed, the project is left running untouched.
4. **Recreate** only the projects with a new image: `docker compose down` followed by `docker compose up -d`.
5. **Prune** the now-dangling old images once, at the very end, and only if at least one project was updated.

Run it with `--dry-run` first to see what would update without changing anything.

## Features

- **No dependencies** - just Docker with the Compose v2 plugin and a standard shell. No `jq`, no Python, nothing to install.
- **Self-discovering** - finds projects from Docker's own container labels, so there is no config file or hardcoded list to keep in sync.
- **Minimal disruption** - only projects with an actual image change are restarted; everything else keeps running.
- **Safe to dry-run** - `--dry-run` reports available updates and performs no pulls-to-disk side effects, recreations, or prunes.
- **Self-cleaning** - prunes dangling images at the end, but only when something was updated.

## Tech Stack

- **Bash** - single POSIX-friendly script using only Docker and coreutils.
- **Docker Compose v2** - all updates go through `docker compose pull / down / up`.

# Getting Started

## Requirements

- A host running **Docker Engine** with the **Docker Compose v2** plugin (`docker compose version` should succeed).
- **Bash** and standard coreutils (`sort`, `dirname`) - present on any typical Linux install.
- Your services managed as **Docker Compose** projects (containers started with plain `docker run` are intentionally ignored).

## Installation

Clone the repo onto the host that runs your containers (for example, a NAS) and make the script executable:

```bash
git clone https://github.com/skuzniak-ca/capybara.git
cd capybara
chmod +x update-compose-stacks.sh
```

## Usage

Preview what would change without touching anything:

```bash
./update-compose-stacks.sh --dry-run
```

Run it for real:

```bash
./update-compose-stacks.sh
```

### Scheduling

To run it automatically, add a cron entry on the host (this example runs every day at 4am):

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

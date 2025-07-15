# RustGS - Rust Game Server Docker Image

A comprehensive Docker image for hosting Rust game servers with support for Oxide/uMod and Carbon modifications. Built with modularity and easy configuration through environment variables.

## Features

- **Steam Integration**: Built on SteamCMD for automatic server updates
- **Mod Support**: Optional Oxide (uMod) and Carbon mod frameworks
- **Environment Configuration**: All server parameters configurable via environment variables
- **Health Monitoring**: Built-in health checks for container orchestration
- **Persistent Storage**: Volume mounts for server data, mods, and logs
- **Resource Management**: Configurable resource limits and performance settings
- **Unraid Compatible**: Optimized for Unraid with template support

### Using Docker Compose (Other Platforms)

```bash
# Clone or download the docker-compose.yml
curl -O https://raw.githubusercontent.com/juddisjudd/RustGS/main/docker-compose.yml

# Edit environment variables in docker-compose.yml
nano docker-compose.yml

# Start the server
docker-compose up -d

# View logs
docker-compose logs -f rust-server
```

### Using Docker Run

```bash
docker run -d \
  --name rust-server \
  -p 28015:28015/tcp \
  -p 28015:28015/udp \
  -p 28016:28016/tcp \
  -p 28016:28016/udp \
  -p 28082:28082/tcp \
  -v rust_server_data:/home/steam/rust-server \
  -v rust_logs:/home/steam/logs \
  -e SERVER_HOSTNAME="My RustGS Server" \
  -e SERVER_MAXPLAYERS=100 \
  -e RCON_PASSWORD="supersecret" \
  ipajudd/rustgs:latest
```

## Building from Source

```bash
# Clone the repository
git clone https://github.com/juddisjudd/RustGS.git
cd RustGS

# Make the build script executable
chmod +x build.sh

# Build and optionally push to Docker Hub
./build.sh
```

### Unraid-Specific Paths

All data is stored in `/mnt/user/appdata/rustgs/`:
- `data/` - Server files and world saves
- `logs/` - Server logs
- `oxide/` - Oxide/uMod plugins and config
- `carbon/` - Carbon plugins and config

### Port Configuration

The template automatically configures these ports:
- `28015` - Game port (TCP/UDP)
- `28016` - Query/RCON port (TCP/UDP)  
- `28082` - Rust+ app port (TCP)

### Monitoring in Unraid

- **Docker tab**: Start/stop, view resource usage
- **Logs**: Click container → Logs
- **Console**: Click container → Console for shell access

## Environment Variables

### Server Identity & Networking

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_IDENTITY` | `rust-server` | Server identity folder name |
| `SERVER_PORT` | `28015` | Game port |
| `SERVER_QUERYPORT` | `28016` | Query port |
| `RCON_PORT` | `28016` | RCON port |
| `RCON_PASSWORD` | `changeme` | RCON password (CHANGE THIS!) |
| `RCON_WEB` | `1` | Enable RCON over WebSockets (1=true, 0=false) |

### Server Information

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_HOSTNAME` | `My RustGS Server` | Server name in server list |
| `SERVER_DESCRIPTION` | `A Rust server powered by RustGS Docker` | Server description |
| `SERVER_URL` | `` | Website or Discord link |
| `SERVER_HEADERIMAGE` | `` | Server banner image URL (512x256 JPG/PNG) |
| `SERVER_MAXPLAYERS` | `100` | Maximum players |

### World Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_LEVEL` | `Procedural Map` | Map type ("Procedural Map","Barren",”HapisIsland”,”SavasIsland” and “SavasIsland_koth”) |
| `SERVER_SEED` | `12345` | World seed |
| `SERVER_WORLDSIZE` | `3000` | World size (2000-6000) |
| `SERVER_LEVELURL` | `` | Custom map URL |
| `SERVER_SAVEINTERVAL` | `600` | Auto-save interval (seconds) |

### Performance Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `FPS_LIMIT` | `30` | FPS cap |
| `SERVER_TICKRATE` | `30` | Server tick rate |

### Rust+ App Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_PORT` | `28082` | Rust+ app communication port |
| `APP_PUBLICIP` | `` | Public IP for Rust+ app |

### Security Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_SECURE` | `true` | Enable/disable EasyAntiCheat |
| `SERVER_ENCRYPTION` | `1` | Enable/disable server encryption |

### Mod Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `USE_OXIDE` | `false` | Enable Oxide (uMod) framework |
| `USE_CARBON` | `false` | Enable Carbon framework |

### Logging

| Variable | Default | Description |
|----------|---------|-------------|
| `LOGFILE_PATH` | `/home/steam/logs/server.log` | Server log file path |

## Ports

- `28015/tcp` & `28015/udp` - Game port
- `28016/tcp` & `28016/udp` - Query/RCON port
- `28082/tcp` - Rust+ app port

## Using with Mods

### Oxide (uMod)

```yaml
environment:
  - USE_OXIDE=true
```

Place your plugins in the mounted `oxide` volume:
- Plugins: `/oxide/plugins/`
- Config: `/oxide/config/`
- Data: `/oxide/data/`

### Carbon

```yaml
environment:
  - USE_CARBON=true
```

Place your plugins in the mounted `carbon` volume:
- Plugins: `/carbon/plugins/`
- Config: `/carbon/config/`
- Data: `/carbon/data/`

## Support

- **Issues**: [GitHub Issues](https://github.com/juddisjudd/RustGS/issues)
- **Docker Hub**: [ipajudd/rustgs](https://hub.docker.com/r/ipajudd/rustgs)

## Acknowledgments

- [SteamCMD Docker](https://github.com/steamcmd/docker) for the base image
- [Oxide/uMod](https://umod.org/) for the modding framework
- [Carbon](https://carbonmod.gg/) for the alternative modding framework

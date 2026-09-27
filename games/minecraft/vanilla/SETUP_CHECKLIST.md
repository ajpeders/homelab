# Minecraft Server Setup Checklist

## ✅ Already Completed
- [x] Repository cloned
- [x] `.env` file created from template

## 🔧 Required Setup Steps

### 1. Configure Environment Variables (.env)
**Status: ⚠️ NEEDS ATTENTION**

Edit `games/minecraft/vanilla/.env` and fill in the following values:

#### Server Configuration (REQUIRED)
- [ ] `EXTERNAL_PORT` - Port to expose the server on (e.g., `25565`)
- [ ] `MOTD` - Message of the Day shown in server list (e.g., `"Logan's Modded Server"`)
- [ ] `LEVEL` - World name (e.g., `"world"` or `"MyWorld"`)
- [ ] `MEMORY` - RAM allocation (e.g., `"4G"` for 4GB, `"8G"` for 8GB)
  - **Recommendation:** Modded servers need more RAM. Use at least 4G, ideally 6-8G.
- [ ] `ICON` - Optional: URL to server icon image

#### Backup Configuration (OPTIONAL - can skip initially)
- [ ] `SRC_DIR` - Source directory for backups (usually `/data`)
- [ ] `BK_DIR` - Backup destination directory (usually `/backups`)
- [ ] `WEB_HOST` - Remote host for backup uploads (SSH format: `user@hostname`)
- [ ] `WEB_BK` - Remote backup path on web host

#### Proxy Configuration (OPTIONAL - only if using proxy)
- [ ] `PROXY_PORT` - Proxy listening port
- [ ] `TARGET_HOST` - Target Minecraft server host
- [ ] `TARGET_PORT` - Target Minecraft server port

### 2. Create Required Directories
**Status: ⚠️ NEEDS ATTENTION**

Run these commands:
```bash
cd games/minecraft/vanilla
mkdir -p data
mkdir -p mc-backups
mkdir -p data/mods
mkdir -p data/config
```

### 3. Install Mods
**Status: ⚠️ NEEDS ATTENTION**

Since you're running a modded server with Paper:
1. [ ] Download your desired mod `.jar` files
2. [ ] Place mod files in: `games/minecraft/vanilla/data/mods/`
3. [ ] Ensure mods are compatible with your Minecraft version
4. [ ] Note: Paper uses plugins (not Forge/Fabric mods)
   - For Forge/Fabric mods, you'll need to change `TYPE` in docker-compose.yml

**Popular Plugin Sites:**
- [SpigotMC](https://www.spigotmc.org/resources/)
- [Bukkit](https://dev.bukkit.org/bukkit-plugins)
- [PaperMC Forums](https://papermc.io/forums/c/paper/7)

### 4. Configure Server Type (If using Forge/Fabric)
**Status: ⚠️ REVIEW NEEDED**

Current setup uses Paper (plugin-based). If you need Forge or Fabric for mods:
- [ ] Change `TYPE: PAPER` to `TYPE: FORGE` or `TYPE: FABRIC` in docker-compose.yml
- [ ] Add mod loader version configuration

### 5. SSH Setup for Backups (OPTIONAL)
**Status: 📋 OPTIONAL**

Only needed if you want remote backups:
```bash
cd games/minecraft/vanilla
./scripts/setup_ssh_infra.sh -h <remote-host> -u <remote-user>
```

### 6. Start the Server
**Status: ⏳ WAITING**

Once the above is configured:
```bash
cd games/minecraft/vanilla
docker compose up -d
```

To view logs:
```bash
docker compose logs -f mc
```

### 7. Verify Server is Running
**Status: ⏳ WAITING**

- [ ] Check logs for successful startup
- [ ] Connect to the server using Minecraft client: `<server-ip>:<EXTERNAL_PORT>`
- [ ] Verify mods/plugins are loaded (check logs or use `/plugins` command in-game)

## 📝 Additional Configuration

### Server Properties
After first run, you can customize server settings:
- [ ] Edit `data/server.properties` for game settings
- [ ] Configure `data/ops.json` for admin players
- [ ] Configure `data/whitelist.json` if needed

### Mod Configuration
- [ ] Review and edit configs in `data/config/` for each mod
- [ ] Restart server after config changes: `docker compose restart mc`

## 🔄 Maintenance Commands

### Backup on Demand
```bash
docker compose exec backups backup now
```

### View Server Console
```bash
docker attach $(docker compose ps -q mc)
# Press Ctrl+P, Ctrl+Q to detach without stopping
```

### Stop Server
```bash
docker compose down
```

### Update Server/Mods
```bash
docker compose pull
docker compose up -d
```

## 🐛 Troubleshooting

### Server won't start
- Check logs: `docker compose logs mc`
- Verify port isn't already in use: `netstat -tuln | grep <EXTERNAL_PORT>`
- Ensure sufficient disk space: `df -h`

### Mods not loading
- Verify mod files are in `data/mods/` directory
- Check mod compatibility with server type (Paper/Forge/Fabric)
- Check logs for mod loading errors

### Memory issues
- Increase `MEMORY` value in `.env`
- Monitor usage: `docker stats`

## 📊 Current Status Summary

**Critical (Must Complete):**
1. Fill out `.env` file with required values
2. Create data directories
3. Add mods to data/mods/
4. Decide on server type (Paper/Forge/Fabric)

**Optional (Can Complete Later):**
- SSH backup configuration
- Proxy setup
- Advanced server properties customization

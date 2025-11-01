# Media Server Stack - Release Notes v1.2

**Release Date:** October 10, 2025
**Type:** Configuration & Integration Enhancements

---

## 🎯 Overview

Version 1.2 focuses on completing the media automation pipeline with proper Usenet integration, download client configuration, and library import workflows. All TV shows and movies now properly flow from indexers → download clients → media libraries with hardlink support for continued seeding.

---

## ✨ New Features & Enhancements

### 1. **Usenet Integration (NZBgeek + SABnzbd)**
- Added NZBgeek indexer to Prowlarr with API integration
- Configured SABnzbd as primary download client for Usenet downloads
- Set up proper category mapping:
  - `tv` - Sonarr TV downloads
  - `movies` - Radarr movie downloads
- Configured indexer priorities:
  - **NZBgeek: Priority 10** (preferred - Usenet)
  - **IPTorrents: Priority 25** (fallback - Torrents)

### 2. **Download Client Configuration**
- **Radarr**: Added Deluge and SABnzbd download clients
  - Deluge (VPN Direct): `172.20.0.10:8112`
  - SABnzbd: `172.20.0.10:8080` with category `movies`
- **Sonarr**: Added SABnzbd download client
  - SABnzbd: `172.20.0.10:8080` with category `tv`
- Both configured with:
  - `removeCompletedDownloads: false` (preserve for seeding)
  - Hardlink support enabled
  - VPN routing via Gluetun container

### 3. **Quality Profile Standardization**
- **Movies**: Upgraded to Ultra-HD (4K) quality profile (ID: 5)
  - Applied to all existing movies (Dark Knight trilogy, Inception)
- **TV Shows**: HD-1080p quality profile (ID: 4)
  - Applied to Bob's Burgers, South Park, Star Wars: The Clone Wars

### 4. **Sonarr Root Folder Correction**
- **Before**: `/data` (incorrect, too broad)
- **After**: `/data/media/tv` (correct, specific)
- Prevents import conflicts and ensures proper library organization

### 5. **TV Show Library Import**
Successfully imported existing downloaded content:
- **Bob's Burgers**: 295 episodes (16 seasons)
- **South Park**: 274 episodes (27 seasons)
- **Star Wars: The Clone Wars**: 133 episodes (7 seasons)
- **Total**: 702 episodes imported via hardlinks

### 6. **Hardlink Import Workflow**
Created workflow for importing pre-existing downloads:
1. Create series folders in `/data/media/tv/`
2. Use `cp -l` to hardlink files from `/data/torrents/` to library
3. Preserve torrents for continued seeding
4. Trigger Sonarr/Radarr rescans to detect files
5. All future downloads automatically imported via Sonarr/Radarr

---

## 🔧 Configuration Changes

### Prowlarr
```yaml
Indexers:
  - Name: NZBgeek
    Priority: 10
    Type: Usenet
    URL: https://api.nzbgeek.info
    API Key: [configured]
    Sync: Enabled to all *arr services

  - Name: IPTorrents
    Priority: 25
    Type: Torrent
    URL: https://iptorrents.com
    Sync: Enabled to all *arr services
```

### Sonarr
```yaml
Root Folder: /data/media/tv
Download Clients:
  - Deluge (VPN Direct): 172.20.0.10:8112
  - SABnzbd: 172.20.0.10:8080 (category: tv)
Series Added:
  - Bob's Burgers (TVDB: 194031)
  - South Park (TVDB: 75897)
  - Star Wars: The Clone Wars (TVDB: 83268)
Quality Profile: HD-1080p (ID: 4)
```

### Radarr
```yaml
Download Clients:
  - Deluge (VPN Direct): 172.20.0.10:8112
  - SABnzbd: 172.20.0.10:8080 (category: movies)
Quality Profile: Ultra-HD (ID: 5)
Movies:
  - The Dark Knight (2008)
  - The Dark Knight Rises (2012)
  - Batman Begins (2005)
  - Inception (2010)
```

### SABnzbd
```yaml
Categories:
  - tv: /data/torrents
  - movies: /data/torrents
  - audio: /data/torrents
  - software: /data/torrents
API Key: [configured in .env.secrets]
Port: 8080
Network: Via Gluetun VPN
```

### Media Management
```yaml
Hardlinks: Enabled (copyUsingHardlinks: true)
Import Mode: Copy (uses hardlinks when same filesystem)
Seeding Protection: Enabled (removeCompletedDownloads: false)
Filesystem: /dev/md0 (same device for /data/torrents and /data/media)
```

---

## 🔒 Security & Best Practices

### VPN Routing Verification
All download traffic (both Usenet and Torrents) properly routed through Gluetun VPN:
- **VPN IP**: 146.70.198.45 (ProtonVPN Canada)
- **Home IP**: 67.199.170.5 (confirmed different)
- **Network Mode**: `container:gluetun` for both Deluge and SABnzbd

### .gitignore Improvements
Enhanced security for both private and public repositories:
```gitignore
# Sensitive files - never commit these
.env.secrets
*.key
*.pem
*.crt

# Service configuration (contains API keys)
*/config.xml
*/config.ini
*/sabnzbd.ini

# Database files (contains configurations)
*.db
*.sqlite
*.db-wal
*.db-shm
```

---

## 📊 Testing & Validation

### Usenet Test (Successful)
- **Movie**: Inception (2010)
- **Source**: NZBgeek (Usenet)
- **Quality**: 4K REMUX (70GB)
- **Download Client**: SABnzbd
- **Result**: ✅ Downloaded and imported successfully

### Torrent Test (Successful)
- **TV Shows**: Bob's Burgers, South Park, Clone Wars
- **Source**: IPTorrents
- **Quality**: 1080p Web-DL/BluRay
- **Download Client**: Deluge
- **Result**: ✅ 702 episodes imported via hardlinks

### VPN Test (Successful)
- **Deluge IP**: 146.70.198.45 (via VPN)
- **SABnzbd IP**: 146.70.198.45 (via VPN)
- **Home IP**: 67.199.170.5 (different)
- **Result**: ✅ All traffic properly routed through VPN

---

## 📁 File Structure

```
/data/
├── media/
│   ├── movies/          # Radarr imports here
│   └── tv/              # Sonarr imports here
│       ├── Andor/
│       ├── Bob's Burgers/      # 295 episodes
│       ├── South Park/         # 274 episodes
│       └── Star Wars - The Clone Wars/  # 133 episodes
└── torrents/            # Download clients download here
    ├── [Active downloads and seeding files]
    └── [Hardlinked to /data/media for import]
```

---

## 🔄 Automation Workflow

### Complete Media Pipeline (Now Fully Automated)

```
┌─────────────┐
│  Prowlarr   │ Manages indexers (NZBgeek, IPTorrents)
└──────┬──────┘
       │
       ├─────────────────────────────┐
       │                             │
┌──────▼──────┐              ┌──────▼──────┐
│   Sonarr    │              │   Radarr    │
│  (TV Shows) │              │  (Movies)   │
└──────┬──────┘              └──────┬──────┘
       │                             │
       │ Searches via Prowlarr       │
       │ Prefers: NZBgeek (Priority 10)
       │ Fallback: IPTorrents (Priority 25)
       │                             │
       ├──────────┬──────────────────┤
       │          │                  │
┌──────▼──────┐  │           ┌──────▼──────┐
│  SABnzbd    │  │           │   Deluge    │
│  (Usenet)   │  │           │  (Torrents) │
└──────┬──────┘  │           └──────┬──────┘
       │         │                  │
       └─────────┴──────────────────┘
                 │
                 │ Both via Gluetun VPN
                 │
          ┌──────▼──────┐
          │/data/torrents│
          └──────┬──────┘
                 │
                 │ Hardlink import
                 │
          ┌──────▼──────┐
          │ /data/media │
          └──────┬──────┘
                 │
          ┌──────▼──────┐
          │    Plex     │
          └─────────────┘
```

---

## 🐛 Issues Fixed

1. **Radarr had no download clients configured**
   - Fixed by adding Deluge and SABnzbd

2. **Sonarr root folder was set to `/data` instead of `/data/media/tv`**
   - Fixed by updating root folder configuration

3. **Pre-existing downloads not imported to library**
   - Fixed by creating hardlink import workflow
   - All 702 episodes now in Plex library

4. **No Usenet indexer configured**
   - Fixed by adding NZBgeek to Prowlarr

5. **SABnzbd not integrated with Sonarr/Radarr**
   - Fixed by adding SABnzbd download client to both services

6. **Movies downloading in 1080p instead of 4K**
   - Fixed by updating quality profiles to Ultra-HD

7. **Download client preference unclear**
   - Fixed by setting indexer priorities (Usenet preferred)

---

## 📝 Configuration Persistence

All configurations are **persistent** and stored in:
- Service databases (mounted as Docker volumes)
- Configuration files (excluded from git for security)
- Survive container restarts and rebuilds

**Database Files** (contain all configurations):
- `sonarr/sonarr.db` - Series, root folders, download clients
- `radarr/radarr.db` - Movies, quality profiles, download clients
- `prowlarr/prowlarr.db` - Indexers, priorities, app sync
- `sabnzbd/sabnzbd.ini` - Categories, API settings

---

## 🚀 Deployment Notes

### For Private Repository (Real Configuration)
- All API keys stored in `.env.secrets` (not committed)
- Database files contain real configurations (not committed)
- Configurations persist in Docker volumes

### For Public Repository (Scrubbed Release)
Users should manually configure:
1. Add NZBgeek indexer to Prowlarr (requires paid subscription)
2. Add SABnzbd download client to Sonarr/Radarr
3. Set indexer priorities (Usenet: 10, Torrents: 25)
4. Update Sonarr root folder to `/data/media/tv`
5. Add Deluge download client to Radarr
6. Set quality profiles (Movies: Ultra-HD, TV: HD-1080p)

---

## 📚 Additional Documentation

- See `NETWORKING_PERSISTENCE_GUIDE.md` for VPN and networking details
- See `CONFIG_TEMPLATES_README.md` for configuration examples
- See `DISASTER_RECOVERY.md` for backup and recovery procedures

---

## ⚠️ Breaking Changes

None. All changes are additive and improve existing functionality.

---

## 🔮 Future Enhancements

- Consider adding additional Usenet indexers for redundancy
- Explore custom quality profiles for specific content types
- Set up automated library maintenance scripts
- Configure Bazarr for subtitle automation

---

## 🙏 Acknowledgments

Configuration based on best practices from:
- TRaSH Guides (https://trash-guides.info)
- Servarr Wiki (https://wiki.servarr.com)
- /r/usenet and /r/sonarr communities

---

**Version:** 1.2
**Previous Version:** 1.1
**Upgrade Path:** Configuration changes only (no container updates required)

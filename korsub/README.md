# KorSub - Korean Subtitle Service

Automatically downloads Korean subtitles from [Cineaste.co.kr](https://cineaste.co.kr) for your Radarr/Sonarr media library.

## Features

- 🇰🇷 **Korean Subtitle Provider**: Scrapes Cineaste.co.kr (씨네스트) for Hollywood/Western movie subtitles
- 🎬 **Radarr Integration**: Webhook support for automatic subtitle download on movie import
- 📺 **Sonarr Integration**: Webhook support for TV show episodes
- 🔄 **Runs Alongside Bazarr**: Complementary service that doesn't interfere with existing subtitle downloads
- 🌐 **Web UI Access**: Manual search interface via Traefik at `https://serenity.watch/korsub`

## Why Cineaste.co.kr?

Cineaste has **excellent coverage** for Hollywood/Western movies with Korean subtitles:
- Active community with daily uploads
- 10+ years of stable operation
- Recent uploads include: Love Actually, Terminator Genisys, The Ring, Primal Fear, etc.
- Better Korean subtitle coverage than OpenSubtitles for Western content

## How It Works

```
Movie Downloaded in Radarr
         ↓
Radarr sends webhook to KorSub
         ↓
KorSub searches Cineaste.co.kr
         ↓
Downloads matching Korean subtitle
         ↓
Saves as {movie_name}.ko.srt
```

## Configuration

### 1. Build and Start Service

```bash
cd /docker/mediaserver
docker compose build korsub
docker compose up -d korsub
```

### 2. Configure Radarr Webhook

1. Go to Radarr → Settings → Connect
2. Click the `+` icon to add a new connection
3. Select **Webhook**
4. Configure:
   - **Name**: Korean Subtitles (KorSub)
   - **On Download**: ✓ Enabled
   - **On Upgrade**: ✓ Enabled
   - **URL**: `http://korsub:7272/webhook/radarr`
   - **Method**: POST
5. Test and Save

### 3. Configure Sonarr Webhook (Optional)

1. Go to Sonarr → Settings → Connect
2. Click the `+` icon to add a new connection
3. Select **Webhook**
4. Configure:
   - **Name**: Korean Subtitles (KorSub)
   - **On Download**: ✓ Enabled
   - **On Upgrade**: ✓ Enabled
   - **URL**: `http://korsub:7272/webhook/sonarr`
   - **Method**: POST
5. Test and Save

## Manual Testing

### Test the Service is Running

```bash
curl http://korsub:7272/health
```

Expected response:
```json
{"service": "KorSub", "status": "healthy"}
```

### Manual Subtitle Search

```bash
curl -X POST http://korsub:7272/manual/search \
  -H "Content-Type: application/json" \
  -d '{"title": "Tron Legacy", "year": 2010}'
```

### Via Web UI

Access `https://serenity.watch/korsub/health` through your browser

## Logs

View logs to monitor subtitle downloads:

```bash
docker logs -f korsub
```

## File Naming

Downloaded Korean subtitles are saved with `.ko.srt` extension:

```
/data/media/movies/TRON - Legacy (2010)/
├── Tron Legacy 2010 2160p.mkv
└── Tron Legacy 2010 2160p.ko.srt  ← Korean subtitle
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `7272` | Service port |
| `LOG_LEVEL` | `INFO` | Logging level (DEBUG, INFO, WARNING, ERROR) |
| `MEDIA_PATH` | `/data/media` | Base media directory path |
| `TZ` | From `.env` | Timezone |

## Troubleshooting

### No subtitles found

- Check if Cineaste.co.kr has subtitles for that movie (may not have all titles)
- Try manual search to see what results are returned
- Check logs for search errors

### Service not responding

```bash
# Check service status
docker ps | grep korsub

# Check logs
docker logs korsub

# Restart service
docker compose restart korsub
```

### Webhook not triggered

- Verify webhook is configured correctly in Radarr/Sonarr
- Test the connection in Radarr/Sonarr settings
- Check that URL is `http://korsub:7272/webhook/radarr` (not localhost or IP)

## Architecture

```
┌─────────────┐
│   Radarr    │ ──── Webhook ────┐
└─────────────┘                   │
                                  ▼
┌─────────────┐           ┌──────────────┐
│   Sonarr    │ ──── Webhook ──> │    KorSub    │
└─────────────┘                   └──────┬───────┘
                                         │
                                         │ Scrapes
                                         ▼
                                  ┌──────────────┐
                                  │ Cineaste.co.kr│
                                  │ (씨네스트)    │
                                  └──────┬───────┘
                                         │ Downloads
                                         ▼
                                  /data/media/{movie}.ko.srt
```

## License

Created for personal use with Cineaste.co.kr subtitle community.

**Note**: Please respect Cineaste.co.kr's terms of service and don't abuse the scraping functionality.

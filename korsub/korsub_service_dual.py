#!/usr/bin/env python3
"""
KorSub - Korean Subtitle Service (Dual Provider Version)
Primary: OpenSubtitles.com API
Fallback: Cineaste.co.kr scraper
"""

import os
import json
import logging
import requests
from flask import Flask, request, jsonify
from pathlib import Path
from opensubtitles_api import OpenSubtitlesAPI
from cineaste_scraper import CineasteScraper
from apscheduler.schedulers.background import BackgroundScheduler

# Configuration
MEDIA_PATH = os.getenv("MEDIA_PATH", "/data/media")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
PORT = int(os.getenv("PORT", "7272"))
OPENSUBTITLES_API_KEY = os.getenv("OPENSUBTITLES_API_KEY", "")
RADARR_URL = os.getenv("RADARR_URL", "http://radarr:7878/radarr")
RADARR_API_KEY = os.getenv("RADARR_API_KEY", "")
SONARR_URL = os.getenv("SONARR_URL", "http://sonarr:8989/sonarr")
SONARR_API_KEY = os.getenv("SONARR_API_KEY", "")
SCAN_INTERVAL_HOURS = int(os.getenv("SCAN_INTERVAL_HOURS", "6"))

# Setup logging
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("KorSub")

# Flask app
app = Flask(__name__)

# Initialize both providers
opensub_api = OpenSubtitlesAPI(api_key=OPENSUBTITLES_API_KEY)
cineaste_scraper = CineasteScraper()

# Initialize scheduler
scheduler = BackgroundScheduler()
scheduler.start()


class SubtitleProcessor:
    """Process subtitle requests with dual-provider support"""

    def __init__(self):
        self.opensub = opensub_api
        self.cineaste = cineaste_scraper

    def search_subtitles(self, title, year=None, imdb_id=None, tmdb_id=None):
        """
        Search for Korean subtitles using both providers

        Priority:
        1. OpenSubtitles.com (faster, more reliable)
        2. Cineaste.co.kr (fallback for rare movies)

        Returns:
            (results, provider_name)
        """
        # Try OpenSubtitles first
        logger.info(f"🔍 Searching OpenSubtitles for: {title}")
        opensub_results = self.opensub.search_subtitles(
            imdb_id=imdb_id,
            tmdb_id=tmdb_id,
            query=title if not imdb_id and not tmdb_id else None,
            languages="ko",
            year=year
        )

        if opensub_results:
            logger.info(f"✓ OpenSubtitles found {len(opensub_results)} Korean subtitle(s)")
            return opensub_results, "opensubtitles"

        # Fallback to Cineaste
        logger.info(f"🔍 OpenSubtitles had no results, trying Cineaste fallback...")
        cineaste_results = self.cineaste.search_subtitles(title, year)

        if cineaste_results:
            logger.info(f"✓ Cineaste found {len(cineaste_results)} Korean subtitle(s)")
            return cineaste_results, "cineaste"

        logger.warning(f"✗ No Korean subtitles found on any provider for: {title}")
        return [], None

    def download_subtitle(self, result, provider, save_path):
        """Download subtitle from the appropriate provider"""
        if provider == "opensubtitles":
            details = self.opensub.get_subtitle_details(result)
            file_id = details.get('file_id')
            if not file_id:
                logger.error("No file ID in OpenSubtitles result")
                return False
            return self.opensub.download_subtitle(file_id, save_path)

        elif provider == "cineaste":
            wr_id = result.get('wr_id')
            if not wr_id:
                logger.error("No wr_id in Cineaste result")
                return False
            return self.cineaste.download_subtitle(wr_id, save_path)

        else:
            logger.error(f"Unknown provider: {provider}")
            return False

    def process_movie(self, payload):
        """Process movie download from Radarr webhook"""
        try:
            movie = payload.get('movie', {})
            movie_file = payload.get('movieFile', {})

            title = movie.get('title')
            year = movie.get('year')
            imdb_id = movie.get('imdbId')
            tmdb_id = movie.get('tmdbId')
            file_path = movie_file.get('path')

            if not file_path:
                logger.warning("No file path in webhook payload")
                return False

            logger.info(f"📽️  Processing: {title} ({year})")

            # Search with both providers
            results, provider = self.search_subtitles(
                title=title,
                year=year,
                imdb_id=imdb_id,
                tmdb_id=tmdb_id
            )

            if not results:
                return False

            # Get best match
            best_match = results[0]
            logger.info(f"📥 Downloading from {provider}: {best_match.get('title', 'subtitle')}")

            # Determine save path
            video_path = Path(file_path)
            subtitle_path = video_path.with_suffix('.ko.srt')

            # Download
            success = self.download_subtitle(best_match, provider, str(subtitle_path))

            if success:
                logger.info(f"✅ Korean subtitle downloaded for {title} (provider: {provider})")
                return True
            else:
                if provider == "cineaste":
                    logger.warning(f"⚠️  Cineaste requires manual download for {title}")
                    logger.warning(f"📋 Korean subtitles available but require CAPTCHA verification")
                else:
                    logger.error(f"❌ Failed to download subtitle for {title}")
                return False

        except Exception as e:
            logger.error(f"Error processing movie: {e}")
            import traceback
            traceback.print_exc()
            return False

    def process_episode(self, payload):
        """Process episode download from Sonarr webhook"""
        try:
            series = payload.get('series', {})
            episodes = payload.get('episodes', [])
            episode_file = payload.get('episodeFile', {})

            series_title = series.get('title')
            imdb_id = series.get('imdbId')
            file_path = episode_file.get('path')

            if not all([series_title, file_path, episodes]):
                logger.warning("Missing required episode data")
                return False

            episode = episodes[0]
            season_num = episode.get('seasonNumber')
            episode_num = episode.get('episodeNumber')

            logger.info(f"📺 Processing: {series_title} S{season_num:02d}E{episode_num:02d}")

            # Search with both providers
            results, provider = self.search_subtitles(
                title=series_title,
                imdb_id=imdb_id
            )

            if not results:
                return False

            best_match = results[0]
            logger.info(f"📥 Downloading from {provider}")

            video_path = Path(file_path)
            subtitle_path = video_path.with_suffix('.ko.srt')

            success = self.download_subtitle(best_match, provider, str(subtitle_path))

            if success:
                logger.info(f"✅ Korean subtitle downloaded (provider: {provider})")
                return True
            else:
                logger.error(f"❌ Failed to download subtitle")
                return False

        except Exception as e:
            logger.error(f"Error processing episode: {e}")
            import traceback
            traceback.print_exc()
            return False


# Initialize processor
processor = SubtitleProcessor()


# Scheduled scanning functions
def scan_radarr_library():
    """Scan Radarr library for movies missing Korean subtitles"""
    if not RADARR_API_KEY:
        logger.warning("Radarr API key not configured, skipping scheduled scan")
        return

    try:
        logger.info("🔍 Starting scheduled Radarr library scan for missing Korean subtitles")

        # Get all movies from Radarr
        response = requests.get(
            f"{RADARR_URL}/api/v3/movie",
            headers={"X-Api-Key": RADARR_API_KEY},
            timeout=30
        )
        response.raise_for_status()
        movies = response.json()

        processed = 0
        downloaded = 0

        for movie in movies:
            # Skip if no file
            if not movie.get('hasFile'):
                continue

            movie_file = movie.get('movieFile')
            if not movie_file:
                continue

            file_path = movie_file.get('path')
            if not file_path:
                continue

            # Check if Korean subtitle already exists
            video_path = Path(file_path)
            subtitle_path = video_path.with_suffix('.ko.srt')

            if subtitle_path.exists():
                continue  # Already has Korean subtitle

            # Try to download Korean subtitle
            logger.info(f"📽️  Missing Korean subtitle: {movie['title']} ({movie.get('year')})")

            results, provider = processor.search_subtitles(
                title=movie.get('title'),
                year=movie.get('year'),
                imdb_id=movie.get('imdbId'),
                tmdb_id=movie.get('tmdbId')
            )

            if results:
                best_match = results[0]
                success = processor.download_subtitle(best_match, provider, str(subtitle_path))

                if success:
                    logger.info(f"✅ Downloaded Korean subtitle for {movie['title']}")
                    downloaded += 1
                elif provider == "cineaste":
                    logger.info(f"⚠️  Cineaste match found but requires manual download: {movie['title']}")

            processed += 1

        logger.info(f"✓ Radarr scan complete: {processed} movies checked, {downloaded} Korean subtitles downloaded")

    except Exception as e:
        logger.error(f"Error scanning Radarr library: {e}")
        import traceback
        traceback.print_exc()


def scan_sonarr_library():
    """Scan Sonarr library for episodes missing Korean subtitles"""
    if not SONARR_API_KEY:
        logger.warning("Sonarr API key not configured, skipping scheduled scan")
        return

    try:
        logger.info("🔍 Starting scheduled Sonarr library scan for missing Korean subtitles")

        # Get all series from Sonarr
        response = requests.get(
            f"{SONARR_URL}/api/v3/series",
            headers={"X-Api-Key": SONARR_API_KEY},
            timeout=30
        )
        response.raise_for_status()
        series_list = response.json()

        processed = 0
        downloaded = 0

        for series in series_list:
            # Get episode files for this series
            series_id = series['id']

            ep_response = requests.get(
                f"{SONARR_URL}/api/v3/episodefile",
                headers={"X-Api-Key": SONARR_API_KEY},
                params={"seriesId": series_id},
                timeout=30
            )
            ep_response.raise_for_status()
            episode_files = ep_response.json()

            for ep_file in episode_files:
                file_path = ep_file.get('path')
                if not file_path:
                    continue

                # Check if Korean subtitle already exists
                video_path = Path(file_path)
                subtitle_path = video_path.with_suffix('.ko.srt')

                if subtitle_path.exists():
                    continue  # Already has Korean subtitle

                # Try to download Korean subtitle
                logger.info(f"📺 Missing Korean subtitle: {series['title']}")

                results, provider = processor.search_subtitles(
                    title=series.get('title'),
                    imdb_id=series.get('imdbId')
                )

                if results:
                    best_match = results[0]
                    success = processor.download_subtitle(best_match, provider, str(subtitle_path))

                    if success:
                        logger.info(f"✅ Downloaded Korean subtitle for {series['title']}")
                        downloaded += 1
                    elif provider == "cineaste":
                        logger.info(f"⚠️  Cineaste match found but requires manual download: {series['title']}")

                processed += 1

        logger.info(f"✓ Sonarr scan complete: {processed} episodes checked, {downloaded} Korean subtitles downloaded")

    except Exception as e:
        logger.error(f"Error scanning Sonarr library: {e}")
        import traceback
        traceback.print_exc()


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'KorSub',
        'providers': {
            'primary': 'OpenSubtitles.com API',
            'fallback': 'Cineaste.co.kr',
            'api_key_configured': bool(OPENSUBTITLES_API_KEY)
        }
    }), 200


@app.route('/webhook/radarr', methods=['POST'])
def radarr_webhook():
    """Handle Radarr webhooks"""
    try:
        payload = request.get_json()
        event_type = payload.get('eventType')

        logger.info(f"📨 Radarr webhook: {event_type}")

        if event_type == 'Download':
            success = processor.process_movie(payload)
            return jsonify({'success': success}), 200
        else:
            return jsonify({'ignored': True}), 200

    except Exception as e:
        logger.error(f"Error handling Radarr webhook: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/webhook/sonarr', methods=['POST'])
def sonarr_webhook():
    """Handle Sonarr webhooks"""
    try:
        payload = request.get_json()
        event_type = payload.get('eventType')

        logger.info(f"📨 Sonarr webhook: {event_type}")

        if event_type == 'Download':
            success = processor.process_episode(payload)
            return jsonify({'success': success}), 200
        else:
            return jsonify({'ignored': True}), 200

    except Exception as e:
        logger.error(f"Error handling Sonarr webhook: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/manual/search', methods=['POST'])
def manual_search():
    """Manual search endpoint"""
    try:
        data = request.get_json()
        title = data.get('title')
        year = data.get('year')
        imdb_id = data.get('imdb_id')
        tmdb_id = data.get('tmdb_id')

        if not any([title, imdb_id, tmdb_id]):
            return jsonify({'error': 'title, imdb_id, or tmdb_id required'}), 400

        results, provider = processor.search_subtitles(
            title=title,
            year=year,
            imdb_id=imdb_id,
            tmdb_id=tmdb_id
        )

        # Format results based on provider
        formatted_results = []
        if provider == "opensubtitles":
            for result in results[:10]:
                details = opensub_api.get_subtitle_details(result)
                formatted_results.append(details)
        elif provider == "cineaste":
            formatted_results = results[:10]

        return jsonify({
            'query': title or imdb_id or tmdb_id,
            'year': year,
            'provider': provider or 'none',
            'results_count': len(results),
            'results': formatted_results
        }), 200

    except Exception as e:
        logger.error(f"Error in manual search: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/scan/radarr', methods=['POST'])
def trigger_radarr_scan():
    """Manually trigger Radarr library scan"""
    try:
        logger.info("📨 Manual Radarr scan triggered")
        scan_radarr_library()
        return jsonify({'success': True, 'message': 'Radarr scan completed'}), 200
    except Exception as e:
        logger.error(f"Error in manual Radarr scan: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/scan/sonarr', methods=['POST'])
def trigger_sonarr_scan():
    """Manually trigger Sonarr library scan"""
    try:
        logger.info("📨 Manual Sonarr scan triggered")
        scan_sonarr_library()
        return jsonify({'success': True, 'message': 'Sonarr scan completed'}), 200
    except Exception as e:
        logger.error(f"Error in manual Sonarr scan: {e}")
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    logger.info("=" * 60)
    logger.info("🎬 Starting KorSub - Korean Subtitle Service")
    logger.info(f"🌐 Port: {PORT}")
    logger.info(f"📁 Media: {MEDIA_PATH}")
    logger.info(f"🔑 OpenSubtitles API: {'✓ Configured' if OPENSUBTITLES_API_KEY else '✗ Not configured'}")
    logger.info("=" * 60)
    logger.info("Provider Priority:")
    logger.info("  1️⃣  OpenSubtitles.com (fast, reliable)")
    logger.info("  2️⃣  Cineaste.co.kr (fallback for rare movies)")
    logger.info("=" * 60)
    logger.info("Automation:")
    logger.info("  📨 Webhooks: Radarr & Sonarr (instant on download)")
    if RADARR_API_KEY or SONARR_API_KEY:
        logger.info(f"  ⏰ Scheduled Scans: Every {SCAN_INTERVAL_HOURS} hours")
        if RADARR_API_KEY:
            logger.info("     ✓ Radarr library scanning enabled")
        if SONARR_API_KEY:
            logger.info("     ✓ Sonarr library scanning enabled")
    else:
        logger.info("  ⏰ Scheduled Scans: Disabled (no API keys configured)")
    logger.info("=" * 60)

    # Schedule periodic scans if API keys are configured
    if RADARR_API_KEY:
        scheduler.add_job(
            scan_radarr_library,
            'interval',
            hours=SCAN_INTERVAL_HOURS,
            id='radarr_scan',
            name='Scan Radarr for missing Korean subtitles',
            next_run_time=None  # Don't run immediately on startup
        )
        logger.info(f"✓ Scheduled Radarr scans every {SCAN_INTERVAL_HOURS} hours")

    if SONARR_API_KEY:
        scheduler.add_job(
            scan_sonarr_library,
            'interval',
            hours=SCAN_INTERVAL_HOURS,
            id='sonarr_scan',
            name='Scan Sonarr for missing Korean subtitles',
            next_run_time=None  # Don't run immediately on startup
        )
        logger.info(f"✓ Scheduled Sonarr scans every {SCAN_INTERVAL_HOURS} hours")

    app.run(host='0.0.0.0', port=PORT, debug=False)

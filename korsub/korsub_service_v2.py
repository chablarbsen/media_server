#!/usr/bin/env python3
"""
KorSub - Korean Subtitle Service (OpenSubtitles API Version)
Automatically downloads Korean subtitles using OpenSubtitles.com API
"""

import os
import json
import logging
from flask import Flask, request, jsonify
from pathlib import Path
from opensubtitles_api import OpenSubtitlesAPI

# Configuration
MEDIA_PATH = os.getenv("MEDIA_PATH", "/data/media")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
PORT = int(os.getenv("PORT", "7272"))
OPENSUBTITLES_API_KEY = os.getenv("OPENSUBTITLES_API_KEY", "")

# Setup logging
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("KorSub")

# Flask app
app = Flask(__name__)

# Initialize OpenSubtitles API
opensub_api = OpenSubtitlesAPI(api_key=OPENSUBTITLES_API_KEY)


class SubtitleProcessor:
    """Process subtitle requests from Radarr/Sonarr webhooks"""

    def __init__(self):
        self.api = opensub_api

    def process_movie(self, payload):
        """Process movie download from Radarr webhook"""
        try:
            movie = payload.get('movie', {})
            movie_file = payload.get('movieFile', {})

            title = movie.get('title')
            year = movie.get('year')
            imdb_id = movie.get('imdbId')  # Radarr provides this!
            tmdb_id = movie.get('tmdbId')
            file_path = movie_file.get('path')

            if not file_path:
                logger.warning("No file path in webhook payload")
                return False

            logger.info(f"Processing movie: {title} ({year}) - IMDb: {imdb_id}")

            # Search for Korean subtitles using IMDb ID (most reliable)
            results = self.api.search_subtitles(
                imdb_id=imdb_id,
                tmdb_id=tmdb_id,
                query=title if not imdb_id and not tmdb_id else None,
                languages="ko",
                year=year,
                type="movie"
            )

            if not results:
                logger.warning(f"No Korean subtitles found for {title}")
                return False

            # Get the best match (first result, highest downloads usually)
            best_match = results[0]
            details = self.api.get_subtitle_details(best_match)

            logger.info(f"Found subtitle: {details['release']} (downloads: {details['downloads']})")

            # Determine save path
            video_path = Path(file_path)
            subtitle_path = video_path.with_suffix('.ko.srt')

            # Download subtitle
            file_id = details['file_id']
            if not file_id:
                logger.error("No file ID in result")
                return False

            success = self.api.download_subtitle(file_id, str(subtitle_path))

            if success:
                logger.info(f"✓ Successfully downloaded Korean subtitle for {title}")
                return True
            else:
                logger.error(f"✗ Failed to download subtitle for {title}")
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
            tvdb_id = series.get('tvdbId')
            imdb_id = series.get('imdbId')
            file_path = episode_file.get('path')

            if not all([series_title, file_path, episodes]):
                logger.warning("Missing required episode data in webhook")
                return False

            # Get first episode info
            episode = episodes[0]
            season_num = episode.get('seasonNumber')
            episode_num = episode.get('episodeNumber')

            logger.info(f"Processing episode: {series_title} S{season_num:02d}E{episode_num:02d}")

            # Search for Korean subtitles
            # Note: OpenSubtitles API episode search requires episode/season numbers
            results = self.api.search_subtitles(
                imdb_id=imdb_id if imdb_id else None,
                query=series_title if not imdb_id else None,
                languages="ko",
                type="episode"
            )

            if not results:
                logger.warning(f"No Korean subtitles found for {series_title} S{season_num:02d}E{episode_num:02d}")
                return False

            # Get the best match
            best_match = results[0]
            details = self.api.get_subtitle_details(best_match)

            logger.info(f"Found subtitle: {details['release']}")

            # Determine save path
            video_path = Path(file_path)
            subtitle_path = video_path.with_suffix('.ko.srt')

            # Download subtitle
            file_id = details['file_id']
            if not file_id:
                logger.error("No file ID in result")
                return False

            success = self.api.download_subtitle(file_id, str(subtitle_path))

            if success:
                logger.info(f"✓ Successfully downloaded Korean subtitle for episode")
                return True
            else:
                logger.error(f"✗ Failed to download subtitle")
                return False

        except Exception as e:
            logger.error(f"Error processing episode: {e}")
            import traceback
            traceback.print_exc()
            return False


# Initialize processor
processor = SubtitleProcessor()


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    has_api_key = bool(OPENSUBTITLES_API_KEY)
    return jsonify({
        'status': 'healthy',
        'service': 'KorSub',
        'provider': 'OpenSubtitles.com API',
        'api_key_configured': has_api_key
    }), 200


@app.route('/webhook/radarr', methods=['POST'])
def radarr_webhook():
    """Handle Radarr webhooks"""
    try:
        payload = request.get_json()
        event_type = payload.get('eventType')

        logger.info(f"Received Radarr webhook: {event_type}")

        # Only process Download events
        if event_type == 'Download':
            success = processor.process_movie(payload)
            return jsonify({'success': success}), 200
        else:
            logger.debug(f"Ignoring event type: {event_type}")
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

        logger.info(f"Received Sonarr webhook: {event_type}")

        # Only process Download events
        if event_type == 'Download':
            success = processor.process_episode(payload)
            return jsonify({'success': success}), 200
        else:
            logger.debug(f"Ignoring event type: {event_type}")
            return jsonify({'ignored': True}), 200

    except Exception as e:
        logger.error(f"Error handling Sonarr webhook: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/manual/search', methods=['POST'])
def manual_search():
    """Manual search endpoint for testing"""
    try:
        data = request.get_json()
        title = data.get('title')
        year = data.get('year')
        imdb_id = data.get('imdb_id')
        tmdb_id = data.get('tmdb_id')

        if not any([title, imdb_id, tmdb_id]):
            return jsonify({'error': 'title, imdb_id, or tmdb_id is required'}), 400

        results = opensub_api.search_subtitles(
            imdb_id=imdb_id,
            tmdb_id=tmdb_id,
            query=title if not imdb_id and not tmdb_id else None,
            languages="ko",
            year=year
        )

        # Extract details for easier reading
        simplified_results = []
        for result in results:
            details = opensub_api.get_subtitle_details(result)
            simplified_results.append(details)

        return jsonify({
            'query': title or imdb_id or tmdb_id,
            'year': year,
            'results_count': len(results),
            'results': simplified_results[:10]  # Limit to 10 results
        }), 200

    except Exception as e:
        logger.error(f"Error in manual search: {e}")
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    logger.info(f"Starting KorSub service on port {PORT}")
    logger.info(f"Media path: {MEDIA_PATH}")
    logger.info(f"Provider: OpenSubtitles.com API")

    if not OPENSUBTITLES_API_KEY:
        logger.warning("=" * 60)
        logger.warning("WARNING: No OpenSubtitles API key configured!")
        logger.warning("Service will work for SEARCH but NOT for DOWNLOAD")
        logger.warning("Get a free API key at: https://www.opensubtitles.com/en/consumers")
        logger.warning("Then set environment variable: OPENSUBTITLES_API_KEY")
        logger.warning("=" * 60)

    app.run(host='0.0.0.0', port=PORT, debug=False)

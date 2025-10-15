#!/usr/bin/env python3
"""
KorSub - Korean Subtitle Service
Automatically downloads Korean subtitles from Cineaste.co.kr for Radarr/Sonarr
"""

import os
import json
import logging
import requests
from flask import Flask, request, jsonify
from pathlib import Path
import time
from bs4 import BeautifulSoup
from urllib.parse import quote, urljoin
import re

# Configuration
CINEASTE_BASE_URL = "https://cineaste.co.kr"
CINEASTE_SEARCH_URL = f"{CINEASTE_BASE_URL}/bbs/search.php"
CINEASTE_SUBTITLE_BOARD = f"{CINEASTE_BASE_URL}/bbs/board.php?bo_table=psd_caption"
MEDIA_PATH = os.getenv("MEDIA_PATH", "/data/media")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
PORT = int(os.getenv("PORT", "7272"))

# Setup logging
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("KorSub")

# Flask app
app = Flask(__name__)

class CineasteScraper:
    """Scraper for Cineaste.co.kr subtitle site"""

    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })

    def search_subtitles(self, title, year=None):
        """
        Search for subtitles on Cineaste

        Args:
            title: Movie/show title (English)
            year: Release year (optional)

        Returns:
            List of subtitle results with download links
        """
        logger.info(f"Searching Cineaste for: {title} ({year})")

        # Try multiple search strategies
        search_terms = [
            title,  # English title
            f"{title} {year}" if year else title,
        ]

        all_results = []
        for search_term in search_terms:
            results = self._search_with_term(search_term)
            all_results.extend(results)
            if results:
                logger.info(f"Found {len(results)} results for '{search_term}'")
                break  # Stop if we found results

        if not all_results:
            logger.warning(f"No subtitles found for '{title}'")

        return all_results

    def _search_with_term(self, search_term):
        """Perform search with a specific term"""
        try:
            # Search directly on the subtitle board for better results
            # Board: psd_caption (자막자료실)
            # Category: %ED%95%9C%EA%B8%80 (Korean subtitles)
            params = {
                'bo_table': 'psd_caption',  # Subtitle board
                'sca': '%ED%95%9C%EA%B8%80',  # Korean category
                'sfl': 'wr_subject',  # Search in subject/title
                'stx': search_term,  # Search term
                'sop': 'and'
            }

            # Use the board URL instead of global search
            board_url = f"{CINEASTE_BASE_URL}/bbs/board.php"
            response = self.session.get(board_url, params=params, timeout=10)
            response.raise_for_status()

            soup = BeautifulSoup(response.content, 'html.parser')
            results = self._parse_search_results(soup)

            return results

        except Exception as e:
            logger.error(f"Search error for '{search_term}': {e}")
            return []

    def _parse_search_results(self, soup):
        """Parse search results page"""
        results = []

        # Find all subtitle entries (adapt selector based on actual HTML structure)
        # This is a placeholder - will need to be refined based on actual site structure
        entries = soup.find_all('div', class_='list-item') or soup.find_all('tr')

        for entry in entries:
            try:
                # Extract title, link, and metadata
                title_elem = entry.find('a', href=re.compile(r'wr_id='))
                if not title_elem:
                    continue

                title = title_elem.get_text(strip=True)
                href = title_elem['href']
                full_url = urljoin(CINEASTE_BASE_URL, href)

                # Extract wr_id for download
                wr_id_match = re.search(r'wr_id=(\d+)', href)
                if not wr_id_match:
                    continue

                wr_id = wr_id_match.group(1)

                results.append({
                    'title': title,
                    'url': full_url,
                    'wr_id': wr_id,
                    'source': 'cineaste.co.kr'
                })

            except Exception as e:
                logger.debug(f"Error parsing entry: {e}")
                continue

        return results

    def download_subtitle(self, wr_id, save_path):
        """
        Download subtitle file from Cineaste

        Args:
            wr_id: Cineaste subtitle ID
            save_path: Path to save the subtitle file

        Returns:
            True if successful, False otherwise
        """
        try:
            # Get the subtitle page to find download link
            page_url = f"{CINEASTE_SUBTITLE_BOARD}&wr_id={wr_id}"
            response = self.session.get(page_url, timeout=10)
            response.raise_for_status()

            soup = BeautifulSoup(response.content, 'html.parser')

            # Find download link (usually in attachments section)
            download_link = soup.find('a', href=re.compile(r'download\.php'))

            if not download_link:
                logger.error(f"No download link found for wr_id={wr_id}")
                return False

            download_url = urljoin(CINEASTE_BASE_URL, download_link['href'])

            # Download the file
            logger.info(f"Downloading subtitle from {download_url}")
            dl_response = self.session.get(download_url, timeout=30, stream=True)
            dl_response.raise_for_status()

            # Save to file
            with open(save_path, 'wb') as f:
                for chunk in dl_response.iter_content(chunk_size=8192):
                    f.write(chunk)

            logger.info(f"Subtitle saved to {save_path}")
            return True

        except Exception as e:
            logger.error(f"Download error for wr_id={wr_id}: {e}")
            return False


class SubtitleProcessor:
    """Process subtitle requests from Radarr/Sonarr webhooks"""

    def __init__(self):
        self.scraper = CineasteScraper()

    def process_movie(self, payload):
        """Process movie download from Radarr webhook"""
        try:
            movie = payload.get('movie', {})
            movie_file = payload.get('movieFile', {})

            title = movie.get('title')
            year = movie.get('year')
            folder_path = movie.get('folderPath')
            file_path = movie_file.get('path')

            if not all([title, folder_path, file_path]):
                logger.warning("Missing required movie data in webhook")
                return False

            logger.info(f"Processing movie: {title} ({year})")

            # Search for Korean subtitles
            results = self.scraper.search_subtitles(title, year)

            if not results:
                logger.warning(f"No Korean subtitles found for {title}")
                return False

            # Download the best match (first result)
            best_match = results[0]
            logger.info(f"Downloading subtitle: {best_match['title']}")

            # Determine save path (same directory as video, with .ko.srt extension)
            video_path = Path(file_path)
            subtitle_path = video_path.with_suffix('.ko.srt')

            success = self.scraper.download_subtitle(best_match['wr_id'], subtitle_path)

            if success:
                logger.info(f"Successfully downloaded Korean subtitle for {title}")
                return True
            else:
                logger.error(f"Failed to download subtitle for {title}")
                return False

        except Exception as e:
            logger.error(f"Error processing movie: {e}")
            return False

    def process_episode(self, payload):
        """Process episode download from Sonarr webhook"""
        try:
            series = payload.get('series', {})
            episodes = payload.get('episodes', [])
            episode_file = payload.get('episodeFile', {})

            series_title = series.get('title')
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
            search_title = f"{series_title} S{season_num:02d}E{episode_num:02d}"
            results = self.scraper.search_subtitles(search_title)

            if not results:
                # Try with just series title
                results = self.scraper.search_subtitles(series_title)

            if not results:
                logger.warning(f"No Korean subtitles found for {search_title}")
                return False

            # Download the best match
            best_match = results[0]
            logger.info(f"Downloading subtitle: {best_match['title']}")

            # Determine save path
            video_path = Path(file_path)
            subtitle_path = video_path.with_suffix('.ko.srt')

            success = self.scraper.download_subtitle(best_match['wr_id'], subtitle_path)

            if success:
                logger.info(f"Successfully downloaded Korean subtitle for {search_title}")
                return True
            else:
                logger.error(f"Failed to download subtitle for {search_title}")
                return False

        except Exception as e:
            logger.error(f"Error processing episode: {e}")
            return False


# Initialize processor
processor = SubtitleProcessor()


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'service': 'KorSub'}), 200


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

        if not title:
            return jsonify({'error': 'title is required'}), 400

        scraper = CineasteScraper()
        results = scraper.search_subtitles(title, year)

        return jsonify({
            'title': title,
            'year': year,
            'results': results
        }), 200

    except Exception as e:
        logger.error(f"Error in manual search: {e}")
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    logger.info(f"Starting KorSub service on port {PORT}")
    logger.info(f"Media path: {MEDIA_PATH}")
    app.run(host='0.0.0.0', port=PORT, debug=False)

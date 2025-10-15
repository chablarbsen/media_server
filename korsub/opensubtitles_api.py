#!/usr/bin/env python3
"""
OpenSubtitles.com REST API Client
Official API documentation: https://opensubtitles.stoplight.io/
"""

import os
import requests
import logging
from typing import List, Dict, Optional
import time

logger = logging.getLogger("OpenSubtitles")


class OpenSubtitlesAPI:
    """Client for OpenSubtitles.com REST API"""

    BASE_URL = "https://api.opensubtitles.com/api/v1"

    def __init__(self, api_key: Optional[str] = None, user_agent: str = "KorSub v1.0"):
        """
        Initialize OpenSubtitles API client

        Args:
            api_key: OpenSubtitles.com API key (optional for search, required for download)
            user_agent: User agent string (required by API)
        """
        self.api_key = api_key or os.getenv("OPENSUBTITLES_API_KEY", "")
        self.user_agent = user_agent
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': self.user_agent,
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        })

        if self.api_key:
            self.session.headers.update({
                'Api-Key': self.api_key
            })
            logger.info("OpenSubtitles API initialized with API key")
        else:
            logger.warning("OpenSubtitles API initialized WITHOUT API key (search-only mode)")

    def search_subtitles(
        self,
        imdb_id: Optional[str] = None,
        tmdb_id: Optional[str] = None,
        query: Optional[str] = None,
        languages: str = "ko",
        year: Optional[int] = None,
        type: str = "movie"
    ) -> List[Dict]:
        """
        Search for subtitles

        Args:
            imdb_id: IMDb ID (e.g., "tt1104001")
            tmdb_id: TMDB ID
            query: Search query (movie/show title)
            languages: Comma-separated language codes (default: "ko" for Korean)
            year: Release year
            type: Content type ("movie" or "episode")

        Returns:
            List of subtitle results
        """
        endpoint = f"{self.BASE_URL}/subtitles"
        params = {
            'languages': languages,
            'type': type
        }

        # Prefer IMDb ID (most reliable)
        if imdb_id:
            params['imdb_id'] = imdb_id.replace('tt', '')  # API wants ID without 'tt'
            logger.info(f"Searching by IMDb ID: {imdb_id}")
        elif tmdb_id:
            params['tmdb_id'] = tmdb_id
            logger.info(f"Searching by TMDB ID: {tmdb_id}")
        elif query:
            params['query'] = query
            if year:
                params['year'] = year
            logger.info(f"Searching by query: {query} ({year})")
        else:
            logger.error("No search criteria provided")
            return []

        try:
            response = self.session.get(endpoint, params=params, timeout=10)
            response.raise_for_status()

            data = response.json()
            results = data.get('data', [])

            logger.info(f"Found {len(results)} subtitle results")
            return results

        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 429:
                logger.error("Rate limit exceeded - too many requests")
            else:
                logger.error(f"HTTP error: {e.response.status_code} - {e.response.text}")
            return []
        except Exception as e:
            logger.error(f"Search error: {e}")
            return []

    def download_subtitle(self, file_id: int, save_path: str) -> bool:
        """
        Download subtitle file

        Args:
            file_id: OpenSubtitles file ID
            save_path: Path to save the subtitle file

        Returns:
            True if successful, False otherwise
        """
        if not self.api_key:
            logger.error("API key required for downloads - please set OPENSUBTITLES_API_KEY")
            return False

        endpoint = f"{self.BASE_URL}/download"
        payload = {
            'file_id': file_id
        }

        try:
            # Request download link
            response = self.session.post(endpoint, json=payload, timeout=10)
            response.raise_for_status()

            data = response.json()
            download_url = data.get('link')

            if not download_url:
                logger.error("No download link in response")
                return False

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

        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 429:
                logger.error("Rate limit exceeded - too many requests")
            elif e.response.status_code == 406:
                logger.error("Daily download limit exceeded")
            else:
                logger.error(f"HTTP error: {e.response.status_code} - {e.response.text}")
            return False
        except Exception as e:
            logger.error(f"Download error: {e}")
            return False

    def get_subtitle_details(self, result: Dict) -> Dict:
        """
        Extract useful details from a search result

        Args:
            result: Single result from search_subtitles()

        Returns:
            Dictionary with extracted details
        """
        attributes = result.get('attributes', {})

        return {
            'file_id': attributes.get('files', [{}])[0].get('file_id') if attributes.get('files') else None,
            'language': attributes.get('language'),
            'release': attributes.get('release'),
            'downloads': attributes.get('download_count', 0),
            'ratings': attributes.get('ratings', 0),
            'uploader': attributes.get('uploader', {}).get('name', 'Unknown'),
            'hearing_impaired': attributes.get('hearing_impaired', False),
            'foreign_parts_only': attributes.get('foreign_parts_only', False),
            'feature_type': attributes.get('feature_details', {}).get('feature_type')
        }


def test_api():
    """Test function to verify API is working"""
    api = OpenSubtitlesAPI()

    # Test search for Tron Legacy
    print("Testing OpenSubtitles API...")
    print("Searching for Tron Legacy (tt1104001) Korean subtitles...\n")

    results = api.search_subtitles(imdb_id="tt1104001", languages="ko")

    if results:
        print(f"✓ Found {len(results)} Korean subtitle(s)!\n")
        for i, result in enumerate(results[:5]):
            details = api.get_subtitle_details(result)
            print(f"{i+1}. Release: {details['release']}")
            print(f"   Language: {details['language']}")
            print(f"   Downloads: {details['downloads']}")
            print(f"   File ID: {details['file_id']}")
            print()
    else:
        print("✗ No results found")
        print("This might mean:")
        print("- API is down")
        print("- Rate limit exceeded")
        print("- No Korean subs for this movie")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    test_api()

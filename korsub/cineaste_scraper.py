#!/usr/bin/env python3
"""
Cineaste.co.kr Scraper - Fallback for movies not on OpenSubtitles
"""

import requests
from bs4 import BeautifulSoup
import logging
import re
from urllib.parse import urljoin
from typing import List, Dict, Optional

logger = logging.getLogger("Cineaste")


class CineasteScraper:
    """Scraper for Cineaste.co.kr subtitle board"""

    BASE_URL = "https://cineaste.co.kr"
    SUBTITLE_BOARD_URL = f"{BASE_URL}/bbs/board.php"

    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })

    def search_subtitles(self, title: str, year: Optional[int] = None) -> List[Dict]:
        """
        Search for Korean subtitles on Cineaste subtitle board

        Args:
            title: Movie title (English)
            year: Release year (optional)

        Returns:
            List of subtitle results
        """
        logger.info(f"Searching Cineaste for: {title} ({year})")

        # Try multiple search terms
        search_terms = [
            title,  # Full title
            title.split(':')[0] if ':' in title else title,  # Before colon
            title.split('-')[0] if '-' in title else title,  # Before dash
        ]

        # Add year variant
        if year:
            search_terms.insert(0, f"{title} {year}")

        all_results = []
        for search_term in search_terms:
            results = self._search_board(search_term.strip())
            if results:
                logger.info(f"Found {len(results)} results for '{search_term}'")
                all_results.extend(results)
                break  # Stop at first successful search

        # Remove duplicates by wr_id
        seen_ids = set()
        unique_results = []
        for result in all_results:
            if result['wr_id'] not in seen_ids:
                seen_ids.add(result['wr_id'])
                unique_results.append(result)

        return unique_results

    def _search_board(self, search_term: str) -> List[Dict]:
        """Search the subtitle board"""
        try:
            params = {
                'bo_table': 'psd_caption',  # Subtitle board
                'sca': '한글',  # Korean category
                'sfl': 'wr_subject',  # Search in subject
                'stx': search_term,
                'sop': 'and'
            }

            response = self.session.get(self.SUBTITLE_BOARD_URL, params=params, timeout=10)
            response.raise_for_status()

            soup = BeautifulSoup(response.content, 'html.parser')
            return self._parse_results(soup)

        except Exception as e:
            logger.error(f"Cineaste search error: {e}")
            return []

    def _parse_results(self, soup: BeautifulSoup) -> List[Dict]:
        """Parse search results from board page"""
        results = []

        # Find all links with wr_id in the subtitle board
        # Look for article/post links (not comments which have #c_)
        for link in soup.find_all('a', href=re.compile(r'wr_id=\d+')):
            href = link.get('href', '')

            # Skip comment links
            if '#c_' in href:
                continue

            # Skip if not from subtitle board
            if 'psd_caption' not in href:
                continue

            # Extract wr_id
            wr_id_match = re.search(r'wr_id=(\d+)', href)
            if not wr_id_match:
                continue

            wr_id = wr_id_match.group(1)
            title = link.get_text(strip=True)

            # Skip empty titles or navigation links
            if not title or len(title) < 3:
                continue

            full_url = urljoin(self.BASE_URL, href)

            results.append({
                'title': title,
                'url': full_url,
                'wr_id': wr_id,
                'source': 'cineaste.co.kr'
            })

        logger.debug(f"Parsed {len(results)} subtitle entries")
        return results

    def download_subtitle(self, wr_id: str, save_path: str) -> bool:
        """
        Download subtitle file from Cineaste

        NOTE: Cineaste has CAPTCHA protection on downloads.
        This method will fail for automated downloads.
        Use for manual downloads or search only.

        Args:
            wr_id: Subtitle post ID
            save_path: Path to save file

        Returns:
            True if successful
        """
        logger.warning("⚠️  Cineaste downloads require CAPTCHA - automated download not possible")
        logger.info(f"📋 Manual download URL: {self.SUBTITLE_BOARD_URL}?bo_table=psd_caption&wr_id={wr_id}")

        # Return False to indicate the download cannot be automated
        # The user will need to manually download from Cineaste
        return False


# Test function
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)

    scraper = CineasteScraper()

    # Test with Tron Legacy
    print("Testing Cineaste scraper with Tron Legacy...")
    results = scraper.search_subtitles("Tron Legacy", 2010)

    if results:
        print(f"\n✓ Found {len(results)} results:")
        for i, result in enumerate(results[:5]):
            print(f"{i+1}. {result['title']}")
            print(f"   ID: {result['wr_id']}")
            print(f"   URL: {result['url']}")
    else:
        print("\n✗ No results found")

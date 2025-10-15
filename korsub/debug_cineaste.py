#!/usr/bin/env python3
"""Debug script to test Cineaste scraping"""

import requests
from bs4 import BeautifulSoup
import json

CINEASTE_BASE_URL = "https://cineaste.co.kr"
CINEASTE_SEARCH_URL = f"{CINEASTE_BASE_URL}/bbs/search.php"

session = requests.Session()
session.headers.update({
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
})

# Test search
search_term = "Terminator"
params = {
    'sfl': 'wr_subject',
    'stx': search_term,
    'sop': 'and'
}

print(f"Searching for: {search_term}")
print(f"URL: {CINEASTE_SEARCH_URL}")
print(f"Params: {params}\n")

try:
    response = session.get(CINEASTE_SEARCH_URL, params=params, timeout=10)
    print(f"Status Code: {response.status_code}")
    print(f"Final URL: {response.url}\n")

    # Save full HTML for inspection
    with open('/tmp/cineaste_search.html', 'w', encoding='utf-8') as f:
        f.write(response.text)
    print("Full HTML saved to /tmp/cineaste_search.html\n")

    # Parse with BeautifulSoup
    soup = BeautifulSoup(response.content, 'html.parser')

    # Try different selectors to find results
    print("=== Testing different selectors ===\n")

    # Test 1: Look for any links with wr_id
    wr_id_links = soup.find_all('a', href=lambda x: x and 'wr_id=' in x)
    print(f"Links with wr_id: {len(wr_id_links)}")
    for i, link in enumerate(wr_id_links[:3]):
        print(f"  {i+1}. {link.get_text(strip=True)[:50]} - {link['href']}")
    print()

    # Test 2: Look for table rows
    rows = soup.find_all('tr')
    print(f"Table rows found: {len(rows)}")
    print()

    # Test 3: Look for divs with class containing 'list'
    list_divs = soup.find_all('div', class_=lambda x: x and 'list' in x.lower())
    print(f"Divs with 'list' in class: {len(list_divs)}")
    print()

    # Test 4: Print first 1000 chars of body
    body = soup.find('body')
    if body:
        print("=== First 1000 chars of body ===")
        print(body.get_text()[:1000])

except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()

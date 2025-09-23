#!/bin/bash

# Security Audit Script
# Checks for sensitive data that should never be in public repos

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "Security Audit for Git Repository"
echo "========================================="
echo ""

FOUND_ISSUES=0

echo -e "${BLUE}Checking for sensitive data in tracked files...${NC}"
echo ""

# Check for IP addresses
echo -n "Checking for IP addresses... "
if git grep -E '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' --cached 2>/dev/null | grep -v "127.0.0.1" | grep -v "0.0.0.0"; then
    echo -e "${RED}✗ Found IP addresses!${NC}"
    FOUND_ISSUES=$((FOUND_ISSUES + 1))
else
    echo -e "${GREEN}✓${NC}"
fi

# Check for API keys
echo -n "Checking for API keys... "
if git grep -iE '(api[_-]?key|apikey|api_token|token|secret|password).*=.*[a-f0-9]{16,}' --cached 2>/dev/null; then
    echo -e "${RED}✗ Found potential API keys!${NC}"
    FOUND_ISSUES=$((FOUND_ISSUES + 1))
else
    echo -e "${GREEN}✓${NC}"
fi

# Check for usernames
echo -n "Checking for usernames... "
if git grep -iE '(username|user|email).*=.*@' --cached 2>/dev/null; then
    echo -e "${RED}✗ Found potential usernames/emails!${NC}"
    FOUND_ISSUES=$((FOUND_ISSUES + 1))
else
    echo -e "${GREEN}✓${NC}"
fi

# Check for domain names
echo -n "Checking for domain names... "
if git grep -E '(serenity\.watch|\.local|\.home)' --cached 2>/dev/null; then
    echo -e "${YELLOW}⚠ Found local domain names${NC}"
    echo "  Consider replacing with generic examples"
fi

# Check for ports
echo -n "Checking for exposed ports... "
if git grep -E '192\.168\.[0-9]+\.[0-9]+:[0-9]+' --cached 2>/dev/null; then
    echo -e "${YELLOW}⚠ Found internal IP:port combinations${NC}"
fi

# Check what files are tracked
echo ""
echo -e "${BLUE}Files currently tracked in git:${NC}"
git ls-files
echo ""

# Check .gitignore effectiveness
echo -e "${BLUE}Checking .gitignore coverage...${NC}"
if [ -f .env.secrets ]; then
    if git check-ignore .env.secrets >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} .env.secrets is properly ignored"
    else
        echo -e "${RED}✗${NC} .env.secrets is NOT ignored!"
        FOUND_ISSUES=$((FOUND_ISSUES + 1))
    fi
fi

echo ""
if [ $FOUND_ISSUES -gt 0 ]; then
    echo -e "${RED}⚠ SECURITY ISSUES FOUND!${NC}"
    echo "Do NOT push to public repository until resolved!"
    echo ""
    echo "To fix:"
    echo "1. Run: bash /docker/mediaserver/sanitize-for-public.sh"
    echo "2. Review all changes"
    echo "3. Commit sanitized version"
else
    echo -e "${GREEN}✓ No critical security issues found${NC}"
    echo "Still recommended to run sanitize-for-public.sh before pushing"
fi
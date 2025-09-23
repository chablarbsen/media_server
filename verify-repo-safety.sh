#!/bin/bash

# Repository Safety Verification Script
# Run this before any git operations to ensure you don't overwrite production repos

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Repository Safety Verification${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check current directory
echo -e "${YELLOW}Current Directory:${NC}"
pwd
echo ""

# Check current branch
echo -e "${YELLOW}Current Branch:${NC}"
current_branch=$(git branch --show-current)
echo "  $current_branch"
echo ""

# Check remotes
echo -e "${YELLOW}Git Remotes:${NC}"
git remote -v
echo ""

# Check if we have uncommitted changes
echo -e "${YELLOW}Git Status:${NC}"
if git diff --quiet && git diff --staged --quiet; then
    echo -e "${GREEN}✓${NC} Working directory clean"
else
    echo -e "${YELLOW}⚠${NC} You have uncommitted changes:"
    git status --short
fi
echo ""

# Show recent commits
echo -e "${YELLOW}Recent Commits:${NC}"
git log --oneline -5
echo ""

# Verify current configuration
echo -e "${YELLOW}Safety Verification:${NC}"

if [ "$current_branch" = "master" ]; then
    echo -e "${BLUE}ℹ${NC} You're on 'master' branch (private configuration)"
    echo -e "${GREEN}✓${NC} Safe to push to: private remote"
    echo -e "${RED}✗${NC} DO NOT push to: origin remote (would expose secrets!)"
elif [ "$current_branch" = "main" ]; then
    echo -e "${BLUE}ℹ${NC} You're on 'main' branch (sanitized configuration)"
    echo -e "${GREEN}✓${NC} Safe to push to: origin remote"
    echo -e "${YELLOW}⚠${NC} Verify sanitization before pushing"
else
    echo -e "${YELLOW}⚠${NC} You're on '$current_branch' branch"
    echo -e "${BLUE}ℹ${NC} Verify which remote is appropriate for this branch"
fi
echo ""

# Check for sensitive data in current state
echo -e "${YELLOW}Quick Sensitivity Check:${NC}"
if grep -r "192\.168\.50\." . --exclude-dir=.git >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} Found real IP addresses - this is NOT sanitized"
    echo -e "${RED}  DO NOT push to public repository!${NC}"
elif grep -r "serenity\.watch" . --exclude-dir=.git >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} Found real domain names - this is NOT sanitized"
    echo -e "${RED}  DO NOT push to public repository!${NC}"
else
    echo -e "${GREEN}✓${NC} No obvious sensitive data found"
fi
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Verification Complete${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Remember:"
echo "• master branch → private remote"
echo "• main branch → origin remote"
echo "• Always check this output before pushing!"
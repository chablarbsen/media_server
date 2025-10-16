#!/bin/bash
# Sanitization Script for Public Repository
# This script removes all sensitive information before pushing to public repo

set -euo pipefail

echo "🧹 Sanitizing media server configuration for public repository..."

# Ensure we're on the main branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "❌ ERROR: Must be on 'main' branch to sanitize. Current branch: $CURRENT_BRANCH"
    exit 1
fi

# Backup current state
BACKUP_DIR="sanitization-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "/tmp/$BACKUP_DIR"
cp -r . "/tmp/$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup created: /tmp/$BACKUP_DIR"

echo "🔧 Sanitizing docker-compose.yml..."

# Replace sensitive values with placeholders
sed -i 's|192\.168\.50\.51|YOUR_VPN_IP|g' docker-compose.yml
sed -i 's|192\.168\.50\.199|YOUR_SERVER_IP|g' docker-compose.yml
sed -i 's|serenity\.watch|your-domain.com|g' docker-compose.yml
sed -i 's|/home/chab|/home/username|g' docker-compose.yml
sed -i 's|chab|username|g' docker-compose.yml

# Replace API keys with placeholders
sed -i 's|OPENSUBTITLES_API_KEY=.*|OPENSUBTITLES_API_KEY=${OPENSUBTITLES_API_KEY}|g' docker-compose.yml
sed -i 's|RADARR_API_KEY=.*|RADARR_API_KEY=${RADARR_API_KEY}|g' docker-compose.yml
sed -i 's|SONARR_API_KEY=.*|SONARR_API_KEY=${SONARR_API_KEY}|g' docker-compose.yml

echo "🔧 Sanitizing .md documentation files..."

# Sanitize all markdown files
for file in *.md; do
    if [ -f "$file" ]; then
        sed -i 's|192\.168\.50\.51|YOUR_VPN_IP|g' "$file"
        sed -i 's|192\.168\.50\.199|YOUR_SERVER_IP|g' "$file"
        sed -i 's|serenity\.watch|your-domain.com|g' "$file"
        sed -i 's|/home/chab|/home/username|g' "$file"
        sed -i 's|chab|username|g' "$file"
        sed -i 's|chablarbsen|your-github-username|g' "$file"

        # Sanitize API keys
        sed -i 's|OPENSUBTITLES_API_KEY=FV19gN73WvIjfDElJeco5yIPnSai85UC|OPENSUBTITLES_API_KEY=YOUR_OPENSUBTITLES_KEY|g' "$file"
        sed -i 's|RADARR_API_KEY=7c00ac8c57144f8e987e3ba435565bcd|RADARR_API_KEY=YOUR_RADARR_KEY|g' "$file"
        sed -i 's|RADARR_API_KEY=34dd79502c9f4e89187a7de6dc5f953d|RADARR_API_KEY=YOUR_RADARR_KEY|g' "$file"
        sed -i 's|SONARR_API_KEY=128e4fcd971c44d1a514715b8b4a5220|SONARR_API_KEY=YOUR_SONARR_KEY|g' "$file"
        sed -i 's|SONARR_API_KEY=fbba6cec984d96eb4ca943f6f05eb778|SONARR_API_KEY=YOUR_SONARR_KEY|g' "$file"

        echo "  ✅ Sanitized: $file"
    fi
done

echo "🔧 Creating .env.template (removing secrets from .env)..."

# Create .env.template if .env exists
if [ -f ".env" ]; then
    cp .env .env.template
    sed -i 's|=.*|=YOUR_VALUE_HERE|g' .env.template
    sed -i 's|192\.168\.50\.[0-9]\+|YOUR_IP|g' .env.template
    sed -i 's|serenity\.watch|your-domain.com|g' .env.template
    echo "  ✅ Created: .env.template"
fi

echo "✅ Sanitization complete!"
echo ""
echo "📋 Next steps:"
echo "  1. Review changes: git diff"
echo "  2. Add changes: git add -A"
echo "  3. Commit: git commit -m 'Update sanitized public version'"
echo "  4. Push to public: git push origin main"
echo ""
echo "⚠️  Remember: NEVER push 'master' branch to 'origin' (public repo)!"
echo "⚠️  master → private/master (real config)"
echo "⚠️  main → origin/main (sanitized config)"

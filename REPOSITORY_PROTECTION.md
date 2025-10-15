# Repository Protection Guide

## CRITICAL - PRODUCTION REPOSITORIES

⚠️ **WARNING**: These repositories contain your working production configuration. NEVER overwrite them accidentally!

## Current Repository Setup

### Public Repository (Sanitized)
- **URL**: https://github.com/chablarbsen/media_server.git
- **Remote**: `origin`
- **Branch**: `main`
- **Purpose**: Public sharing with sanitized configuration
- **Contains**: Generic IPs, example domains, template files

### Private Repository (Real Configuration)
- **URL**: https://github.com/chablarbsen/media_server_private.git
- **Remote**: `private`
- **Branch**: `master`
- **Purpose**: Disaster recovery with real configuration
- **Contains**: Real IPs, API keys, actual service configs

## SAFETY CHECKLIST

Before ANY git operation, run these commands:

```bash
# 1. Verify your location and branch
pwd
git branch
git remote -v

# 2. Check what you're about to commit/push
git status
git log --oneline -5
git diff HEAD

# 3. VERIFY VERSION NUMBERS - Check existing release notes and commits
# This prevents creating duplicate version numbers or overwriting existing releases
git log --oneline | grep -i "release\|v1\."  # Check for version commits
ls -la RELEASE_NOTES_*.md                     # List existing release notes
git log --oneline -1                          # Check latest commit for current version

# 4. Verify the correct remote for your intent
# For private changes (real config):
git push private master

# For public changes (sanitized):
git push origin main
```

## PROTECTION RULES

### ❌ NEVER DO THIS:
- `git push origin master` (pushes real config to public!)
- `git push private main` (pushes sanitized to private!)
- `git push --force` on either repository
- `git reset --hard` without backing up first
- Overwrite existing branches without confirmation

### ✅ SAFE OPERATIONS:
- Always check `git remote -v` first
- Always check `git branch` before pushing
- Always review `git diff` before committing
- Create backup branches for experiments
- Test changes in development environment first

## RECOVERY COMMANDS

If you accidentally push to wrong remote:

```bash
# 1. Check what happened
git log --oneline -10

# 2. If you pushed real config to public repo:
# Contact GitHub support immediately to purge history
# Then regenerate all API keys as they're now compromised

# 3. If you pushed sanitized to private:
# Force push the correct version (after backing up):
git checkout master
git push private master --force-with-lease
```

## WORKFLOW REMINDERS

### Creating a New Release (IMPORTANT!)

**Before creating any release notes or version commits:**

```bash
# 1. Check existing versions to determine next version number
git log --oneline | grep -E "v[0-9]+\.[0-9]+"
ls -la RELEASE_NOTES_*.md

# 2. Review the latest release to understand what's already documented
git show $(git log --oneline | grep -i "release\|v1\." | head -1 | cut -d' ' -f1)

# 3. Check current changes since last release
git diff $(git log --oneline | grep -i "release" | head -1 | cut -d' ' -f1)..HEAD

# 4. Create release notes with NEXT version number (never duplicate!)
# Example: If v1.4 exists, create RELEASE_NOTES_v1.5.md

# 5. Document ALL changes made since last version
# Review: git log --oneline <last-version-commit>..HEAD
```

### Making Changes to Real Configuration
```bash
git checkout master              # Switch to real config branch
# Make your changes
git add -A && git commit -m "Updated real config"
git push private master         # Push to PRIVATE repo
```

### Updating Public Repository
```bash
git checkout main               # Switch to sanitized branch
bash sanitize-for-public.sh    # Re-sanitize if needed
git add -A && git commit -m "Updated public config"
git push origin main           # Push to PUBLIC repo
```

## BACKUP STRATEGY

Before major changes:
```bash
# Create backup branches
git checkout master
git branch backup-$(date +%Y%m%d) master
git checkout main
git branch backup-public-$(date +%Y%m%d) main
```

## CONTACT FOR EMERGENCIES

If you accidentally expose sensitive data:
1. **Immediately** regenerate all API keys
2. Contact GitHub support to purge repository history
3. Review and rotate all credentials
4. Check for any unauthorized access

Remember: **When in doubt, DON'T PUSH**
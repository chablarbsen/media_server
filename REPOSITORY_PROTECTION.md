# Repository Protection Guide

## CRITICAL - PRODUCTION REPOSITORIES

⚠️ **WARNING**: These repositories contain your working production configuration. NEVER overwrite them accidentally!

## Current Repository Setup

### Public Repository (Sanitized)
- **URL**: https://github.com/your-github-username/media_server.git
- **Remote**: `origin`
- **Branch**: `main`
- **Purpose**: Public sharing with sanitized configuration
- **Contains**: Generic IPs, example domains, template files

### Private Repository (Real Configuration)
- **URL**: https://github.com/your-github-username/media_server_private.git
- **Remote**: `private`
- **Branch**: `master`
- **Purpose**: Disaster recovery with real configuration
- **Contains**: Real IPs, API keys, actual service configs

## CRITICAL: Branch and Remote Rules

**NEVER DEVIATE FROM THESE RULES:**

| Branch | Remote | Purpose | Contains |
|--------|--------|---------|----------|
| `master` | `private` | Production backup | Real IPs, API keys, domains |
| `main` | `origin` | Public sharing | Sanitized placeholders |

**❌ FORBIDDEN COMBINATIONS:**
- `master` → `origin` (exposes secrets to public!)
- `main` → `private` (overwrites real config!)

## PRE-PUSH SAFETY HOOK

A git pre-push hook is installed to prevent accidents. It will **automatically block** forbidden push combinations.

**Location**: `.git/hooks/pre-push`

**What it blocks:**
- ❌ Pushing `master` to `origin` (public)
- ❌ Pushing `main` to `private`
- ❌ Pushing unsanitized data to `origin/main`

**To bypass** (ONLY if you're absolutely certain): `git push --no-verify`
**WARNING**: Never bypass without understanding why it blocked you!

## SAFETY CHECKLIST

Before ANY git operation, run these commands:

```bash
# 1. Verify your location and branch
pwd
git branch               # Shows current branch with *
git remote -v            # Shows configured remotes

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
# The git hook will block if you get this wrong, but verify anyway:

# For private changes (real config):
if [ "$(git branch --show-current)" = "master" ]; then
    git push private master
else
    echo "ERROR: Not on master branch!"
fi

# For public changes (sanitized):
if [ "$(git branch --show-current)" = "main" ]; then
    git push origin main
else
    echo "ERROR: Not on main branch!"
fi
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

### Updating Public Repository (COMPLETE WORKFLOW)
```bash
# Step 1: Commit your changes to master (real config) first
git checkout master
git add docker-compose.yml CHANGELOG.md  # Add only config files, not runtime data
git commit -m "v1.x.x - Description of changes"
git push private master

# Step 2: Switch to main branch and merge changes
git checkout main
git merge master --no-commit  # Merge but don't commit yet

# Step 3: Run sanitization script
./sanitize-for-public.sh

# Step 4: Review sanitized changes
git diff  # Verify all secrets are replaced with placeholders

# Step 5: Commit and push sanitized version
git add -A
git commit -m "v1.x.x - Description of changes (sanitized)"
git push origin main  # Pre-push hook will verify safety

# Step 6: Verify public repo is clean
# Visit https://github.com/your-username/media_server
# Check docker-compose.yml and .md files for exposed secrets
```

**Important**: The pre-push hook will block if you try to push unsanitized data!

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
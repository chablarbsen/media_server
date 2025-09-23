# Security Audit Documentation

## Overview
This document tracks security considerations for the media server configuration repository.

## Repository Structure

### Public Branch (`public-safe`)
- Sanitized configuration files
- Generic IP addresses (192.168.1.X)
- Example domain names (yourdomain.example.com)
- No API keys or secrets
- Template files only

### Private Branch (`master`)
- Actual configuration with real IPs
- Real domain names
- Active service configurations
- Never push to public repositories

## Sensitive Data Checklist

### ❌ Never Commit
- [ ] API keys (any hex strings 16+ characters)
- [ ] Passwords or tokens
- [ ] Real IP addresses (internal or external)
- [ ] Real domain names
- [ ] Email addresses
- [ ] Usernames (except generic 'admin')
- [ ] VPN credentials
- [ ] SSL certificates
- [ ] Personal paths (/home/username)

### ✅ Safe to Commit
- [ ] Docker compose structure
- [ ] Service relationships
- [ ] Generic paths (/data, /config)
- [ ] Port mappings (without IPs)
- [ ] Shell scripts (sanitized)
- [ ] Documentation
- [ ] Configuration templates

## Sanitization Patterns

| Type | Original Example | Sanitized Version |
|------|-----------------|-------------------|
| IP Address | 192.168.1.100 | 192.168.1.100 |
| Domain | yourdomain.example.com | yourdomain.example.com |
| Username | user | user |
| Path | /home/user/ssd-cache | /path/to/cache |
| API Key | 128e4fcd971c44d1a514... | ${API_KEY_VARIABLE} |

## Pre-Push Checklist

Before pushing to ANY repository:

1. **Run Security Audit**
   ```bash
   bash security-audit.sh
   ```

2. **Check Git Status**
   ```bash
   git status
   git diff --cached
   ```

3. **Verify .gitignore**
   ```bash
   git check-ignore .env.secrets
   git check-ignore */config.xml
   ```

4. **For Public Repository**
   ```bash
   bash sanitize-for-public.sh
   git checkout public-safe
   ```

## Security Best Practices

### 1. Environment Variables
- Use `.env.example` for templates
- Store real values in `.env.secrets`
- Never hardcode credentials

### 2. API Key Management
- Generate unique keys per service
- Rotate keys periodically
- Use the manage-api-keys.sh script

### 3. Network Security
- Use internal Docker networks
- Expose only necessary ports
- Bind to specific interfaces

### 4. Backup Security
- Encrypt backup archives
- Store separately from main config
- Test restoration regularly

### 5. Configuration Management (CRITICAL)
- **NEVER sacrifice working configurations for convenience**
- Always backup current configs before running automation scripts
- Test automation scripts in development environment first
- Verify current service status before applying bulk changes
- Document all manual configurations before automating
- If services are working, understand WHY before changing

## Automated Checks

The `security-audit.sh` script checks for:
- Exposed IP addresses
- Hardcoded API keys
- Email addresses
- Domain names
- Proper .gitignore coverage

Run before every commit:
```bash
bash security-audit.sh
```

## Git Workflow

### Two-Remote Setup
```bash
# Private repository (full config)
git remote add private git@github.com:yourusername/mediaserver-private.git

# Public repository (sanitized)
git remote add public git@github.com:yourusername/mediaserver-public.git

# Push private changes
git checkout master
git push private master

# Push public changes
git checkout public-safe
bash sanitize-for-public.sh
git push public public-safe:main
```

## Recovery Security

When recovering from backup:
1. Clone from private repo first
2. Restore `.env.secrets` from secure backup
3. Regenerate API keys if needed
4. Never restore from untrusted public forks

## Monitoring

Regular security tasks:
- Weekly: Review access logs
- Monthly: Rotate API keys
- Quarterly: Full security audit
- Yearly: Review and update security practices

## Contact

For security concerns:
- Keep security issues private
- Don't report security issues publicly
- Document fixes in this file

Last Audit: $(date +%Y-%m-%d)
Next Scheduled: $(date -d '+30 days' +%Y-%m-%d)
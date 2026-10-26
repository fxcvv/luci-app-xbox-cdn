# Changelog

## [2.0.0] - 2026-10-26

### Added
- LuCI web interface (luci-app-xbox-cdn)
  - Manual trigger with live log polling
  - SmartDNS / dnsmasq mode switch
  - Scheduled test configuration
  - Status display (last run, current mode)
- SmartDNS output mode (`--mode smartdns`)
  - Merges rules into `/etc/smartdns/custom.conf` via marked block
  - Non-destructive: preserves existing custom.conf content
- `xbox-cdn-run` background launcher (start-stop-daemon based)
- `xbox-cdn-cron` crontab manager
- Auto-detect DNS service on port 53 during install
- UCI config (`/etc/config/xbox-cdn`)

### Fixed
- `log()` no longer pollutes stdout, which caused timestamps to leak into IP results
- Cron job now uses `xbox-cdn-run` for proper status tracking
- `current-config` shows only the xbox-cdn block for SmartDNS mode

### Removed
- `config.example` (replaced by UCI config)
- `QUICKSTART.md` (merged into README)
- `RELEASE_NOTES.md` (merged into CHANGELOG)
- `test-on-router.sh` (outdated)

## [1.0.0] - 2026-10-25

### Added
- Initial release
- Automated CDN speed testing for Xbox downloads
- Support for Xbox China CDN (xboxlive.cn), Akamai, Microsoft Delivery
- Concurrent download testing
- Automatic dnsmasq configuration generation
- Change detection to minimize reloads
- File locking to prevent concurrent runs
- Interactive installation / uninstallation scripts

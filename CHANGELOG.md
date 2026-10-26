# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2024-10-25

### Added
- Initial release
- Automated CDN speed testing for Xbox downloads
- Support for Xbox China CDN (xboxlive.cn)
- Support for Akamai CDN nodes
- Support for Microsoft delivery CDN
- Concurrent download testing
- Automatic dnsmasq configuration generation
- Change detection to minimize dnsmasq reloads
- File locking to prevent concurrent runs
- Comprehensive logging
- Interactive installation script
- Uninstallation script
- Quick start guide
- Router test utility

### Features
- Configurable test parameters (size, timeout, concurrency)
- Top-N IP selection per CDN group
- Backup and rollback on configuration errors
- Custom configuration file support
- Cron job integration for automated optimization

### Documentation
- English README
- Chinese README (README_CN.md)
- Quick start guide (QUICKSTART.md)
- Configuration examples
- Troubleshooting guide

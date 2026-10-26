# Xbox CDN Speedtest for OpenWrt

Automatically test and optimize Xbox download speeds on OpenWrt by selecting the fastest CDN nodes for your network.

## Problem

Xbox downloads are often slow due to:
- Suboptimal CDN node selection by DNS
- Geographic routing issues
- Network congestion on default nodes

This script tests multiple CDN IPs and configures your router to use the fastest ones.

## Features

- Tests Xbox China CDN (xboxlive.cn)
- Tests Akamai CDN nodes (xboxlive.com)
- Tests Microsoft delivery CDN
- Generates dnsmasq configuration automatically
- Change detection - only reloads when needed
- Concurrent downloads for accurate speed comparison
- Prevents duplicate runs with file locking

## Requirements

- OpenWrt router
- `curl` with HTTP/2 support
- `dnsmasq` for DNS
- `flock` (busybox version OK)
- Basic tools: `awk`, `grep`, `sed`

## Installation

**Quick Install (Recommended):**
```bash
wget -qO- https://raw.githubusercontent.com/fxcvv/xbox-cdn-speedtest/main/install.sh | sh
```

See [QUICKSTART.md](QUICKSTART.md) for detailed installation guide.

**Manual Installation:**

```bash
# Download script
wget -O /etc/xbox-speedtest.sh https://raw.githubusercontent.com/fxcvv/xbox-cdn-speedtest/main/xbox-speedtest.sh
chmod +x /etc/xbox-speedtest.sh

# Download CDN IP list
wget -O /etc/xbox-cdn-ips.conf https://raw.githubusercontent.com/fxcvv/xbox-cdn-speedtest/main/cdn-ips.conf

# Test run
/etc/xbox-speedtest.sh

# Add to cron (daily at 3:30 AM)
echo "30 3 * * * /etc/xbox-speedtest.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

## Configuration

Edit variables at the top of `xbox-speedtest.sh`:

```bash
DNSMASQ_CONF="/tmp/dnsmasq.d/xbox-cdn.conf"  # Output file
LOG_FILE="/tmp/xbox-speedtest.log"           # Log location
TEST_SIZE="10M"                               # Download size per test
CONCURRENT=3                                  # Parallel downloads
TIMEOUT=15                                    # Timeout per test
```

## How It Works

1. **Load CDN IPs** from `cdn-ips.conf`
2. **Concurrent speed test** - Download test files from each IP
3. **Select fastest** - Top 2 from each CDN group
4. **Generate config** - Create dnsmasq address rules
5. **Apply changes** - Reload dnsmasq only if config changed

## Tested CDN Domains

- `assets1.xboxlive.cn`, `assets2.xboxlive.cn`
- `d1.xboxlive.cn`, `d2.xboxlive.cn`
- `dlassets.xboxlive.cn`, `dlassets2.xboxlive.cn`
- `assets1.xboxlive.com`, `assets2.xboxlive.com` (Akamai)
- `dl.delivery.mp.microsoft.com`

## Advanced Usage

### With Local Cache Server

If you run a local nginx cache for Xbox downloads:

```bash
# Edit the script to use your cache server
CACHE_SERVER="192.168.1.100"
# Uncomment and modify test URLs in the script
```

### Custom Test URLs

The script uses Xbox CDN paths that always return valid files. You can modify:
- `/filestable/` - Xbox game files path
- Test file size and timeout

## Troubleshooting

**No speed improvement:**
- Check if dnsmasq config was generated: `cat /tmp/dnsmasq.d/xbox-cdn.conf`
- Verify dnsmasq reloaded: `/etc/init.d/dnsmasq status`
- Test DNS resolution: `nslookup assets1.xboxlive.cn`

**Script fails:**
- Check dependencies: `which curl flock`
- Review log: `tail -f /tmp/xbox-speedtest.log`
- Test manually: Run script with verbose output

**Timeouts during testing:**
- Increase `TIMEOUT` value
- Reduce `CONCURRENT` downloads
- Check if test URLs are accessible

## Contributing

Contributions welcome! Please:
1. Test on your OpenWrt setup
2. Document any compatibility issues
3. Submit PRs for improvements

## License

GPL-3.0 - See LICENSE file

## Credits

Inspired by real-world Xbox download optimization on OpenWrt routers.

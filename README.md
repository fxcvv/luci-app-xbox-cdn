# luci-app-xbox-cdn

Xbox CDN optimization for OpenWrt with LuCI web interface.

Automatically tests multiple CDN nodes and applies the fastest IP to your DNS resolver — so Xbox downloads go direct through the optimal Chinese CDN instead of routing through your proxy.

## Features

- **LuCI web UI** — run tests, configure schedule, switch modes, view live log
- **SmartDNS & dnsmasq** — auto-detects which DNS service is on port 53
- **Scheduled tests** — daily cron via UI, no manual editing
- **Non-destructive** — SmartDNS mode merges a marked block into `custom.conf`, leaves everything else intact
- **CLI friendly** — all scripts work standalone without LuCI

## Requirements

- OpenWrt with LuCI
- SmartDNS or dnsmasq as DNS resolver
- `curl`, `flock` (`util-linux-flock`)

## Installation

```sh
git clone https://github.com/fxcvv/luci-app-xbox-cdn.git
cd luci-app-xbox-cdn
sh install.sh
```

The installer:
1. Detects SmartDNS or dnsmasq on port 53
2. Installs scripts to `/usr/bin/`
3. Installs LuCI app (Services → Xbox CDN 优化)
4. Optionally sets up a daily cron job

## Usage

**LuCI:** Services → Xbox CDN 优化

**CLI:**
```sh
# Run test and apply immediately
xbox-speedtest.sh --mode smartdns --apply
xbox-speedtest.sh --mode dnsmasq --apply

# Check status
xbox-cdn-run status

# Enable daily cron at 3:00
xbox-cdn-cron enable 3 0

# Disable cron
xbox-cdn-cron disable
```

## How it works

```
Test CDN IPs (XboxCN / AkamaiCN / MS Delivery)
  → Pick fastest per group
  → Write address rules to DNS resolver
  → Restart DNS service

SmartDNS: writes to /etc/smartdns/custom.conf
          between # BEGIN xbox-cdn / # END xbox-cdn markers
dnsmasq:  writes to /tmp/dnsmasq.d/xbox-cdn.conf
```

## File overview

| File | Description |
|---|---|
| `xbox-speedtest.sh` | Core speed test and config generator |
| `xbox-cdn-run` | Background launcher, status/log reader |
| `xbox-cdn-cron` | Crontab manager |
| `cdn-ips.conf` | CDN IP list to test |
| `install.sh` | Interactive installer |
| `uninstall.sh` | Clean removal |
| `luci-app/` | LuCI web UI files |

## License

GPL-3.0

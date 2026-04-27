# auto_network

Automatic network configuration for Ubuntu Server. Detects the active network on boot and applies the matching static IP via Netplan. Falls back to DHCP if no known network is found.

---

## Files

| File | Description |
|---|---|
| `auto_network.sh` | Main script |
| `network.conf` | Your configuration (IPs, gateways, interface...) |

---

## How it works

1. The script reads `network.conf` to load your network definitions.
2. For each defined network (in order), it temporarily assigns a probe IP on the interface, then pings the gateway.
3. As soon as a gateway responds, it writes the matching static IP config to Netplan and applies it.
4. If no gateway responds, it writes a DHCP config and applies it.

```
Network 1 reachable?  →  Apply static IP 1
      ↓ no
Network 2 reachable?  →  Apply static IP 2
      ↓ no
Network 3 reachable?  →  Apply static IP 3
      ↓ no
         →  Fall back to DHCP
```

The probe IPs are cleaned up after each test, whether the ping succeeded or not.

---

## Installation

```bash
sudo cp auto_network.sh /usr/local/bin/auto_network.sh
sudo cp network.conf /usr/local/bin/network.conf
sudo chmod +x /usr/local/bin/auto_network.sh
```

### Run at boot with systemd

Create `/etc/systemd/system/auto-ip.service`:

```ini
[Unit]
Description=Auto network IP configuration
After=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/auto_network.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Then enable it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable auto-ip.service
```

---

## Configuration — network.conf

### Interface & paths

```bash
INTERFACE="eth0"          # Network interface to configure
CONFIG_FILE="/etc/netplan/50-cloud-init.yaml"  # Netplan file to write
DNS="[1.1.1.1, 8.8.8.8]" # DNS servers applied to all static configs
```

### Network definitions

Networks are defined as numbered blocks. Add as many as you need:

```bash
# --- Network 1 ---
PROBE_1="10.0.0.254/8"       # Temporary IP used to reach the gateway
GATEWAY_1="10.0.0.1"         # Gateway to ping to detect this network
STATIC_IP_1="10.100.0.20/8"  # Static IP to assign if detected

# --- Network 2 ---
PROBE_2="192.168.1.254/24"
GATEWAY_2="192.168.1.1"
STATIC_IP_2="192.168.1.251/24"

# --- Network 3 ---
PROBE_3="172.16.0.254/24"
GATEWAY_3="172.16.0.1"
STATIC_IP_3="172.16.0.50/24"
```

Networks are tested in ascending order (1, 2, 3...). The first one whose gateway responds wins.

### Ping settings

```bash
PING_COUNT=3    # Number of ping attempts per gateway
PING_TIMEOUT=2  # Seconds to wait for each ping reply
```

---

## Custom config path

By default the script looks for `network.conf` in the same directory as itself. You can override this:

```bash
NETWORK_CONF=/path/to/custom/network.conf auto_network.sh
```

---

## Netplan output examples

**Static config (network detected):**
```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 192.168.1.251/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
```

**DHCP fallback (no network detected):**
```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: yes
```

---

## Troubleshooting

**The script doesn't run at boot** → Check the service status:
```bash
sudo systemctl status auto-ip.service
journalctl -u auto-ip.service
```

**Wrong network is picked** → Check that your probe IPs don't conflict with existing addresses on the interface, and that the gateway order in `network.conf` is correct.

**Netplan fails to apply** → Validate the generated config:
```bash
sudo netplan --debug apply
cat /etc/netplan/50-cloud-init.yaml
```

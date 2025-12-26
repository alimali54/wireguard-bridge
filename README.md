# WireGuard Bridge for Windows (Transparent Gateway)

This project enables a Windows PC to function as a **WireGuard Bridge** for other devices on a local network, such as gaming consoles, smart TVs, and mobile devices. It establishes a transparent gateway that routes traffic through a WireGuard tunnel without requiring any software installation on the client devices.

---

## Installation Note

**Important:** Due to file size limitations on GitHub, the necessary executable files are not included in the main repository source. Please download the complete package containing all pre-configured tools from the **[Releases](../../releases)** section of this repository.

---

## Requirements

* **NPcap:** Required for packet capturing functionality. Download and install from the official [NPcap website](https://nmap.org/npcap/).
* **Privileges:** This implementation is designed to operate without requiring administrator rights.

---

## Configuration and Setup

### 1. WireGuard Configuration
The project supports two routing modes: **Full Tunnel** and **Whitelist (Split Tunneling)**. 

1. Navigate to the `/sing-box` directory.
2. Select the desired mode:
   * For **Full Tunnel** (all traffic): Copy the content of `wireguard-config-all-example.json` into `wireguard-config.json`.
   * For **Whitelist Mode** (specific domains): Copy the content of `wireguard-config-whitelist-example.json` into `wireguard-config.json`.

3. Update the `wireguard-config.json` file with your specific WireGuard credentials:

**Field Mapping Reference:**

| WireGuard (.conf) | wireguard-config.json |
| :--- | :--- |
| `Address (IPv4 Only)` | `"local_address"` |
| `PrivateKey` | `"private_key"` |
| `PublicKey` | `"peer_public_key"` |
| `PresharedKey` | `"pre_shared_key"` |
| `Endpoint` (IP only) | `"server"` |
| `Endpoint` (Port only) | `"server_port"` |

```
Example WireGuard config:
[Interface]
PrivateKey = CJ2lgACYDNP4yuq4l4jYzZ+CujUp29nDUP94jKvzW1Q=
Address = 10.66.66.3/32,fd42:42:42::3/128
DNS = 1.1.1.1,1.0.0.1

[Peer]
PublicKey = U5nGijwylDjUFjuPTNmZe2msJ1O1lWAIBPWVt9+DThg=
PresharedKey = RnjXOSa63DmYouhszG3ts0Ihpn2eEr4HUU7a7Pz/pNE=
Endpoint = 141.11.109.242:49875
AllowedIPs = 0.0.0.0/0,::/0
```

```
Corresponding sing-box wireguard-config.json values:
"local_address": [
                "10.66.66.3/32"
            ],
            "mtu": 1280,
            "peer_public_key": "U5nGijwylDjUFjuPTNmZe2msJ1O1lWAIBPWVt9+DThg=",
            "pre_shared_key": "RnjXOSa63DmYouhszG3ts0Ihpn2eEr4HUU7a7Pz/pNE=",
            "private_key": "CJ2lgACYDNP4yuq4l4jYzZ+CujUp29nDUP94jKvzW1Q=",
            "server": "141.11.109.242",
            "server_port": 49875,
            "system_interface": false,
            "tag": "proxy",
            "type": "wireguard"
```
**Whitelist Modification:**
If using the whitelist configuration, locate the `"domain_suffix"` array and append the domains you wish to route through the VPN (e.g., `discord.com`, `roblox.com`).

```
"domain_suffix": [
                    "browserleaks.com",
                    "discord.com",
                    "discord.gg",
                    "discordapp.com",
                    "discordapp.net",
                    "discord.media",
                    "roblox.com",
                    "rbxcdn.com",
                    "api.roblox.com"
                ],
```

---

### 2. Manual Verification
It is recommended to verify each component individually before using automation scripts:

1. **Start sing-box:** Execute `sing-box/run_config.cmd`. This initiates the WireGuard tunnel and provides a SOCKS5 proxy at `127.0.0.1:2080`.
   * *Validation:* Configure a browser extension (e.g., FoxyProxy) to use SOCKS5 at `127.0.0.1:2080` and verify connectivity.
2. **Start DNS:** Execute `dnscrypt-proxy/dnscrypt-proxy.exe`.
3. **Start Gateway:** Execute `go-pcap2socks/go-pcap2socks.exe`. This process bridges the local network traffic to the proxy.

---

## Client Device Configuration

Configure the network settings of the target device (Console, TV, etc.) manually as follows:

| Setting | Value |
| :--- | :--- |
| **IP Address** | `172.24.2.2-255` (e.g., `172.24.2.5`) |
| **Gateway** | `172.24.2.1` |
| **Subnet Mask** | `255.255.0.0` |
| **DNS** | `1.1.1.1` (Note: `go-pcap2socks` will override this to use `dnscrypt-proxy` internally). |

---

## Automation Scripts

For routine use, utilize the VBScript files located in the root directory:

* **`run-all.vbs`**: Launches all services with visible terminal windows.
* **`run-all-silent.vbs`**: Launches all services in the background (hidden mode).
* **`stop-all.vbs`**: Terminates all associated processes (`nekobox_core.exe`, `dnscrypt-proxy.exe`, `go-pcap2socks.exe`).

---
├── README.md
├── run-all.vbs
├── run-all-silent.vbs
└── stop-all.vbs: Primary automation script for background operation.

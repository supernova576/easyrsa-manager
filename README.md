# easyrsa-manager

Detailed helper for generating and managing server certificates using Easy-RSA.

This repository contains `ynsjk_easyrsa.sh`, an interactive Bash script that:

- Generates server certificates and private keys using Easy-RSA.
- Optionally copies generated certificates/keys to a local destination.
- Optionally copies generated certificates/keys to a remote host via `scp` (password-based).
- Revokes certificates from the local PKI and deletes files from local destinations.
- Lists certificate expiry dates for certificates in the local PKI.

**Important:** This script is intended as a convenience wrapper around an Easy-RSA installation and assumes you run it from the root of an Easy-RSA PKI directory that contains `pki/issued` and `pki/private`.

**Files:**
- `ynsjk_easyrsa.sh` - main interactive script.
- `script.conf` - configuration file read by the script (must be present in the same directory).
- `easyrsa_ynsjk.log` - log file created/updated by the script.

**Prerequisites**
- `bash` (script is a Bash script)
- Easy-RSA CLI accessible as `easyrsa` (script invokes `bash easyrsa ...`)
- `sshpass` (only required if you use the remote `scp` option)
- `openssl` (used to inspect certificate expiry dates)

Install tools on Debian/Ubuntu, for example:

```bash
sudo apt update
sudo apt install easy-rsa sshpass openssl -y
```

Adjust package names for your distribution as needed.

Configuration (`script.conf`)
The script reads several values from `script.conf` in the current directory. Provide at minimum the following keys (simple whitespace-separated key/value pairs):

```
local_dest /path/to/local/destination/
scp_user remoteuser
scp_dest_dir /remote/destination/path/
```

- `local_dest`: local directory where the script will copy generated certificates and keys when requested. Trailing slash is recommended.
- `scp_user`: username for remote `scp` (if using the remote copy option).
- `scp_dest_dir`: remote destination directory for `scp` copies.

Usage
-----
Make the script executable and run it from the Easy-RSA directory (the directory that contains `pki/` and `script.conf`):

```bash
chmod +x ynsjk_easyrsa.sh
./ynsjk_easyrsa.sh
```

When launched the script prints a menu of options and prompts you to choose one.

Options (menu)
----------------
0: Generate web-certificate and key for server
- Walks through prompts to generate a server certificate using Easy-RSA.
- Prompts the user whether to copy the certificate/key to the `local_dest` from `script.conf` and whether to copy to a remote server via `scp`.
- Prompts for: base filename, SAN (Subject Alternative Name) string (single or comma-separated multi-value like `DNS:example.com,IP:1.2.3.4`), and validity in days.
- Invokes: `bash easyrsa --san=<SAN> --days=<DAYS> build-server-full <name> nopass`.

1: Delete certificate and key from local destination
- Prompts for base filename and removes `<local_dest>/<name>.crt` and `<local_dest>/<name>.key`.

2: Delete (revoke) certificate and key from local PKI
- Prompts for base filename and will check for files under `pki/issued` and `pki/private`.
- If present it calls `bash easyrsa revoke <name>` to revoke the certificate in the PKI.

3: Copy existing certificate to `local_dest`
- Prompts for base filename and copies `pki/issued/<name>.crt` and `pki/private/<name>.key` to `local_dest`.

4: Copy existing certificate to remote server (via `scp`)
- Prompts for base filename.
- Reads `scp_user` and `scp_dest_dir` from `script.conf`.
- Asks for the remote host and prompts twice for a password (uses `sshpass` and `scp` to copy certificate and key).
- WARNING: Passwords are read in plain for `sshpass` usage; SSH key authentication is much safer.

5: List expiry date of all certificates in PKI
- Iterates over files in `pki/issued` and uses `openssl x509 -noout -enddate` to log certificate expiry dates.

Logging
-------
The script appends human-readable log lines to `easyrsa_ynsjk.log` with timestamps, log level, and an option number. It also echoes log lines to stdout.

Example log line format:

```
2025-11-15 12:34:56	INFO	Certificate created	Running Option: 0
```

Security notes and best practices
--------------------------------
- Avoid using `sshpass` and plaintext passwords for production systems. Configure SSH key-based auth for the remote host and use `scp`/`rsync` without `sshpass`.
- Keep private keys secure. Restrict filesystem permissions on `pki/private` and any destination directories.
- The script uses Easy-RSA commands with `nopass` (no passphrase on the key) for convenience. For higher security, use passphrases and protect keys appropriately.
- Ensure `script.conf` permissions are restrictive if it contains sensitive destination information.

Troubleshooting
---------------
- "Command not found: easyrsa": install Easy-RSA and ensure the `easyrsa` wrapper is in PATH or run from the directory that contains the `easyrsa` script.
- `scp`/`sshpass` errors: verify network connectivity, `scp_user`, `scp_dest_dir`, and that `sshpass` is installed. Prefer SSH keys.
- Certificate generation fails: check that `pki/` exists and Easy-RSA is initialized (`easyrsa init-pki`, and CA is present).

Extending or modifying
----------------------
- Replace password-based remote copy with an SSH-key-based flow: remove `sshpass` usage and rely on `scp` or `rsync` over SSH keys.
- Add input validation and stricter error handling for user inputs (e.g., check SAN format, ensure valid number for days).

Contact / Contributing
----------------------
If you want improvements or fixes, open an issue or send a pull request. Be sure to include reproducible steps and any relevant `easyrsa_ynsjk.log` excerpts.

---
Generated README for `ynsjk_easyrsa.sh` (interactive Easy-RSA helper).

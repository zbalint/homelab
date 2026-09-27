# Homelab rebuild

This repository is being rebuilt from scratch. The previous configuration is kept in
`old_stuff/` as reference only.

## Radxa DNS hosts: `dns01-prd-huhbh-home` and `dns02-prd-huhbh-home`

`ansible/site.yml` is the shared remote Ansible playbook for both reinstalled
Radxa DNS hosts. It creates a key-authenticated administrator and
installs Tailscale, Docker Engine, the Compose plugin, gVisor, nftables, and
unattended upgrades. Docker is
configured for user namespace remapping and `runsc`. Tailscale enrollment, firewall
activation, and Technitium deployment are separate steps: they need network access
and a tested recovery path before either board becomes a resolver again.

Run Ansible from your computer over SSH. After DietPi first-boot setup, each
Radxa needs SSH access, a user with sudo access, Python 3, and `python3-apt`.
On each board, install any missing target packages:

```sh
sudo apt update
sudo apt install python3 python3-apt
```

Install `ansible-core` on your computer (for example,
`sudo apt install --no-install-recommends ansible-core` on Debian/Ubuntu).
From this repository, copy `ansible/inventory.example.yml` to
`ansible/inventory.yml`. Fill in each board's LAN IP, existing SSH login,
actual LAN interface, and LAN subnet; the working inventory is gitignored.
Each playbook checks that the connected board's hostname matches its inventory entry.
Check SSH access and run the playbook for one board at a time:

```sh
cp ansible/inventory.example.yml ansible/inventory.yml
# Edit ansible/inventory.yml before running the following commands.
ansible -i ansible/inventory.yml --limit dns01-prd-huhbh-home dns_hosts -m ping
ansible-playbook -i ansible/inventory.yml --limit dns01-prd-huhbh-home ansible/site.yml \
  -e admin_user=YOUR_USER \
  -e admin_ssh_public_key='YOUR_SSH_PUBLIC_KEY'
```

Run the same commands with `--limit dns02-prd-huhbh-home` for the second board.
If the existing SSH user needs a sudo password, add `--ask-become-pass` to
the playbook command. The `ping` module checks Ansible's SSH/Python connection;
it does not test ICMP.

Supply a **public** SSH key only. Do not put a private key or Tailscale auth key in
the command, inventory, or repository. The administrator uses `sudo` for Docker;
membership in the `docker` group grants root-level control of the host. Set the
administrator's local sudo password on each board after the playbook runs with
`sudo passwd YOUR_USER`; do not send that password to anyone or put it in git.

The initial playbook does not change SSH server settings or apply firewall rules.
After it runs, enroll Tailscale, verify management access, then apply and test the
DNS host firewall. Configure the DNS Compose deployment before changing client resolvers.

Validate changes on your computer with:

```sh
ansible-playbook --syntax-check -i ansible/inventory.yml \
  ansible/site.yml ansible/firewall.yml ansible/firewall-confirm.yml ansible/technitium.yml
```

This checks playbook syntax; it does not prove package installation or network
behavior on the Radxa boards.

## Host firewall with rollback

After Tailscale is enrolled and management access works, run `ansible/firewall.yml`
from your computer with `--limit` for exactly one Radxa. Its LAN interface and
IPv4 subnet come from the inventory:

```sh
ansible-playbook -i ansible/inventory.yml --limit dns01-prd-huhbh-home ansible/firewall.yml
```

The playbook checks the rendered rules with `nft -c` before replacing the file.
When the file changes, it arms a ten-minute rollback timer and atomically reloads
only the `homelab_input` table. The stock `nftables.service` must be inactive and disabled:
its default global flush can erase Docker and Tailscale rules. The new firewall
service is not enabled at boot until you confirm the change.

Before the ten minutes expire, test a **new** SSH login over the LAN and another
over Tailscale from a separate device or terminal. Then confirm that same
Radxa from your computer:

```sh
ansible-playbook -i ansible/inventory.yml --limit dns01-prd-huhbh-home ansible/firewall-confirm.yml \
  -e connectivity_verified=true
```

Repeat the firewall apply, connection tests, and confirmation with
`--limit dns02-prd-huhbh-home` after the first board is confirmed. Both
firewall playbooks reject a run that selects both boards.

Confirmation cancels the rollback and enables the dedicated firewall service at
boot. If you cannot reconnect or do not confirm, the timer removes only the
homelab input table; it does not touch Docker or Tailscale tables. A later
firewall change uses the same apply, test, confirm sequence. Re-running the
firewall playbook without a change leaves the active rules alone.

The rules allow SSH from the LAN subnet and Tailscale, plus Tailscale's default
UDP port 41641 for direct peer connections. To disable LAN SSH, add
`-e allow_lan_ssh=false`, but then the LAN test above no longer applies and
you need a working local recovery path. Confirm Tailscale's actual listen port
before activation if it has been changed. The policy drops other inbound host
traffic; it does not restrict Docker-published ports, which Docker handles
through its own forwarding rules.

Technitium DNS must answer on both the home LAN and Tailscale, on **UDP and
TCP port 53**. Configure those published ports in the later Compose deployment;
the host INPUT rules above cannot open or restrict them. If Compose binds to
the two specific host IPs, its startup must wait until the Tailscale IP exists
after boot. Decide how to provide that ordering before enabling automatic
container restarts. Keep a working local recovery path before changing the
firewall on either headless board.

## Technitium Compose deployment

`ansible/technitium.yml` stages `ansible/files/technitium/docker-compose.yml`
and a rendered `.env` onto one Radxa at a time, owned by the existing admin
user. It does not pull images or start containers; run `docker compose up -d`
yourself over SSH after staging:

```sh
ansible-playbook -i ansible/inventory.yml --limit dns01-prd-huhbh-home ansible/technitium.yml \
  -e admin_user=YOUR_USER
```

Pass `-e technitium_tag=vX.Y.Z` to stage a different image tag than the
default. Repeat with `--limit dns02-prd-huhbh-home` for the second board.

Port 53 publishes on all interfaces; the web console (5380 HTTP, 53443
HTTPS) publishes only on `BIND_ADDRESS`, which defaults to loopback
(`127.0.0.1`, console unreachable except from the board itself). Pass
`-e technitium_bind_address=<tailscale-ip>` with that board's own Tailscale
IP to reach the console over the tailnet. If Docker starts the container
before Tailscale has assigned that IP (e.g. on boot), the port bind fails;
`restart: unless-stopped` keeps retrying until the IP exists.

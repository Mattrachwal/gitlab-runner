# **Secure GitLab Runner ( DIRECT INSTALL )**

### With Optional Local Admin Web UI (LAN Access)

---

## 📖 **Table of Contents**

1. **What Is This?**
2. **Who Is This For?**
3. **Why This Exists**
4. **Security Model & Philosophy**
5. **What You’ll Get After Installing**
6. **Two Main Modes: Runner Only vs. Runner + Admin UI**
7. **Quick Setup (Runner Only)**
8. **Optional Setup (Runner + Admin UI)**
9. **How It Works Under the Hood**
10. **GitLab CI/CD Basics (Runner Concepts)**
11. **Security Features in Detail**
12. **Scaling to Multiple Projects**
13. **Updating & Uninstalling**
14. **Troubleshooting**
15. **Frequently Asked Questions**
16. **Future Improvements**

---

## 1. **What Is This?**

This project sets up a **GitLab Runner** on a Debian 13 machine in a **secure, reproducible, and maintainable** way.  
It includes:

- **Automated installation scripts**
- **Systemd hardening** for defense-in-depth
- A single **`config.json`** file that holds all your settings
- Optional **local admin web UI** to manage your runner via a browser (accessible over your LAN)

It’s designed so that you can set up a new runner from scratch **in minutes**, whether you’re doing it for yourself or teaching others.

---

## 2. **Who Is This For?**

- **Junior Developers** who are just learning CI/CD and want to see how a runner fits in.
- **Homelab / self-hosting enthusiasts** running GitLab pipelines on their own machines.
- **Small teams** that want **private** runners without the risk of public abuse.
- Anyone who wants a **repeatable, secure** runner install they can deploy to multiple machines.

---

## 3. **Why This Exists**

Out-of-the-box, the `gitlab-runner` package works — but:

- It can be **less secure** (default configs often allow untagged jobs from any accessible project).
- It’s **manual** to set up multiple runners or replicate a runner to another machine.
- Many people forget to **lock down their runner**, especially in public repos, leading to abuse.

This repo fixes those by:

- Providing **safe defaults** (`run_untagged=false`, `locked=true`).
- Using **JSON config** to store runner definitions.
- Adding **systemd security settings** so the runner can’t mess with the rest of the system.
- Documenting everything in **human language**.

---

## 4. **Security Model & Philosophy**

We assume:

- This runner will be used for **private** projects, OR for public projects with strict tag rules.
- You don’t want random people from the internet to run jobs on your hardware.
- You want to **minimize damage** if a malicious job somehow runs.

**How we achieve that:**

- **Scope** the runner to your group or project only.
- **Disable untagged jobs** → jobs must have specific tags to run here.
- **Lock** the runner → can’t be hijacked by other groups/projects.
- **Systemd sandboxing** → runner process has minimal filesystem and device access.
- **No sudo in CI jobs** → jobs run as the `gitlab-runner` user, not root.
- **Optional Admin UI** is LAN-only and UFW-restricted to your subnet.

---

## 5. **What You’ll Get After Installing**

- **A secure runner** that can execute your GitLab pipelines.
- Central `config.json` for:
  - GitLab URL
  - Concurrency setting
  - Build/cache directories
  - Runner(s) definitions (name, tags, token)
- Hardened service environment.
- If enabled: **a web UI** to:
  - View/edit config.json
  - Register runners from JSON
  - Restart runner service
  - See list of registered runners

---

## 6. **Two Main Modes**

### **A) Runner Only (Default)**

- Installs the runner service.
- No web UI — everything is CLI-based.

### **B) Runner + Admin UI (Optional)**

- Also installs a small Node.js/Express server on your LAN (port 80 by default).
- Accessible at `http://<runner-ip>/` from devices on your subnet.
- Password-protected with Basic Auth.
- Only whitelisted subnet can access (via UFW).

You choose the mode by setting an environment variable when running `install.sh`.

---

## 7. **Quick Setup (Runner Only)**

**Step 1:** Clone this repo onto your Debian 13 machine.

```bash
git clone https://github.com/Mattrachwal/gitlab-runner.git
cd gitlab-runner
```

**Step 2:** Edit `config.json`.

```json
{
  "gitlab_url": "https://gitlab.com",
  "concurrent": 5,
  "builds_dir": "/var/lib/gitlab-runner/builds",
  "cache_dir": "/var/lib/gitlab-runner/cache",
  "security": {
    "run_untagged": false,
    "locked": true,
    "access_level": "not_protected"
  },
  "runners": [
    {
      "name": "mini1-shared",
      "tags": ["shared", "shell", "debian13"],
      "registration_token": "YOUR_GROUP_OR_PROJECT_TOKEN"
    }
  ]
}
```

**Step 3:** Install runner.

```bash
sudo ./scripts/install.sh
sudo ./scripts/harden-systemd.sh
sudo ./scripts/set-concurrent.sh
sudo ./scripts/register-from-json.sh
```

## 8. **Optional Setup (Runner + Admin UI)**

Enable when running `install.sh`:

```bash
sudo SETUP_ADMIN_UI=1 ADMIN_SUBNET="192.168.1.0/24" ADMIN_PORT=80 \
  ./scripts/install.sh
```

- Admin UI will be reachable at:  
  `http://<runner-ip>/`
- Default credentials: `admin / change-me`  
  (Edit `/opt/debian-secure-gitlab-runner/admin-server/.env` to change.)

**Service controls:**

```bash
sudo systemctl enable --now runner-admin
sudo systemctl status runner-admin
sudo systemctl stop runner-admin
```

**Firewall (UFW) rule added automatically (adjust subnet/port as needed):**

```bash
sudo ufw allow from 192.168.1.0/24 to any port 80 proto tcp
```

---

## 9. **How It Works Under the Hood**

- **`install.sh`**

  - Updates system packages.
  - Installs UFW, fail2ban, unattended-upgrades, jq.
  - Installs `gitlab-runner` package from the official repository.
  - Creates build/cache dirs with restricted permissions.
  - Optionally installs and configures the Admin UI.

- **`harden-systemd.sh`**

  - Adds a systemd drop-in to restrict the runner process (filesystem protection, capability drop, syscall/address-family limits).

- **`set-concurrent.sh`**

  - Reads `concurrent` from `config.json` and applies it to `/etc/gitlab-runner/config.toml`.

- **`register-from-json.sh`**

  - Iterates over `runners[]` in `config.json` and registers each runner with your GitLab instance using the provided tokens/tags.
  - Applies secure defaults: `run_untagged=false`, `locked=true`, `access_level=not_protected`.

- **Admin UI (optional)**
  - Runs as `runneradmin` user.
  - Calls a root helper via sudo with a **strict allow-list** (no arbitrary commands).
  - Binds to LAN (port 80 by default) and is protected by Basic Auth + UFW subnet rule.

---

## 10. **GitLab CI/CD Basics (Runner Concepts)**

- **Runner**: The machine/agent that executes jobs from your pipelines.
- **Tags**: Labels on a runner. Jobs must request matching tags to run there (routing).
- **`run_untagged`**: If `true`, jobs **without** tags can run on the runner (we set this to `false` for safety).
- **Locked runner**: Tied to the project/group it was registered to; won’t accept jobs from elsewhere.
- **Concurrency**: Max number of jobs the runner host will execute in parallel (shared across all `[[runners]]` on that host).

**Mental model:**

- `concurrent` = how many **lanes** on the highway.
- Each `[[runner]]` = a **toll booth** with different **signs** (tags). Jobs choose a booth whose signs they match, but total cars on the road are still capped by `concurrent`.

---

## 11. **Security Features in Detail**

1. **`run_untagged=false`**  
   Jobs must explicitly request your tags (prevents random, tag-less jobs from using your hardware).

2. **`locked=true`**  
   Keeps the runner scoped tightly to the project/group where it was registered.

3. **Systemd sandboxing**

   - `ProtectSystem=strict`, `ProtectHome=true`, `PrivateTmp=true`, `PrivateDevices=true`, `NoNewPrivileges=true`, capability bounding set = empty.
   - Limits filesystem writes to specific runner directories.
   - Restricts syscalls and network address families to the essentials.

4. **Least privilege in jobs**  
   Jobs run as the `gitlab-runner` Unix user (no `sudo` by default).

5. **Network controls**  
   UFW baseline: allows SSH; Admin UI (if enabled) is restricted to your LAN/subnet.

6. **Hygiene**  
   `unattended-upgrades` enabled to keep security patches flowing; `fail2ban` to slow down brute-force SSH attempts.

7. **Token handling**  
   Tokens are read from `config.json` but never printed to console; the Admin UI masks tokens on read.

---

## 12. **Scaling to Multiple Projects**

### Private organization (recommended)

- Use a **group-level runner** (register once with the group registration token).
- In each repo’s `.gitlab-ci.yml`, set tags that match your runner (e.g., `shared, shell, debian13`).

### Public repositories

- Prefer **project-level runners** with project-specific registration tokens.
- Keep `run_untagged=false`.
- Avoid publishing sensitive tags in public docs; treat tags as routing, not secrets.
- Consider disabling pipelines for forks if you’re worried about abuse.

### Multiple runner identities on the same host

Add more entries to `config.json → runners[]` with different `name`/`tags` (e.g., a `heavy` lane):

```json
{
  "name": "mini1-heavy",
  "tags": ["heavy", "shell", "debian13"],
  "registration_token": "TOKEN_FOR_THIS_RUNNER"
}
```

Then re-run:

```bash
sudo ./scripts/register-from-json.sh
```

Remember: Throughput is still bounded by `concurrent`.

---

## 13. **Updating & Uninstalling**

**Update the runner package:**

```bash
sudo ./scripts/update.sh
```

**Uninstall everything (runner + optional Admin UI):**

```bash
sudo ./scripts/uninstall.sh
```

---

## 14. **Troubleshooting**

**Jobs stuck in “pending”**

- Make sure job tags match the runner’s tags:
  - In `.gitlab-ci.yml`:
    ```yaml
    default:
      tags: [shared, shell, debian13]
    ```
- Verify the runner is **online** in GitLab → Project/Group → **Settings → CI/CD → Runners**.
- Check service:
  ```bash
  sudo systemctl status gitlab-runner
  ```

**Runner service won’t start**

- Review logs:
  ```bash
  journalctl -u gitlab-runner -e
  ```
- Re-apply systemd hardening (in case the drop-in is missing):
  ```bash
  sudo ./scripts/harden-systemd.sh
  ```

**Admin UI unreachable (when enabled)**

- Confirm it’s running:
  ```bash
  sudo systemctl status runner-admin
  ```
- Confirm firewall rule:
  ```bash
  sudo ufw status
  ```
- Confirm `.env` has correct `PORT` and host binding:
  ```bash
  sudo nano /opt/debian-secure-gitlab-runner/admin-server/.env
  sudo systemctl restart runner-admin
  ```

**Pipelines can’t find a runner**

- Ensure you used the **correct registration token** (group vs project).
- If public repos: consider project-level runner; ensure `locked=true`.

---

## 15. **Frequently Asked Questions**

**Q: Can someone fork my public repo and use my runner?**  
**A:** If the runner is group-scoped and the fork can submit pipelines that match your tags, yes. Use **project-level runners**, keep `run_untagged=false`, and consider disabling pipelines for forks in project settings.

**Q: How many `concurrent` should I use on a 6-core / 32 GB machine?**  
**A:** Start at **5**. If jobs are heavy (C/C++, large builds), try **3–4**. If they’re light (lint, tests), try **6**.

**Q: Can I run Docker jobs?**  
**A:** This setup uses the **shell executor**. Docker is possible but requires additional hardening (namespaces, cgroups, avoiding giving jobs Docker daemon privileges). Consider a separate, dedicated Docker runner.

**Q: Can I manage multiple runners on one host?**  
**A:** Yes—add multiple entries under `runners[]` in `config.json`. They’ll share the same `concurrent` pool.

---

## 16. **Future Improvements**

- Optional Docker executor path with strong isolation guidance.
- TLS termination or mTLS for the Admin UI (when enabled).
- cgroup v2 CPU/RAM limits per job wrapper.
- Ansible playbook / Terraform module for fleet rollout.
- Metrics integration (Prometheus node_exporter, runner exporter).

---

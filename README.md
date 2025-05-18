# OpenShift User & Identity Cleanup Tool

A **safe, modular, cross-platform bash utility** for managing and cleaning up OpenShift users and identities associated with an LDAP provider.

Supports:
- LDAP provider-based user and identity cleanup
- Bulk scanning and deletion of OpenShift identities and users
- Exclusion of specific users from deletion (via file)
- Dry-run mode for safe verification
- Auto-confirmation support for non-interactive usage
- Debug and quiet operation modes
- Configurable retry mechanisms for improved reliability
- Cross-platform compatibility (Linux & macOS, Bash 3.2+)

---

## 📂 Folder Structure

```bash
oc_user_cleanup/
├── scripts/
│   └── clean-ocp-users.sh    # Main cleanup script
├── config/
│   └── excluded_users.txt    # Optional exclusion file (one user ID per line)
├── reports/
│   ├── users.csv            # Generated scan results
│   └── cleanup.log          # Operation logs
└── README.md               # This file
```
---

## ✅ Usage Scenarios

### Basic Cleanup with Default Provider

```bash
./scripts/clean-ocp-users.sh
```

### Dry Run Mode (simulate deletions)

```bash
./scripts/clean-ocp-users.sh --dry-run
```

### Specify Custom LDAP Provider

```bash
./scripts/clean-ocp-users.sh --provider custom_ldap_prefix
```

### Use Exclusion File

```bash
./scripts/clean-ocp-users.sh --exclude-file ./config/excluded_users.txt
```

### Non-Interactive Mode (auto-confirm)

```bash
./scripts/clean-ocp-users.sh --yes
```

### Custom CSV and Log Locations

```bash
./scripts/clean-ocp-users.sh --csv ./custom/path/users.csv --log ./custom/path/cleanup.log
```
---

## 🛡 Safety Features

* Dry-run mode to preview changes (`--dry-run`)
* Confirmation prompt before deletions (unless `--yes` specified)
* Optional exclusion file support (`--exclude-file`)
* Detailed logging of all operations
* Configurable retry mechanisms for reliability
* CSV report generation for audit purposes
* Debug mode for detailed operation tracking
---

## 📄 Exclusion File Example (`excluded_users.txt`)

```
pj61323
pj42928
pj50000
```

Location:
```
./config/excluded_users.txt
```

---

## 💻 Platform Compatibility

### System Requirements

* Bash 3.2+ (macOS default bash supported)
* OpenShift CLI (`oc`)
* `jq` (JSON processor)

### Tested Platforms

* ✅ Linux (Ubuntu, RHEL, etc.)
* ✅ macOS (Intel & ARM)
  * Works with default Bash 3.2
  * Optional: Install newer Bash via Homebrew:
    ```bash
    brew install bash
    ```
---

## ⚠ Advanced Options

| Option | Description | Default |
| ------ | ----------- | ------- |
| `--provider PREFIX` | LDAP provider prefix | pnc_rnd_oim |
| `--exclude-file FILE` | File containing users to exclude | |
| `--dry-run` | Show what would be deleted without changes | false |
| `--csv FILE` | CSV file location | ./reports/users.csv |
| `--log FILE` | Log file location | ./reports/cleanup.log |
| `--quiet` | Suppress console output | false |
| `--debug` | Enable debug output | false |
| `--yes`, `-y` | Auto-confirm deletions | false |
| `--max-retries N` | Number of retries for failed operations | 3 |
| `--retry-delay N` | Delay between retries in seconds | 5 |
| `--help`, `-h` | Show help message | |

---

## ⚠ Important Notes

* Always run with `--dry-run` first to preview changes
* Keep your exclusion list up-to-date
* Use `--debug` for troubleshooting
* Consider using `--yes` only in automated environments
* Monitor the generated CSV and log files for audit purposes

---

## 📜 License

MIT (Customize per your organization's standards)


# ocp-user-cleanup

# OpenShift User & Identity Cleanup Tool

A **safe, modular, cross-platform bash utility** for managing and cleaning up OpenShift users and identities associated with an LDAP provider.

## 🛠 Makefile Options

This project includes a Makefile to simplify common operations. Using the Makefile provides consistent command execution with predefined options and ensures proper file paths.

### Common Makefile Targets

| Target | Description |
| ------ | ----------- |
| `make scan` | Find users and create CSV report (no deletions) |
| `make process` | Delete users from existing CSV report |
| `make dry-run` | Preview deletions (creates CSV if missing) |
| `make full` | Scan and delete in one step |
| `make test-gen` | Generate test users for testing |
| `make test-clean` | Remove test users |
| `make clean` | Remove generated CSV and log files |
| `make help` | Show available commands and options |

### Usage Examples

**Scan for users without making changes:**
```bash
make scan
```

**Perform a dry run to preview changes:**
```bash
make dry-run
```

**Process users from an existing scan:**
```bash
make process
```

**Generate test users for testing:**
```bash
make test-gen TEST_COUNT=50 TEST_PREFIX=qa-user
```

**Remove test users:**
```bash
make test-clean
```

### Customizable Variables

You can override default variables:

```bash
# Custom CSV location
make scan CSV_FILE=./custom/path/users.csv

# Custom exclude file
make process EXCLUDE_FILE=./custom/path/excluded_users.txt

# Generate specific number of test users
make test-gen TEST_COUNT=100

# Custom test user prefix
make test-gen TEST_PREFIX=qa-user
```

---

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
abc31323
cde72928
juk78000
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
| `--provider PREFIX` | LDAP provider prefix | ceo_rnd_oim |
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

Copyright (c) 2025 ephico2real2 

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

**Attribution Requirement:**
1. The above copyright notice and this permission notice shall be included in all
   copies or substantial portions of the Software.
2. Any project using this Software or its substantial portions must include visible
   attribution to the original project (https://github.com/ephico2real2/ocp-user-cleanup)
   in documentation, user interfaces, or other appropriate locations.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

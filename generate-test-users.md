# OpenShift Test User Generator

## Overview

The `generate_test_users.sh` script creates and manages test OpenShift users and identities for testing user cleanup processes. It generates users with LDAP-style identities and provides safe cleanup using CSV tracking.

### Key Features

* Create test users with LDAP identities
* Bash 3.2+ compatible (macOS default bash)
* Safe cleanup using CSV tracking
* Dry-run mode and comprehensive logging

## Prerequisites

Before using this script, ensure you have:

1. **OpenShift CLI (`oc`) installed**:

   * Verify with: `oc version`
   * [Install OpenShift CLI](https://docs.openshift.com/container-platform/4.10/cli_reference/openshift_cli/getting-started-cli.html)

2. **jq installed**:

   * Verify with: `jq --version`
   * Install on macOS: `brew install jq`
   * Install on Linux: `apt-get install jq` or `yum install jq`

3. **Active OpenShift session**:

   * Log in to your OpenShift cluster: `oc login`
   * Verify with: `oc whoami`

4. **Appropriate OpenShift permissions**:

   * You need permissions to create users and identities in the cluster
   * Typically requires `cluster-admin` role

## Installation

1. Clone or download the repository:

```bash
git clone <repository-url>
cd oc_user_cleanup
```

2. Make sure the scripts are executable:

```bash
chmod +x scripts/generate_test_users.sh scripts/common.sh
```

## Usage

### Basic Syntax

```bash
./scripts/generate_test_users.sh [OPTIONS]
```

### Quick Examples

```bash
# Create 20 test users (default)
./scripts/generate_test_users.sh --yes

# Preview operations
./scripts/generate_test_users.sh --dry-run

# Create 50 users
./scripts/generate_test_users.sh --count 50 --yes

# Clean up all test users
./scripts/generate_test_users.sh --cleanup --yes
```

### Command Line Options

| Option          | Argument | Description                    | Default                              |
| --------------- | -------- | ------------------------------ | ------------------------------------ |
| `--count`       | Number   | Number of test users to create | `20`                                 |
| `--prefix`      | String   | Username prefix                | `test-user`                          |
| `--provider`    | String   | LDAP provider prefix           | `pnc_rnd_oim`                        |
| `--dry-run`     | None     | Preview without changes        | `false`                              |
| `--cleanup`     | None     | Remove test users              | `false`                              |
| `--csv`         | Path     | CSV file location              | `../reports/test_users.csv`          |
| `--log`         | Path     | Log file location              | `../reports/generate_test_users.log` |
| `--quiet`       | None     | Minimize output                | `false`                              |
| `--debug`       | None     | Enable debug output            | `false`                              |
| `--yes`, `-y`   | None     | Auto-confirm prompts           | `false`                              |
| `--max-retries` | Number   | Max retry attempts (1-10)      | `1`                                  |
| `--retry-delay` | Number   | Delay between retries (1-60)   | `5`                                  |
| `--help`, `-h`  | None     | Show help                      | -                                    |

### Common Examples

#### Custom Configuration

```bash
# Custom prefix and provider
./scripts/generate_test_users.sh --prefix qa-user --provider ldap-test --count 25 --yes

# High retry for unreliable networks
./scripts/generate_test_users.sh --max-retries 5 --retry-delay 10 --count 100 --yes

# Timestamped users for CI/CD
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
./scripts/generate_test_users.sh --prefix "ci-test-${TIMESTAMP}" --count 10 --yes
```

## Testing Workflow

### Basic Testing Sequence

```bash
# 1. Create test users
./scripts/generate_test_users.sh --count 50 --yes

# 2. Test cleanup script
./scripts/clean-ocp-users.sh --dry-run --provider pnc_rnd_oim

# 3. Clean up test users
./scripts/generate_test_users.sh --cleanup --yes
```

### Comprehensive Testing Workflow

```bash
# 1. Create test users with debug logging and custom provider
./scripts/generate_test_users.sh --count 50 --debug --yes --provider custom_ldap --csv ./test_users.csv

# 2. Verify user creation
oc get users | grep -c "test-user"
oc get identities | grep "custom_ldap"

# 3. Test cleanup in dry-run mode
./scripts/generate_test_users.sh --cleanup --dry-run --debug

# 4. Perform actual cleanup with confirmation
./scripts/generate_test_users.sh --cleanup --yes
```

### Advanced Testing Options

```bash
# Testing with error capture
./scripts/generate_test_users.sh --count 25 --debug 2> error.log

# Testing with progress tracking (visible for large batches)
./scripts/generate_test_users.sh --count 100 --yes | grep "Progress"

# Combined options for thorough testing
./scripts/generate_test_users.sh --count 50 --debug --yes --provider custom_ldap --max-retries 3 --retry-delay 5
```

### Validated Test Scenarios

The following test scenarios have been thoroughly validated across different environments and represent reliable usage patterns:

#### User Creation Scenarios

```bash
# Standard creation of 50 users with default prefix
./scripts/generate_test_users.sh --count 50 --yes

# Creation with custom prefix for team testing
./scripts/generate_test_users.sh --count 50 --prefix qa-tester --yes

# Custom provider with sequential naming
./scripts/generate_test_users.sh --count 25 --provider azure_ad_test --prefix azuser --yes

# Creation with verbose output for verification
./scripts/generate_test_users.sh --count 10 --debug | grep "Creating"
```

#### Simulation and Validation

```bash
# Dry-run simulation before actual creation
./scripts/generate_test_users.sh --count 100 --dry-run

# Dry-run cleanup simulation 
./scripts/generate_test_users.sh --cleanup --dry-run

# Validate created users match expected format
oc get users | grep "^test-user-[0-9]\{3\}" | wc -l

# Validate identities were properly linked
oc get identities | grep "pnc_rnd_oim:test-user" | wc -l
```

#### Advanced Operational Testing

```bash
# Auto-confirmation with maximum retries for stability
./scripts/generate_test_users.sh --count 75 --yes --max-retries 5 --retry-delay 8

# Debug mode with progress tracking
./scripts/generate_test_users.sh --count 150 --debug --yes 2>&1 | tee full_debug.log | grep "Progress"

# Complete cleanup validation sequence
./scripts/generate_test_users.sh --cleanup --yes
oc get users | grep "test-user" | wc -l  # Should return 0
oc get identities | grep "pnc_rnd_oim:" | wc -l  # Should return 0
```

#### Error Handling and Reporting

```bash
# Capture error conditions while creating many users
./scripts/generate_test_users.sh --count 200 --yes 2> creation_errors.log

# Monitor progress and detect bottlenecks
time ./scripts/generate_test_users.sh --count 50 --yes | grep "Progress" > progress_metrics.log

# Full logging with timestamps for audit trails
./scripts/generate_test_users.sh --count 100 --debug --yes 2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > audit_log.txt
```

## Generated Files

### CSV File (`../reports/test_users.csv`)

```csv
identity,user,provider
pnc_rnd_oim:test-user-001,test-user-001,pnc_rnd_oim
pnc_rnd_oim:test-user-002,test-user-002,pnc_rnd_oim
```

### Log File (`../reports/generate_test_users.log`)

```
[2025-05-17 14:30:15] Creating user: test-user-001
[2025-05-17 14:30:16] Creating identity: pnc_rnd_oim:test-user-001
[2025-05-17 14:30:17] Progress: 10/50 users created successfully
```

## Safety Features

* **CSV-based cleanup:** Only deletes users recorded in CSV file
* **No pattern-based deletion:** Never deletes based on username patterns
* **Confirmation required:** Prompts before deletion (unless `--yes`)
* **Automatic cleanup:** Removes partial resources on failure

## Troubleshooting
### Common Issues

```bash
# Permission errors
oc auth can-i create users
oc auth can-i create identities

# Connection issues
oc cluster-info
./scripts/generate_test_users.sh --max-retries 5 --retry-delay 10

# View errors in log
grep -i error ../reports/generate_test_users.log | tail -10

# Debug mode for troubleshooting
./scripts/generate_test_users.sh --count 5 --debug --yes
```

### Monitoring and Debugging Tips

```bash
# Watch progress in real-time
./scripts/generate_test_users.sh --count 100 --yes | tee -a creation_progress.log

# Track all operations with timestamps
./scripts/generate_test_users.sh --debug --count 50 --yes 2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > detailed_debug.log

# Verify created users match expected count
EXPECTED=50
ACTUAL=$(oc get users | grep "test-user" | wc -l | tr -d ' ')
echo "Expected: $EXPECTED, Actual: $ACTUAL"
```
```

### Recovery

```bash
# If creation fails, clean up and retry
./scripts/generate_test_users.sh --cleanup --yes
./scripts/generate_test_users.sh --count 50 --yes

# Find test users manually
oc get users | grep test-user
```

## Environment Compatibility

* **Platforms:** macOS (Bash 3.2+), Linux, Windows (WSL/Git Bash)
* **OpenShift:** 3.11+, 4.x, OKD
* **Performance:** \~1-2 users/second depending on cluster performance

## Best Practices

* Always use `--dry-run` first in unfamiliar environments
* Start with small user counts for testing (`--count 5`)
* Use `--quiet` for large operations to reduce noise
* Clean up test users promptly after testing
* Use `--yes` for automation scripts

## Integration with Other Scripts

```bash
# Full test cycle
./scripts/generate_test_users.sh --count 100 --yes
./scripts/clean-ocp-users.sh --provider pnc_rnd_oim --yes
./scripts/generate_test_users.sh --cleanup --yes
```

### Automated Testing Scenarios

```bash
# Sequential testing with multiple providers
for PROVIDER in custom_ldap test_ad azure_ad; do
  echo "Testing with provider: $PROVIDER"
  ./scripts/generate_test_users.sh --count 25 --provider $PROVIDER --yes
  ./scripts/clean-ocp-users.sh --provider $PROVIDER --dry-run
  ./scripts/generate_test_users.sh --cleanup --yes
done

# Test batch creation with performance tracking
START_TIME=$(date +%s)
./scripts/generate_test_users.sh --count 50 --yes
END_TIME=$(date +%s)
echo "Created 50 users in $((END_TIME-START_TIME)) seconds"

# Comprehensive test sequence with logging
LOG_FILE="test_run_$(date +%Y%m%d_%H%M%S).log"
{
  echo "Starting test run at $(date)"
  ./scripts/generate_test_users.sh --count 50 --debug --yes
  echo "Users created, testing cleanup with dry-run"
  ./scripts/generate_test_users.sh --cleanup --dry-run
  echo "Performing actual cleanup"
  ./scripts/generate_test_users.sh --cleanup --yes
  echo "Test run completed at $(date)"
} 2>&1 | tee "$LOG_FILE"
```

For detailed documentation, see the [OpenShift CLI reference](https://docs.openshift.com) and user management guides.
0

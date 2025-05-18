#!/bin/bash

set -euo pipefail

# Script to generate test OpenShift users and identities
# for testing the user cleanup process
# Bash 3.2+ Compatible

# Configuration (define before sourcing common.sh)
LDAP_PROVIDER_PREFIX="ceo_rnd_oim"
USER_PREFIX="test-user"
USER_COUNT=20
MAX_RETRIES=1
RETRY_DELAY=5
DRY_RUN=false
CLEANUP_MODE=false
QUIET=false
AUTO_CONFIRM=false
DEBUG=false
OS_TYPE="unknown"
# Global temp directory for cleanup operations
TEMP_DIR=""
# Set paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV_FILE="${SCRIPT_DIR}/../reports/test_users.csv"
LOG_FILE="${SCRIPT_DIR}/../reports/generate_test_users.log"

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
fi

# Define log_message function early (before sourcing common.sh)
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] $1"
    
    # Always output to console unless QUIET is set
    if [ "$QUIET" != "true" ]; then
        echo "$message"
    fi
    
    # Log to file if LOG_FILE is set
    if [ -n "${LOG_FILE:-}" ]; then
        echo "$message" >> "$LOG_FILE"
    fi
}

# Enhanced safe_confirm with AUTO_CONFIRM support
safe_confirm() {
    local message="$1"
    
    # Skip confirmation if AUTO_CONFIRM is enabled
    if [ "$AUTO_CONFIRM" = true ]; then
        log_message "Auto-confirmed: $message"
        return 0
    fi
    
    # Otherwise use the standard confirmation process
    read -p "$message (y/N): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && {
        log_message "Operation cancelled by user."
        exit 0
    }
}

# Source common functions if file exists (after defining our own functions)
if [ -f "${SCRIPT_DIR}/common.sh" ]; then
    # Check if common.sh is compatible with this bash version
    if bash -n "${SCRIPT_DIR}/common.sh" 2>/dev/null; then
        source "${SCRIPT_DIR}/common.sh"
        log_message "Loaded common functions from ${SCRIPT_DIR}/common.sh"
    else
        log_message "Warning: common.sh has syntax errors, skipping"
    fi
fi

# Enhanced retry_command with safer execution
retry_command() {
    local cmd=("$@")
    local attempt=0
    while [ $attempt -lt $MAX_RETRIES ]; do
        log_message "Executing: ${cmd[*]} (attempt $((attempt+1))/$MAX_RETRIES)"
        if "${cmd[@]}"; then
            log_message "Command succeeded: ${cmd[*]}"
            return 0
        fi
        attempt=$((attempt+1))
        if [ $attempt -lt $MAX_RETRIES ]; then
            log_message "Retrying in $RETRY_DELAY seconds: ${cmd[*]}"
            sleep $RETRY_DELAY
        fi
    done
    log_message "Failed after $MAX_RETRIES retries: ${cmd[*]}"
    return 1
}

# Run OpenShift command with timeout and retry
run_oc_cmd() {
    local cmd=("$@")
    [ "$DEBUG" = true ] && log_message "DEBUG: Running command: ${cmd[*]}"
    
    local attempt=0
    while [ $attempt -lt $MAX_RETRIES ]; do
        local output
        # Use timeout if available, otherwise run directly
        if command -v timeout >/dev/null 2>&1; then
            output=$(timeout 15 "${cmd[@]}" 2>&1) && {
                [ "$DEBUG" = true ] && log_message "DEBUG: Command succeeded: ${cmd[*]}"
                echo "$output"
                return 0
            }
        else
            output=$("${cmd[@]}" 2>&1) && {
                [ "$DEBUG" = true ] && log_message "DEBUG: Command succeeded: ${cmd[*]}"
                echo "$output"
                return 0
            }
        fi
        
        attempt=$((attempt+1))
        log_message "Command failed (attempt $attempt/$MAX_RETRIES): ${cmd[*]}"
        [ "$DEBUG" = true ] && log_message "DEBUG: Error: $output"
        
        if [ $attempt -lt $MAX_RETRIES ]; then
            log_message "Retrying in $RETRY_DELAY seconds..."
            sleep $RETRY_DELAY
        fi
    done
    
    log_message "ERROR: Command failed after $MAX_RETRIES attempts: ${cmd[*]}"
    return 1
}

# Check dependencies and OpenShift connection
check_dependencies() {
    log_message "Checking dependencies..."
    
    # Check required commands
    for cmd in oc jq; do
        if ! command -v $cmd &>/dev/null; then
            if [[ "$OS_TYPE" == "macos" ]]; then
                log_message "ERROR: '$cmd' is not installed. Install using: brew install $cmd"
            else
                log_message "ERROR: '$cmd' is not installed. Install using your package manager."
            fi
            exit 1
        fi
    done
    log_message "All required commands found"

    # Check if logged in to OpenShift
    local whoami_output
    if ! whoami_output=$(oc whoami 2>&1); then
        log_message "ERROR: Not logged in to OpenShift. Run 'oc login' first."
        log_message "Details: $whoami_output"
        exit 1
    fi
    
    log_message "Logged in as: $whoami_output"
    
    # Test API access with a simple command
    if ! oc get projects --request-timeout=5s &>/dev/null; then
        log_message "ERROR: Cannot access OpenShift API. Check network connection or token validity."
        log_message "You are logged in as '$whoami_output' but API access failed."
        exit 1
    fi
    
    # Check permissions by trying to get users
    if ! oc get users --request-timeout=5s &>/dev/null; then
        log_message "ERROR: Insufficient permissions to manage users."
        log_message "Current user '$whoami_output' cannot access User resources."
        log_message "Please login with a user that has cluster-admin privileges."
        exit 1
    fi
    
    log_message "OpenShift connection verified. Continuing..."
}

# Create necessary directories
ensure_directories() {
    # Ensure reports directory exists
    local reports_dir
    reports_dir="$(dirname "$CSV_FILE")"
    if [ ! -d "$reports_dir" ]; then
        log_message "Creating reports directory: $reports_dir"
        mkdir -p "$reports_dir" || {
            log_message "ERROR: Failed to create reports directory: $reports_dir"
            exit 1
        }
    fi

    # If logging is enabled, ensure log directory exists
    if [ -n "${LOG_FILE:-}" ]; then
        local log_dir
        log_dir="$(dirname "$LOG_FILE")"
        if [ ! -d "$log_dir" ]; then
            log_message "Creating log directory: $log_dir"
            mkdir -p "$log_dir" || {
                log_message "ERROR: Failed to create log directory: $log_dir"
                exit 1
            }
        fi
    fi
}

# Initialize CSV file
initialize_csv() {
    mkdir -p "$(dirname "$CSV_FILE")"
    echo "identity,user,provider" > "$CSV_FILE"
    log_message "CSV file initialized: $CSV_FILE"
}

# Create a single user and identity
create_user() {
    local username="$1"
    local identity="${LDAP_PROVIDER_PREFIX}:${username}"
    
    if [ "$DRY_RUN" = true ]; then
        log_message "[DRY-RUN] Would create user: $username"
        log_message "[DRY-RUN] Would create identity: $identity"
        log_message "[DRY-RUN] Would link user to identity"
    else
        log_message "Creating user: $username"
        if ! oc create user "$username" 2>/dev/null; then
            # Check if the failure was because the user already exists
            if oc get user "$username" &>/dev/null; then
                log_message "User already exists: $username - skipping"
                # Record to CSV even if user exists
                echo "$identity,$username,$LDAP_PROVIDER_PREFIX" >> "$CSV_FILE"
                return 2  # Special return code for "already exists"
            else
                log_message "ERROR: Failed to create user: $username"
                return 1
            fi
        fi
        
        log_message "Creating identity: $identity"
        if ! oc create identity "$identity" 2>/dev/null; then
            # Check if the failure was because the identity already exists
            if oc get identity "$identity" &>/dev/null; then
                log_message "Identity already exists: $identity - skipping"
            else
                # Only retry once for identity creation
                if ! retry_command oc create identity "$identity"; then
                    log_message "ERROR: Failed to create identity: $identity"
                    log_message "Cleaning up user: $username"
                    oc delete user "$username" 2>/dev/null || true
                    return 1
                fi
            fi
        fi
        
        # Link user to identity using useridentitymapping
        log_message "Creating user identity mapping: $identity -> $username"
        if ! oc get useridentitymapping "$identity" &>/dev/null; then
            if ! retry_command oc create useridentitymapping "$identity" "$username"; then
                log_message "ERROR: Failed to create user identity mapping"
                log_message "Cleaning up user and identity..."
                oc delete identity "$identity" 2>/dev/null || true
                oc delete user "$username" 2>/dev/null || true
                return 1
            fi
        else
            log_message "User identity mapping already exists - skipping"
        fi
    fi
    
    # Record to CSV
    echo "$identity,$username,$LDAP_PROVIDER_PREFIX" >> "$CSV_FILE"
    return 0
}

# Generate all test users
generate_users() {
    local success_count=0
    local failed_count=0
    local skipped_count=0
    local total_processed=0
    
    initialize_csv
    
    log_message "Generating $USER_COUNT test users with prefix '$USER_PREFIX'..."
    
    for i in $(seq -f "%03g" 1 $USER_COUNT); do
        local username="${USER_PREFIX}-${i}"
        local result=0
        
        # Create user and handle the return code
        create_user "$username" || result=$?
        
        if [ $result -eq 0 ]; then
            # User created successfully
            success_count=$((success_count+1))
            total_processed=$((total_processed+1))
            if [ $((success_count % 10)) -eq 0 ] || [ $success_count -eq $USER_COUNT ]; then
                log_message "Progress: $success_count/$USER_COUNT users created successfully"
            fi
        elif [ $result -eq 2 ]; then
            # User already exists - treat as success for exit code purposes
            skipped_count=$((skipped_count+1))
            total_processed=$((total_processed+1))
            if [ $((skipped_count % 10)) -eq 0 ]; then
                log_message "Progress: $skipped_count users skipped (already exist)"
            fi
        else
            # Real failure case
            failed_count=$((failed_count+1))
            log_message "Failed to create user: $username (error code: $result)"
        fi
    done
    
    log_message "Generation complete:"
    log_message "  Created: $success_count"
    log_message "  Skipped: $skipped_count" 
    log_message "  Failed: $failed_count"
    log_message "  Total processed: $total_processed"
    
    # Return success if we processed any users successfully or skipped existing ones
    if [ $((success_count + skipped_count)) -gt 0 ]; then
        return 0
    else
        log_message "No users were successfully processed"
        return 1
    fi
}

# Remove all generated test users
cleanup_users() {
    log_message "Starting cleanup of test users..."
    
    # If CSV doesn't exist or is empty, try to find existing test users
    if [ ! -f "$CSV_FILE" ] || [ ! -s "$CSV_FILE" ]; then
        log_message "No CSV file found, searching for existing test users..."
        # Initialize CSV
        mkdir -p "$(dirname "$CSV_FILE")"
        echo "identity,user,provider" > "$CSV_FILE"
        
        # Find all test users and add them to CSV
        local found_users=0
        while IFS= read -r username; do
            if [ -n "$username" ]; then
                log_message "Found test user: $username"
                identity="${LDAP_PROVIDER_PREFIX}:${username}"
                echo "$identity,$username,$LDAP_PROVIDER_PREFIX" >> "$CSV_FILE"
                found_users=$((found_users + 1))
            fi
        done < <(oc get users -o json | jq -r ".items[] | select(.metadata.name | startswith(\"$USER_PREFIX-\")) | .metadata.name" 2>/dev/null || true)
        
        if [ $found_users -eq 0 ]; then
            log_message "No test users found matching prefix: $USER_PREFIX"
            return 0
        fi
        
        log_message "Found $found_users existing test users"
    fi

    if [ ! -f "$CSV_FILE" ]; then
        log_message "ERROR: CSV file does not exist: $CSV_FILE"
        exit 1
    fi
    
    local total=$(( $(wc -l < "$CSV_FILE") - 1 ))
    if [ $total -eq 0 ]; then
        log_message "No test users to remove"
        return 0
    fi
    
    log_message "Preparing to remove $total test users and identities..."
    
    if [ "$DRY_RUN" = true ]; then
        log_message "[DRY-RUN] Would delete $total test users and their identities"
        while IFS=, read -r identity user provider; do
            [ -n "$user" ] && log_message "[DRY-RUN] Would delete: $user (identity: $identity)"
        done < <(tail -n +2 "$CSV_FILE")
        return 0
    fi
    
    safe_confirm "Are you sure you want to delete all $total test users?"
    
    # Create temporary files for counting
    TEMP_DIR=""
    if ! TEMP_DIR=$(mktemp -d 2>/dev/null); then
        log_message "ERROR: Failed to create temporary directory"
        exit 1
    fi
    
    local temp_success="${TEMP_DIR}/success"
    local temp_fail="${TEMP_DIR}/fail"
    touch "$temp_success" "$temp_fail"
    
    # Cleanup function for temp files
    cleanup_temp() {
        if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
            rm -rf "$TEMP_DIR"
        fi
    }
    trap cleanup_temp EXIT INT TERM
    # Process each user
    while IFS=, read -r identity user provider; do
        [ -z "$user" ] && continue
        
        local deletion_success=true
        
        # Delete the identity first
        log_message "Deleting identity: $identity"
        if ! oc delete identity "$identity" --ignore-not-found=true; then
            if oc get identity "$identity" &>/dev/null; then
                deletion_success=false
                log_message "Failed to delete identity: $identity"
            else
                log_message "Identity already deleted: $identity"
            fi
        else
            log_message "Successfully deleted identity: $identity"
        fi
        
        # Only try to delete user if identity deletion was successful
        if [ "$deletion_success" = true ]; then
            log_message "Deleting user: $user"
            if ! oc delete user "$user" --ignore-not-found=true; then
                if oc get user "$user" &>/dev/null; then
                    deletion_success=false
                    log_message "Failed to delete user: $user"
                else
                    log_message "User already deleted: $user"
                fi
            else
                log_message "Successfully deleted user: $user"
            fi
        else
            log_message "Skipping user deletion due to identity deletion failure: $user"
        fi
        
        # Record the result
        if [ "$deletion_success" = true ]; then
            echo "$user" >> "$temp_success"
            log_message "Successfully removed user and identity: $user"
        else
            echo "$user" >> "$temp_fail"
            log_message "Failed to remove user or identity: $user"
        fi
        
        # Update progress using temp files
        local success_count=$(wc -l < "$temp_success")
        local failed_count=$(wc -l < "$temp_fail")
        local processed=$((success_count + failed_count))
        
        if [ $((processed % 10)) -eq 0 ] || [ $processed -eq $total ]; then
            log_message "Progress: $processed/$total (Success: $success_count, Failed: $failed_count)"
        fi
    done < <(tail -n +2 "$CSV_FILE")
    
    # Get final counts
    local success_count=$(wc -l < "$temp_success")
    local failed_count=$(wc -l < "$temp_fail")
    
    # Show final summary with details
    log_message "Cleanup complete:"
    log_message "Successfully deleted users ($success_count):"
    if [ "$success_count" -gt 0 ]; then
        while IFS= read -r user; do
            log_message "  - $user"
        done < "$temp_success"
    fi
    
    if [ "$failed_count" -gt 0 ]; then
        log_message "Failed to delete users ($failed_count):"
        while IFS= read -r user; do
            log_message "  - $user"
        done < "$temp_fail"
    fi
    
    # Remove CSV file only if all deletions were successful
    if [ "$failed_count" -eq 0 ]; then
        rm -f "$CSV_FILE"
        log_message "All users successfully deleted, removed CSV file: $CSV_FILE"
    else
        log_message "Some deletions failed, keeping CSV file for reference: $CSV_FILE"
    fi
    
}

# Display usage information
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Generate test OpenShift users and identities for testing the cleanup process.
Compatible with Bash 3.2+ (macOS default bash).

Options:
  --count N          Number of users to create (default: 20)
  --prefix PREFIX    Username prefix (default: test-user)
  --provider PREFIX  LDAP provider prefix (default: pnc_rnd_oim)
  --dry-run         Show what would be done without making changes
  --cleanup         Remove previously generated test users
  --csv FILE        CSV file location for user records
  --log FILE        Log file location
  --quiet           Minimal output
  --debug           Enable debug output
  --yes, -y         Automatically confirm all prompts
  --max-retries N   Max retry attempts for OpenShift commands (default: 1)
  --retry-delay N   Delay between retries in seconds (default: 5)
  --help, -h        Show this help message

Examples:
  $(basename "$0") --count 50 --yes           # Create 50 test users
  $(basename "$0") --cleanup --yes            # Remove all test users
  $(basename "$0") --dry-run --count 10       # Show what would be created

EOF
    exit 0
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --count) shift; USER_COUNT="$1" ;;
        --prefix) shift; USER_PREFIX="$1" ;;
        --provider) shift; LDAP_PROVIDER_PREFIX="$1" ;;
        --dry-run) DRY_RUN=true ;;
        --cleanup) CLEANUP_MODE=true ;;
        --csv) shift; CSV_FILE="$1" ;;
        --log) shift; LOG_FILE="$1" ;;
        --quiet) QUIET=true ;;
        --debug) DEBUG=true ;;
        --yes|-y) AUTO_CONFIRM=true ;;
        --max-retries)
            shift
            if [[ ! "$1" =~ ^[0-9]+$ ]] || [ "$1" -lt 1 ] || [ "$1" -gt 10 ]; then
                log_message "ERROR: Invalid max-retries value: $1 (must be between 1 and 10)"
                exit 1
            fi
            MAX_RETRIES="$1"
            ;;
        --retry-delay)
            shift
            if [[ ! "$1" =~ ^[0-9]+$ ]] || [ "$1" -lt 1 ] || [ "$1" -gt 60 ]; then
                log_message "ERROR: Invalid retry-delay value: $1 (must be between 1 and 60)"
                exit 1
            fi
            RETRY_DELAY="$1"
            ;;
        --help|-h) show_help ;;
        *) log_message "ERROR: Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Main function
main() {
    # Initialize logging
    if [ -n "${LOG_FILE:-}" ]; then
        mkdir -p "$(dirname "$LOG_FILE")"
        > "$LOG_FILE"  # Start with empty log file
    fi
    
    log_message "Starting test user generator script"
    log_message "LDAP Provider: $LDAP_PROVIDER_PREFIX"
    log_message "User Prefix: $USER_PREFIX"
    log_message "Dry Run Mode: $DRY_RUN"
    log_message "Cleanup Mode: $CLEANUP_MODE"
    [ "$DEBUG" = true ] && log_message "Debug Mode: Enabled"
    
    check_dependencies
    ensure_directories
    
    if [ "$CLEANUP_MODE" = true ]; then
        cleanup_users
        return $?
    else
        log_message "Will create $USER_COUNT test users with prefix '$USER_PREFIX'"
        if [ "$DRY_RUN" = false ]; then
            safe_confirm "Are you sure you want to create $USER_COUNT test users?"
        fi
        generate_users
        return $?
    fi
}

################################################################################
# Function definitions above this line
# Main script execution starts here

# Execute main function and exit with appropriate status
if ! main; then
    exit 1
fi

exit 0

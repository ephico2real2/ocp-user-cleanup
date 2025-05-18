#!/bin/bash

# Common functions and variables for OpenShift cleanup scripts
# Version: 1.2.0 - Bash 3.2+ Compatible

VERSION="1.2.0"

# Default configuration - can be overridden by environment variables or main script
DEFAULT_CSV_FILE="../reports/oc_user_audit.csv"
DEFAULT_LOG_FILE="../reports/oc_user_cleanup.log"
DEFAULT_EXCLUDE_FILE="../config/excluded_users.txt"

# Only set these if they're not already defined (allows main script to override)
CSV_FILE="${CSV_FILE:-${CLEANUP_CSV_FILE:-$DEFAULT_CSV_FILE}}"
LOG_FILE="${LOG_FILE:-${CLEANUP_LOG_FILE:-$DEFAULT_LOG_FILE}}"
EXCLUDE_FILE="${EXCLUDE_FILE:-${CLEANUP_EXCLUDE_FILE:-$DEFAULT_EXCLUDE_FILE}}"

# Default timeouts and retries if not set by main script
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_DELAY="${RETRY_DELAY:-5}"
OC_TIMEOUT="${OC_TIMEOUT:-15}"

# Check if we're being sourced or executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script should be sourced, not executed directly."
    echo "Usage: source $(basename "$0")"
    exit 1
fi

# Enhanced dependency checking
check_dependencies() {
    local missing_deps=""
    
    # Check for required commands
    for cmd in oc jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps="$missing_deps $cmd"
        fi
    done
    
    # Report missing dependencies
    if [ -n "$missing_deps" ]; then
        echo "Error: Missing required dependencies:$missing_deps"
        
        # Provide installation suggestions based on OS
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "Install using Homebrew:"
            for dep in $missing_deps; do
                case $dep in
                    oc) echo "  brew install openshift-cli" ;;
                    jq) echo "  brew install jq" ;;
                    *) echo "  brew install $dep" ;;
                esac
            done
        else
            echo "Install using your package manager (apt/yum/dnf):"
            for dep in $missing_deps; do
                case $dep in
                    oc) echo "  # Download from: https://github.com/openshift/origin/releases" ;;
                    jq) echo "  sudo apt install jq  # or: sudo yum install jq" ;;
                    *) echo "  sudo apt install $dep  # or: sudo yum install $dep" ;;
                esac
            done
        fi
        exit 1
    fi
    
    # Check OpenShift connection if oc is available
    if command -v oc >/dev/null 2>&1; then
        if ! oc whoami >/dev/null 2>&1; then
            echo "Warning: Not logged in to OpenShift. Run 'oc login' first."
            return 1
        fi
    fi
    
    return 0
}

# Enhanced directory creation with proper error handling
ensure_directories() {
    local dir
    local dirs_to_create="$(dirname "$CSV_FILE") $(dirname "$LOG_FILE")"
    
    # Add exclude file directory if it doesn't exist
    if [ -n "$EXCLUDE_FILE" ]; then
        dirs_to_create="$dirs_to_create $(dirname "$EXCLUDE_FILE")"
    fi
    
    for dir in $dirs_to_create; do
        if [ ! -d "$dir" ]; then
            if ! mkdir -p "$dir" 2>/dev/null; then
                echo "Error: Failed to create directory: $dir"
                return 1
            fi
        fi
    done
    
    return 0
}

# Enhanced configuration validation
validate_config() {
    local errors=""
    
    # Check if exclude file exists (only if specified)
    if [ -n "$EXCLUDE_FILE" ] && [ ! -f "$EXCLUDE_FILE" ]; then
        # Try to create it with some default content
        if ! ensure_directories; then
            errors="$errors\n  - Cannot create directory for exclude file: $EXCLUDE_FILE"
        else
            cat > "$EXCLUDE_FILE" << 'EOF'
# Excluded users file
# Add usernames (one per line) that should NOT be deleted
# Lines starting with # are comments and will be ignored
# Empty lines are also ignored
# Whitespace around usernames will be trimmed

# Example:
# admin-user
# service-account-user
# system:admin
EOF
            echo "Created default exclude file: $EXCLUDE_FILE"
            echo "Please edit this file to add users you want to protect"
        fi
    fi
    
    # Ensure output directories exist
    if ! ensure_directories; then
        errors="$errors\n  - Failed to create required directories"
    fi
    
    # Check write permissions for CSV and log files
    for file in "$CSV_FILE" "$LOG_FILE"; do
        local dir=$(dirname "$file")
        if [ ! -w "$dir" ]; then
            errors="$errors\n  - No write permission for directory: $dir"
        fi
    done
    
    # Report any errors
    if [ -n "$errors" ]; then
        echo "Configuration validation errors:"
        echo -e "$errors"
        return 1
    fi
    
    return 0
}

# Enhanced logging with better timestamp handling
# Note: This version won't conflict with main script's log_message if defined first
common_log_message() {
    local message="$1"
    local timestamp
    
    # Use different timestamp format for better readability
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Only output to console if QUIET is not set
    if [ "${QUIET:-false}" != "true" ]; then
        echo "[$timestamp] $message"
    fi
    
    # Log to file if LOG_FILE is set and accessible
    if [ -n "${LOG_FILE:-}" ]; then
        # Ensure log directory exists
        local log_dir=$(dirname "$LOG_FILE")
        [ ! -d "$log_dir" ] && mkdir -p "$log_dir"
        
        # Append to log file
        echo "[$timestamp] $message" >> "$LOG_FILE" 2>/dev/null || {
            echo "Warning: Cannot write to log file: $LOG_FILE" >&2
        }
    fi
}

# Basic confirmation function (can be overridden by main script)
# This version doesn't include AUTO_CONFIRM to avoid conflicts
basic_safe_confirm() {
    local message="$1"
    
    read -p "$message (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        common_log_message "Operation cancelled by user."
        exit 0
    fi
}

# Utility function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Utility function to validate OpenShift connection
check_oc_connection() {
    local timeout_val="${1:-10}"
    
    if ! command_exists oc; then
        echo "Error: oc command not found"
        return 1
    fi
    
    # Check if logged in (with timeout if available)
    if command_exists timeout; then
        if ! timeout "$timeout_val" oc whoami >/dev/null 2>&1; then
            echo "Error: Not logged in to OpenShift or connection failed"
            echo "Run 'oc login' to authenticate"
            return 1
        fi
    else
        if ! oc whoami >/dev/null 2>&1; then
            echo "Error: Not logged in to OpenShift or connection failed"
            echo "Run 'oc login' to authenticate"
            return 1
        fi
    fi
    
    # Check basic permissions (with timeout if available)
    if command_exists timeout; then
        if ! timeout "$timeout_val" oc get users --request-timeout=5s >/dev/null 2>&1; then
            echo "Warning: Cannot access user resources. Check permissions."
            return 1
        fi
    else
        if ! oc get users --request-timeout=5s >/dev/null 2>&1; then
            echo "Warning: Cannot access user resources. Check permissions."
            return 1
        fi
    fi
    
    return 0
}

# Function to backup existing files before operations
backup_file() {
    local file="$1"
    local backup_suffix="${2:-.backup.$(date +%Y%m%d_%H%M%S)}"
    
    if [ -f "$file" ]; then
        local backup_file="${file}${backup_suffix}"
        if cp "$file" "$backup_file" 2>/dev/null; then
            echo "Backed up $file to $backup_file"
            return 0
        else
            echo "Warning: Could not backup $file"
            return 1
        fi
    fi
    return 0
}

# Function to get script directory reliably (bash 3.2 compatible)
get_script_dir() {
    local source="${BASH_SOURCE[1]}"
    while [ -h "$source" ]; do
        local dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        # Handle relative symlinks
        case "$source" in
            /*) ;;
            *) source="$dir/$source" ;;
        esac
    done
    echo "$(cd -P "$(dirname "$source")" && pwd)"
}

# Utility function to trim whitespace (bash 3.2 compatible)
trim_whitespace() {
    local text="$1"
    # Remove leading whitespace
    text="${text#"${text%%[![:space:]]*}"}"
    # Remove trailing whitespace
    text="${text%"${text##*[![:space:]]}"}"
    echo "$text"
}

# Utility function to check if a user is excluded (bash 3.2 compatible)
# Usage: is_user_excluded "username" "exclude_file"
is_user_excluded() {
    local username="$1"
    local exclude_file="${2:-$EXCLUDE_FILE}"
    
    [ -z "$username" ] && return 1
    [ ! -f "$exclude_file" ] && return 1
    
    # Process exclude file line by line and check for exact match
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
            # Trim whitespace and compare
            line=$(trim_whitespace "$line")
            if [ "$line" = "$username" ]; then
                return 0
            fi
        fi
    done < "$exclude_file"
    
    return 1
}

# Set default aliases (can be overridden)
# Only set these if they don't already exist
if ! command -v log_message >/dev/null 2>&1; then
    alias log_message=common_log_message
fi

if ! command -v safe_confirm >/dev/null 2>&1; then
    alias safe_confirm=basic_safe_confirm
fi

# Print version info when sourced (if not in quiet mode)
if [ "${QUIET:-false}" != "true" ]; then
    echo "Loaded common functions (version $VERSION) - Bash 3.2+ compatible"
fi

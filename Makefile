# OpenShift User Cleanup Makefile
SCRIPT = ./scripts/clean-ocp-users.sh
TEST_SCRIPT = ./scripts/generate_test_users.sh
EXCLUDE_FILE = ./config/excluded_users.txt
CSV_FILE = ./reports/oc_user_audit.csv
LOG_FILE = ./reports/oc_user_cleanup.log

# Test user configuration
TEST_COUNT = 20
TEST_PREFIX = test-user

# Default target
.DEFAULT_GOAL := help

# Create directories if they don't exist
$(shell mkdir -p ./config ./reports)

# Ensure exclude file exists with default content
$(EXCLUDE_FILE):
	@echo "Creating default exclude file: $(EXCLUDE_FILE)"
	@echo "# Add usernames to exclude (one per line)" > $(EXCLUDE_FILE)
	@echo "# Lines starting with # are comments" >> $(EXCLUDE_FILE)
	@echo "system:admin" >> $(EXCLUDE_FILE)
	@echo "admin" >> $(EXCLUDE_FILE)
	@echo "kubeadmin" >> $(EXCLUDE_FILE)
	@echo "developer" >> $(EXCLUDE_FILE)

.PHONY: scan process dry-run full help test-gen test-clean clean

# Main operations
scan: | $(EXCLUDE_FILE)
	$(SCRIPT) --dry-run --csv $(CSV_FILE) --exclude-file $(EXCLUDE_FILE) --log $(LOG_FILE)

process: | $(EXCLUDE_FILE)
	@if [ ! -f "$(CSV_FILE)" ]; then \
		echo "Error: CSV file $(CSV_FILE) not found. Run 'make scan' first."; \
		exit 1; \
	fi
	$(SCRIPT) --csv $(CSV_FILE) --exclude-file $(EXCLUDE_FILE) --log $(LOG_FILE)

dry-run: | $(EXCLUDE_FILE)
	@if [ ! -f "$(CSV_FILE)" ]; then \
		echo "Warning: CSV file $(CSV_FILE) not found. Running scan instead."; \
		$(MAKE) scan; \
	else \
		$(SCRIPT) --dry-run --csv "$(CSV_FILE)" --exclude-file "$(EXCLUDE_FILE)" --log "$(LOG_FILE)"; \
	fi

full: | $(EXCLUDE_FILE)
	$(SCRIPT) --exclude-file $(EXCLUDE_FILE) --log $(LOG_FILE)

# Test user operations
test-gen:
	$(TEST_SCRIPT) --count $(TEST_COUNT) --prefix $(TEST_PREFIX) --yes

test-clean:
	$(TEST_SCRIPT) --cleanup --yes

# Utility targets
clean:
	@echo "Removing generated files..."
	rm -f $(CSV_FILE) $(LOG_FILE)
	@echo "Note: Exclude file $(EXCLUDE_FILE) preserved"

help:
	@echo "OpenShift User Cleanup Makefile"
	@echo ""
	@echo "Usage: make TARGET [ARGS]"
	@echo ""
	@echo "Main targets:"
	@echo "  scan      - Find users and create CSV (no deletions)"
	@echo "  process   - Delete users from existing CSV"
	@echo "  dry-run   - Preview deletions (creates CSV if missing)"
	@echo "  full      - Scan and delete in one step"
	@echo ""
	@echo "Test targets:"
	@echo "  test-gen  - Generate test users for testing"
	@echo "  test-clean - Remove test users"
	@echo ""
	@echo "Utility targets:"
	@echo "  clean     - Remove generated CSV and log files"
	@echo "  help      - Show this help message"
	@echo ""
	@echo "Override variables:"
	@echo "  make scan CSV_FILE=custom.csv"
	@echo "  make process EXCLUDE_FILE=custom_exclude.txt"
	@echo "  make test-gen TEST_COUNT=50"
	@echo "  make test-gen TEST_PREFIX=qa-user TEST_COUNT=100"

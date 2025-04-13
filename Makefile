# Makefile for S2 compression

# Directories and files
SAMPLES_DIR = .samples_temp
TEST_FILES = vendor/github.com/klauspost/compress/s2/encode_all.go main.go
WORK_DIR = .work_temp
DICT_FILE = $(WORK_DIR)/dictionary.s2dict

# Utility paths
BUILDDICT = builddict
S2CP = go run main.go

# Define compression test function
define run_compression_test
	ORIG_SIZE=$$(wc -c < $(1)) && \
	cat $(1) | $(S2CP) $(2) > $(WORK_DIR)/$$(basename $(1)).$(3).s2 && \
	COMP_SIZE=$$(wc -c < $(WORK_DIR)/$$(basename $(1)).$(3).s2) && \
	SAVED=$$(expr $$ORIG_SIZE - $$COMP_SIZE) && \
	RATIO=$$(expr 100 - \( $$COMP_SIZE \* 100 / $$ORIG_SIZE \) ) && \
	printf "%-20s | %14d | %13d | %11d | %5d%%\n" "$(4)" $$COMP_SIZE $$ORIG_SIZE $$SAVED $$RATIO
endef

# All steps
all: test_compression verify_compression test_dict_errors
	@echo ""
	@echo "=== All tests completed successfully ==="

# Install builddict if not present
install_builddict:
	go install github.com/klauspost/compress/dict/cmd/builddict@latest

# Create working directory and vendor dependencies
prepare:
	@echo "=== Preparing workspace ==="
	@mkdir -p $(WORK_DIR)
	@mkdir -p $(SAMPLES_DIR)
	@go mod vendor
	@find vendor -name "*.go" -exec cp {} $(SAMPLES_DIR)/ \;

# Create dictionary
build_dict: install_builddict prepare
	@echo "=== Building Dictionary ==="
	@echo "Sample files info:"
	@echo "Total files: $$(find $(SAMPLES_DIR) -type f | wc -l)"
	@echo "Total size: $$(find $(SAMPLES_DIR) -type f -exec wc -c {} \; | awk '{total += $$1} END {print total}') bytes"
	$(BUILDDICT) -format s2 -len 65536 -o $(DICT_FILE) $(SAMPLES_DIR)
	@echo "Dictionary created: $(DICT_FILE)"

# Test all compression methods
test_compression: build_dict
	@echo "=== Starting compression tests ==="
	@for file in $(TEST_FILES); do \
		echo "\nTesting file: $$file"; \
		echo "Compression Results:"; \
		echo "==="; \
		echo "Method                 | Compressed Size | Original Size | Saved Space | Ratio"; \
		echo "---------------------|----------------|---------------|-------------|-------"; \
		$(call run_compression_test,$$file,-c,default,Default) && \
		$(call run_compression_test,$$file,-c -faster,faster,Faster) && \
		$(call run_compression_test,$$file,-c -slower,slower,Slower) && \
		$(call run_compression_test,$$file,-c -dict $(DICT_FILE),default_dict,Default+Dict) && \
		$(call run_compression_test,$$file,-c -faster -dict $(DICT_FILE),faster_dict,Faster+Dict) && \
		$(call run_compression_test,$$file,-c -slower -dict $(DICT_FILE),slower_dict,Slower+Dict) && \
		echo "==="; \
	done

# Verify compression/decompression correctness
verify_compression:
	@echo ""
	@echo "=== Verifying correct compression/decompression ==="
	@for file in $(TEST_FILES); do \
		echo "Verifying file: $$file"; \
		for METHOD in default faster slower; do \
			cat $(WORK_DIR)/$$(basename $$file).$$METHOD.s2 | $(S2CP) -d > $(WORK_DIR)/$$(basename $$file).$$METHOD.decoded; \
			diff $$file $(WORK_DIR)/$$(basename $$file).$$METHOD.decoded > /dev/null && \
			echo "$$METHOD: OK" || echo "$$METHOD: FAILED"; \
			\
			cat $(WORK_DIR)/$$(basename $$file).$${METHOD}_dict.s2 | $(S2CP) -d -dict $(DICT_FILE) > $(WORK_DIR)/$$(basename $$file).$${METHOD}_dict.decoded; \
			diff $$file $(WORK_DIR)/$$(basename $$file).$${METHOD}_dict.decoded > /dev/null && \
			echo "$$METHOD+Dict: OK" || echo "$$METHOD+Dict: FAILED"; \
		done; \
	done

# Test dictionary error cases
test_dict_errors:
	@echo ""
	@echo "=== Testing dictionary error cases ==="
	@echo "Testing without required dictionary:"
	@if cat $(WORK_DIR)/$$(basename $(firstword $(TEST_FILES))).default_dict.s2 | $(S2CP) -d > $(WORK_DIR)/no_dict.decoded 2>/dev/null; then \
		echo "ERROR: Decompression should fail without required dictionary"; \
		exit 1; \
	else \
		echo "OK: Decompression failed as expected without dictionary"; \
	fi

# Cleanup
clean:
	@echo ""
	@echo "=== Cleanup ==="
	rm -rf $(WORK_DIR) $(SAMPLES_DIR)

.PHONY: all prepare build_dict test_compression verify_compression test_dict_errors clean

HEADERS=$(patsubst %.csv,%.vh,$(SOURCES))
UNDEF_FILE=$(COMPONENTS_DIR)/global_undef.vh

.phony: all
all: conflict_check headers undefines_file

.phony: conflict_check
conflict_check: $(SOURCES)
	@echo Checking for macro conflicts...
	@perl -e '$$err=`$(DEFPARSER) $(SOURCES) 2>&1 1>/dev/null`; print $$err; exit(1) if $$err ne "";'

.phony: headers
headers: $(HEADERS)
%.vh: %.csv
	@echo Parsing $^...
	@$(DEFPARSER) -o $@ $^

.phony: undef undefines_file
undef: undefines_file
undefines_file: $(UNDEF_FILE)
$(UNDEF_FILE): $(SOURCES)
	@echo Generating global undefines file...
	@echo 'DEBUG,0' | $(DEFPARSER) -o $(UNDEF_FILE) -u $(SOURCES) -

.phony: clean
clean:
	rm -f $(HEADERS)
	rm -f $(UNDEF_FILE)
HEADER_FILES=$(patsubst %.csv,%.vh,$(SOURCES))
SOURCE_FILES=$(patsubst %.s,%.v,$(VERILOG_SOURCES))

.phony: all
all: conflict_check headers sources undefines_file

.phony: conflict_check
conflict_check: $(SOURCES)
	@echo Checking for macro conflicts...
	@perl -e '$$err=`$(DEFPARSER) $(SOURCES) 2>&1 1>/dev/null`; print $$err; exit(1) if $$err ne "";'

.phony: headers
headers: $(HEADER_FILES)
%.vh: %.csv
	@echo Parsing $^...
	@$(DEFPARSER) -o $@ $^

.phony: sources
sources: $(SOURCE_FILES)
%.v: %.s
	@echo Parsing $^...
	@$(PREPROCESSOR) -o $@ $^

.phony: undef undefines_file
undef: undefines_file
undefines_file: $(UNDEF_FILE)
$(UNDEF_FILE): $(SOURCES)
	@echo Generating global undefines file...
	@echo 'DEBUG,0' | $(DEFPARSER) -o $(UNDEF_FILE) -u $(SOURCES) -

.phony: clean
clean:
	@echo Removing header files...
	@rm -f $(HEADER_FILES)
	@echo Removing source files...
	@rm -f $(SOURCE_FILES)
	@echo Removing undefines file...
	@rm -f $(UNDEF_FILE)
#	@for h in $(HEADER_FILES) $(SOURCE_FILES) $(UNDEF_FILE); do \
	echo Removing $$h...; \
	rm -f $$h; \
	done
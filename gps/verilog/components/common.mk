-include local.mk

REPO_DIR?=../..
VERILOG_DIR?=$(REPO_DIR)/verilog
COMPONENTS_DIR?=$(VERILOG_DIR)/components
DEFPARSER?=defparser

SOURCES+=$(COMPONENTS_DIR)/global.csv

.phony: all
all: conflict_check headers

.phony: conflict_check
conflict_check: $(SOURCES)
	@echo Checking for macro conflicts...
	@perl -e '$$err=`$(DEFPARSER) $(SOURCES) 2>&1 1>/dev/null`; print $$err; exit(1) if $$err ne "";'

.phony: headers
headers: $(SOURCES)
	@for s in $(SOURCES); do \
	echo Parsing $${s}...; \
	$(DEFPARSER) -o `perl -e 'print "$$1.vh" if "'$${s}.'"=~/(.*)\.[^.]+/;'` $${s}; \
	done
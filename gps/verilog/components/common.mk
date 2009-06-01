-include local.mk

REPO_DIR?=../..
VERILOG_DIR?=$(REPO_DIR)/verilog
COMPONENTS_DIR?=$(VERILOG_DIR)/components
DEFPARSER?=defparser

SOURCES+=$(COMPONENTS_DIR)/global.csv

all:
	@for s in $(SOURCES); do \
	echo Parsing $${s}; \
	$(DEFPARSER) -o `perl -e 'print "$$1.vh" if "'$${s}.'"=~/(.*)\.[^.]+/;'` $${s}; \
	done
-include local.mk

REPO_DIR?=../..
VERILOG_DIR?=$(REPO_DIR)/verilog
COMPONENTS_DIR?=$(VERILOG_DIR)/components
SOURCE_DIR?=$(COMPONENTS_DIR)/source
BUILD_DIR?=$(COMPONENTS_DIR)/build

DEFPARSER?=java -jar $(REPO_DIR)/utilities/defines_parser_java/defparser.jar
PREPROCESSOR?=python $(REPO_DIR)/utilities/preprocessor/preprocessor.py

SOURCES+=$(COMPONENTS_DIR)/global.csv \
	$(COMPONENTS_DIR)/debug.csv

VERILOG_SOURCES+=

UNDEF_FILE=$(COMPONENTS_DIR)/global_undef.vh
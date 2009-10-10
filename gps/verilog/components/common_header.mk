-include local.mk

REPO_DIR?=../..
VERILOG_DIR?=$(REPO_DIR)/verilog
COMPONENTS_DIR?=$(VERILOG_DIR)/components
DEFPARSER?=java -jar $(REPO_DIR)/utilities/defines_parser_java/defparser.jar

SOURCES+=$(COMPONENTS_DIR)/global.csv \
	$(COMPONENTS_DIR)/debug.csv
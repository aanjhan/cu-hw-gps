# This file is part of the Cornell University Hardware GPS Receiver Project.
# Copyright (C) 2009 - Adam Shapiro (ams348@cornell.edu)
#                      Tom Chatt (tjc42@cornell.edu)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

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
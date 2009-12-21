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
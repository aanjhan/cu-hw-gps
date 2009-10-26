ifeq ($(TERM),)
PLATFORM=win
else
ifeq ($(TERM),cygwin)
PLATFORM=win
else
ifeq ($(shell uname -s),Darwin)
PLATFORM=mac
else
PLATFORM=unix
endif
endif
endif

# File extnsion. This should only be set in a Windows environment.
ifeq ($(PLATFORM),win)
EXT?=.exe
endif

# Determine whether or not dependencies are needed based on target.
#
ifeq (,$(MAKECMDGOALS))
NEEDDEPS:=all
else
ifneq (,$(filter all run debug $(OUTPUT),$(MAKECMDGOALS)))
NEEDDEPS:=all
else
ifneq (,$(filter-out clean info,$(MAKECMDGOALS)))
NEEDDEPS:=some
else
NEEDDEPS:=none
endif
endif
endif

CC?=gcc
CXX?=g++
CFLAGS?=-Wall
ENV?=
INCLUDES?=-I.
LDFLAGS?=
LIBS?= 
LIBDIRS?=
TARGET?=debug
RM?=$(if $(PLATFORM)=='win',del /Q,rm -f)

# Debug Target
ifeq ($(TARGET),debug)
CFLAGS+=-g
endif

# Source list.
SOURCES=main.cpp data_feed.cpp

# Include subdirectory Makefiles.
DIRS=
ifneq ($(DIRS),)
include $(patsubst %, %/makefile.mk, $(DIRS))
endif

#Note that the following definitions exist for each environment:
#  Windows: #define WIN32
#  OS X: #define __APPLE__
ifeq ($(PLATFORM),mac)
CFLAGS+= -D__unix__ #Force Unix declaration for STLSoft library.
LIBDIRS+=
LIBS+= -lpcap -lboost_date_time-xgcc40-mt -lboost_thread-xgcc40-mt -lboost_program_options-xgcc40-mt
INCLUDES+= -I/usr/local/include/boost-1_36 -I/usr/local/include/stlsoft-1.9.87/include
SOURCES+= raw_socket_osx.cpp
else
ifeq ($(PLATFORM),win)
LIBDIRS+= -Lc:/WinPcap/Lib -Lc:/boost/lib
LIBS+= -lwpcap -liphlpapi -lboost_date_time-mgw34-mt -lboost_thread-mgw34-mt -lboost_program_options-mgw34-mt
INCLUDES+= -Ic:/WinPcap/Include -Ic:/boost/include/boost-1_40 -Ic:/stlsoft-1.9.87/include
SOURCES+= raw_socket_win.cpp
else
LIBDIRS+=
LIBS+= -lpcap
INCLUDES+=
SOURCES+= raw_socket_unix.cpp
endif
endif

DEPENDENCIES=$(patsubst %.cpp, %.d, $(SOURCES))
OBJECTS=$(patsubst %.cpp, %.o, $(SOURCES))
PROJECT=data_feed
OUTPUT=$(PROJECT)$(EXT)

.PHONY: all
all: $(OUTPUT)

$(OUTPUT): $(OBJECTS)
	$(CXX) -o $@ $(CFLAGS) $(INCLUDES) $(LIBDIRS) $^ $(LIBS)

.PHONY: depend
depend: $(DEPENDENCIES)

%.d: %.cpp
	@printf "Generating dependency for $<  ->  $@\n"
	@set -e; \
	$(CXX) -MM -w  $(CFLAGS) $(INCLUDES) $< \
	| sed -e "s/^\(.*\)\.o/$(patsubst %/,%\/,$(dir $<))\1.d $(patsubst %/,%\/,$(dir $<))\1.o/" > $@; \
	[ -s $@ ] || rm -f $@

ifneq ($(NEEDDEPS), none)
  ifeq ($(NEEDDEPS), all)
    -include $(DEPENDENCIES)
  else
    -include $(patsubst %.o, %.d, $(MAKECMDGOALS))
  endif
endif

%.o: %.c
	$(CC) -o $@ -c $(CFLAGS) $(INCLUDES) $<

%.o: %.cpp
	$(CXX) -o $@ -c $(CFLAGS) $(INCLUDES) $<

.PHONY: clean
clean:
	rm -f $(DEPENDENCIES)
	rm -f $(OBJECTS)
	rm -f $(OUTPUT)

.PHONY: run debug
run: $(OUTPUT)
	./$(OUTPUT) -gldebug
debug: $(OUTPUT)
	gdb $(OUTPUT)

.PHONY: info
info:
	@echo Platform: $(PLATFORM)
	@echo Extension: $(EXT)
	@echo Sources: $(SOURCES)
	@echo Dependencies: $(DEPENDENCIES)
	@echo Objects: $(OBJECTS)
	@echo Libraries: $(LIBS)
	@echo Project: $(PROJECT)
	@echo Output File: $(OUTPUT)
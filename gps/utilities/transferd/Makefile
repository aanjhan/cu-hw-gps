# Determine whether or not dependencies are needed based on target.
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

HOST=linux
CFLAGS=-g -Wall

ifeq ($(HOST),arm)
INC_DIR=/usr/local/arm/kernel/linux-2.6.10/include
SYSINC_DIR=/usr/local/arm/gnu/release-3.4.0-vfp/arm-linux/include
CC=arm-linux-gcc
CFLAGS+=-Os -I$(INC_DIR) -isystem $(SYSINC_DIR) -mlittle-endian -mfpu=vfp -marm
else
CC=gcc
endif

transferd_SOURCES=transferd.c socket.c command_server.c list.c
transferd_DEPENDENCIES=$(patsubst %.c, %.d, $(transferd_SOURCES))
transferd_OBJECTS=$(patsubst %.c, %.o, $(transferd_SOURCES))
transferd_OUTPUT=transferd

transfer_SOURCES=transfer.c socket.c command_client.c
transfer_DEPENDENCIES=$(patsubst %.c, %.d, $(transfer_SOURCES))
transfer_OBJECTS=$(patsubst %.c, %.o, $(transfer_SOURCES))
transfer_OUTPUT=transfer

DEPENDENCIES=$(transferd_DEPENDENCIES) $(transfer_DEPENDENCIES)
OUTPUT=$(transferd_OUTPUT) $(transfer_OUTPUT)

all: $(OUTPUT)

$(transferd_OUTPUT): $(transferd_OBJECTS)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@

$(transfer_OUTPUT): $(transfer_OBJECTS)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@

.PHONY: depend
depend: $(DEPENDENCIES)

%.d: %.c
	@printf "Generating dependency for $<  ->  $@\n"
	@set -e; \
	$(CC) -MM -MG -w  $(CFLAGS) $(INCLUDES) $< \
	| sed -e "s/^\(.*\)\.o/$(patsubst %/,%\/,$(dir $<))\1.d $(patsubst %/,%\/,$(dir $<))\1.o/" > $@; \
	[ -s $@ ] || rm -f $@

ifneq ($(NEEDDEPS), none)
  ifeq ($(NEEDDEPS), all)
    -include $(DEPENDENCIES)
  else
    ifneq (,$(filter %.o, $(MAKECMDGOALS)))
      -include $(patsubst %.o, %.d, $(filter %.o, $(MAKECMDGOALS)))
    endif
  endif
endif

%.o: %.c
	$(CC) -c $(CFLAGS) $< -o $@

.phony: clean transferd_clean transfer_clean
clean: transferd_clean transfer_clean
transferd_clean:
	rm -f $(transferd_DEPENDENCIES)
	rm -f $(transferd_OBJECTS)
	rm -f *.elf
	rm -f $(transferd_OUTPUT)
transfer_clean:
	rm -f $(transfer_DEPENDENCIES)
	rm -f $(transfer_OBJECTS)
	rm -f *.elf
	rm -f $(transfer_OUTPUT)
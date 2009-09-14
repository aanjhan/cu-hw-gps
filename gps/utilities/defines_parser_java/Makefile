SUBDIRS=Exceptions OptionsParser
SOURCES=*.java $(foreach dir,$(SUBDIRS),$(dir)/*.java)
OBJECTS=$(patsubst %.java,%.class,$(SOURCES))
OUTPUT=defparser.jar

.PHONY: all
all: $(OUTPUT) clean_build

$(OUTPUT): objects
	jar -cfm $@ Manifest.txt $(OBJECTS)

.PHONY: objects
objects: $(SOURCES)
	javac -g $(SOURCES)

.PHONY: clean clean_build
clean: clean_build
	rm -f $(OUTPUT)

clean_build:
	rm -f $(OBJECTS)
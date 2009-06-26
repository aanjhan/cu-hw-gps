SUBDIRS=Exceptions OptionsParser
SOURCES=*.java $(foreach dir,$(SUBDIRS),$(dir)/*.java)
OBJECTS=$(patsubst %.java,%.class,$(SOURCES))
OUTPUT=defparser.jar

.PHONY: all
all: $(OUTPUT)

$(OUTPUT): objects
	jar -cfm $@ Manifest.txt $(OBJECTS)

.PHONY: objects
objects: $(SOURCES)
	javac -g $(SOURCES)

.PHONY: clean
clean:
	rm -f $(OBJECTS)
	rm -f $(OUTPUT)
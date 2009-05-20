SOURCES+=../components/global.csv

all:
	@for s in $(SOURCES); do \
	echo defparser -o `perl -e 'print "$$1.vh" if "'$${s}.'"=~/(.*)\.[^.]+/;'` $${s}; \
	done
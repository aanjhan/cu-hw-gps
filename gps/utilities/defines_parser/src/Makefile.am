bin_PROGRAMS=defparser
defparser_SOURCES=main.cpp tokenizer.cpp tree_node.cpp parser.cpp expression.cpp
defparser_CPPFLAGS=$(BOOST_CPPFLAGS)
defparser_LDFLAGS=$(BOOST_REGEX_LDFLAGS) $(BOOST_PROGRAM_OPTIONS_LDFLAGS)
defparser_LDADD=$(BOOST_REGEX_LIBS) $(BOOST_PROGRAM_OPTIONS_LIBS)
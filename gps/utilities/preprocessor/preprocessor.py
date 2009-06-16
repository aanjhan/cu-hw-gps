#Built-in library imports
import sys
import csv
import os
import string
import math

#src imports
from parser_defs import *

#import pdb   #debugger

###############################################################################

#Init a global printbuffer
printbuffer = ""

def main():

    global printbuffer

    # Parse input args
    (args,list_mode,help_mode,ofile) = parseArgs()

    # If in help_mode, print help string and exit
    if help_mode:
        print HELP_STRING
        sys.exit(1)

  #  try:

    # If in list mode:
    if list_mode:

        # Remove duplicates from list
        args = list(set(args))

        # Initialize a list of include file paths
        include_paths = []

        # Process all of the listed files
        for path in args:

            # Check to make sure the file ends in .s
            if not path.endswith(".s"):
                print("Error: the file \"" + path + "\" has an invalid file extension " +
                      "and may not be a valid source file.\nExiting...")
                sys.exit(1)

            # Check to make sure the file exists
            if not (os.path.exists(path) and os.path.isfile(path)):
                print("Error: the file \"" + path + "\" does not exist.\nExiting...")
                sys.exit(1)

            # Try to open the file
            try:
                sfile = open(path,'r')
            except:
                print("Error: the file \"" + path + "\" cannot be opened.\nExiting...")
                sys.exit(1)           

            # Find the absolute paths of all includes from the file
            include_paths.extend(getIncludes(sfile))

        # Remove duplicate headers
        include_paths = list(set(include_paths))

        # Get the print buffer ready
        pbuffer("HEADERS=")

        # Escape any spaces in the pathname
        includes = [inc_path.replace(" ","\ ") for inc_path in include_paths]

        # Add the include paths to the print buffer
        for path in include_paths:
            path = path[0:len(path) - 3] + ".csv"
            pbuffer(path + " ")

    # If in regular mode:
    else:       
        path = args[0]

        # Check to make sure the input file ends in .s
        if not path.endswith(".s"):
            print("Error: the file \"" + path + "\" has an invalid file extension " +
                  "and may not be a valid source file.\nExiting...")
            sys.exit(1)

        # Check to make sure the input file exists
        if not (os.path.exists(path) and os.path.isfile(path)):
            print("Error: the file \"" + path + "\" does not exist.\nExiting...")
            sys.exit(1)

        # Try to open the source file
        try:
            sfile = open(path,'r')
        except:
            print("Error: the file \"" + path + "\" cannot be opened.\nExiting...")
            sys.exit(1)
        
        # Find the absolute paths of all includes from the source file
        include_paths = getIncludes(sfile)

        # Parse the include files and build a defines dictionary
        var_dict = {}

        # For each header file:
        for hpath in include_paths:
            
            # Try to open the file
            try:
                hfile = open(hpath,'r')
            except:
                print("Error: the file \"" + hpath + "\" cannot be opened.\nExiting...")
                sys.exit(1)

            # Parse the header file
            parseHeader(hfile, hpath, var_dict)

        # Parse the source file
        parseSource(sfile, var_dict)

    # Print out the printbuffer
    if ofile == None:
        print printbuffer
    else:
        try:
            file = open(ofile,'w')
            file.write(printbuffer)
            file.close()
        except:
            print "Error: could not open output file \"" + ofile + "\" for writing.\nExiting..."
            sys.exit(1)

###############################################################################

# Print to the printbuffer
def pbuffer(str):
    global printbuffer
    printbuffer = printbuffer + str

###############################################################################

# Find any included files in a source file
def getIncludes(sfile):

    includes = []                               # List to hold the included files
    linecounter = 0                             # Line counter
    abs_path = os.path.abspath(sfile.name)      # Relative pathname of the source file

    # Look for any line that has `include and pull out the filepath
    sfile.seek(0)
    for line in sfile:   
        linecounter = linecounter + 1
        if "`include" in line:
            sp = line.split(None,1)
            
            # Grab the filepath
            try:
                includes.append(sp[1])
            except:   #Throw an exception because there is a blank `include statement
                raise Warning("Invalid `include statement in file " + abs_path + " at line " + `linecounter` + ".\n")

    # Knock the quotes and newline off the pathname
    includes = [inc_path.replace('"','') for inc_path in includes]
    includes = [inc_path.replace('\n','') for inc_path in includes]

    # Prepend the prefix of the filepath to the relative path of the included file
    includes = [os.path.dirname(abs_path) + "/" + inc_path for inc_path in includes]

    # Make absolute paths of all of the includes
    includes = [os.path.abspath(inc_path) for inc_path in includes]

    # Strip carriage return
    includes = [p.replace("\r","") for p in includes]

    # Escape spaces
    includes = [p.replace(" ","\ ") for p in includes]    

    # Check to see if all the includes end with .vh, exist, and are files
    if [p for p in includes if not (p.endswith(".vh") and os.path.exists(p) and os.path.isfile(p))]:
        raise Warning("Invalid `include file: " + p + ".\n")
    else:
        return includes

###############################################################################

# Parse out the script input arguments using optparse
def parseArgs():   

    list_mode = False
    help_mode = False
    ofile = None

    #Pop off the script name arg
    sys.argv.pop(0)

    #Search for a -h flag.  If a -h flag is found, return with help_mode flagged
    try:
        sys.argv.remove("-h")
        help_mode = True
    except:
        pass

    #Search for -l or -o flags.  If -o is flagged, grab the output filepath
    try:
        sys.argv.remove("-l")
        list_mode = True
    except:
        pass

    try:
        i = sys.argv.index("-o")
        ofile = sys.argv[index + 1]
        sys.argv.pop(i)             #Pop the -o flag
        sys.argv.pop(i)             #Pop the output filepath
    except:
        pass

    #Return all remaining arguments in a list structure (only 1 argument unless in list mode)
    return (sys.argv,list_mode,help_mode,ofile)


###############################################################################

# Parse values out of a Verilog header file
def parseHeader(hfile, hfile_path, var_dict):

    vd = var_dict  #copy the variables dictionary to update it
    i = 0;         #line counter
    line = " "     #line string

    # Run through each line in the file
    hfile.seek(0)
    while line:

        #Strip whitespace
        line = line.strip()

        # Wipe off comments
        commentIndex = string.find(line,"//")
        if commentIndex >= 0:
            line = line[0:commentIndex]

        # Break up each line            
        line_fields = string.split(line," ")

        # Grab the lines that contain valid defines
        if len(line_fields) == 3:
            key = line_fields[1]        
            value = line_fields[2]

	    #strip \n from the value
            value = string.replace(value,"\n","")

            #If we have a valid define statement:
            if line_fields[0] == "`define" and key != None and value != None:

                # Check to make sure that the variable name is valid
                if qualifiedName.match(key) != None:

                    # Check to see if the variable value is valid
                    if (verilogConstant.match(value) != None or
                        hexValue.match(value) != None or
                        number.match(value) != None):

                           # Check to see if the variable name is already in the dictionary
                           if not vd.has_key(key):
                               # Add the new variable to the dictionary
                               vd[key] = createValue(value,hfile_path,i)

        # Read the next line and update line counter
        line = hfile.readline()        
        i = i + 1;

    # Return the updated dictionary
    return vd
    
###############################################################################

# Parse a source file, replace preprocessor tags, and write output file
def parseSource(sfile, vars_dict):

    i = 0;                  #line counter
    in_v_comment = False;   #Flag for lines inside a verilog comment block
    in_p_block = False;     #Flag for lines inside a preprocessor block

    #Run through the file character by character using a DFA
    state = DEFAULT             # State variable
    err_code = NOERR            # Code variable for syntax errors
    pre_seg_begin_line = 0      # Line number of a preprocessor section start
    v_com_begin_line = 0        # Line number of a Verilog block comment start
    pre_expr_begin_line = 0     # Line number of a preprocessor expression start
    line_count = 0              # Current line number
    char_count = 0              # Current character number (in line)

    pre_seg_buffer = ""         # Character buffer for preprocessor segments
    pre_expr_buffer = ""        # Character buffer for preprocessor expressions
    define_buffer = ""          # Character buffer for DEFINE statements

    sfile.seek(0)
    char = sfile.read(1)

    while char and state != ERROR:

        # DEFAULT
        if state == DEFAULT:
            if char == "/":
                state = DEF_FOUND_FSLASH
                pbuffer(char)
            elif char == "%":
                state = PRE_COM
            elif char == "`":
                state = DEFINE
                pbuffer(char)
            elif char == "<":
                state = DEF_FOUND_LCARET
            else:
                pbuffer(char)

        # DEF_FOUND_FSLASH
        elif state == DEF_FOUND_FSLASH:
            if char == "*":
                state = V_COM
                v_com_begin_line = line_count
                pbuffer(char)
            elif char == "/":
                state = V_COM_LINE
                pbuffer(char)
            else:
                state = DEFAULT
                pbuffer(char)

        # V_COM_LINE
        elif state == V_COM_LINE:
            if char == "\n":
                state = DEFAULT
            pbuffer(char)
        
        # V_COM
        elif state == V_COM:
            if char == "*":
                state = V_COM_FOUND_AST
            pbuffer(char)

        # V_COM_FOUND_AST       
        elif state == V_COM_FOUND_AST:
            if char == "/":
                state = DEFAULT
            elif not char == "*":
                state = V_COM
            pbuffer(char)    

        # DEFINE
        elif state == DEFINE:
            if char == "\n":
                state = DEFAULT
                parseDefine(define_buffer,vars_dict)
                pbuffer(define_buffer + "\n")
                define_buffer = ""
            else:
                define_buffer = define_buffer + char

        # DEF_FOUND_LCARET
        elif state == DEF_FOUND_LCARET:
            if char == "?":
                state = PRE_SEG
                pre_seg_begin_line = line_count
            else:
                state = DEFAULT
                pbuffer("<" + char)  # have to put a < because prev state didn't write one 
        
        # PRE_COM
        elif state == PRE_COM:
            if char == "\n":
                state = DEFAULT

        # PRE_SEG
        elif state == PRE_SEG:
            if char == "{":
                state = PRE_EXPR
                pre_expr_begin_line = line_count
            elif char == "<":
                state = PRE_FOUND_LCARET
            elif char == "?":
                state = PRE_FOUND_QUEST
            else: 
                pre_seg_buffer = pre_seg_buffer + char

        # PRE_EXPR
        elif state == PRE_EXPR:
            if char == "}":
                state = PRE_SEG
                if pre_expr_buffer != "":
                    parsePreExpr(pre_expr_buffer,pre_seg_buffer,vars_dict)
                    pre_expr_buffer = ""
            elif char == "\n":
                state = ERROR
                err_code = NEWLINE_IN_PRE_EXPR
            else:
                pre_expr_buffer = pre_expr_buffer + char
        
        # PRE_FOUND_QUEST
        elif state == PRE_FOUND_QUEST:
            if char == ">":
                state = DEFAULT
                parsePreSeg(pre_seg_buffer, vars_dict)
                pre_seg_buffer = ""
            else:
                state = PRE_SEG
                pre_seg_buffer = pre_seg_buffer + "?" + char

        # PRE_FOUND_LCARET
        elif state == PRE_FOUND_LCARET:
            if char == "?":
                state = ERROR
                err_code = DUP_PRE_BEGIN
            else:
                state = PRE_SEG
                pre_seg_buffer = pre_seg_buffer + "<" + char

        # Update line count and char count
        if state != ERROR:
            char_count = char_count + 1
            if char == "\n":
                line_count = line_count + 1
                char_count = 0

            # Read the next character
            char = sfile.read(1)
    #end while

    #Check to make sure EOF did not occur in an invalid state
    if state == V_COM:
        err_code = UNCLOSED_V_COM
    elif state == PRE_EXPR:
        err_code = UNCLOSED_PRE_EXPR
    elif state == PRE_FOUND_LCARET:
        err_code = UNCLOSED_PRE_EXPR
    elif state == PRE_FOUND_QUEST:
        err_code = UNCLOSED_PRE_SEG

    #If an error occured, report it
    if err_code != NOERR:
        if err_code == UNCLOSED_V_COM:
            print "Error: Unclosed Verilog block comment (beginning at line " + `v_com_begin_line` + ")\n"
            sys.exit(1)
        elif err_code == NEWLINE_IN_PRE_EXPR:
            print "Error: Newline occurred in preprocessor expression: at line " + `line_count` +"\n"
            sys.exit(1)
        elif err_code == UNCLOSED_PRE_EXPR:
            print "Error: Unclosed preprocessor expression (beginning at line " + `pre_expr_begin_line` + ")\n"
            sys.exit(1)
        elif err_code == DUP_PRE_BEGIN:
            print "Error: Nested preprocessor tags: at line " + `line_count` + "\n"
            sys.exit(1)
        elif err_code == UNCLOSED_PRE_SEG:
            print "Error: Unclosed preprocessor tags (beginning at line " + `pre_seg_begin_line` + ")\n"
            sys.exit(1)

###############################################################################

# Create a value entry for the variables dictionary
# Structure: [VAR_NAME, FILE_NAME, LINE_NUMBER]
def createValue(var_name, path, line_number):
    return [var_name, path, line_number]

###############################################################################

# Grab the line number out of an entry in the variables dictionary
def getLineNumber(entry):
    return entry[2]

###############################################################################

# Grab the file name out of an entry in the variables
def getFileName(entry):
    return entry[1]

###############################################################################   

# Parse a #define statement from the source file and write to the output file
def parseDefine(def_str,var_dict):

    vd = var_dict
    line = def_str

    #strip whitespace
    line = line.strip()

    #split the line
    line_fields = string.split(line, " ") 

    #check for "define" keyword
    if line_fields[0] != "define":
        return

    else:
        #grab the key and value
        if len(line_fields) == 3:
            key = line_fields[1]        
            value = line_fields[2]

        #strip \n from the value
        value = string.replace(value,"\n","")

        #If we have a valid define statement:
        if line_fields[0] == "define" and key != None and value != None:

            # Check to make sure that the variable name is valid
            if qualifiedName.match(key) != None:

                # Check to see if the variable value is valid
                if (verilogConstant.match(value) != None or
                    hexValue.match(value) != None or
                    number.match(value) != None):

                       # Check to see if the variable name is already in the dictionary
                       if not vd.has_key(key):
                           # Add the new variable to the dictionary
                           vd[key] = createValue(value,"",0)

###############################################################################

# Parse a preprocessor arithmetic expression and write the result to the
# preprocessor segment buffer
# NOT CURRENTLY SUPPORTED
def parsePreExpr(expr_str,pre_seg_buffer,vars_dict):
    pass

###############################################################################    

# Parse a preprocessor segment and write the resulting Verilog code to the 
# output file
def parsePreSeg(seg_str,vars_dict):

    # Strip whitespace
    seg_str = seg_str.strip()

    # Replace any defined variables using regex search & replace
    for var in vars_dict:
        regex = re.compile("`"+var)
        replacement = vars_dict.get(var)[0]
        seg_str = regex.sub(replacement,seg_str)

    # Get rid of carriage return
    regex = re.compile(".\n")
    seg_str = regex.sub("\n",seg_str)

    # Replace "print(" with "pbuffer("
    regex = re.compile("print\(")
    seg_str = regex.sub("pbuffer(",seg_str)

    # Execute the segment
    exec(seg_str)

###############################################################################

# Main method launcher
if __name__ == "__main__":
    main()

import re
import string

#Compile regexes
verilogConstant = re.compile("^('[dhb])")
hexValue = re.compile("^(\\d+[A-Fa-f][A-Fa-f0-9]*)")
number = re.compile("^(\\d+(\\.\\d+)?(e-?\\d+)?)")
qualifiedName = re.compile("^(`?[A-Za-z_]\\w*)")

# decimal to binary converter
d2b = lambda n: n>0 and d2b(n>>1).lstrip('0')+str(n&1) or '0'

#Define constants:

#Source parser state machine states:
DEFAULT          = 1;
PRE_COM          = 2;
DEFINE 	         = 3;
DEF_FOUND_FSLASH = 4;
DEF_FOUND_LCARET = 5;
V_COM_LINE       = 6;
V_COM            = 7;
V_COM_FOUND_AST  = 8;
PRE_SEG          = 9;
PRE_EXPR         = 10;
PRE_FOUND_QUEST  = 11;
PRE_FOUND_LCARET = 12;
ERROR            = -1;

#State machine dict: (for debugging!)
state_dict = {"1":"DEFAULT",
              "2":"PRE_COM",
              "3":"DEFINE",
              "4":"DEF_FOUND_FSLASH",
              "5":"DEF_FOUND_LCARET",
              "6":"V_COM_LINE",
              "7":"V_COM",
              "8":"V_COM_FOUND_AST",
              "9":"PRE_SEG",
              "10":"PRE_EXPR",
              "11":"PRE_FOUND_QUEST",
              "12":"PRE_FOUND_LCARET",
              "-1":"ERROR"}

#Preprocessor expression state machine states:


#Source parser state machine error codes
NOERR               = 0;
UNCLOSED_V_COM      = 1;
NEWLINE_IN_PRE_EXPR = 2;
UNCLOSED_PRE_EXPR   = 3;
DUP_PRE_BEGIN       = 4;
UNCLOSED_PRE_SEG    = 5;

#Token types
COLON     = 1;
CONST     = 2;
PLUS      = 3;
MINUS     = 4;
TIMES     = 5;
DIVIDE    = 6;
CARET     = 7;
LPAREN    = 8;
RPAREN    = 9;
FUNCTION  = 10;
VARIABLE  = 11;
VALUE     = 12;
NUMBER    = 13;
HEX       = 14;
ILLEGAL   = 15; 

#Char types
LETTER    = 16;
NUMBER    = 17;
PAREN     = 18;
OPERATOR  = 19;
ILLEGAL   = 20;

#Define the valid treeNode types
OPERATOR = 1;
FUNCTION = 2;
VARIABLE = 3;
CONSTANT = 4;

#Supported functions for preprocessor expressions
functions = ["abs",       #Absolute value
             "acos",      #Arc-cosine
             "asin",      #Arc-sine
             "atan",      #Arc-tangent
             "ceil",      #Ceiling (round up)
             "cos",       #Cosine
             "exp",       #e^x
             "floor",     #Floor (round down)
             "ln",        #Natural logarithm
             "log10",     #Base-10 logarithm
             "log2",      #Base-2 logarithm
             "max_value", #2^n - 1
             "max_width", #ceil(log2(ceil(value)));
             "mod",       #Modulus
             "round",     #round to the nearest integet
             "sin",       #Sine
             "sqrt",      #Square root
             "tan"]       #Tangent

#Supported operators in preprocessor expressions
operators = ["+",         #Addition
             "-",         #Subtraction / Negation
             "*",         #Multiplication
             "/",         #Division
             "^",         #Exponentiation
             "="]         #Variable assignment
             
#treeNode classdef
class treeNode:
    "Expression parser tree node"
    type = ""       #Options: OPERATOR, FUNCTION, VARIABLE, CONSTANT
    function = ""   #Options: defined by "supported functions" (above)
    operator = ""   #Options: defined by "supported operators" (above)
    variable = ""   #Options: any valid variable name
    constant = 0    #Options: any valid constant value
    parent = None   #Parent node (remains None if root node)
    children = None #List of children (for example, arguments of a function)

#Preprocessor help string
HELP_STRING = '''
NAME
        preprocessor.py - process a .s source file into syntactically correct 
                          Verilog code

SYNOPSIS
        python preprocessor.py [-l|-h] [list of .s files] [-o] [output filepath]

DESCRIPTION
        Process a .s source file into syntactically correct Verilog code by
        executing snippets of Python code embedded in Verilog source code.

        -h                         Display this help message

        -l [list of source files]  Print out a list of header files used by the
                                   given source files

        -o                         Print output to output file instead of 
                                   stdout

        Normal usage: Input a single .s file to process the file contents into
        syntactically correct Verilog code.

AUTHOR
        Written by Tom Chatt  <tom.j.chatt@gmail.com>
        '''        

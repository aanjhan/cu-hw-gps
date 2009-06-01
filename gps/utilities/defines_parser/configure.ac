AC_INIT(DefParser, 1.1, ams348@cornell.edu)
AC_CONFIG_AUX_DIR([config])
AM_INIT_AUTOMAKE([-Wall])

#Check for programs.
AC_PROG_CXX
AC_PROG_CC
AC_PROG_SED
AC_PROG_LIBTOOL

#Check for libraries.
BOOST_REQUIRE
BOOST_REGEX
BOOST_PROGRAM_OPTIONS

#Check for functionality.
AC_C_CONST

#Configure constants.
AC_ARG_ENABLE(optimization, [  --disable-optimization   disable -Ox gcc optimization],,wantopto=yes)
if test "$wantopto" != "yes"; then
	CPPFLAGS=`echo $CPPFLAGS | sed -e 's/-O.//g'`
	CXXFLAGS=`echo $CXXFLAGS | sed -e 's/-O.//g'`
fi

#Process output.
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_SRCDIR([src/main.cpp])
AM_CONFIG_HEADER([src/config.h])
AC_CONFIG_FILES([Makefile src/Makefile])
AC_OUTPUT
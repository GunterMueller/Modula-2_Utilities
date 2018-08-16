# This makefile will generate the small demo program XTest
# with the help of the Modula to C translator mtc and the
# C compiler gcc.
# Note that a file named Xlib.h will be created; it is a special
# version created by mtc and required to compile X programs with
# mtc. You should NOT mix it with the original Xlib.h file from the
# X package.
# The same is true for other files.
CC	= gcc

                # C libraries
                # You may want to adjust the X11R6 librarie's location (just after '-L')
CLIBS	= -lX11 -L/usr/X11R6/lib

                # options for gcc
CFLAGS	=

                # options for mtc
M2FLAGS =

                # This file is needed by any program compiled through mtc.
                # It contains main()
SYSTEM	= SYSTEM_.o

all	:

# HEAD

sources	: KeySyms.h

sources	: KeySyms.c
KeySyms.o	: KeySyms.c KeySyms.h

sources	: X.h
X.h	: Xglobal.h

sources	: X.c
X.o	: X.c X.h

sources	: XMacros.h
XMacros.h	: Xglobal.h
XMacros.h	: X.h
XMacros.h	: Xlib.h

sources	: XMacros.c
XMacros.o	: XMacros.c XMacros.h
XMacros.o	: Xglobal.h
XMacros.o	: X.h
XMacros.o	: Xlib.h
XMacros.o	: KeySyms.h

sources	: XTest.c
all	: XTest
XTest.o	: XTest.c
XTest.o	: Xglobal.h
XTest.o	: X.h
XTest.o	: Xlib.h
XTest.o	: Xutil.h
XTest.o	: XMacros.h

sources	: Xglobal.h

sources	: Xglobal.c
Xglobal.o	: Xglobal.c Xglobal.h

sources	: Xlib.h
Xlib.h	: Xglobal.h
Xlib.h	: X.h

sources	: Xlib.c
Xlib.o	: Xlib.c Xlib.h

sources	: Xutil.h
Xutil.h	: Xglobal.h
Xutil.h	: X.h
Xutil.h	: Xlib.h

sources	: Xutil.c
Xutil.o	: Xutil.c Xutil.h

SYSTEM_.o	: SYSTEM_.c SYSTEM_.h

XTest	: $(SYSTEM)	\
	XTest.o	\
	XMacros.o	\
	KeySyms.o	\
	Xlib.o	\
	X.o	\
	Xglobal.o	\
	Xutil.o	\
;	$(CC) $(CFLAGS) -o XTest $(SYSTEM)	\
	XTest.o	\
	XMacros.o	\
	KeySyms.o	\
	Xlib.o	\
	X.o	\
	Xglobal.o	\
	Xutil.o	\
	$(CLIBS)

# TAIL

clean	:
	rm -f core *.o

.SUFFIXES: .md .mi .h .c .o

.mi.c:
	mtc $(M2FLAGS) $*.mi;

.md.h:
	mtc $(M2FLAGS) $*.md;

.c.o:
	$(CC) $(CFLAGS) -c $*.c

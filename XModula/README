XModula
=======

This is a set of file that will allow you to use the X11 library calls directly with the Modula-2
programming language. It includes the full Modula-2 foreign definition modules for the most
important headers of X11: Xlib.h, X.h, Xutil.h and keysyms.h.

There is NO WARRENTY these definitions will work and are bug-free. They have only be tested
superficially. I cannot be held responsible for any problems related to their usage.

Please consider this set to be a pre-pre-pre-beta version 0.0000...0001.

You may want to edit Xglobal.md to suit it to your compiler. Different compilers have different
basic types with different sizes. The version given there will successfully compile with Mocka and
mtc. No other compiler have been tested, and other modifications may be necessary for some of them
too.

These files have been created manually, from the X11 headers, 90% using macros and
search-replace-like commands; thus, there may be repeated mistakes as well as isolated ones.
Remember that these files have not been tested strongly yet. If you find bugs, contact me at
Nicky@GameBox.net and I will update them if I have the time.

I tried to make them as Modula-2-like as possible: Many pointers used in procedure calls to return
values have been replaced by VAR-parameters; pointer to chars followed by a length have been
replaced by an ARRAY OF CHAR parameter; underscore (_) (which are not supported by some compiler)
have been removed and characters just following them have been converted to uppercase; the C types
int, unsigned long, ... have been renamed using Modula-2-looking types INT, CARD32, ... which are
declared in Xglobal.md so you can adapt them to match the corresponding C type without changing
all the other files.

The definitions are complete: everything from the Xlib.h, X.h and Xutil.h has been translated
(including the original comments). The only trick is that the inline macros from Xlib and Xutil
are in a separate module called Xmacro because most Modula-2 compilers does not accept macro
definition; they are of course implemented using normal Modula-2 procedures.

About ARRAY OF CHAR: As mentioned above, pointers to char + length pairs have been replaced by
ARRAY OF CHAR. The idea is that you can then directly pass a string constant as argument.
Sometimes though, you may need to pass a custom length (eg. when the string is built in a static
array). There is no way to do it, but usually, there are equivalent calls that use a pointer to an
array of 16-bit wide chars (Xlib.XChar2b) plus a length that can be used for that purpose. You can
convert from a CHAR ch to a XChar2b c using c.byte2:= ch; c.byte1:= 0C; see XTest.mi for an
example.

Note that many X11 calls return a value that is usually not important. In C you can ignore this
value by calling the function like a procedure. But in Modula you always have to put the result
somewhere, unfortunatly.


Read the file README.Mocka if you are using Mocka.
Read the file README.mtc if you are using mtc.

Contact me if you have successfully compiled these files with an other compiler (with or without
changes) so I can update the documentation.


Nicky  (Nicky@GameBox.net)
Institute of Informatics,
University of Fribourg (CH).

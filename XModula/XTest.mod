MODULE XTest;

 (*
  * This example module shows how to access X11 from a Modula-2 program.
  * To make the code easy to read, no check are performed; the program is
  * therefore likely to crash if something goes wrong.
  * A real program should always check returned values for possible errors.
  *
  * This program assumes an X display with at least 16 colors.
  *)

FROM  SYSTEM 	   IMPORT  ADDRESS, ADR;
FROM  Xglobal 	   IMPORT  CARD8, INT, CARD, CARD32, SET32;
FROM  X  	   IMPORT  Window, WindowPtr, KeySym, Expose, KeyPress, ButtonPress,
      		   	   ExposureMask, ButtonPressMask, KeyPressMask, None, Colormap, AllocAll, 
  			   DoRed, DoGreen, DoBlue;
FROM  Xlib         IMPORT  Display, DisplayPtr, Screen, ScreenPtr, GC, XOpenDisplay,
      		   	   XCreateSimpleWindow, XSelectInput, XCreateGC, XSetBackground,
			   XSetForeground, XClearWindow, XMapRaised, XFreeGC, XDestroyWindow,
			   XCloseDisplay, XEvent, XNextEvent, XFillRectangle, XFillArc,
			   XDrawString, XColor, XCreateColormap, XStoreColors, XSetWindowColormap,
			   XFreeColormap, XDrawString16, XChar2b; 
FROM  Xutil        IMPORT  XSetStandardProperties, XLookupString;
FROM  XMacros 	   IMPORT  DefaultScreen, BlackPixel, WhitePixel, DefaultRootWindow, RootWindow,
      		   	   DefaultVisual; 

VAR    dis		   : DisplayPtr;  	(* Connection to the X server *)
       screen		   : INT; 		(* Default screen number *)
       win		   : Window; 		(* My window *)
       gc		   : GC; 		(* Graphics context *)
       cmap 		   : Colormap; 		(* My private Colormap *)
       black, white	   : CARD32; 		(* Pixel numbers for black and white colors *)
       res    		   : INT; 		(* dummy variable to fetch X calls' results *)


PROCEDURE InitX;	   (* Create everythings that is necessary to draw on a window *)

CONST  WindowName   = "My window";
       IconName     = "HI!";

VAR    windowName, iconName 	: ARRAY[0..59] OF CHAR;

BEGIN
  windowName := WindowName; 	(* Mocka does not allow ADR(Const) *)
  iconName := IconName;     	(* therefore copy it in a variable. *)


  dis := XOpenDisplay (NIL);	   	(* Connect to the X server *)
  screen := DefaultScreen (dis);
  black := BlackPixel (dis, screen);
  white := WhitePixel (dis, screen);
  cmap := 0; 	      	    	    	(* No colormap created yet *)

 (* Create a window *)
  win := XCreateSimpleWindow (dis, DefaultRootWindow(dis), 0, 0, 200, 300, 5, white, black);
  res := XSetStandardProperties (dis, win, ADR(windowName), ADR(iconName), None, NIL, 0, NIL);
  res := XSelectInput (dis, win, ExposureMask + ButtonPressMask + KeyPressMask);

 (* Create a graphic context *)
  gc  := XCreateGC (dis, win, SET32 {}, NIL);
  res := XSetBackground (dis, gc, white);
  res := XSetForeground (dis, gc, black);

 (* Bring the window to the front *)
  res := XMapRaised (dis, win)
END InitX;


PROCEDURE CreateColormap;	(* Create a grayscale colormap and attach it to the window *)

VAR	  i	   : INT;
   	  tmp	   : ARRAY[0..15] OF XColor;

BEGIN
  FOR i:= 0 TO 15 DO	(* Create a grayscale *)
    WITH tmp [i] DO
      pixel := i;  	(* By default, Xglobal.CARD8 = CHAR; therefore, use CHR() *)
      flags := CHR (DoRed + DoGreen + DoBlue);
      red := i * 4369; 	   	     	     	(* 15x4369 = 65535 = 2^16 - 1  :-) *)
      green := i * 4369;
      blue := i * 4369
    END
  END;

 (* Create the Colormap *)
  cmap := XCreateColormap (dis, RootWindow(dis, screen), DefaultVisual(dis, screen), AllocAll);
  res := XStoreColors (dis, cmap, ADR(tmp), 16);

  res := XSetWindowColormap (dis, win, cmap);		 (* Attach it to the window *)
  black := 0;		    	       			 (* Update black and white *)
  white := 15
END CreateColormap;


PROCEDURE CloseX;

BEGIN
  res := XFreeGC (dis, gc);
  res := XDestroyWindow (dis, win);
  IF cmap <> 0 THEN  res := XFreeColormap (dis, cmap)  END;
  res := XCloseDisplay (dis)
END CloseX;


PROCEDURE Redraw;		(* Redraw our window's content *)

VAR      i, j	     : INT;

BEGIN
  res := XSetForeground (dis, gc, white);
  res := XFillRectangle (dis, win, gc, 0, 0, 200, 300);
  FOR i := 0 TO 15 DO
    res := XSetForeground (dis, gc, i);
    j := i * 6;
    res := XFillArc (dis, win, gc, j, j + 100, 200 - j * 2, 200 - j * 2, 0, 360 * 64)
  END;
  res := XSetForeground (dis, gc, black);
  res := XDrawString (dis, win, gc, 10, 10, "Press 'q' to quit")
END Redraw;


PROCEDURE ClearTextArea;

BEGIN
  res := XSetForeground (dis, gc, white);
  res := XFillRectangle (dis, win, gc, 10, 12, 190, 32);
  res := XSetForeground (dis, gc, black)
END ClearTextArea;


VAR
  event		: XEvent;
  key		: KeySym;
  text		: ARRAY [0..255] OF CHAR;
  ch		: ARRAY [0..15] OF XChar2b;
  length	: CARDINAL;

BEGIN
  InitX;
  (* You can remove the next line to use the standard colors *)
  (* CreateColormap; *)

  LOOP
    res := XNextEvent(dis, event);
    IF  (event.type = Expose) THEN  Redraw  END;
    IF  (event.type = KeyPress) AND
       (XLookupString(ADR(event.xkey), text, key, NIL) = 1) THEN
      IF (text[0] = "q") THEN EXIT END;
      ClearTextArea;

      (* Convert CHAR to XChar2b so we can use a custom string length *)
      length := 0;
      WHILE (text [length] <> 0C) AND (length < 16) DO
        ch [length].byte2 := text[length]; 
	ch [length].byte1 := 0C;
    	INC (length)
      END;

      res := XDrawString (dis, win, gc, 10, 26, "You pressed the key:");
      res := XDrawString16 (dis, win, gc, 10, 42, ADR(ch[0]), length)
    END;
    IF  (event.type = ButtonPress)  THEN
      ClearTextArea;
      res := XDrawString (dis, win, gc, 10, 26, "Button pressed")
    END
  END;

  CloseX;

END XTest.

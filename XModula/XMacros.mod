IMPLEMENTATION MODULE XMacros;
 (* Macros from Xlib.h and Xutil.h *)

 FROM SYSTEM IMPORT BYTE, ADDRESS, ADR;
 FROM Xglobal IMPORT CARD8, INT16, CARD16, INT, CARD, INT32, CARD32, SET32,
  BOOL, StringPtr;
 FROM X IMPORT Window, Colormap, KeySym;
 FROM Xlib IMPORT Display, DisplayPtr, Screen, ScreenPtr, GC, Visual, VisualPtr,
  XImage, XImagePtr;
 FROM KeySyms IMPORT XKKPSpace, XKKPEqual, XKHome, XKSelect, XKKPF1, XKKPF4,
  XKF1, XKF35, XKBreak, XKShiftL, XKHyperR, XKModeswitch, XKNumLock;


(* Xlib macros *)
 PROCEDURE ConnectionNumber(dpy: DisplayPtr): INT;
 BEGIN
  RETURN dpy^.fd
 END ConnectionNumber;

 PROCEDURE RootWindow(dpy: DisplayPtr; scr: INT): Window;
  VAR s: ScreenPtr;
 BEGIN
  s:= ScreenOfDisplay(dpy, scr);
  RETURN s^.root
 END RootWindow;

 PROCEDURE DefaultScreen(dpy: DisplayPtr): INT;
 BEGIN
  RETURN dpy^.defaultScreen
 END DefaultScreen;

 PROCEDURE DefaultRootWindow(dpy: DisplayPtr): Window;
 BEGIN
  RETURN RootWindow(dpy, DefaultScreen(dpy))
 END DefaultRootWindow;

 PROCEDURE DefaultVisual(dpy: DisplayPtr; scr: INT): VisualPtr;
  VAR s: ScreenPtr;
 BEGIN
  s:= ScreenOfDisplay(dpy, scr);
  RETURN s^.rootVisual
 END DefaultVisual;

 PROCEDURE DefaultGC(dpy: DisplayPtr; scr: INT): GC;
  VAR s: ScreenPtr;
 BEGIN
  s:= ScreenOfDisplay(dpy, scr);
  RETURN s^.defaultGc
 END DefaultGC;

 PROCEDURE BlackPixel(dpy: DisplayPtr; scr: INT): CARD32;
  VAR s: ScreenPtr;
 BEGIN
  s:= ScreenOfDisplay(dpy, scr);
  RETURN s^.blackPixel
 END BlackPixel;

 PROCEDURE WhitePixel(dpy: DisplayPtr; scr: INT): CARD32;
  VAR s: ScreenPtr;
 BEGIN
  s:= ScreenOfDisplay(dpy, scr);
  RETURN s^.whitePixel
 END WhitePixel;

 PROCEDURE QLength(dpy: DisplayPtr): INT;
 BEGIN
  RETURN dpy^.qlen
 END QLength;

 PROCEDURE DisplayWidth(dpy: DisplayPtr; scr: INT): INT;
  VAR s: ScreenPtr;
 BEGIN
  s:= ScreenOfDisplay(dpy, scr);
  RETURN s^.width
 END DisplayWidth;

 PROCEDURE DisplayHeight(dpy: DisplayPtr; scr: INT): INT;
  VAR s: ScreenPtr;
 BEGIN
  s:= ScreenOfDisplay(dpy, scr);
  RETURN s^.height
 END DisplayHeight;

 PROCEDURE DisplayWidthMM(dpy: DisplayPtr; scr: INT): INT;
  VAR s: ScreenPtr;
 BEGIN
  s:= ScreenOfDisplay(dpy, scr);
  RETURN s^.mwidth
 END DisplayWidthMM;

 PROCEDURE DisplayHeightMM(dpy: DisplayPtr; scr: INT): INT;
  VAR s: ScreenPtr;
 BEGIN
  s:= ScreenOfDisplay(dpy, scr);
  RETURN s^.mheight
 END DisplayHeightMM;

 PROCEDURE DisplayPlanes(dpy: DisplayPtr; scr: INT): INT;
  VAR s: ScreenPtr;
 BEGIN
  s:= ScreenOfDisplay(dpy, scr);
  RETURN s^.rootDepth
 END DisplayPlanes;

 PROCEDURE DisplayCells(dpy: DisplayPtr; scr: INT): INT;
  VAR v: VisualPtr;
 BEGIN
  v:= DefaultVisual(dpy, scr);
  RETURN v^.mapEntries
 END DisplayCells;

 PROCEDURE ScreenCount(dpy: DisplayPtr): INT;
 BEGIN
  RETURN dpy^.nscreens
 END ScreenCount;

 PROCEDURE ServerVendor(dpy: DisplayPtr): StringPtr;
 BEGIN
  RETURN dpy^.vendor
 END ServerVendor;

 PROCEDURE ProtocolVersion(dpy: DisplayPtr): INT;
 BEGIN
  RETURN dpy^.protoMajorVersion
 END ProtocolVersion;

 PROCEDURE ProtocolRevision(dpy: DisplayPtr): INT;
 BEGIN
  RETURN dpy^.protoMinorVersion
 END ProtocolRevision;

 PROCEDURE VendorRelease(dpy: DisplayPtr): INT;
 BEGIN
  RETURN dpy^.release
 END VendorRelease;

 PROCEDURE DisplayString(dpy: DisplayPtr): StringPtr;
 BEGIN
  RETURN dpy^.displayName
 END DisplayString;

 PROCEDURE DefaultDepth(dpy: DisplayPtr; scr: INT): INT;
  VAR s: ScreenPtr;
 BEGIN
  s:= ScreenOfDisplay(dpy, scr);
  RETURN s^.rootDepth
 END DefaultDepth;

 PROCEDURE DefaultColormap(dpy: DisplayPtr; scr: INT): Colormap;
  VAR s: ScreenPtr;
 BEGIN
  s:= ScreenOfDisplay(dpy, scr);
  RETURN s^.cmap
 END DefaultColormap;

 PROCEDURE BitmapUnit(dpy: DisplayPtr): INT;
 BEGIN
  RETURN dpy^.bitmapUnit
 END BitmapUnit;

 PROCEDURE BitmapBitOrder(dpy: DisplayPtr): INT;
 BEGIN
  RETURN dpy^.bitmapBitOrder
 END BitmapBitOrder;

 PROCEDURE BitmapPad(dpy: DisplayPtr): INT;
 BEGIN
  RETURN dpy^.bitmapPad
 END BitmapPad;

 PROCEDURE ImageByteOrder(dpy: DisplayPtr): INT;
 BEGIN
  RETURN dpy^.byteOrder
 END ImageByteOrder;

 PROCEDURE NextRequest(dpy: DisplayPtr): CARD32;
 BEGIN
  RETURN dpy^.request + 1
 END NextRequest;

 PROCEDURE LastKnownRequestProcessed(dpy: DisplayPtr): CARD32;
 BEGIN
  RETURN dpy^.lastRequestRead
 END LastKnownRequestProcessed;

(* macros for screen oriented applications (toolkit) *)
 PROCEDURE ScreenOfDisplay(dpy: DisplayPtr; scr: INT): ScreenPtr;
 BEGIN
  RETURN ADR(dpy^.screens^[scr])
 END ScreenOfDisplay;

 PROCEDURE DefaultScreenOfDisplay(dpy: DisplayPtr): ScreenPtr;
 BEGIN
  RETURN ScreenOfDisplay(dpy, DefaultScreen(dpy))
 END DefaultScreenOfDisplay;

 PROCEDURE DisplayOfScreen(s: ScreenPtr): DisplayPtr;
 BEGIN
  RETURN s^.display
 END DisplayOfScreen;

 PROCEDURE RootWindowOfScreen(s: ScreenPtr): Window;
 BEGIN
  RETURN s^.root
 END RootWindowOfScreen;

 PROCEDURE BlackPixelOfScreen(s: ScreenPtr): CARD32;
 BEGIN
  RETURN s^.blackPixel
 END BlackPixelOfScreen;

 PROCEDURE WhitePixelOfScreen(s: ScreenPtr): CARD32;
 BEGIN
  RETURN s^.whitePixel
 END WhitePixelOfScreen;

 PROCEDURE DefaultColormapOfScreen(s: ScreenPtr): Colormap;
 BEGIN
  RETURN s^.cmap
 END DefaultColormapOfScreen;

 PROCEDURE DefaultDepthOfScreen(s: ScreenPtr): INT;
 BEGIN
  RETURN s^.rootDepth
 END DefaultDepthOfScreen;

 PROCEDURE DefaultGCOfScreen(s: ScreenPtr): GC;
 BEGIN
  RETURN s^.defaultGc
 END DefaultGCOfScreen;

 PROCEDURE DefaultVisualOfScreen(s: ScreenPtr): VisualPtr;
 BEGIN
  RETURN s^.rootVisual
 END DefaultVisualOfScreen;

 PROCEDURE WidthOfScreen(s: ScreenPtr): INT;
 BEGIN
  RETURN s^.width
 END WidthOfScreen;

 PROCEDURE HeightOfScreen(s: ScreenPtr): INT;
 BEGIN
  RETURN s^.height
 END HeightOfScreen;

 PROCEDURE WidthMMOfScreen(s: ScreenPtr): INT;
 BEGIN
  RETURN s^.mwidth
 END WidthMMOfScreen;

 PROCEDURE HeightMMOfScreen(s: ScreenPtr): INT;
 BEGIN
  RETURN s^.mheight
 END HeightMMOfScreen;

 PROCEDURE PlanesOfScreen(s: ScreenPtr): INT;
 BEGIN
  RETURN s^.rootDepth
 END PlanesOfScreen;

 PROCEDURE CellsOfScreen(s: ScreenPtr): INT;
  VAR v: VisualPtr;
 BEGIN
  v:= DefaultVisualOfScreen(s);
  RETURN v^.mapEntries
 END CellsOfScreen;

 PROCEDURE MinCmapsOfScreen(s: ScreenPtr): INT;
 BEGIN
  RETURN s^.minMaps
 END MinCmapsOfScreen;

 PROCEDURE MaxCmapsOfScreen(s: ScreenPtr): INT;
 BEGIN
  RETURN s^.maxMaps
 END MaxCmapsOfScreen;

 PROCEDURE DoesSaveUnders(s: ScreenPtr): BOOL;
 BEGIN
  RETURN s^.saveUnders
 END DoesSaveUnders;

 PROCEDURE DoesBackingStore(s: ScreenPtr): INT;
 BEGIN
  RETURN s^.backingStore
 END DoesBackingStore;

 PROCEDURE EventMaskOfScreen(s: ScreenPtr): SET32;
 BEGIN
  RETURN s^.rootInputMask
 END EventMaskOfScreen;


(* Xutil macros *)
(*
 * These macros are used to give some sugar to the image routines so that
 * naive people are more comfortable with them.
 *)
 PROCEDURE XDestroyImage(ximage: XImagePtr): INT;
 BEGIN
  RETURN ximage^.f.destroyImage(ximage)
 END XDestroyImage;

 PROCEDURE XGetPixel(ximage: XImagePtr; x, y: INT): CARD32;
 BEGIN
  RETURN ximage^.f.getPixel(ximage, x, y)
 END XGetPixel;

 PROCEDURE XPutPixel(ximage: XImagePtr; x, y: INT; pixel: CARD32);
 BEGIN
  ximage^.f.putPixel(ximage, x, y, pixel)
 END XPutPixel;

 PROCEDURE XSubImage(ximage: XImagePtr; x, y: INT; width, height: CARD): XImagePtr;
 BEGIN
  RETURN ximage^.f.subImage(ximage, x, y, width, height)
 END XSubImage;

 PROCEDURE XAddPixel(ximage: XImagePtr; value: INT32);
 BEGIN
  ximage^.f.addPixel(ximage, value)
 END XAddPixel;

(*
 * Keysym macros, used on Keysyms to test for classes of symbols
 *)
PROCEDURE IsKeypadKey(keysym: KeySym): BOOLEAN;
BEGIN
 RETURN (keysym >= XKKPSpace) AND (keysym <= XKKPEqual)
END IsKeypadKey;

PROCEDURE IsPrivateKeypadKey(keysym: KeySym): BOOLEAN;
BEGIN
 RETURN (keysym >= 011000000H) AND (keysym <= 01100FFFFH)
END IsPrivateKeypadKey;

PROCEDURE IsCursorKey(keysym: KeySym): BOOLEAN;
BEGIN
 RETURN (keysym >= XKHome) AND (keysym < XKSelect)
END IsCursorKey;

PROCEDURE IsPFKey(keysym: KeySym): BOOLEAN;
BEGIN
 RETURN (keysym >= XKKPF1) AND (keysym <= XKKPF4)
END IsPFKey;

PROCEDURE IsFunctionKey(keysym: KeySym): BOOLEAN;
BEGIN
 RETURN (keysym >= XKF1) AND (keysym <= XKF35)
END IsFunctionKey;

PROCEDURE IsMiscFunctionKey(keysym: KeySym): BOOLEAN;
BEGIN
 RETURN (keysym >= XKSelect) AND (keysym <= XKBreak)
END IsMiscFunctionKey;

PROCEDURE IsModifierKey(keysym: KeySym): BOOLEAN;
BEGIN
 RETURN ((keysym >= XKShiftL) AND (keysym <= XKHyperR))
     OR (keysym = XKModeswitch)
     OR (keysym = XKNumLock)
END IsModifierKey;

(*
#define XUniqueContext()       ((XContext) XrmUniqueQuark())
#define XStringToContext(string)   ((XContext) XrmStringToQuark(string))
*)

END XMacros.

IMPLEMENTATION MODULE FileIO;
(* Logitech V.4.0/SB version by Mike McGaw. 76301.71@compuserve.com *)
(* This file is based on the Terry implementation of the StonyBrook *)
(* QuickMod and Logitech V.3.0 implementations.  Began with SB, and *)
(* made the changes required to suit the Logitech V.4.0 RTS, based  *)
(* on the prior Logitech V.3.0 RTS usage 			    *)

(* This module attempts to provide several potentially non-portable
   facilities for Coco/R.

   (a)  A general file input/output module, with all routines required for
        Coco/R itself, as well as several other that would be useful in
        Coco-generated applications.
   (b)  Definition of the "LONGINT" type needed by Coco.
   (c)  Some conversion functions to handle this long type.
   (d)  Some "long" and other constant literals that may be problematic
        on some implementations.
   (e)  Some string handling primitives needed to interface to a variety
        of known implementations.

   The intention is that the rest of the code of Coco and its generated
   parsers should be as portable as possible.  Provided the definition
   module given, and the associated implementation, satisfy the
   specification given here, this should be almost 100% possible.

   FileIO is based on code by MB 1990/11/25; heavily modified and extended
   by PDT and others between 1992/1/6 and the present day. *)

IMPORT FileSystem, Strings, SYSTEM, RTSMain, Terminal, RTSTerm;
FROM Storage IMPORT ALLOCATE, DEALLOCATE;
FROM RTSTypes IMPORT Status;

CONST
  MaxFiles = BitSetSize;
  NameLength = 256;
  BufSize = 256;

TYPE
  Environ = POINTER TO ARRAY [0 .. 10000] OF CHAR;
  File = POINTER TO FileRec;
  FileRec = RECORD
              ref: FileSystem.File;
              self: File;
              handle: CARDINAL;
              savedCh: CHAR;
              textOK, eof, eol, noOutput, noInput, haveCh: BOOLEAN;
              name: ARRAY [0 .. NameLength] OF CHAR;
            END;

VAR
  Handles: BITSET;
  Opened: ARRAY [0 .. MaxFiles-1] OF File;
  FromKeyboard, ToScreen: BOOLEAN;
  InBuf, OutBuf: ARRAY [0 .. BufSize - 1] OF CHAR;
  InPos, InLen, OutPos: CARDINAL;
  Param: CARDINAL;
  EnvPtr: Environ;
  CmdLine: ARRAY [0 .. 127] OF CHAR;
  CmdIndx, CmdLength: CARDINAL;

PROCEDURE StdInRead (VAR ch: CHAR);
  VAR
    R: SYSTEM.REGISTERS;
    Adr: SYSTEM.ADDRESS;
  BEGIN
    Okay := TRUE;
    IF InPos = InLen THEN
      Adr := SYSTEM.ADR(InBuf);
      R.AX := 3F00H; R.DS := Adr.SEGMENT; R.DX := Adr.OFFSET;
      R.CX := 256; R.BX := 0; SYSTEM.INT(21H, R);
      Okay :=  ~ (0 IN R.FLAGS) & (R.AX # 0);
      InLen := R.AX; InPos := 0
    END;
    IF Okay THEN ch := InBuf[InPos]; INC(InPos) END
  END StdInRead;

PROCEDURE StdOutWrite (ch: CHAR);
(* Buffered write to redirected output *)
  VAR
    R: SYSTEM.REGISTERS;
    Adr: SYSTEM.ADDRESS;
  BEGIN
    Okay := TRUE;
    OutBuf[OutPos] := ch; INC(OutPos);
    IF OutPos = 256 THEN
      OutPos := 0;
      Adr := SYSTEM.ADR(OutBuf);
      R.AX := 4000H; R.DS := Adr.SEGMENT; R.DX := Adr.OFFSET;
      R.CX := 256; R.BX := 1; SYSTEM.INT(21H, R);
      Okay :=  ~ (0 IN R.FLAGS) & (R.AX = 256);
    END;
  END StdOutWrite;

PROCEDURE ErrWrite (ch: CHAR);
  VAR
    R: SYSTEM.REGISTERS;
    Adr: SYSTEM.ADDRESS;
  BEGIN
    Adr := SYSTEM.ADR(ch); R.AX := 4000H;
    R.DS := Adr.SEGMENT; R.DX := Adr.OFFSET;
    R.CX := 1; R.BX := 2; SYSTEM.INT(21H, R);
  END ErrWrite;

PROCEDURE NotRead (f: File): BOOLEAN;
  BEGIN
    RETURN (f = NIL) OR (f^.self # f) OR (f^.noInput);
  END NotRead;

PROCEDURE NotWrite (f: File): BOOLEAN;
  BEGIN
    RETURN (f = NIL) OR (f^.self # f) OR (f^.noOutput);
  END NotWrite;

PROCEDURE NotFile (f: File): BOOLEAN;
  BEGIN
    RETURN (f = NIL) OR (f^.self # f) OR (File(f) = con) OR (File(f) = err)
      OR (File(f) = StdIn) & FromKeyboard
      OR (File(f) = StdOut) & ToScreen
  END NotFile;

PROCEDURE CheckRedirection;
  VAR
    R: SYSTEM.REGISTERS;
  BEGIN
    FromKeyboard := FALSE; ToScreen := FALSE;
    R.AX := 4400H; R.BX := 0; SYSTEM.INT(21H, R);
    IF ~ (0 IN R.FLAGS) THEN
      IF {7, 0} <= BITSET(R.DX) THEN FromKeyboard := TRUE END;
    END;
    R.AX := 4400H; R.BX := 1; SYSTEM.INT(21H, R);
    IF ~ (0 IN R.FLAGS) THEN
      IF {7, 1} <= BITSET(R.DX) THEN ToScreen := TRUE END;
    END;
  END CheckRedirection;

PROCEDURE ASCIIZ (VAR s1, s2: ARRAY OF CHAR);
(* Convert s2 to a nul terminated string in s1 *)
  VAR
    i: CARDINAL;
  BEGIN
    i := 0;
    WHILE (i <= HIGH(s2)) & (s2[i] # 0C) DO
      s1[i] := s2[i]; INC(i)
    END;
    s1[i] := 0C
  END ASCIIZ;

PROCEDURE NextParameter (VAR s: ARRAY OF CHAR);
  VAR
    i: CARDINAL;
  BEGIN
    WHILE (CmdIndx < CmdLength) & (CmdLine[CmdIndx] = " ") DO
      INC(CmdIndx);
    END;
    i := 0;
    IF CmdIndx < CmdLength THEN
      REPEAT
        IF i <= HIGH(s) THEN
          s[i] := CmdLine[CmdIndx];
          INC(i);
        END;
        INC(CmdIndx);
      UNTIL (CmdIndx >= CmdLength) OR (CmdLine[CmdIndx] = " ");
    END;
    IF i <= HIGH(s) THEN s[i] := 0C END;
  END NextParameter;

PROCEDURE GetEnv (envVar: ARRAY OF CHAR; VAR s: ARRAY OF CHAR);
  VAR
    i, j: CARDINAL;
  BEGIN
    i := 0;
    LOOP
      IF EnvPtr^[i] = 0C THEN EXIT END;
      j := 0;
      WHILE (j <= HIGH(envVar)) & (envVar[j] # 0C) & (EnvPtr^[i] = envVar[j]) DO
        INC(i); INC(j);
      END;
      IF ((j > HIGH(envVar)) OR (envVar[j] = 0C)) & (EnvPtr^[i] = "=") THEN
        INC(i); j := 0;
        WHILE (EnvPtr^[i] # 0C) & (j <= HIGH(s)) DO
          s[j] := EnvPtr^[i]; INC(i); INC(j);
        END;
        IF j <= HIGH(s) THEN s[j] := 0C END;
        RETURN;
      ELSE
        WHILE EnvPtr^[i] # 0C DO INC(i) END;
        INC(i);
      END;
    END;
    s[0] := 0C;
  END GetEnv;

PROCEDURE Open (VAR f: File; fileName: ARRAY OF CHAR; newFile: BOOLEAN);
  VAR
    i: CARDINAL;
    name: ARRAY [0 .. NameLength] OF CHAR;
  BEGIN
    ExtractFileName(fileName, name);
    FOR i := 0 TO NameLength - 1 DO name[i] := CAP(name[i]) END;
    IF (name[0] = 0C) OR (Compare(name, "CON") = 0) THEN
      (* con already opened, but reset it *)
      Okay := TRUE; f := con;
      f^.savedCh := 0C; f^.haveCh := FALSE;
      f^.eof := FALSE; f^.eol := FALSE; f^.name := "CON";
      RETURN
    ELSIF Compare(name, "ERR") = 0 THEN
      Okay := TRUE; f := err; RETURN
    ELSE
      ALLOCATE(f, SYSTEM.TSIZE(FileRec));
      IF newFile THEN FileSystem.Delete(fileName, f^.ref) END;
      FileSystem.Lookup(f^.ref, fileName, newFile);
      Okay := f^.ref.res = FileSystem.done;
      IF ~ Okay
        THEN
          DEALLOCATE(f, SYSTEM.TSIZE(FileRec)); f := NIL
        ELSE
      (* textOK below may have to be altered according to implementation *)
          f^.savedCh := 0C; f^.haveCh := FALSE; f^.textOK := TRUE;
          f^.eof := newFile; f^.eol := newFile; f^.self := f;
          f^.noInput := newFile; f^.noOutput := ~ newFile;
          ASCIIZ(f^.name, fileName);
          i := 0 (* find next available filehandle *);
          WHILE (i IN Handles) & (i < MaxFiles) DO INC(i) END;
          IF i < MaxFiles
            THEN f^.handle := i; INCL(Handles, i); Opened[i] := f
            ELSE WriteString(err, "Too many files"); Okay := FALSE
          END;
      END
    END
  END Open;

PROCEDURE Close (VAR f: File);
  BEGIN
    IF NotFile(f) OR (File(f) = StdIn) OR (File(f) = StdOut)
      THEN Okay := FALSE
      ELSE
        EXCL(Handles, f^.handle);
        FileSystem.Close(f^.ref);
        Okay := f^.ref.res = FileSystem.done;
        IF Okay THEN DEALLOCATE(f, SYSTEM.TSIZE(FileRec)) END;
        f := NIL
    END
  END Close;

PROCEDURE Delete (VAR f: File);
  BEGIN
    IF NotFile(f) OR (File(f) = StdIn) OR (File(f) = StdOut)
      THEN Okay := FALSE
      ELSE
        EXCL(Handles, f^.handle);
        FileSystem.Delete(f^.name, f^.ref);
        Okay := f^.ref.res = FileSystem.done;
        IF Okay THEN DEALLOCATE(f, SYSTEM.TSIZE(FileRec)) END;
        f := NIL
    END
  END Delete;

PROCEDURE SearchFile (VAR f: File; envVar, fileName: ARRAY OF CHAR;
                      newFile: BOOLEAN);
  VAR
    i, j: INTEGER;
    k: CARDINAL;
    c: CHAR;
    fname: ARRAY [0 .. NameLength] OF CHAR;
    path: ARRAY [0 .. NameLength] OF CHAR;
  BEGIN
    FOR k := 0 TO HIGH(envVar) DO envVar[k] := CAP(envVar[k]) END;
    GetEnv(envVar, path);
    WHILE path[0] = " " DO Strings.Delete(path, 0, 1) END;
    i := 0;
    REPEAT
      j := 0;
      REPEAT
        c := path[i]; fname[j] := c; INC(i); INC(j)
      UNTIL (c = PathSep) OR (c = 0C);
      IF (j > 1) & (fname[j-2] = DirSep) THEN DEC(j) ELSE fname[j-1] := DirSep END;
      fname[j] := 0C; Concat(fname, fileName, fname);
      Open(f, fname, newFile);
    UNTIL (c = 0C) OR Okay
  END SearchFile;

PROCEDURE ExtractDirectory (fullName: ARRAY OF CHAR;
                            VAR directory: ARRAY OF CHAR);
  VAR
    i, start: CARDINAL;
  BEGIN
    start := 0; i := 0;
    WHILE (i <= HIGH(fullName)) & (fullName[i] # 0C) DO
      IF i <= HIGH(directory) THEN
        directory[i] := fullName[i];
      END;
      IF (fullName[i] = ":") OR (fullName[i] = DirSep) THEN start := i + 1 END;
      INC(i)
    END;
    IF start <= HIGH(directory) THEN directory[start] := 0C END
  END ExtractDirectory;

PROCEDURE ExtractFileName (fullName: ARRAY OF CHAR;
                           VAR fileName: ARRAY OF CHAR);
  VAR
    i, l, start: CARDINAL;
  BEGIN
    start := 0; l := 0;
    WHILE (l <= HIGH(fullName)) & (fullName[l] # 0C) DO
      IF (fullName[l] = ":") OR (fullName[l] = DirSep) THEN start := l + 1 END;
      INC(l)
    END;
    i := 0;
    WHILE (start < l) & (i <= HIGH(fileName)) DO
      fileName[i] := fullName[start]; INC(start); INC(i)
    END;
    IF i <= HIGH(fileName) THEN fileName[i] := 0C END
  END ExtractFileName;

PROCEDURE AppendExtension (oldName, ext: ARRAY OF CHAR;
                           VAR newName: ARRAY OF CHAR);
  VAR
    i, j: CARDINAL;
    fn: ARRAY [0 .. NameLength] OF CHAR;
  BEGIN
    ExtractDirectory(oldName, newName);
    ExtractFileName(oldName, fn);
    i := 0; j := 0;
    WHILE (i <= NameLength) & (fn[i] # 0C) DO
      IF fn[i] = "." THEN j := i + 1 END;
      INC(i)
    END;
    IF (j # i) (* then name did not end with "." *) OR (i = 0) THEN
      IF j # 0 THEN i := j - 1 END;
      IF (ext[0] # ".") & (ext[0] # 0C) THEN
        IF i <= NameLength THEN fn[i] := "."; INC(i) END
      END;
      j := 0;
      WHILE (j <= HIGH(ext)) & (ext[j] # 0C) & (i <= NameLength) DO
        fn[i] := ext[j]; INC(i); INC(j)
      END
    END;
    IF i <= NameLength THEN fn[i] := 0C END;
    Concat(newName, fn, newName)
  END AppendExtension;

PROCEDURE ChangeExtension (oldName, ext: ARRAY OF CHAR;
                           VAR newName: ARRAY OF CHAR);
  VAR
    i, j: CARDINAL;
    fn: ARRAY [0 .. NameLength] OF CHAR;
  BEGIN
    ExtractDirectory(oldName, newName);
    ExtractFileName(oldName, fn);
    i := 0; j := 0;
    WHILE (i <= NameLength) & (fn[i] # 0C) DO
      IF fn[i] = "." THEN j := i + 1 END;
      INC(i)
    END;
    IF j # 0 THEN i := j - 1 END;
    IF (ext[0] # ".") & (ext[0] # 0C) THEN
      IF i <= NameLength THEN fn[i] := "."; INC(i) END
    END;
    j := 0;
    WHILE (j <= HIGH(ext)) & (ext[j] # 0C) & (i <= NameLength) DO
      fn[i] := ext[j]; INC(i); INC(j)
    END;
    IF i <= NameLength THEN fn[i] := 0C END;
    Concat(newName, fn, newName)
  END ChangeExtension;

PROCEDURE Length (f: File): INT32;
  VAR
    high, low: CARDINAL;
  BEGIN
    IF NotFile(f)
      THEN
        Okay := FALSE; RETURN Long0
      ELSE
        FileSystem.Length(f^.ref, high, low);
        Okay := f^.ref.res = FileSystem.done;
        RETURN VAL(LONGINT, high) * VAL(LONGINT, 65536) + VAL(LONGINT, low)
    END
  END Length;

PROCEDURE GetPos (f: File): INT32;
  VAR
    high, low: CARDINAL;
  BEGIN
    IF NotFile(f)
      THEN
        Okay := FALSE; RETURN Long0
      ELSE
        FileSystem.GetPos(f^.ref, high, low);
        Okay := f^.ref.res = FileSystem.done;
        RETURN VAL(LONGINT, high) * VAL(LONGINT, 65536) + VAL(LONGINT, low)
    END
  END GetPos;

PROCEDURE SetPos (f: File; pos: INT32);
  VAR
    high, low: CARDINAL;
  BEGIN
    IF NotFile(f)
      THEN
        Okay := FALSE
      ELSE
        high := VAL(CARDINAL, pos DIV 65536);
        low := VAL(CARDINAL, pos MOD 65536);
        FileSystem.SetPos(f^.ref, high, low);
        Okay := f^.ref.res = FileSystem.done; f^.haveCh := FALSE
    END
  END SetPos;

PROCEDURE Reset (f: File);
  BEGIN
    IF NotFile(f)
      THEN
        Okay := FALSE
      ELSE
        FileSystem.Reset(f^.ref);
        Okay := f^.ref.res = FileSystem.done;
        IF Okay THEN
          f^.haveCh := FALSE; f^.eof := f^.noInput; f^.eol := f^.noInput
        END
    END
  END Reset;

PROCEDURE Rewrite (f: File);
  BEGIN
    IF NotFile(f)
      THEN
        Okay := FALSE
      ELSE
        FileSystem.Delete(f^.name, f^.ref);
        FileSystem.Lookup(f^.ref, f^.name, TRUE);
        Okay := f^.ref.res = FileSystem.done;
        IF Okay THEN
          f^.haveCh := FALSE; f^.savedCh := 0C;
          f^.eof := FALSE; f^.eol := FALSE
        END
    END
  END Rewrite;

PROCEDURE EndOfLine (f: File): BOOLEAN;
  BEGIN
    IF NotRead(f)
      THEN Okay := FALSE; RETURN TRUE
      ELSE Okay := TRUE; RETURN f^.eol OR f^.eof
    END
  END EndOfLine;

PROCEDURE EndOfFile (f: File): BOOLEAN;
  BEGIN
    IF NotRead(f)
      THEN Okay := FALSE; RETURN TRUE
      ELSE Okay := TRUE; RETURN f^.eof
    END
  END EndOfFile;

PROCEDURE Read (f: File; VAR ch: CHAR);
  BEGIN
    IF NotRead(f) THEN Okay := FALSE; ch := 0C; RETURN END;
    IF f^.haveCh OR f^.eof
      THEN
        ch := f^.savedCh; Okay := ch # 0C;
      ELSE
        IF (File(f) = con) OR (File(f) = StdIn) & FromKeyboard
          THEN
            Terminal.Read(ch);
            IF ch = CR THEN ch := EOL END;
            Write(con, ch);
            IF ch = BS THEN Terminal.Write(" "); Terminal.Write(BS) END;
            Okay := ch # EOFChar;
        ELSIF (f = File(StdIn))
          THEN
            StdInRead(ch);
            IF ch = EOFChar THEN Okay := FALSE END;
            IF ch = CR THEN StdInRead(ch); ch := EOL END
          ELSE
            FileSystem.ReadChar(f^.ref, ch);
            Okay := f^.ref.res = FileSystem.done;
        END;
    END;
    IF ~ Okay THEN ch := 0C END;
    f^.savedCh := ch; f^.haveCh := ~ Okay;
    f^.eof := ch = 0C; f^.eol := f^.eof OR (ch = EOL);
  END Read;

PROCEDURE ReadAgain (f: File);
  BEGIN
    IF NotRead(f)
      THEN Okay := FALSE
      ELSE f^.haveCh := TRUE
    END
  END ReadAgain;

PROCEDURE ReadLn (f: File);
  VAR
    ch: CHAR;
  BEGIN
    IF NotRead(f) THEN Okay := FALSE; RETURN END;
    WHILE ~ f^.eol DO Read(f, ch) END;
    f^.haveCh := FALSE; f^.eol := FALSE;
  END ReadLn;

PROCEDURE ReadString (f: File; VAR str: ARRAY OF CHAR);
  VAR
    j: CARDINAL;
    ch: CHAR;
  BEGIN
    str[0] := 0C; j := 0;
    IF NotRead(f) THEN Okay := FALSE; RETURN END;
    REPEAT Read(f, ch) UNTIL (ch # " ") OR ~ Okay;
    IF Okay THEN
      WHILE ch >= " " DO
        IF j <= HIGH(str) THEN str[j] := ch END; INC(j);
        Read(f, ch);
        WHILE (ch = BS) OR (ch = DEL) DO
          IF j > 0 THEN DEC(j) END; Read(f, ch)
        END
      END;
      IF j <= HIGH(str) THEN str[j] := 0C END;
      Okay := j > 0; f^.haveCh := TRUE; f^.savedCh := ch;
    END
  END ReadString;

PROCEDURE ReadLine (f: File; VAR str: ARRAY OF CHAR);
  VAR
    j: CARDINAL;
    ch: CHAR;
  BEGIN
    str[0] := 0C; j := 0;
    IF NotRead(f) THEN Okay := FALSE; RETURN END;
    Read(f, ch);
    IF Okay THEN
      WHILE ch >= " " DO
        IF j <= HIGH(str) THEN str[j] := ch END; INC(j);
        Read(f, ch);
        WHILE (ch = BS) OR (ch = DEL) DO
          IF j > 0 THEN DEC(j) END; Read(f, ch)
        END
      END;
      IF j <= HIGH(str) THEN str[j] := 0C END;
      Okay := j > 0; f^.haveCh := TRUE; f^.savedCh := ch;
    END
  END ReadLine;

PROCEDURE ReadToken (f: File; VAR str: ARRAY OF CHAR);
  VAR
    j: CARDINAL;
    ch: CHAR;
  BEGIN
    str[0] := 0C; j := 0;
    IF NotRead(f) THEN Okay := FALSE; RETURN END;
    REPEAT Read(f, ch) UNTIL (ch > " ") OR ~ Okay;
    IF Okay THEN
      WHILE ch > " " DO
        IF j <= HIGH(str) THEN str[j] := ch END; INC(j);
        Read(f, ch);
        WHILE (ch = BS) OR (ch = DEL) DO
          IF j > 0 THEN DEC(j) END; Read(f, ch)
        END
      END;
      IF j <= HIGH(str) THEN str[j] := 0C END;
      Okay := j > 0; f^.haveCh := TRUE; f^.savedCh := ch;
    END
  END ReadToken;

PROCEDURE ReadInt (f: File; VAR i: INTEGER);
  VAR
    Digit: INTEGER;
    j: CARDINAL;
    Negative: BOOLEAN;
    s: ARRAY [0 .. 80] OF CHAR;
  BEGIN
    i := 0; j := 0;
    IF NotRead(f) THEN Okay := FALSE; RETURN END;
    ReadToken(f, s);
    IF s[0] = "-" (* deal with sign *)
      THEN Negative := TRUE; INC(j)
      ELSE Negative := FALSE; IF s[0] = "+" THEN INC(j) END
    END;
    IF (s[j] < "0") OR (s[j] > "9") THEN Okay := FALSE END;
    WHILE (j <= 80) & (s[j] >= "0") & (s[j] <= "9") DO
      Digit := VAL(INTEGER, ORD(s[j]) - ORD("0"));
      IF i <= (MAX(INTEGER) - Digit) DIV 10
        THEN i := 10 * i + Digit
        ELSE Okay := FALSE
      END;
      INC(j)
    END;
    IF Negative THEN i := -i END;
    IF (j > 80) OR (s[j] # 0C) THEN Okay := FALSE END;
    IF ~ Okay THEN i := 0 END;
  END ReadInt;

PROCEDURE ReadCard (f: File; VAR i: CARDINAL);
  VAR
    Digit: CARDINAL;
    j: CARDINAL;
    s: ARRAY [0 .. 80] OF CHAR;
  BEGIN
    i := 0; j := 0;
    IF NotRead(f) THEN Okay := FALSE; RETURN END;
    ReadToken(f, s);
    WHILE (j <= 80) & (s[j] >= "0") & (s[j] <= "9") DO
      Digit := ORD(s[j]) - ORD("0");
      IF i <= (MAX(CARDINAL) - Digit) DIV 10
        THEN i := 10 * i + Digit
        ELSE Okay := FALSE
      END;
      INC(j)
    END;
    IF (j > 80) OR (s[j] # 0C) THEN Okay := FALSE END;
    IF ~ Okay THEN i := 0 END;
  END ReadCard;

PROCEDURE ReadBytes (f: File; VAR buf: ARRAY OF SYSTEM.BYTE; VAR len: CARDINAL);
  VAR
    TooMany: BOOLEAN;
    Wanted: CARDINAL;
  BEGIN
    IF NotRead(f) OR (File(f) = con)
      THEN Okay := FALSE; len := 0;
      ELSE
        IF len = 0 THEN Okay := TRUE; RETURN END;
        TooMany := len - 1 > HIGH(buf);
        IF TooMany THEN Wanted := HIGH(buf) + 1 ELSE Wanted := len END;
        FileSystem.ReadNBytes(f^.ref, SYSTEM.ADR(buf), Wanted, len);
        Okay := f^.ref.res = FileSystem.done;
        IF len # Wanted THEN Okay := FALSE END;
    END;
    IF ~ Okay THEN f^.eof := TRUE END;
    IF TooMany THEN Okay := FALSE END;
  END ReadBytes;

PROCEDURE Write (f: File; ch: CHAR);
  BEGIN
    IF NotWrite(f) THEN Okay := FALSE; RETURN END;
    IF (File(f) = con) OR (File(f) = StdOut) & ToScreen
      THEN
        IF ch = EOL
          THEN Terminal.Write(CR); Terminal.Write(LF)
          ELSE Terminal.Write(ch)
        END;
        Okay := TRUE;
      ELSIF File(f) = err
        THEN
          IF ch = EOL
            THEN ErrWrite(CR); ErrWrite(LF)
            ELSE ErrWrite(ch)
          END;
          Okay := TRUE;
      ELSIF File(f) = StdOut
        THEN
          IF ch = EOL
            THEN StdOutWrite(CR); StdOutWrite(LF)
            ELSE StdOutWrite(ch)
          END;
      ELSE
        FileSystem.WriteChar(f^.ref, ch);
        Okay := f^.ref.res = FileSystem.done
    END;
  END Write;

PROCEDURE WriteLn (f: File);
  BEGIN
    IF NotWrite(f)
      THEN Okay := FALSE;
      ELSE Write(f, EOL)
    END
  END WriteLn;

PROCEDURE WriteString (f: File; str: ARRAY OF CHAR);
  VAR
    pos: CARDINAL;
  BEGIN
    IF NotWrite(f) THEN Okay := FALSE; RETURN END;
    pos := 0;
    WHILE (pos <= HIGH(str)) & (str[pos] # 0C) DO
      Write(f, str[pos]); INC(pos)
    END
  END WriteString;

PROCEDURE WriteText (f: File; text: ARRAY OF CHAR; len: INTEGER);
  VAR
    i, slen: INTEGER;
  BEGIN
    IF NotWrite(f) THEN Okay := FALSE; RETURN END;
    slen := Strings.Length(text);
    FOR i := 0 TO len - 1 DO
      IF i < slen THEN Write(f, text[i]) ELSE Write(f, " ") END;
    END
  END WriteText;

PROCEDURE WriteInt (f: File; n: INTEGER; wid: CARDINAL);
  VAR
    l, d: CARDINAL;
    x: INTEGER;
    t: ARRAY [1 .. 25] OF CHAR;
    sign: CHAR;
  BEGIN
    IF NotWrite(f) THEN Okay := FALSE; RETURN END;
    IF n < 0
      THEN sign := "-"; x := - n;
      ELSE sign := " "; x := n;
    END;
    l := 0;
    REPEAT
      d := x MOD 10; x := x DIV 10;
      INC(l); t[l] := CHR(ORD("0") + d);
    UNTIL x = 0;
    IF wid = 0 THEN Write(f, " ") END;
    WHILE wid > l + 1 DO Write(f, " "); DEC(wid); END;
    IF (sign = "-") OR (wid > l) THEN Write(f, sign); END;
    WHILE l > 0 DO Write(f, t[l]); DEC(l); END;
  END WriteInt;

PROCEDURE WriteCard (f: File; n, wid: CARDINAL);
  VAR
    l, d: CARDINAL;
    t: ARRAY [1 .. 25] OF CHAR;
  BEGIN
    IF NotWrite(f) THEN Okay := FALSE; RETURN END;
    l := 0;
    REPEAT
      d := n MOD 10; n := n DIV 10;
      INC(l); t[l] := CHR(ORD("0") + d);
    UNTIL n = 0;
    IF wid = 0 THEN Write(f, " ") END;
    WHILE wid > l DO Write(f, " "); DEC(wid); END;
    WHILE l > 0 DO Write(f, t[l]); DEC(l); END;
  END WriteCard;

PROCEDURE WriteBytes (f: File; VAR buf: ARRAY OF SYSTEM.BYTE; len: CARDINAL);
  VAR
    TooMany: BOOLEAN;
  BEGIN
    TooMany := (len > 0) & (len - 1 > HIGH(buf));
    IF NotWrite(f) OR (File(f) = con) OR (File(f) = err)
      THEN
        Okay := FALSE
      ELSE
        IF TooMany THEN len := HIGH(buf) + 1 END;
        FileSystem.WriteNBytes(f^.ref, SYSTEM.ADR(buf), len, len);
        Okay := f^.ref.res = FileSystem.done
    END;
    IF TooMany THEN Okay := FALSE END;
  END WriteBytes;

PROCEDURE GetDate (VAR Year, Month, Day: CARDINAL);
  VAR
    R: SYSTEM.REGISTERS;
  BEGIN
    R.AX := 2A00H;
    SYSTEM.INT(21H, R);
    Year := R.CX;
    Month := R.DX DIV 256;
    Day := R.DX MOD 256;
  END GetDate;

PROCEDURE GetTime (VAR Hrs, Mins, Secs, Hsecs: CARDINAL);
  VAR
    R: SYSTEM.REGISTERS;
  BEGIN
    R.AX := 2C00H;
    SYSTEM.INT(21H, R);
    Hrs := R.CX DIV 256;
    Mins := R.CX MOD 256;
    Secs := R.DX DIV 256;
    Hsecs := R.DX MOD 256;
  END GetTime;

PROCEDURE Write2 (f: File; i: CARDINAL);
  BEGIN
    Write(f, CHR(i DIV 10 + ORD("0")));
    Write(f, CHR(i MOD 10 + ORD("0")));
  END Write2;

PROCEDURE WriteDate (f: File);
  VAR
    Year, Month, Day: CARDINAL;
  BEGIN
    IF NotWrite(f) THEN Okay := FALSE; RETURN END;
    GetDate(Year, Month, Day);
    Write2(f, Day); Write(f, "/"); Write2(f, Month); Write(f, "/");
    WriteCard(f, Year, 1)
  END WriteDate;

PROCEDURE WriteTime (f: File);
  VAR
    Hrs, Mins, Secs, Hsecs: CARDINAL;
  BEGIN
    IF NotWrite(f) THEN Okay := FALSE; RETURN END;
    GetTime(Hrs, Mins, Secs, Hsecs);
    Write2(f, Hrs); Write(f, ":"); Write2(f, Mins); Write(f, ":");
    Write2(f, Secs)
  END WriteTime;

VAR
  Hrs0, Mins0, Secs0, Hsecs0: CARDINAL;
  Hrs1, Mins1, Secs1, Hsecs1: CARDINAL;

PROCEDURE WriteElapsedTime (f: File);
  VAR
    Hrs, Mins, Secs, Hsecs, s, hs: CARDINAL;
  BEGIN
    IF NotWrite(f) THEN Okay := FALSE; RETURN END;
    GetTime(Hrs, Mins, Secs, Hsecs);
    WriteString(f, "Elapsed time: ");
    IF Hrs >= Hrs1
      THEN s := (Hrs - Hrs1) * 3600 + (Mins - Mins1) * 60 + Secs - Secs1
      ELSE s := (Hrs + 24 - Hrs1) * 3600 + (Mins - Mins1) * 60 + Secs - Secs1
    END;
    IF Hsecs >= Hsecs1
      THEN hs := Hsecs - Hsecs1
      ELSE hs := (Hsecs + 100) - Hsecs1; DEC(s);
    END;
    WriteCard(f, s, 1); Write(f, ".");
    Write2(f, hs); WriteString(f, " s"); WriteLn(f);
    Hrs1 := Hrs; Mins1 := Mins; Secs1 := Secs; Hsecs1 := Hsecs;
  END WriteElapsedTime;

PROCEDURE WriteExecutionTime (f: File);
  VAR
    Hrs, Mins, Secs, Hsecs, s, hs: CARDINAL;
  BEGIN
    IF NotWrite(f) THEN Okay := FALSE; RETURN END;
    GetTime(Hrs, Mins, Secs, Hsecs);
    WriteString(f, "Execution time: ");
    IF Hrs >= Hrs0
      THEN s := (Hrs - Hrs0) * 3600 + (Mins - Mins0) * 60 + Secs - Secs0
      ELSE s := (Hrs + 24 - Hrs0) * 3600 + (Mins - Mins0) * 60 + Secs - Secs0
    END;
    IF Hsecs >= Hsecs0
      THEN hs := Hsecs - Hsecs0
      ELSE hs := (Hsecs + 100) - Hsecs0; DEC(s);
    END;
    WriteCard(f, s, 1); Write(f, "."); Write2(f, hs);
    WriteString(f, " s"); WriteLn(f);
  END WriteExecutionTime;

(* The code for the next four procedures below may be commented out if your
   compiler supports ISO PROCEDURE constant declarations and these declarations
   are made in the DEFINITION MODULE *)

PROCEDURE SLENGTH (stringVal: ARRAY OF CHAR): CARDINAL;
  BEGIN
    RETURN Strings.Length(stringVal)
  END SLENGTH;

PROCEDURE Assign (source: ARRAY OF CHAR; VAR destination: ARRAY OF CHAR);
  BEGIN
  (* Be careful - some libraries have the parameters reversed! *)
    Strings.Assign(source, destination)
  END Assign;

PROCEDURE Extract (source: ARRAY OF CHAR; startIndex: CARDINAL;
                   numberToExtract: CARDINAL; VAR destination: ARRAY OF CHAR);
  BEGIN
    Strings.Copy(source, startIndex, numberToExtract, destination)
  END Extract;

PROCEDURE Concat (source1, source2: ARRAY OF CHAR; VAR destination: ARRAY OF CHAR);
  BEGIN
    Strings.Concat(source1, source2, destination);
  END Concat;

(* The code for the four procedures above may be commented out if your
   compiler supports ISO PROCEDURE constant declarations and these declarations
   are made in the DEFINITION MODULE *)

PROCEDURE Compare (stringVal1, stringVal2: ARRAY OF CHAR): INTEGER;
  BEGIN
    RETURN Strings.CompareStr(stringVal1, stringVal2)
  END Compare;

PROCEDURE ORDL (n: INT32): CARDINAL;
   BEGIN RETURN VAL(CARDINAL, n) END ORDL;

PROCEDURE INTL (n: INT32): INTEGER;
   BEGIN RETURN VAL(INTEGER, n) END INTL;

PROCEDURE INT (n: CARDINAL): INT32;
   BEGIN RETURN VAL(INT32, n) END INT;

PROCEDURE CloseAll;
  VAR
    handle: CARDINAL;
    R: SYSTEM.REGISTERS;
    Adr: SYSTEM.ADDRESS;
  BEGIN
    FOR handle := 0 TO MaxFiles - 1 DO
      IF handle IN Handles THEN Close(Opened[handle]) END
    END;
    IF ~ ToScreen THEN
      Adr := SYSTEM.ADR(OutBuf);
      R.AX := 4000H; R.DS := Adr.SEGMENT; R.DX := Adr.OFFSET;
      R.CX := OutPos; R.BX := 1; SYSTEM.INT(21H, R);
      R.AX := 3E00H; R.BX := 1; SYSTEM.INT(21H, R) (* Close stdout *)
    END;
  END CloseAll;

PROCEDURE QuitExecution;
  BEGIN
    RTSTerm.Terminate(Normal)
  END QuitExecution;

PROCEDURE GetCommandLine (VAR CmdLine: ARRAY OF CHAR);
  TYPE
    PSP = POINTER TO ARRAY [0 .. 255] OF CHAR;
  VAR
    i, l: CARDINAL;
    PSPptr: PSP;
  BEGIN
    PSPptr := PSP(RTSMain.cmdLinePtr.addr);
    l := ORD(PSPptr^[128]);
    FOR i := 1 TO l DO CmdLine[i-1] := PSPptr^[i+128] END;
    CmdLine[l] := 0C;
  END GetCommandLine;

PROCEDURE GetEnvPtr (VAR EnvPtr: Environ);
  VAR
    PSPPtr: RECORD
              CASE :CARDINAL OF
                0: addr: SYSTEM.ADDRESS;
              | 1: offset, base: CARDINAL;
              END;
            END;
  BEGIN
    PSPPtr.addr := RTSMain.cmdLinePtr.addr; INC(PSPPtr.addr, 44);
    PSPPtr.base := CARDINAL(PSPPtr.addr^); PSPPtr.offset := 0;
    EnvPtr := Environ(PSPPtr.addr);
  END GetEnvPtr;

BEGIN
  CheckRedirection; (* Not apparently available on many systems *)
  GetTime(Hrs0, Mins0, Secs0, Hsecs0);
  Hrs1 := Hrs0; Mins1 := Mins0; Secs1 := Secs0; Hsecs1 := Hsecs0;
  Handles := BITSET{};
  Okay := FALSE; EOFChar := 32C;
  InPos := 0; InLen := 0; OutPos := 0;
  Param := 0;
  GetCommandLine(CmdLine); GetEnvPtr(EnvPtr);
  CmdIndx := 0; CmdLength := Strings.Length(CmdLine);

  ALLOCATE(con, SYSTEM.TSIZE(FileRec));
  con^.savedCh := 0C; con^.haveCh := FALSE; con^.self := con;
  con^.noOutput := FALSE; con^.noInput := FALSE; con^.textOK := TRUE;
  con^.eof := FALSE; con^.eol := FALSE;

  ALLOCATE(StdIn, SYSTEM.TSIZE(FileRec));
  StdIn^.savedCh := 0C; StdIn^.haveCh := FALSE; StdIn^.self := StdIn;
  StdIn^.noOutput := TRUE; StdIn^.noInput := FALSE; StdIn^.textOK := TRUE;
  StdIn^.eof := FALSE; StdIn^.eol := FALSE;

  ALLOCATE(StdOut, SYSTEM.TSIZE(FileRec));
  StdOut^.savedCh := 0C; StdOut^.haveCh := FALSE; StdOut^.self := StdOut;
  StdOut^.noOutput := FALSE; StdOut^.noInput := TRUE; StdOut^.textOK := TRUE;
  StdOut^.eof := TRUE; StdOut^.eol := TRUE;

  ALLOCATE(err, SYSTEM.TSIZE(FileRec));
  err^.savedCh := 0C; err^.haveCh := FALSE; err^.self := err;
  err^.noOutput := FALSE; err^.noInput := TRUE; err^.textOK := TRUE;
  err^.eof := TRUE; err^.eol := TRUE;

  RTSTerm.InstallTermProc(CloseAll);
END FileIO.

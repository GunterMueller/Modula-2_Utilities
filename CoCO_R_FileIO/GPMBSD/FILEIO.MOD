IMPLEMENTATION MODULE FileIO;
(* GPM Linux/freeBSD Modula version by Pat Terry.  cspt@cs.ru.ac.za 1995-09-15 *)

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

IMPORT UxFiles, UxHandles, Strings, SYSTEM, StdFiles, GpFiles, SysClock, 
       ProgArgs, LIBC;
FROM Storage IMPORT ALLOCATE, DEALLOCATE;

CONST
  MaxFiles = BitSetSize;
  NameLength = 256;
  notImp = "Delete not implemented in this version";
  TermFD = 3; (* risky! *)

TYPE
  File = POINTER TO FileRec;
  FileRec = RECORD
              ref: UxFiles.File;
              self: File;
              handle: CARDINAL;
              savedCh: CHAR;
              textOK, eof, eol, noOutput, noInput, haveCh: BOOLEAN;
              name: ARRAY [0 .. NameLength] OF CHAR;
            END;

VAR
  Handles: BITSET;
  Opened: ARRAY [0 .. MaxFiles-1] OF File;
  FromKeyboard, ToScreen, BreakEnabled: BOOLEAN;
  Param: CARDINAL;
  numPar: CARDINAL;
  Erase, Kill, EndInput, Intr: CHAR;
  termioOrig, termioNew, termioProbe: LIBC.TermIO;
  reply: INTEGER;

PROCEDURE ErrWrite (ch: CHAR);
  BEGIN
    UxFiles.WriteByte(err^.ref, ch);
    UxHandles.FlushStream(err^.ref, Okay);
  END ErrWrite;

PROCEDURE ConWrite (ch: CHAR);
  BEGIN
    UxFiles.WriteByte(con^.ref, ch);
    UxHandles.FlushStream(con^.ref, Okay);
  END ConWrite;

PROCEDURE ConRead (VAR ch: CHAR);
  BEGIN
    reply := LIBC.tcsetattr(TermFD, 0, termioNew);
    UxFiles.ReadByte(con^.ref, ch);
    reply := LIBC.tcsetattr(TermFD, 0, termioOrig);
    IF ch = CR THEN ch := EOL END;
    IF (ch = Intr) & BreakEnabled THEN HALT END;
  END ConRead;

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
    RETURN (f = NIL) OR (f^.self # f) OR (f = con) OR (f = err)
      OR (f = StdIn) & FromKeyboard
      OR (f = StdOut) & ToScreen
  END NotFile;

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
  BEGIN
    INC(Param);
    IF Param < numPar
      THEN ProgArgs.GetArg(Param,s);
      ELSE s[0] := 0C
    END
  END NextParameter;

PROCEDURE GetEnv (var: ARRAY OF CHAR; VAR val: ARRAY OF CHAR);
  BEGIN
    ProgArgs.EnvironString(var, val);
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
      IF newFile
        THEN GpFiles.GpCreateFile(fileName, "", f^.name, f^.ref);
        ELSE GpFiles.GpFindLocal(fileName, "", f^.name, f^.ref);
      END;
      Okay := f^.ref # NIL;
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
    IF NotFile(f) OR (f = StdIn) OR (f = StdOut)
      THEN Okay := FALSE
      ELSE
        EXCL(Handles, f^.handle);
        UxFiles.Close(f^.ref, Okay);
        IF Okay THEN DEALLOCATE(f, SYSTEM.TSIZE(FileRec)) END;
        f := NIL
    END
  END Close;

PROCEDURE Delete (VAR f: File);
  BEGIN 
    ProgArgs.Assert(FALSE, notImp);
    (* UxFiles wants a filename! *)
(*
    IF NotFile(f) OR (f = StdIn) OR (f = StdOut)
      THEN Okay := FALSE
      ELSE WriteString(err, "FileIO.Delete not implemented")
    END;
    Okay := FALSE; f := NIL
*)
  END Delete;

(* The following utility procedure is not used by Coco, but may be useful.
   It is unique to the Gardens Point version, and is non portable *)

PROCEDURE GetUxFile (f: File): UxFiles.File;
  BEGIN
    IF (f = NIL) OR (f^.self # f) 
      THEN Okay := FALSE; RETURN NIL
      ELSE Okay := TRUE;  RETURN f^.ref
    END
  END GetUxFile;

PROCEDURE SearchFile (VAR f: File; env, name: ARRAY OF CHAR; output: BOOLEAN);
  VAR
    fname: ARRAY [0 .. NameLength] OF CHAR;
    path: ARRAY [0 .. NameLength] OF CHAR;
    temp: UxFiles.File;
  BEGIN
    ProgArgs.EnvironString(env, path);
    GpFiles.GpFindOnPath(path, name, "", fname, temp);
    IF temp # NIL 
      THEN UxFiles.Close(temp, Okay); Open(f, fname, output);
      ELSE Okay := FALSE;
    END
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
    pos, len: INTEGER;
  BEGIN
    IF NotFile(f)
      THEN Okay := FALSE; RETURN Long0
      ELSE Okay := TRUE;  RETURN StdFiles.Length(f^.ref)
    END
  END Length;

PROCEDURE GetPos (f: File): INT32;
  VAR
    pos: CARDINAL;
  BEGIN
    IF NotFile(f)
      THEN Okay := FALSE; RETURN Long0
      ELSE UxFiles.GetPos(f^.ref, pos);
    END;
    RETURN VAL(INT32, pos);
  END GetPos;

PROCEDURE SetPos (f: File; pos: INT32);
  BEGIN
    IF NotFile(f)
      THEN Okay := FALSE
      ELSE UxFiles.SetPos(f^.ref, pos); f^.haveCh := FALSE
    END
  END SetPos;

PROCEDURE Reset (f: File);
  BEGIN
    IF NotFile(f)
      THEN
        Okay := FALSE
      ELSE
        SetPos(f, 0);
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
        UxFiles.Close(f^.ref, Okay);
        UxFiles.Open(f^.ref, f^.name, UxFiles.WriteOnly, Okay);  
        IF ~ Okay
          THEN
            DEALLOCATE(f, SYSTEM.TSIZE(FileRec)); f := NIL
          ELSE
            f^.savedCh := 0C; f^.haveCh := FALSE;
            f^.eof := TRUE; f^.eol := TRUE; 
            f^.noInput := TRUE; f^.noOutput := FALSE;
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
        IF (f = con) OR (f = StdIn) & FromKeyboard 
          THEN
            ConRead(ch); ConWrite(ch); 
            IF ch = Erase THEN 
              IF ch # BS THEN ConWrite(BS) END; 
              ConWrite(" "); ConWrite(BS) 
            END;
            Okay := ch # EndInput;
          ELSE
            UxFiles.ReadByte(f^.ref, ch);
            IF (ch = 377C) AND UxFiles.EndFile(f^.ref) THEN Okay := FALSE END;
            IF ch = CR THEN ch := EOL END;
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
        WHILE ch = Erase DO 
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
        WHILE ch = Erase DO 
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
        WHILE ch = Erase DO 
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
    IF NotRead(f) OR (f = con)
      THEN Okay := FALSE; len := 0;
      ELSE
        IF len = 0 THEN Okay := TRUE; RETURN END;
        TooMany := len - 1 > HIGH(buf);
        IF TooMany THEN Wanted := HIGH(buf) + 1 ELSE Wanted := len END;
        UxFiles.ReadNBytes(f^.ref, SYSTEM.ADR(buf), Wanted, len);
        Okay := len # 0;
        IF len # Wanted THEN Okay := FALSE END;
        len := Wanted;
    END;
    IF ~ Okay THEN f^.eof := TRUE END;
    IF TooMany THEN Okay := FALSE END;
  END ReadBytes;

PROCEDURE Write (f: File; ch: CHAR);
  BEGIN
    IF NotWrite(f) THEN Okay := FALSE; RETURN END;
    IF ch = EOL THEN ch := LF END;
    IF (f = con) OR (f = StdOut) & ToScreen 
      THEN  ConWrite(ch); Okay := TRUE;
      ELSIF f = err THEN ErrWrite(ch); Okay := TRUE;
      ELSE  UxFiles.WriteByte(f^.ref, ch);
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
    slen := LENGTH(text);
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
    num: CARDINAL;
  BEGIN
    TooMany := (len > 0) & (len - 1 > HIGH(buf));
    IF NotWrite(f) OR (f = con) OR (f = err)
      THEN
        Okay := FALSE
      ELSE
        IF TooMany THEN len := HIGH(buf) + 1 END;
        UxFiles.WriteNBytes(f^.ref, SYSTEM.ADR(buf), len, num);
        Okay := num = len;
    END;
    IF TooMany THEN Okay := FALSE END;
  END WriteBytes;

PROCEDURE GetDate (VAR Year, Month, Day: CARDINAL);
  VAR
    time: SysClock.DateTime;
  BEGIN
    SysClock.GetClock(time);
    Year  := time.year;
    Month := time.month;
    Day   := time.day;
  END GetDate;

PROCEDURE GetTime (VAR Hrs, Mins, Secs, Hsecs: CARDINAL);
  VAR
    time: SysClock.DateTime;
  BEGIN
    SysClock.GetClock(time);
    Hrs   := time.hour;
    Mins  := time.minute;
    Secs  := time.second;
    Hsecs := time.fractions;
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
    Strings.Extract(source, startIndex, numberToExtract, destination);
  END Extract;

PROCEDURE Concat (source1, source2: ARRAY OF CHAR; VAR destination: ARRAY OF CHAR);
  BEGIN
    Strings.Assign(source1, destination);
    Strings.Append(source2, destination);
  END Concat;

(* The code for the four procedures above may be commented out if your
   compiler supports ISO PROCEDURE constant declarations and these declarations
   are made in the DEFINITION MODULE *)

PROCEDURE Compare (stringVal1, stringVal2: ARRAY OF CHAR): INTEGER;
  BEGIN
    RETURN VAL(INTEGER, Strings.Compare(stringVal1, stringVal2)) - 1;
  END Compare;

PROCEDURE ORDL (n: INT32): CARDINAL;
   BEGIN RETURN VAL(CARDINAL, n) END ORDL;

PROCEDURE INTL (n: INT32): INTEGER;
   BEGIN RETURN VAL(INTEGER, n) END INTL;

PROCEDURE INT (n: CARDINAL): INT32;
   BEGIN RETURN VAL(INT32, n) END INT;

PROCEDURE InitTTY;
  VAR
    termName: ARRAY [0 .. 30] OF CHAR;
  BEGIN
    reply := LIBC.tcgetattr(TermFD, termioOrig); (* terminal characteristics *)
    Erase := termioOrig.CC[LIBC.ERASE];
    Kill := termioOrig.CC[LIBC.KILL];
    EndInput := termioOrig.CC[LIBC.EOF];
    Intr := termioOrig.CC[LIBC.INTR];
    BreakEnabled := LIBC.ISIG IN termioOrig.LFlag;
    termioNew := termioOrig;            (* retain so can reset later *)
    EXCL(termioNew.LFlag, LIBC.ISIG);
    EXCL(termioNew.LFlag, LIBC.ICANON);
    EXCL(termioNew.LFlag, LIBC.ECHO); (* stty -isig -echo -canon *)
  END InitTTY;

PROCEDURE CloseAll;
  VAR
    handle: CARDINAL;
  BEGIN
    FOR handle := 0 TO MaxFiles - 1 DO
      IF handle IN Handles THEN UxFiles.Close(Opened[handle]^.ref, Okay) END
    END;
    reply := LIBC.tcsetattr(TermFD, 0, termioOrig);
  END CloseAll;

PROCEDURE QuitExecution;
  BEGIN
    HALT
  END QuitExecution;

BEGIN
  GetTime(Hrs0, Mins0, Secs0, Hsecs0);
  Hrs1 := Hrs0; Mins1 := Mins0; Secs1 := Secs0; Hsecs1 := Hsecs0;
  Handles := BITSET{};
  Okay := FALSE; EOFChar := 04C;
  Param := 0;
  numPar := ProgArgs.ArgNumber();

  ALLOCATE(con, SYSTEM.TSIZE(FileRec));
  UxFiles.Open(con^.ref, "/dev/tty", UxFiles.ReadWrite, Okay);
  con^.savedCh := 0C; con^.haveCh := FALSE; con^.self := con;
  con^.noOutput := FALSE; con^.noInput := FALSE; con^.textOK := TRUE;
  con^.eof := FALSE; con^.eol := FALSE;
  InitTTY;

  ALLOCATE(StdIn, SYSTEM.TSIZE(FileRec));
  StdIn^.ref := StdFiles.StreamOfStdIn(); 
  StdIn^.savedCh := 0C; StdIn^.haveCh := FALSE; StdIn^.self := StdIn;
  StdIn^.noOutput := TRUE; StdIn^.noInput := FALSE; StdIn^.textOK := TRUE;
  StdIn^.eof := FALSE; StdIn^.eol := FALSE;
  FromKeyboard := LIBC.tcgetattr(0, termioProbe) = 0; (* probe redirection *);

  ALLOCATE(StdOut, SYSTEM.TSIZE(FileRec));
  StdOut^.ref := StdFiles.StreamOfStdOut();   
  StdOut^.savedCh := 0C; StdOut^.haveCh := FALSE; StdOut^.self := StdOut;
  StdOut^.noOutput := FALSE; StdOut^.noInput := TRUE; StdOut^.textOK := TRUE;
  StdOut^.eof := TRUE; StdOut^.eol := TRUE;
  ToScreen := LIBC.tcgetattr(1, termioProbe) = 0; (* probe redirection *);

  ALLOCATE(err, SYSTEM.TSIZE(FileRec));
  err^.ref := StdFiles.StreamOfStdErr(); 
  err^.savedCh := 0C; err^.haveCh := FALSE; err^.self := err;
  err^.noOutput := FALSE; err^.noInput := TRUE; err^.textOK := TRUE;
  err^.eof := TRUE; err^.eol := TRUE;

  reply := LIBC.atexit(CloseAll); 
END FileIO.

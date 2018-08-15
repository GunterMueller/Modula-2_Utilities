/* This is the source file for <StdFiles>       */
/* StdFiles is a helper library for gpm-pc      */
/* It requires Turbo-C 5.x and an assembler     */
/* editted by kjg 30-May-89                     */

#pragma inline
#include <dos.h>

/***********************************************
 * -------------- Extern Data ---------------- *
 ***********************************************/

struct FILEStruct
          {int  handle;
           char open;
           char done;
	  };

typedef struct FILEStruct *File;
struct FILEStruct StdHandles[3] = {{0, '\1', '\0'},
				   {1, '\1', '\0'},
				   {2, '\1', '\0'}};

/***********************************************
 * ------------ End External data ------------ *
 ***********************************************/

static unsigned long lseek(char dir,int handle,unsigned long offset)
{
int   storeAX,storeDX;
    _BX=handle;
    _DX=(unsigned)(offset&0xffff);
    _CX=(unsigned)((offset>>16)&0xffff);
    storeAX=0x4200 + dir;
    _AX=storeAX;
    __int__(0x21);
    storeAX=_AX;
    storeDX=_DX;
    _DL=0;
asm adc DL,0
    if (_DL==0) {
                 offset =  storeDX;
                 offset = (offset << 16) | storeAX;
                };
    return (offset);
}

/* ========================================================= *
 *
 * PROCEDURE Length( f : File) : CARDINAL;
 *
 * PROCEDURE StreamOfStdIn () : File;
 * PROCEDURE StreamOfStdOut() : File;
 * PROCEDURE StreamOfStdErr() : File;
 *
 * ========================================================= */

unsigned long StdFiles_Length(File f)
{
   unsigned long len, num;
   num = lseek(1,f->handle,0); /* save old pos */
   len = lseek(2,f->handle,0); /* go to filend */
   (void) lseek(0,f->handle,num); /* restore   */
   return (len);
}

File StdFiles_StreamOfStdIn(void)
{
   return ( &StdHandles[0]);
}

File StdFiles_StreamOfStdOut(void)
{
   return ( &StdHandles[1]);
}

File StdFiles_StreamOfStdErr(void)
{
   return ( &StdHandles[2]);
}

/* ========================================================= */


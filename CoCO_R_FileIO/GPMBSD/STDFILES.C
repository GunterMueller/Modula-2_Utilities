/* This is the source file for <StdFiles> */
/* Created kjg April 1993 		   */
/*
 *      For 16-bit environs, int and unsigned need "long"
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdio.h>

typedef FILE *File;

/* file mode strings */
static char __fm__[3][3] = {"r", "w", "r+"};

/*---------------- implementation of StdFiles --------------------- *
 *  PROCEDURE Length( f : File) : CARDINAL;
 *  PROCEDURE StreamOfStdIn () : File;
 *  PROCEDURE StreamOfStdOut() : File;
 *  PROCEDURE StreamOfStdErr() : File;
 *----------------------------------------------------------------- */

unsigned long StdFiles_Length(File f)
{
    unsigned long pos, len;

    pos  = ftell(f);			/* save current position */
    (void) fseek(f,0L,SEEK_END);	/* seek to end of file   */
    len  = ftell(f);			/* find current position */
    (void) fseek(f,pos,SEEK_SET);	/* reset file position   */
    return (len);
}

static File StreamOfHandle(short int fd)
{
        int flags;
	flags = fcntl(fd,F_GETFL,0) & 03;
	return (fdopen(fd,__fm__[flags]));
}

File StdFiles_StreamOfStdIn(void)
{
   StreamOfHandle(0);
}

File StdFiles_StreamOfStdOut(void)
{
   StreamOfHandle(1);
}

File StdFiles_StreamOfStdErr(void)
{
   StreamOfHandle(2);
}
/*----------------------- end of StdFiles ------------------------ */


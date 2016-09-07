@ECHO OFF
REM Run COMA several times. It should
REM only attach to OK.COM.
COMA.COM > COMA.TXT
COMA.COM
COMA.COM

REM Run PRESENT.COM. COMA should not be
REM present.
PRESENT.COM > PRESENT.TXT

REM Run TOOBIG.COM. COMA should not be
REM present.
TOOBIG.COM > TOOBIG.TXT

REM Run OK.COM. COMA should run.
OK.COM > OK_COMA.TXT

REM Run CLEAN.COM. COMA should be removed
REM from OK.COM.
CLEAN.COM > CLEAN.TXT

REM Run the cleaned OK.COM. COMA should
REM not be present.
OK.COM > OK_CLEAN.TXT

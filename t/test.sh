#!/bin/bash
# File containing the original output of ok.com.
OK_OUT="t/ok.out"

################################################
# Check the exit status of the last run command.
# Exits if it is different from 0.
################################################
function check {
    MESSAGE=$1
    RC=$2
    if [ $RC == 0 ]; then
        echo ">$MESSAGE... [OK]"
    else
        echo ">$MESSAGE... [ERR $RC]"
        exit 1
    fi
}

grep -q "Success" t/COMA.TXT
check "Attaching to a host." $?

diff "$OK_OUT" t/PRESENT.TXT >/dev/null 2>&1
check "COMA should NOT attach to present.com." $?

diff "$OK_OUT" t/TOOBIG.TXT >/dev/null 2>&1
check "COMA should NOT attach to toobig.com." $?

grep -q "COMA" t/OK_COMA.TXT
check "COMA should attach to ok.com." $?

grep -q "OK" t/OK_COMA.TXT
check "Running ok.com." $?

grep -q "Removed COMA" t/CLEAN.TXT
check "Removing COMA from all hosts." $?

diff "$OK_OUT" t/OK_CLEAN.TXT >/dev/null 2>&1
check "Running the cleaned ok.com." $?

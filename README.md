![COMA logo](https://github.com/nramon/COMA/raw/master/logo.png) [![Build Status](https://travis-ci.org/nramon/COMA?branch=master)](https://travis-ci.org/nramon/COMA)

# COMA

COMA is a self-reproducing program written for learning purposes. Although there is no malicious code in COMA, it does modify any [COM file](https://en.wikipedia.org/wiki/COM_file) it attaches to. However:

 * COMA is itself a 16 bit COM file. It will not even run on a 64 bit Windows OS.
 * It only attaches to the first COM file it finds in its current working directory. It does not traverse directories or drives.
 * It ignores [system and hidden](https://en.wikipedia.org/wiki/File_attribute#DOS_and_Windows) files.
 * It is very verbose about what it does and logs to STDOUT.
 * A utility to remove COMA from any files it has attached to is provided.

## Building on Linux

Make sure [NASM](https://en.wikipedia.org/wiki/Netwide_Assembler) is installed. Then, from the project's top level directory, run the following command:

    make

This will build **coma.com** and **clean.com**. COMA's tests are run on [DOSBox](https://www.dosbox.com/). If you would like to run them, install it and then run:
 
    make test

## Running COMA

The easiest way to try COMA is to install [DOSBox](https://www.dosbox.com/) and, from the project's top level directory, run the following command:

    dosbox -conf dosbox/dosbox.conf
 
Inside DOSBox, copy to *c:\* any COM file you want COMA to attach to and run:

    coma

The next time that COM file is run, COMA will run first (attaching to another COM file if it can) and then it will transfer control back to the original program.

## FAQ

### How do I remove COMA from a COM file?

Simply place **clean.com** in the same directory as the COM file and run:

    clean

### What's with the 41 character column width?

Sorry about that! COMA was written on a 5.1-inch screen and anything over 41 characters made the source code unreadable :-S

## Copyright

Copyright (C) 2016 Ramon Novoa <ramonnovoa@gmail.com>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

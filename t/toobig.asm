; Copyright (C) 2016 Ramon Novoa
; <ramonnovoa AT gmail DOT com> This
; program is free software: you can
; redistribute it and/or modify it under
; the terms of the GNU General Public
; License as published by the Free
; Software Foundation, either version 3
; of the License, or (at your option) any
; later version.
;
; This program is distributed in the hope
; that it will be useful, but WITHOUT ANY
; WARRANTY; without even the implied
; warranty of MERCHANTABILITY or FITNESS
; FOR A PARTICULAR PURPOSE.  See the GNU
; General Public License for more
; details.
;
; You should have received a copy of the
; GNU General Public License along with
; this program.  If not, see
; <http://www.gnu.org/licenses/>.

;----------------------------------------
; COMA should NOT attach to this program.
;----------------------------------------
use16    ; Generate code designed to run
         ; in 16-bit mode.
cpu 8086 ; Assemble only 8086 instruction
         ; set.

org 100h ; Leave room for the Program
         ; Segment Prefix.

jmp toobig_code
 
;----------------------------------------
; Data.
;----------------------------------------
hdr:   times 65000d db 0 ; Prevent COMA
                         ; from attaching
                         ; to this file
						 ; (too big to
						 ; hold it).
msg:   db "[OK]$"

toobig_code:
 ; Log.
 mov dx, msg
 mov ah, 09h ; Write string to STDOUT.
 int 21h

 ; Exit.
 mov al, 0   ; Return code.
 mov ah, 4ch ; Exit program.
 int 21h

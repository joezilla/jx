;--------------------------------------------------------
; File Created by SDCC : free open source ISO C Compiler
; Version 4.5.0 #15242 (Mac OS X ppc)
;--------------------------------------------------------
	.module putchar
	
	.optsdcc -mz80 sdcccall(1)
;--------------------------------------------------------
; Public variables in this module
;--------------------------------------------------------
	.globl _bdos_conout
	.globl _putchar
;--------------------------------------------------------
; special function registers
;--------------------------------------------------------
;--------------------------------------------------------
; ram data
;--------------------------------------------------------
	.area _DATA
;--------------------------------------------------------
; ram data
;--------------------------------------------------------
	.area _INITIALIZED
;--------------------------------------------------------
; absolute external ram data
;--------------------------------------------------------
	.area _DABS (ABS)
;--------------------------------------------------------
; global & static initialisations
;--------------------------------------------------------
	.area _HOME
	.area _GSINIT
	.area _GSFINAL
	.area _GSINIT
;--------------------------------------------------------
; Home
;--------------------------------------------------------
	.area _HOME
	.area _HOME
;--------------------------------------------------------
; code
;--------------------------------------------------------
	.area _CODE
;putchar.c:4: int putchar(int c) {
;	---------------------------------
; Function putchar
; ---------------------------------
_putchar::
	ex	de, hl
;putchar.c:6: if (c == '\n') {
	ld	a, e
	sub	a, #0x0a
	or	a, d
	jr	NZ, 00102$
;putchar.c:7: bdos_conout('\r');
	push	de
	ld	a, #0x0d
	call	_bdos_conout
;putchar.c:8: bdos_conout('\n');
	ld	a, #0x0a
	call	_bdos_conout
	pop	de
	ret
00102$:
;putchar.c:10: bdos_conout((char)c);
	ld	a, e
	push	de
	call	_bdos_conout
	pop	de
;putchar.c:12: return c;
;putchar.c:13: }
	ret
	.area _CODE
	.area _INITIALIZER
	.area _CABS (ABS)

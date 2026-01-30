;========================================================
; crt0.s - C Runtime for JX TPA Programs
;========================================================
; This startup code is linked first in every C program.
; It sets up the execution environment and calls main().
;========================================================

        .module crt0
        .area   _CODE

        ;; Entry point at TPA_BASE (0x0100)
        ;; Linker will place this at --code-loc address

;--------------------------------------------------------
; Constants from JX system
;--------------------------------------------------------
TPA_BASE        = 0x0100        ; Program load address
BDOS_ENTRY      = 0x0005        ; BDOS call interface
BDOS_EXIT       = 0x00          ; System reset (warm boot)
BDOS_GETTPA     = 0x31          ; Get TPA top address

;--------------------------------------------------------
; Program Entry Point
;--------------------------------------------------------
init:
        ;; Get TPA top from BDOS for stack setup
        ld      c, #BDOS_GETTPA
        call    BDOS_ENTRY      ; Returns HL = TPA_TOP
        ld      sp, hl          ; Set stack at top of TPA

        ;; Save TPA top for heap initialization
        ld      (_tpa_top), hl

        ;; Initialize BSS (zero uninitialized data)
        call    init_bss

        ;; Initialize heap for malloc
        call    _heap_init

        ;; Call main() - no arguments for minimal version
        call    _main

        ;; Exit with return value from main
        ;; (Return value is in HL but we ignore it for now)
        ld      c, #BDOS_EXIT
        call    BDOS_ENTRY

        ;; Should never return
        halt

;--------------------------------------------------------
; Initialize BSS segment (zero uninitialized data)
;--------------------------------------------------------
init_bss:
        ld      hl, #s__BSS     ; Start of BSS
        ld      bc, #l__BSS     ; Length of BSS
        ld      a, b
        or      c
        ret     z               ; BSS is empty, return

        xor     a               ; A = 0
bss_loop:
        ld      (hl), a
        inc     hl
        dec     bc
        ld      a, b
        or      c
        jr      nz, bss_loop
        ret

;--------------------------------------------------------
; Ordering of segments for the linker
;--------------------------------------------------------
        .area   _HOME
        .area   _CODE
        .area   _INITIALIZER
        .area   _GSINIT
        .area   _GSFINAL

        .area   _DATA
_tpa_top::                      ; TPA top address (for heap)
        .ds     2

        .area   _INITIALIZED
        .area   _BSEG
        .area   _BSS
        .area   _HEAP

;--------------------------------------------------------
; Heap start marker (accessible from C as heap_start)
;--------------------------------------------------------
_heap_start::
        .ds     1

;--------------------------------------------------------
; GSINIT - Global initialization
;--------------------------------------------------------
        .area   _GSINIT
gsinit::
        .area   _GSFINAL
        ret

;========================================================
; JX Operating System - Hello World Test
;========================================================
; A simple test program that prints "Hello from JX!"
; to the console using direct I/O port access.
;
; This test verifies:
;   - Assembler toolchain works
;   - Binary loads at correct address
;   - Console output via simulator I/O
;
; Assemble with: make test-hello
; Run with: make run-test TEST=hello
;========================================================

        ORG     0100H           ; Load at TPA base

;--------------------------------------------------------
; I/O Ports (cpmsim specific)
;--------------------------------------------------------
CONSTAT EQU     0               ; Console status port
CONDATA EQU     1               ; Console data port

;--------------------------------------------------------
; ASCII
;--------------------------------------------------------
CR      EQU     0DH
LF      EQU     0AH

;========================================================
; Main Entry Point
;========================================================
START:
        LXI     SP,STACK        ; Set up stack

        ; Print the hello message
        LXI     H,MSG_HELLO
        CALL    PUTS

        ; Print memory configuration
        LXI     H,MSG_MEM
        CALL    PUTS

        ; Print success message
        LXI     H,MSG_OK
        CALL    PUTS

        ; Halt the CPU
        HLT

;========================================================
; PUTS - Print null-terminated string
; Input: HL = pointer to string
;========================================================
PUTS:
        MOV     A,M             ; Get character
        ORA     A               ; Is it null?
        RZ                      ; Yes, return
        CALL    PUTC            ; Print character
        INX     H               ; Next character
        JMP     PUTS            ; Loop

;========================================================
; PUTC - Print single character
; Input: A = character to print
;========================================================
PUTC:
        OUT     CONDATA         ; Send to console
        RET

;========================================================
; Data Section
;========================================================
MSG_HELLO:
        DB      CR,LF
        DB      '================================',CR,LF
        DB      '  JX Operating System',CR,LF
        DB      '  Toolchain Test Program',CR,LF
        DB      '================================',CR,LF
        DB      CR,LF
        DB      'Hello from JX!',CR,LF
        DB      0

MSG_MEM:
        DB      CR,LF
        DB      'Build configuration:',CR,LF
        DB      '  TPA base: 0100H',CR,LF
        DB      0

MSG_OK:
        DB      CR,LF
        DB      'Toolchain test PASSED!',CR,LF
        DB      CR,LF
        DB      'CPU halted.',CR,LF
        DB      0

;========================================================
; Stack (256 bytes)
;========================================================
        DS      256
STACK   EQU     $

;========================================================
        END     START

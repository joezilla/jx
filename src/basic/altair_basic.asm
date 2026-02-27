;============================================================
; Altair BASIC 3.2 (4K) - Ported for JX Monitor BIOS I/O
; Converted from annotated listing by convert-basic-lst.py
;
; Copyright 1975, Bill Gates, Paul Allen, Monte Davidoff
; Source: http://altairbasic.org/
;
; I/O routines patched to use JX BIOS calls.
; Requires: BASIC_STANDALONE (0 or 1) defined at assembly.
;============================================================

;--------------------------------------------------------
; BIOS I/O entry points
;--------------------------------------------------------
; B_PUTCHAR, B_GETCHAR, B_CONST must be defined before
; this file is INCLUDEd (via EQU in the entry point file).
;
; Standalone: EQUs point to PUTCHAR/GETCHAR/CONST labels
;             defined after BASIC code in the same binary.
; Loadable:   EQUs point to BIOS jump table addresses.
;--------------------------------------------------------

;--------------------------------------------------------
; Build mode defaults (overridden by -d flags)
;--------------------------------------------------------
        IFNDEF BASIC_STANDALONE
BASIC_STANDALONE EQU 0
        ENDIF
        IFNDEF BAS_MEM_TOP
BAS_MEM_TOP EQU 0F1AH
        ENDIF

        ORG 00

Start   DI
        JMP Init

        DW 0490H
        DW 07F9H

SyntaxCheck
        MOV A,M	;A=Byte of BASIC program.
        XTHL	;HL=return address.
        CMP M	;Compare to byte expected.
        INX H	;Return address++;
        XTHL	;
        JNZ SyntaxError	;Error if not what was expected.
NextChar
        INX H
        MOV A,M
        CPI 3AH
        RNC
        JMP NextChar_tail
OutChar PUSH PSW
        LDA TERMINAL_X
        JMP OutChar_tail
        NOP
CompareHLDE
        MOV A,H
        SUB D
        RNZ
        MOV A,L
        SUB E
        RET
TERMINAL_Y
        DB 01
TERMINAL_X
        DB 00
FTestSign
        LDA FACCUM+3
        ORA A
        JNZ FTestSign_tail
        RET
PushNextWord
        XTHL
        SHLD L003A+1
        POP H
        MOV C,M
        INX H
        MOV B,M
        INX H
        PUSH B
L003A   JMP L003A
KW_INLINE_FNS
        DW Sgn
        DW Int
        DW Abs
        DW FunctionCallError
        DW Sqr
        DW Rnd
        DW Sin
KW_ARITH_OP_FNS
        DB 79H
        DW FAdd	;+
        DB 79H
        DW FSub	;-
        DB 7CH
        DW FMul	;*
        DB 7CH
        DW FDiv	;/
KEYWORDS
        DB 45H,4EH,0C4H	;"END" 80
        DB 46H,4FH,0D2H	; "FOR"
        DB 4EH,45H,58H,0D4H	; "NEXT" 82
        DB 44H,41H,54H,0C1H	; "DATA" 83
        DB 49H,4EH,50H,55H,0D4H	; "INPUT" 84
        DB 44H,49H,0CDH	; "DIM" 85
        DB 52H,45H,41H,0C4H	; "READ" 86
        DB 4CH,45H,0D4H	; "LET" 87
        DB 47H,4FH,54H,0CFH	; "GOTO" 88
        DB 52H,55H,0CEH	; "RUN" 89
        DB 49H,0C6H	; "IF" 8A
        DB 52H,45H,53H,54H,4FH,52H,0C5H	; "RESTORE" 8B
        DB 47H,4FH,53H,55H,0C2H	; "GOSUB" 8C
        DB 52H,45H,54H,55H,52H,0CEH	; "RETURN" 8D
        DB 52H,45H,0CDH	; "REM" 8E
        DB 53H,54H,4FH,0D0H	; "STOP" 8F
        DB 50H,52H,49H,4EH,0D4H	; "PRINT" 90
        DB 4CH,49H,53H,0D4H	; "LIST" 91
        DB 43H,4CH,45H,41H,0D2H	; "CLEAR" 92
        DB 4EH,45H,0D7H	; "NEW" 93
;
        DB 54H,41H,42H,0A8H	; "TAB(" 94
        DB 54H,0CFH	; "TO" 95
        DB 54H,48H,45H,0CEH	; "THEN" 96
        DB 53H,54H,45H,0D0H	; "STEP" 97
;
        DB 0ABH	; "+" 98
        DB 0ADH	; "-" 99
        DB 0AAH	; "*" 9A
        DB 0AFH	; "/" 9B
        DB 0BEH	; ">" 9C
        DB 0BDH	; "=" 9D
        DB 0BCH	; "<" 9E
;
        DB 53H,47H,0CEH	; "SGN" 9F
        DB 49H,4EH,0D4H	; "INT" A0
        DB 41H,42H,0D3H	; "ABS" A1
        DB 55H,53H,0D2H	; "USR" A2
        DB 53H,51H,0D2H	; "SQR" A3
        DB 52H,4EH,0C4H	; "RND" A4
        DB 53H,49H,0CEH	; "SIN" A5
;
        DB 00H	;
;
KW_GENERAL_FNS
        DW Stop	;END
        DW For	;FOR
        DW Next	;NEXT
        DW FindNextStatement	;DATA
        DW Input	;INPUT
        DW Dim	;DIM
        DW Read	;READ
        DW Let	;LET
        DW Goto	;GOTO
        DW Run	;RUN
        DW If	;IF
        DW Restore	;RESTORE
        DW Gosub	;GOSUB
        DW Return	;RETURN
        DW Rem	;REM
        DW Stop	;STOP
        DW Print	;PRINT
        DW List	;LIST
        DW Clear	;CLEAR
        DW New	;NEW

ERROR_CODES
        DB 4EH,0C6H	;"NF" NEXT without FOR.
        DB 53H,0CEH	;"SN" Syntax Error
        DB 52H,0C7H	;"RG" RETURN without GOSUB.
        DB 4FH,0C4H	;"OD" Out of Data
        DB 46H,0C3H	;"FC" Illegal Function Call
        DB 4FH,0D6H	;"OV" Overflow.
        DB 4FH,0CDH	;"OM" Out of memory.
        DB 55H,0D3H	;"US" Undefined Subroutine
        DB 42H,0D3H	;"BS" Bad Subscript
        DB 44H,0C4H	;"DD" Duplicate Definition
        DB 2FH,0B0H	;"\0" Division by zero.
        DB 49H,0C4H	;"ID" Invalid in Direct mode.

        DB ','	;
LINE_BUFFER
        DW 0000,0000,0000,0000H	;72 chars
        DW 0000,0000,0000,0000H	;
        DW 0000,0000,0000,0000H	;
        DW 0000,0000,0000,0000H	;
        DW 0000,0000,0000,0000H	;
        DW 0000,0000,0000,0000H	;
        DW 0000,0000,0000,0000H	;
        DW 0000,0000,0000,0000H	;
        DW 0000,0000,0000,0000H	;

DIM_OR_EVAL
        DB 00H	;
INPUT_OR_READ
        DB 00H	;
PROG_PTR_TEMP
        DW 0000H	;
L015F   DW 0000H	;
CURRENT_LINE
        DW 0000H	;
BAS_STKTOP
        DW BAS_MEM_TOP	; Init overwrites this
PROGRAM_BASE
        DW 0000H	;
VAR_BASE
        DW 0000H	;
VAR_ARRAY_BASE
        DW 0000H	;
VAR_TOP DW 0000H	;
DATA_PROG_PTR
        DW 0000H	;
FACCUM  DB 00H,00H,00H,00H	;
FTEMP   DB 00H	;
FBUFFER DW 0000,0000,0000
        DW 0000,0000,0000
        DB 00	;
szError DB 20H,45H,52H,52H,4FH,0D2H,00H	;" ERROR\0"
szIn    DB 20H,49H,4EH,0A0H,00H	;" IN \0"
szOK    DB 0DH,4FH,0CBH,0DH,00H	;"\rOK\r\0"
GetFlowPtr
        LXI H,0004H	;HL=SP+4 (ie get word
        DAD SP	;just past return addr)
        MOV A,M	;
        INX H	;
        CPI 81H	;'FOR'?
        RNZ	;Return if not 'FOR'
        RST 6	; RST PushNextWord ;PUSH (HL)
        XTHL	;POP HL (ie HL=(HL))
        RST 4	; RST CompareHLDE ;HL==DE?
        LXI B,000DH	;
        POP H	;Restore HL
        RZ	;Return if var ptrs match.
        DAD B	;HL+=000D
        JMP GetFlowPtr+4	;Loop
CopyMemoryUp
        CALL CheckEnoughMem;
        PUSH B	;Exchange BC with HL.
        XTHL	;
        POP B	;
CopyMemLoop
        RST 4	;HL==DE?
        MOV A,M	;
        STAX B	;
        RZ	;Exit if DE reached.
        DCX B	;
        DCX H	;
        JMP CopyMemLoop	;
CheckEnoughVarSpace
        PUSH H	;
        LHLD VAR_TOP	;
        MVI B,00H	;BC=C*4
        DAD B	;
        DAD B	;
        CALL CheckEnoughMem;
        POP H	;
        RET	;
CheckEnoughMem
        PUSH D	;
        XCHG	;
        LXI H,0FFDEH	;HL=-34 (extra 2 bytes for return address)
        DAD SP	;
        RST 4	;
        XCHG	;
        POP D	;
        RNC	;
OutOfMemory
        MVI E,0CH	;
        DB 01	;LXI B,.... ;
SyntaxError
        MVI E,02H	;
        DB 01	;LXI B,.... ;
DivideByZero
        MVI E,14H	;
Error   CALL ResetStack	;
        CALL NewLine	;
        LXI H,ERROR_CODES	;
        MOV D,A	;
        MVI A,'?'	;Print '?'
        RST 03	;RST OutChar ;
        DAD D	;HL points to error code.
        MOV A,M	;
        RST 03	;RST OutChar 11 011 111 ;Print first char of code.
        RST 02	;RST NextChar 11 010 111 ;
        RST 03	;RST OutChar ;Print second char of code.
        LXI H,szError	;Print " ERROR".
        CALL PrintString	;
        LHLD CURRENT_LINE	;
        MOV A,H	;
        ANA L	;
        INR A	;
        CNZ PrintIN	;
        DB 01	;LXI B,.... ;LXI over Stop and fall into Main
Stop    RNZ	;Syntax Error if args.
        POP B	;Lose return address.
Main    LXI H,szOK	;
        CALL Init	;
GetNonBlankLine
        LXI H,0FFFFH	;
        SHLD CURRENT_LINE	;
        CALL InputLine	;
        RST 02	;RST NextChar ;
        INR A	;
        DCR A	;
        JZ GetNonBlankLine	;
        PUSH PSW
        CALL LineNumberFromStr
        PUSH D
        CALL Tokenize
        MOV B,A
        POP D
        POP PSW
        JNC Exec
StoreProgramLine
        PUSH D	;Push line number
        PUSH B	;Push line length
        RST 02	;RST NextChar ;Get first char of line
        ORA A	;Zero set if line is empty (ie removing a line)
        PUSH PSW	;Preserve line-empty flag
        CALL FindProgramLine	;Get nearest program line address in BC.
        PUSH B	;Push line address.
        JNC InsertProgramLine	;If line doesn't exist, jump ahead to insert it.
RemoveProgramLine
        XCHG	;DE=Next line address.
        LHLD VAR_BASE	;
RemoveLine
        LDAX D	;Move byte of program remainder down
        STAX B	;in memory.
        INX B	;
        INX D	;
        RST 4	;Loop until DE==VAR_BASE, ie whole
        JNZ RemoveLine	;program remainder done.
        MOV H,B	;
        MOV L,C	;Update VAR_BASE from BC.
        SHLD VAR_BASE	;
InsertProgramLine
        POP D	;DE=Line address (from 224)
        POP PSW	;Restore line-empty flag (see above)
        JZ UpdateLinkedList;If line is empty, then we don't need to insert it so can jump ahead.
        LHLD VAR_BASE	;
        XTHL	;HL = Line length (see 21D)
        POP B	;BC = VAR_BASE
        DAD B	;HL = VAR_BASE + line length.
        PUSH H	;
        CALL CopyMemoryUp	;Move remainder of program so there's enough space for the new line.
        POP H	;
        SHLD VAR_BASE	;Update VAR_BASE
        XCHG	;HL=Line address, DE=VAR_BASE
        MOV M,H	;???
        INX H	;Skip over next line ptr (updated below)
        INX H	;
        POP D	;DE = line number (see 21C)
        MOV M,E	;Write line number to program line memory.
        INX H	;
        MOV M,D	;
        INX H	;
CopyFromBuffer
        LXI D,LINE_BUFFER	;Copy the line into the program.
        LDAX D	;
        MOV M,A	;
        INX H	;
        INX D	;
        ORA A	;
        JNZ CopyFromBuffer+3;
UpdateLinkedList
        CALL ResetAll	;
        INX H	;
        XCHG	;
L0265   MOV H,D	;
        MOV L,E	;
        MOV A,M	;If the pointer to the next line is a null
        INX H	;word then we've reached the end of the
        ORA M	;program, job is done, and we can jump back
        JZ GetNonBlankLine	;to let the user type in the next line.
        INX H	;Skip over line number.
        INX H	;
        INX H	;
        XRA A	;
L0271   CMP M	;
        INX H	;
        JNZ L0271	;
        XCHG	;
        MOV M,E	;
        INX H	;
        MOV M,D	;
        JMP L0265	;
FindProgramLine
        LHLD PROGRAM_BASE	;
        MOV B,H	;BC=this line
        MOV C,L	;
        MOV A,M	;If we've found two consecutive
        INX H	;null bytes, then we've reached the end
        ORA M	;of the program and so return.
        DCX H	;
        RZ	;
        PUSH B	;Push this line address
        RST 6	;Push (next line address)
        RST 6	;Push (this line number)
        POP H	;HL = this line number
        RST 4	;Compare line numbers
        POP H	;HL = next line address
        POP B	;BC = this line address
        CMC	;
        RZ	;Return carry set if line numbers match.
        CMC	;
        RNC	;Return if we've reached a line number greater than the one required.
        JMP FindProgramLine+3
New     RNZ
        LHLD PROGRAM_BASE
        XRA A
        MOV M,A
        INX H
        MOV M,A
        INX H
        SHLD VAR_BASE
Run     RNZ
ResetAll
        LHLD PROGRAM_BASE
        DCX H
Clear   SHLD PROG_PTR_TEMP
        CALL Restore
        LHLD VAR_BASE
        SHLD VAR_ARRAY_BASE
        SHLD VAR_TOP
ResetStack
        POP B
        LHLD BAS_STKTOP
        SPHL
        XRA A
        MOV L,A
        PUSH H
        PUSH B
        LHLD PROG_PTR_TEMP
        RET
InputLineWith
        MVI A,'?'	;Print '?'
        RST 03	;RST OutChar ;
        MVI A,' '	;Print ' '
        RST 03	;RST OutChar ;
        CALL InputLine	;
        INX H	;
Tokenize
        MVI C,05	;Initialise line length to 5.
        LXI D,LINE_BUFFER	;ie, output ptr is same as input ptr at start.
        MOV A,M	;
        CPI ' '	;
        JZ WriteChar	;
        MOV B,A	;
        CPI '"'	;
        JZ FreeCopy	;
        ORA A	;
        JZ Exit	;
        PUSH D	;Preserve output ptr.
        MVI B,00	;Initialise Keyword ID to 0.
        LXI D,KEYWORDS-1	;
        PUSH H	;Preserve input ptr.
        DB 3EH	;LXI over get-next-char
KwCompare
        RST 02	; RST 01 ; SyntaxCheck0 ;Get next input char
        INX D	;
        LDAX D	;Get keyword char to compare with.
        ANI 7FH	;Ignore bit 7 of keyword char.
        JZ NotAKeyword	;If keyword char==0, then end of keywords reached.
        CMP M	;Keyword char matches input char?
        JNZ NextKeyword	;If not, jump to get next keyword.
        LDAX D	;
        ORA A	;
        JP KwCompare	;
        POP PSW	;Remove input ptr from stack. We don't need it.
        MOV A,B	;A=Keyword ID
        ORI 80H	;Set bit 7 (indicates a keyword)
        DB 0F2H	;JP .... ;LXI trick again.
NotAKeyword
        POP H	;Restore input ptr
        MOV A,M	;and get input char
        POP D	;Restore output ptr
WriteChar
        INX H	;Advance input ptr
        STAX D	;Store output char
        INX D	;Advance output ptr
        INR C	;C++ (arf!).
        SUI 8EH	;If it's not the
        JNZ Tokenize+5	;
        MOV B,A	;B=0
FreeCopyLoop
        MOV A,M	;A=Input char
        ORA A	;If char is null then exit
        JZ Exit	;
        CMP B	;If input char is term char then
        JZ WriteChar	;we're done free copying.
FreeCopy
        INX H	;
        STAX D	;
        INR C	;
        INX D	;
        JMP FreeCopyLoop	;
NextKeyword
        POP H	;Restore input ptr
        PUSH H	;
        INR B	;Keyword ID ++;
        XCHG	;HL=keyword table ptr
NextKwLoop
        ORA M	;Loop until
        INX H	;bit 7 of previous
        JP NextKwLoop	;keyword char is set.
        XCHG	;DE=keyword ptr, HL=input ptr
        JMP KwCompare+2	;
Exit    LXI H,LINE_BUFFER-1	;
        STAX D	;
        INX D	;
        STAX D	;
        INX D	;
        STAX D	;
        RET	;
Backspace
        DCR B	;Char count--;
        DCX H	;Input ptr--;
        RST 03	;RST OutChar ;Print backspace char.
        JNZ InputNext	;
ResetInput
        RST 03	;RST OutChar ;
        CALL NewLine	;
InputLine
        LXI H,LINE_BUFFER	;
        MVI B,01	;
InputNext
        CALL InputChar	;
        CPI 0DH	;
        JZ TerminateInput	;
        CPI ' '	;If < ' '
        JC InputNext	;or
        CPI 7DH	;> '}'
        JNC InputNext	;then loop back.
        CPI '@'	;
        JZ ResetInput	;
        CPI '_'	;
        JZ Backspace	;
        MOV C,A	;
        MOV A,B	;
        CPI 48H	;
        MVI A,07	;
        JNC L036A	;
        MOV A,C	;Write char to LINE_BUFFER.
        MOV M,C	;
        INX H	;
        INR B	;
L036A   RST 03	;RST OutChar ;
        JMP InputNext	;
OutChar_tail
        CPI 48H	;
        CZ NewLine	;
        INR A	;
        STA TERMINAL_X	;
;--- PATCHED: BIOS dual output (was Altair port I/O) ---
WaitTermReady
        POP PSW         ; Restore char from RST 3's PUSH
        ANI 7FH         ; Strip bit 7 (BASIC string terminator)
        CALL B_PUTCHAR  ; BIOS dual output (serial + video)
        RET
        NOP             ; Pad to preserve addresses
        NOP
        NOP
        NOP
        NOP
;--- end patch (0377-0381, 11 bytes) ---
;--- PATCHED: BIOS blocking input (was Altair port I/O) ---
InputChar
        CALL B_GETCHAR  ; BIOS blocking read
        RET
        NOP             ; Pad to preserve addresses
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
;--- end patch (0382-038D, 12 bytes) ---
List    CALL LineNumberFromStr
        RNZ
        POP B	;?why get return address?
        CALL FindProgramLine
        PUSH B
ListNextLine
        POP H
        RST 6
        POP B
        MOV A,B
        ORA C
        JZ Main
        CALL TestBreakKey
        PUSH B
        CALL NewLine
        RST 6
        XTHL
        CALL PrintInt
        MVI A,' '
        POP H
ListChar
        RST 03	;RST OutChar
        MOV A,M
        ORA A
        INX H
        JZ ListNextLine
        JP ListChar
        SUI 7FH	;A is now keyword index + 1.
        MOV C,A
        PUSH H
        LXI D,KEYWORDS
        PUSH D
ToNextKeyword
        LDAX D
        INX D
        ORA A
        JP ToNextKeyword
        DCR C
        POP H
        JNZ ToNextKeyword-1
PrintKeyword
        MOV A,M
        ORA A
        JM ListChar-1
        RST 03	;RST OutChar
        INX H
        JMP PrintKeyword
For     CALL Let
        XTHL
        CALL GetFlowPtr
        POP D
        JNZ L03E2
        DAD B
        SPHL
L03E2   XCHG
        MVI C,08
        CALL CheckEnoughVarSpace
        PUSH H
        CALL FindNextStatement
        XTHL
        PUSH H
        LHLD CURRENT_LINE
        XTHL
        RST 01	; SyntaxCheck; SyntaxCheck
        DB 95H	;KWID_TO
        CALL EvalExpression
        PUSH H
        CALL FCopyToBCDE
        POP H
        PUSH B
        PUSH D
        LXI B,8100H
        MOV D,C
        MOV E,D
        MOV A,M
        CPI 97H	;KWID_STEP
        MVI A,01H
        JNZ PushStepValue
        CALL EvalExpression+1
        PUSH H
        CALL FCopyToBCDE
        RST 05	; FTestSign
        POP H
PushStepValue
        PUSH B
        PUSH D
        PUSH PSW
        INX SP
        PUSH H
        LHLD PROG_PTR_TEMP
        XTHL
EndOfForHandler
        MVI B,81H
        PUSH B
        INX SP
ExecNext
        CALL TestBreakKey
        MOV A,M
        CPI ':'
        JZ Exec
        ORA A
        JNZ SyntaxError
        INX H
        MOV A,M
        INX H
        ORA M
        INX H
        JZ Main
        MOV E,M
        INX H
        MOV D,M
        XCHG
        SHLD CURRENT_LINE
        XCHG
Exec    RST 02	;RST NextChar
        LXI D,ExecNext
        PUSH D
        RZ
        SUI 80H
        JC Let
        CPI 14H
        JNC SyntaxError
        RLC	;BC = A*2
        MOV C,A
        MVI B,00H
        XCHG
        LXI H,KW_GENERAL_FNS
        DAD B
        MOV C,M
        INX H
        MOV B,M
        PUSH B
        XCHG
        RST 02	;RST NextChar
        RET
NextChar_tail
        CPI ' '
        JZ NextChar
        CPI '0'
        CMC
        INR A
        DCR A
        RET
Restore XCHG
        LHLD PROGRAM_BASE
        DCX H
L046E   SHLD DATA_PROG_PTR
        XCHG
        RET
;--- PATCHED: BIOS console status (was Altair port I/O) ---
; Note: Altair RNZ (1=not ready) -> BIOS RZ (00=not ready)
TestBreakKey
        CALL B_CONST    ; BIOS: 00=no char, FF=ready
        ORA A
        RZ              ; Return if no key
        CALL InputChar  ; Read the key
        CPI 03H         ; Ctrl-C?
        JMP Stop
;--- end patch (0473-047F, 13 bytes exact fit) ---
CharIsAlpha
        MOV A,M
        CPI 'A'
        RC
        CPI 'Z'+1
        CMC
        RET
GetSubscript
        RST 02	;RST NextChar
        CALL EvalExpression
        RST 05	; FTestSign
        JM FunctionCallError
        LDA FACCUM+3
        CPI 90H
        JC FAsInteger
FunctionCallError
        MVI E,08H
        JMP Error
LineNumberFromStr
        DCX H
        LXI D,0000
NextLineNumChar
        RST 02	;RST NextChar
        RNC
        PUSH H
        PUSH PSW	;Preserve flags
        LXI H,1998H	;Decimal 6552
        RST 4
        JC SyntaxError
        MOV H,D
        MOV L,E
        DAD D
        DAD H
        DAD D
        DAD H
        POP PSW
        SUI '0'
        MOV E,A
        MVI D,00H
        DAD D
        XCHG
        POP H
        JMP NextLineNumChar
Gosub   MVI C,03H
        CALL CheckEnoughVarSpace
        POP B
        PUSH H
        PUSH H
        LHLD CURRENT_LINE
        XTHL
        MVI D,8CH
        PUSH D
        INX SP
        PUSH B
Goto    CALL LineNumberFromStr
        RNZ
        CALL FindProgramLine
        MOV H,B
        MOV L,C
        DCX H
        RC
        MVI E,0EH
        JMP Error
Return  RNZ
        MVI D,0FFH
        CALL GetFlowPtr
        SPHL
        CPI 8CH
        MVI E,04H
        JNZ Error
        POP H
        SHLD CURRENT_LINE
        LXI H,ExecNext
        XTHL
FindNextStatement
        DB 01H,3AH	;LXI B,..3A
Rem     DB 10H
        NOP
FindNextStatementLoop
        MOV A,M
        ORA A
        RZ
        CMP C
        RZ
        INX H
        JMP FindNextStatementLoop
Let     CALL GetVar
        RST 01	; SyntaxCheck
        DB 9DH
AssignVar
        PUSH D
        CALL EvalExpression
        XTHL
        SHLD PROG_PTR_TEMP
        PUSH H
        CALL FCopyToMem
        POP D
        POP H
        RET
If      CALL EvalExpression
        MOV A,M
        CALL FPush
        MVI D,00
GetCompareOpLoop
        SUI 9CH	; KWID_>
        JC GotCompareOp
        CPI 03H
        JNC GotCompareOp
        CPI 01H
        RAL
        ORA D
        MOV D,A
        RST 02	;RST NextChar
        JMP GetCompareOpLoop
GotCompareOp
        MOV A,D
        ORA A
        JZ SyntaxError
        PUSH PSW
        CALL EvalExpression
        RST 01	; SyntaxCheck
        DB 96H	;KWID_THEN
        DCX H
        POP PSW
        POP B
        POP D
        PUSH H
        PUSH PSW
        CALL FCompare
        INR A
        RAL
        POP B
        ANA B
        POP H
        JZ Rem
        RST 02	;RST NextChar
        JC Goto
        JMP Exec+5
        DCX H
        RST 02	;RST NextChar
Print   JZ NewLine
        RZ
        CPI '"'
        CZ PrintString-1
        JZ Print-2
        CPI 94H	;KWID_TAB
        JZ Tab
        PUSH H
        CPI ','
        JZ ToNextTabBreak
        CPI ';'
        JZ ExitTab
        POP B
        CALL EvalExpression
        PUSH H
        CALL FOut
        CALL PrintString
        MVI A,' '
        RST 03	;RST OutChar
        POP H
        JMP Print-2
TerminateInput
        MVI M,00H
        LXI H,LINE_BUFFER-1
NewLine MVI A,0DH
        STA TERMINAL_X
        RST 03	;RST OutChar
        MVI A,0AH
        RST 03	;RST OutChar
        LDA TERMINAL_Y
PrintNullLoop
        DCR A
        STA TERMINAL_X
        RZ
        PUSH PSW
        XRA A
        RST 03	;RST OutChar
        POP PSW
        JMP PrintNullLoop
        INX H
PrintString
        MOV A,M
        ORA A
        RZ
        INX H
        CPI '"'
        RZ
        RST 03	;RST OutChar
        CPI 0DH
        CZ NewLine
        JMP PrintString
ToNextTabBreak
        LDA TERMINAL_X
        CPI 38H
        CNC NewLine
        JNC ExitTab
CalcSpaceCount
        SUI 0EH
        JNC CalcSpaceCount
        CMA
        JMP PrintSpaces
Tab     CALL GetSubscript
        RST 01	; SyntaxCheck
        DB 29H	;')'
        DCX H
        PUSH H
        LDA TERMINAL_X
        CMA
        ADD E
        JNC ExitTab
PrintSpaces
        INR A
        MOV B,A
        MVI A,' '
PrintSpaceLoop
        RST 03	;RST OutChar
        DCR B
        JNZ PrintSpaceLoop
ExitTab POP H
        RST 02	;RST NextChar
        JMP Print+3
Input   PUSH H
        LHLD CURRENT_LINE
        MVI E,16H
        INX H
        MOV A,L
        ORA H
        JZ Error
        CALL InputLineWith
        JMP L05FA+1
Read    PUSH H
        LHLD DATA_PROG_PTR
L05FA   ORI 0AFH
;XRA A
        STA INPUT_OR_READ
        XTHL
        DB 01	;LXI B,....
ReadNext
        RST 01	; SyntaxCheck
        DB 2CH	;','
        CALL GetVar
        XTHL
        PUSH D
        MOV A,M
        CPI ','
        JZ GotDataItem
        ORA A
        JNZ SyntaxError
        LDA INPUT_OR_READ
        ORA A
        INX H
        JNZ NextDataLine+1
        MVI A,'?'
        RST 03	;RST OutChar
        CALL InputLineWith
GotDataItem
        POP D
        INX H
        CALL AssignVar
        XTHL
        DCX H
        RST 02	;RST NextChar
        JNZ ReadNext
        POP D
        LDA INPUT_OR_READ
        ORA A
        RZ
        XCHG
        JNZ L046E
NextDataLine
        POP H
        RST 6
        MOV A,C
        ORA B
        MVI E,06H
        JZ Error
        INX H
        RST 02	;RST NextChar
        CPI 83H	;KWID_DATA
        JNZ NextDataLine
        POP B
        JMP GotDataItem
Next    CALL GetVar
        SHLD PROG_PTR_TEMP
        CALL GetFlowPtr
        SPHL
        PUSH D
        MOV A,M
        INX H
        PUSH PSW
        PUSH D
        MVI E,00H
        JNZ Error
        CALL FLoadFromMem
        XTHL
        PUSH H
        CALL FAddMem
        POP H
        CALL FCopyToMem
        POP H
        CALL FLoadBCDEfromMem
        PUSH H
        CALL FCompare
        POP H
        POP B
        SUB B
        CALL FLoadBCDEfromMem
        JZ ForLoopIsComplete
        XCHG
        SHLD CURRENT_LINE
        MOV L,C
        MOV H,B
        JMP EndOfForHandler
ForLoopIsComplete
        SPHL
        LHLD PROG_PTR_TEMP
        JMP ExecNext
EvalExpression
        DCX H
        MVI D,00H
        PUSH D
        MVI C,01H
        CALL CheckEnoughVarSpace
        CALL EvalTerm
        SHLD L015F
ArithParse
        LHLD L015F
        POP B
        MOV A,M
        MVI D,00H
        SUI 98H	;KWID_PLUS
        RC
        CPI 04H
        RNC
        MOV E,A
        RLC
        ADD E
        MOV E,A
        LXI H,KW_ARITH_OP_FNS
        DAD D
        MOV A,B
        MOV D,M
        CMP D
        RNC
        INX H
        PUSH B
        LXI B,ArithParse
        PUSH B
        MOV C,D	;???
        CALL FPush
        MOV D,C
        RST 6
        LHLD L015F
        JMP EvalExpression+3
EvalTerm
        RST 02	;RST NextChar
        JC FIn
        CALL CharIsAlpha
        JNC EvalVarTerm
        CPI 98H	;KWID_PLUS
        JZ EvalTerm
        CPI '.'
        JZ FIn
        CPI 99H	;KWID_MINUS
        JZ EvalMinusTerm
        SUI 9FH
        JNC EvalInlineFn
EvalBracketed
        RST 01	; SyntaxCheck
        DB 28H	;'('
        CALL EvalExpression
        RST 01	; SyntaxCheck
        DB 29H	;')'
        RET
EvalMinusTerm
        CALL EvalTerm
        PUSH H
        CALL FNegate
        POP H
        RET
EvalVarTerm
        CALL GetVar
        PUSH H
        XCHG
        CALL FLoadFromMem
        POP H
        RET
EvalInlineFn
        MVI B,00H
        RLC
        MOV C,A
        PUSH B
        RST 02	;RST NextChar
        CALL EvalBracketed
        XTHL
        LXI D,06F1H
        PUSH D
        LXI B,KW_INLINE_FNS
        DAD B
        RST 6
        RET
DimContd
        DCX H
        RST 02	;RST NextChar
        RZ
        RST 01	; SyntaxCheck
        DB 2CH	;','
Dim     LXI B,DimContd
        PUSH B
        DB 0F6H
GetVar  XRA A
        STA DIM_OR_EVAL
        MOV B,M
        CALL CharIsAlpha
        JC SyntaxError
        XRA A
        MOV C,A
        RST 02	;RST NextChar
        JNC 072EH
        MOV C,A
        RST 02	;RST NextChar
        SUI '('
        JZ GetArrayVar
        PUSH H
        LHLD VAR_ARRAY_BASE
        XCHG
        LHLD VAR_BASE
FindVarLoop
        RST 4
        JZ AllocNewVar
        MOV A,C
        SUB M
        INX H
        JNZ L0747
        MOV A,B
        SUB M
L0747   INX H
        JZ L0782
        INX H
        INX H
        INX H
        INX H
        JMP FindVarLoop
AllocNewVar
        POP H	;HL=prog ptr
        XTHL	;(SP)=prog ptr, HL=ret.addr.
        PUSH D	;
        LXI D,06F6H	;an address inside EvalTerm
        RST 4	;
        POP D	;
        JZ AlreadyAllocd	;
        XTHL	;(SP)=ret.addr, HL=prog ptr.
        PUSH H	;Prog ptr back on stack
        PUSH B	;Preserve var name on stack
        LXI B,0006H
        LHLD VAR_TOP
        PUSH H
        DAD B
        POP B
        PUSH H
        CALL CopyMemoryUp
        POP H
        SHLD VAR_TOP
        MOV H,B
        MOV L,C
        SHLD VAR_ARRAY_BASE
InitVarLoop
        DCX H
        MVI M,00H
        RST 4
        JNZ InitVarLoop
        POP D
        MOV M,E
        INX H
        MOV M,D
        INX H
L0782   XCHG
        POP H
        RET
AlreadyAllocd
        STA FACCUM+3	;A was set to zero at 075A.
        POP H
        RET
GetArrayVar
        PUSH B
        LDA DIM_OR_EVAL
        PUSH PSW
        CALL GetSubscript
        RST 01	; SyntaxCheck
        DB 29H	;')'
        POP PSW
        STA DIM_OR_EVAL
        XTHL
        XCHG
        DAD H
        DAD H
        PUSH H
        LHLD VAR_ARRAY_BASE
        DB 01H	;LXI B,....
FindArray
        POP B
        DAD B
        XCHG
        PUSH H
        LHLD VAR_TOP
        RST 4
        XCHG
        POP D
        JZ AllocArray
        RST 6
        XTHL
        RST 4
        POP H
        RST 6
        JNZ FindArray
        LDA DIM_OR_EVAL
        ORA A
        MVI E,12H
        JNZ Error
L07BF   POP D
        DCX D
        XTHL
        RST 4
        MVI E,10H
        JNC Error
        POP D
        DAD D
        POP D
        XCHG
        RET
AllocArray
        MOV M,E
        INX H
        MOV M,D
        INX H
        LXI D,002CH
        LDA DIM_OR_EVAL
        ORA A
        JZ L07E1
        POP D
        PUSH D
        INX D
        INX D
        INX D
        INX D
L07E1   PUSH D
        MOV M,E
        INX H
        MOV M,D
        INX H
        PUSH H
        DAD D
        CALL CheckEnoughMem
        SHLD VAR_TOP
        POP D
InitElements
        DCX H
        MVI M,00H
        RST 4
        JNZ InitElements
        JMP L07BF
FWordToFloat
        MOV D,B
        MVI E,00H
        MVI B,90H	;exponent=2^16
        JMP FCharToFloat+5	;
FAddOneHalf
        LXI H,ONE_HALF	;Load BCDE with (float) 0.5.
FAddMem CALL FLoadBCDEfromMem
        JMP FAdd+2
FSub    POP B	;Get lhs in BCDE.
        POP D	;
        CALL FNegate	;Negate rhs and slimily
        DB 21H	;LXI H,.... ;LXI into FAdd + 2.
FAdd    POP B	;Get lhs in BCDE.
        POP D	;
        MOV A,B	;If lhs==0 then we don't need
        ORA A	;to do anything and can just
        RZ	;exit.
        LDA FACCUM+3	;If rhs==0 then exit via a copy
        ORA A	;of lhs to FACCUM.
        JZ FLoadFromBCDE	;
        SUB B	;A=rhs.exponent-lhs.exponent.
        JNC L082C	;If rhs' exponent >= lhs'exponent, jump ahead.
        CMA	;Two's complement the exponent
        INR A	;difference, so it's correct.
        XCHG	;
        CALL FPush	;Push old rhs
        XCHG	;
        CALL FLoadFromBCDE	;rhs = old lhs
        POP B	;lhs = old rhs.
        POP D	;
L082C   PUSH PSW	;Preserve exponent diff
        CALL FUnpackMantissas
        MOV H,A	;H=sign relationship
        POP PSW	;A=exponent diff.
        CALL FMantissaRtMult	;Shift lhs mantissa right by (exponent diff) places.
        ORA H	;A=0 after last call, so this tests
        LXI H,FACCUM	;the sign relationship.
        JP FSubMantissas	;Jump ahead if we need to subtract.
        CALL FAddMantissas	;
        JNC FRoundUp	;Jump ahead if that didn't overflow.
        INX H	;Flip the sign in FTEMP_SIGN.
        INR M	;
        JZ Overflow	;Error out if exponent overflowed.
        CALL FMantissaRtOnce;Shift mantissa one place right
        JMP FRoundUp	;Jump ahead.
FSubMantissas
        XRA A	;B=0-B (HL=FACCUM on entry)
        SUB B	;carry_1
        STA ARITH_TMP	;save result (no flag effect)
        LDA FACCUM	;load (FACCUM+0) (no flag effect)
        SBB E	;(FACCUM)-E, carry_2
        STA ARITH_TMP+1	;save result
        LDA FACCUM+1	;load (FACCUM+1)
        SBB D	;(FACCUM+1)-D, carry_3
        STA ARITH_TMP+2	;save result
        LDA FACCUM+2	;load (FACCUM+2)
        SBB C	;(FACCUM+2)-C, carry_4
        STA ARITH_TMP+3	;save result
        PUSH PSW	;save carry_4 for CC FNegateInt
        LDA ARITH_TMP	;restore B
        MOV B,A
        LDA ARITH_TMP+1	;restore E
        MOV E,A
        LDA ARITH_TMP+2	;restore D
        MOV D,A
        LDA ARITH_TMP+3	;restore C
        MOV C,A
        POP PSW	;restore carry_4 (sign flag)
FNormalise
        CC FNegateInt	;
        MVI H,00H	;
        MOV A,C	;Test most-significant bit of mantissa
        ORA A	;and jump ahead if it's 1.
        JM FRoundUp	;
NormLoop
        MOV A,H	;Get shift count for safety check
        CPI 0E0H	;If we've shifted 32 times,
        JZ FZero	;then the number is 0.
        DCR H	;
        MOV A,B	;Left-shift extra mantissa byte
        ADD A	;
        MOV B,A	;
        CALL FMantissaLeft	;Left-shift mantissa.
        MOV A,C	;Get mantissa high byte
        ORA A	;Set flags explicitly (S=1 when normalized)
        JP NormLoop	;Loop while not normalized
        MOV A,H	;Get shift count for exponent adjustment
        LXI H,FACCUM+3	;
        ADD M	;
        STA FACCUM+3	;(no flag effect, preserves carry+zero)
        JNC FZero	;have carried, hence the extra check for zero.
        RZ	;?why?
FRoundUp
        MOV A,B	;A=extra mantissa byte
        LXI H,FACCUM+3	;
        ORA A	;If bit 7 of the extra mantissa byte
        CM FMantissaInc	;is set, then round up the mantissa.
        MOV B,M	;B=exponent
        INX H	;
        MOV A,M	;A=FTEMP_SIGN
        ANI 80H	;
        XRA C	;Bit 7 of C is always 1. Thi
        MOV C,A	;
        JMP FLoadFromBCDE	;Exit via copying BCDE to FACCUM.
FMantissaLeft
        ;Pre-save E,D,C to memory (MOV clobbers carry on this CPU)
        MOV A,E
        STA ARITH_TMP
        MOV A,D
        STA ARITH_TMP+1
        MOV A,C
        STA ARITH_TMP+2
        ;Shift chain with LDA/STA only (preserves carry)
        LDA ARITH_TMP	;load E
        RAL	;carry_1 = MSB of E
        STA ARITH_TMP	;save shifted E
        LDA ARITH_TMP+1	;load D (carry_1 preserved)
        RAL	;carry_2
        STA ARITH_TMP+1
        LDA ARITH_TMP+2	;load C (carry_2 preserved)
        ADC A	;carry_3
        STA ARITH_TMP+2
        ;Restore registers
        PUSH PSW	;save carry_3
        LDA ARITH_TMP
        MOV E,A
        LDA ARITH_TMP+1
        MOV D,A
        LDA ARITH_TMP+2
        MOV C,A
        POP PSW	;restore carry_3
        RET
FMantissaInc
        INR E
        RNZ
        INR D
        RNZ
        INR C
        RNZ
        MVI C,80H	;Mantissa overflowed to zero, so set it
        INR M	;to 1 and increment the exponent.
        RNZ	;And if the exponent overflows...
Overflow
        MVI E,0AH
        JMP Error
FAddMantissas
        MOV A,M	;load first byte
        ADD E	;carry_1
        PUSH PSW	;save result + carry_1
        MOV E,A	;save result to E
        INX H	;advance HL
        MOV A,M	;load next byte (clobbers carry_1)
        STA ARITH_TMP	;park value (no flag effect)
        POP PSW	;restore carry_1
        LDA ARITH_TMP	;reload value (carry_1 preserved)
        ADC D	;carry_2
        PUSH PSW	;save result + carry_2
        MOV D,A	;save result to D
        INX H	;advance HL
        MOV A,M	;load next byte (clobbers carry_2)
        STA ARITH_TMP	;park value
        POP PSW	;restore carry_2
        LDA ARITH_TMP	;reload value (carry_2 preserved)
        ADC C	;carry_3
        PUSH PSW	;save carry_3 for caller's JNC test
        MOV C,A	;save result to C
        POP PSW	;restore carry_3
        RET
FNegateInt
        LXI H,FTEMP
        MOV A,M
        CMA
        MOV M,A
        XRA A
        MOV L,A
        SUB B
        MOV B,A
        MOV A,L
        SBB E
        MOV E,A
        MOV A,L
        SBB D
        MOV D,A
        MOV A,L
        SBB C
        MOV C,A
        RET
FMantissaRtMult
        MVI B,00H	;Initialise extra mantissa byte
        INR A
        MOV L,A
RtMultLoop
        XRA A
        DCR L
        RZ
        CALL FMantissaRtOnce
        JMP RtMultLoop
FMantissaRtOnce
        MOV A,C	;load C (1 byte, normal entry)
FMantRtSkipC	;entry when A already has C value
        ;Pre-save all four bytes to memory
        STA ARITH_TMP	;save C/A
        MOV A,D
        STA ARITH_TMP+1
        MOV A,E
        STA ARITH_TMP+2
        MOV A,B
        STA ARITH_TMP+3
        ;Shift chain (LDA/STA preserve carry)
        LDA ARITH_TMP	;load C
        RAR
        STA ARITH_TMP
        LDA ARITH_TMP+1	;load D (carry preserved)
        RAR
        STA ARITH_TMP+1
        LDA ARITH_TMP+2	;load E (carry preserved)
        RAR
        STA ARITH_TMP+2
        LDA ARITH_TMP+3	;load B (carry preserved)
        RAR
        STA ARITH_TMP+3
        ;Restore registers
        PUSH PSW	;save final carry
        LDA ARITH_TMP
        MOV C,A
        LDA ARITH_TMP+1
        MOV D,A
        LDA ARITH_TMP+2
        MOV E,A
        LDA ARITH_TMP+3
        MOV B,A
        POP PSW	;restore carry
        RET	;
FMul    POP B	;Get lhs in BCDE
        POP D	;
        RST 05	; FTestSign ;If rhs==0 then exit
        RZ	;
        MVI L,00H	;L=0 to signify exponent add
        CALL FExponentAdd
        MOV A,C
        STA FMulInnerLoop+13
        XCHG
        SHLD FMulInnerLoop+8
        LXI B,0000H
        MOV D,B
        MOV E,B
        LXI H,FNormalise+3
        PUSH H
        LXI H,FMulOuterLoop
        PUSH H
        PUSH H
        LXI H,FACCUM
FMulOuterLoop
        MOV A,M	;A=FACCUM mantissa byte
        INX H	;
        PUSH H	;Preserve FACCUM ptr
        MVI L,08H	;8 bits to do
FMulInnerLoop
        RAR	;Test lowest bit of mantissa byte
        JNC L0919_SKIP	;test carry before MOV clobbers it
        MOV H,A	;Preserve mantissa byte
        MOV A,C	;A=result mantissa's high byte
        PUSH H	;
        LXI H,0000H	;
        DAD D	;
        POP D	;
        ACI 00	;A=result mantissa high byte -> C via FMantRtSkipC
        XCHG	;
        JMP L0919
L0919_SKIP
        MOV H,A	;Preserve mantissa byte
        MOV A,C	;A=result mantissa's high byte
L0919   CALL FMantRtSkipC
        DCR L
        JZ PopHLandReturn	;exit if done (test Z before MOV)
        MOV A,H	;Restore mantissa byte
        JMP FMulInnerLoop	;loop
PopHLandReturn
        POP H	;Restore FACCUM ptr
        RET	;Return to FMulOuterLoop, or finish to FNormalise
FDivByTen
        CALL FPush	;
        LXI B,8420H	;BCDE=(float)10;
        LXI D,0000H
        CALL FLoadFromBCDE
FDiv    POP B
        POP D
        RST 05	; FTestSign
        JZ DivideByZero
        MVI L,0FFH
        CALL FExponentAdd
        INR M
        INR M
        DCX H
        MOV A,M
        STA L095F+1
        DCX H
        MOV A,M
        STA L095F-3
        DCX H
        MOV A,M
        STA L095F-7
        MOV B,C
        XCHG
        XRA A
        MOV C,A
        MOV D,A
        MOV E,A
        STA L095F+4
FDivLoop
        PUSH H
        PUSH B
        MOV A,L
        SUI 00H
        MOV L,A
        MOV A,H
        SBI 00
        MOV H,A
        MOV A,B
L095F   SBI 00
        MOV B,A
        MVI A,00H
        SBI 00
        CMC
        JNC L0971
        STA L095F+4H
        POP PSW
        POP PSW
        STC
        DB 0D2H	;JNC ....
L0971   POP B
        POP H
        MOV A,C
        INR A
        DCR A
        RAR
        JM FRoundUp+1
        RAL
        CALL FMantissaLeft
        DAD H
        MOV A,B
        RAL
        MOV B,A
        LDA L095F+4H
        RAL
        STA L095F+4H
        MOV A,C
        ORA D
        ORA E
        JNZ FDivLoop
        PUSH H
        LXI H,FACCUM+3
        DCR M
        POP H
        JNZ FDivLoop
        JMP Overflow
FExponentAdd
        MOV A,B
        ORA A
        JZ FExpAdd_ZeroExp
        MOV A,L	;A=0 for add, FF for subtract.
        LXI H,FACCUM+3	;
        XRA M	;XOR with FAccum's exponent.
        ADD B	;Add exponents
        MOV B,A	;
        RAR	;Carry (after the add) into bit 7.
        XRA B	;XOR with old bit 7.
        JP FExpAdd_NoOvf	;test sign before MOV clobbers it
        MOV A,B	;
        ADI 80H
        STA FACCUM+3	;(no flag effect, preserves zero)
        JZ PopHLandReturn
        CALL FUnpackMantissas
        MOV M,A
        DCX H
        RET
FExpAdd_NoOvf
        MOV A,B	;restore A=B for the ORA A path
FExpAdd_ZeroExp
        ORA A
        POP H	;Ignore return address so we'll end
        JM Overflow
FZero   XRA A
        STA FACCUM+3
        RET
FMulByTen
        CALL FCopyToBCDE
        MOV A,B
        ORA A
        RZ
        ADI 02
        JC Overflow
        MOV B,A
        CALL FAdd+2
        LXI H,FACCUM+3
        INR M
        RNZ
        JMP Overflow
FTestSign_tail
        LDA FACCUM+2
        DB 0FEH
InvSignToInt
        CMA
SignToInt
        RAL
        SBB A
        RNZ
        INR A
        RET
Sgn     RST 05	; FTestSign
FCharToFloat
        MVI B,88H	;ie 2^8
        LXI D,0000H
        LXI H,FACCUM+3
        MOV C,A
        MOV M,B
        MVI B,00H
        INX H
        MVI M,80H
        RAL
        JMP FNormalise
Abs     RST 05	; FTestSign
        RP
FNegate LXI H,FACCUM+2
        MOV A,M
        XRI 80H
        MOV M,A
        RET
FPush   XCHG
        LHLD FACCUM
        XTHL
        PUSH H
        LHLD FACCUM+2
        XTHL
        PUSH H
        XCHG
        RET
FLoadFromMem
        CALL FLoadBCDEfromMem
FLoadFromBCDE
        XCHG
        SHLD FACCUM
        MOV H,B
        MOV L,C
        SHLD FACCUM+2
        XCHG
        RET
FCopyToBCDE
        LXI H,FACCUM
FLoadBCDEfromMem
        MOV E,M
        INX H
        MOV D,M
        INX H
        MOV C,M
        INX H
        MOV B,M
IncHLReturn
        INX H
        RET
FCopyToMem
        LXI D,FACCUM
        MVI B,04H
FCopyLoop
        LDAX D
        MOV M,A
        INX D
        INX H
        DCR B
        JNZ FCopyLoop
        RET
FUnpackMantissas
        LXI H,FACCUM+2
        MOV A,M	;
        RLC	;Move FACCUM's sign to bit 0.
        STC	;Set MSB of FACCUM mantissa,
        RAR	;FACCUM's sign is now in carry.
        MOV M,A	;
        CMC	;Negate FACCUM's sign.
        RAR	;Bit 7 of A is now FACCUM's sign.
        INX H	;Store negated FACCUM sign at FTEMP_SIGN.
        INX H	;
        MOV M,A	;
        MOV A,C	;
        RLC	;Set MSB of BCDE mantissa,
        STC	;BCDE's sign is now in carry.
        RAR	;
        MOV C,A	;
        RAR	;Bit 7 of A is now BCDE's sign
        XRA M	;XORed with FTEMP_SIGN.
        RET	;
FCompare
        MOV A,B
        ORA A
        JZ FTestSign
        LXI H,InvSignToInt
        PUSH H
        RST 05	; FTestSign
        MOV A,C
        RZ
        LXI H,FACCUM+2
        XRA M
        MOV A,C
        RM
        CALL FIsEqual
        RAR
        XRA C
        RET
FIsEqual
        INX H
        MOV A,B
        CMP M
        RNZ
        DCX H
        MOV A,C
        CMP M
        RNZ
        DCX H
        MOV A,D
        CMP M
        RNZ
        DCX H
        MOV A,E
        SUB M
        RNZ	;
        POP H	;Lose 0A5E
        POP H	;Lose 09DE
        RET	;Return to caller
FAsInteger
        MOV B,A	;
        MOV C,A
        MOV D,A
        MOV E,A
        ORA A
        RZ
        PUSH H
        CALL FCopyToBCDE
        CALL FUnpackMantissas
        XRA M	;Get sign back (sets sign flag)
        PUSH PSW	;save A + sign flag
        MOV H,A	;save value to H (clobbers flags)
        POP PSW	;restore sign flag
        CM FMantissaDec
        MVI A,98H
        SUB B	;by (24-exponent) places?
        CALL FMantissaRtMult	;WHY?
        MOV A,H
        RAL
        CC FMantissaInc
        MVI B,00H	;Needed for FNegateInt.
        CC FNegateInt
        POP H
        RET
FMantissaDec
        DCX D	;DE--
        MOV A,D	;If DE!=0xFFFF...
        ANA E	;
        INR A	;
        RNZ	;... then return
        DCR C	;C--
        RET	;
Int     LXI H,FACCUM+3	;
        MOV A,M	;
        CPI 98H	;
        RNC	;
        CALL FAsInteger	;
        MVI M,98H	;
        MOV A,C	;
        RAL	;
        JMP FNormalise	;
FIn     DCX H	;
        CALL FZero	;
        MOV B,A	;B=count of fractional digits
        MOV D,A	;D=exponent sign
        MOV E,A	;E=exponent
        CMA	;C=decimal_point_done (0xFF for no, 0x00 for yes)
        MOV C,A	;
FInLoop RST 02	;RST NextChar
        JC ProcessDigit
        CPI '.'
        JZ L0AE4
        CPI 'E'
        JNZ ScaleResult
GetExponent
        RST 02	;RST NextChar
        DCR D
        CPI 99H	;KWID_MINUS
        JZ NextExponentDigit
        INR D
        CPI 98H	;KWID_PLUS
        JZ NextExponentDigit
        DCX H
NextExponentDigit
        RST 02	;RST NextChar
        JC DoExponentDigit
        INR D
        JNZ ScaleResult
        XRA A
        SUB E
        MOV E,A
        INR C	;C was 0xFF, so here it
L0AE4   INR C	;becomes 0x01.
        JZ FInLoop	;If C is now zero
ScaleResult
        PUSH H
        MOV A,E
        SUB B
DecimalLoop
        CP DecimalShiftUp
        JP DecimalLoopEnd
        PUSH PSW
        CALL FDivByTen
        POP PSW
        INR A
DecimalLoopEnd
        JNZ DecimalLoop
        POP H
        RET
DecimalShiftUp
        RZ
        PUSH PSW
        CALL FMulByTen
        POP PSW
        DCR A
        RET
ProcessDigit
        PUSH D
        MOV D,A
        MOV A,B
        ADC C
        MOV B,A
        PUSH B
        PUSH H
        PUSH D
        CALL FMulByTen
        POP PSW
        SUI '0'
        CALL FPush
        CALL FCharToFloat
        POP B
        POP D
        CALL FAdd+2
        POP H
        POP B
        POP D
        JMP FInLoop
DoExponentDigit
        MOV A,E
        RLC
        RLC
        ADD E
        RLC
        ADD M
        SUI '0'
        MOV E,A
        JMP NextExponentDigit
PrintIN PUSH H
        LXI H,szIn
        CALL PrintString
        POP H
PrintInt
        XCHG	;DE=integer
        XRA A	;A=0 (ends up in C)
        MVI B,98H	;B (ie exponent) = 24
        CALL FCharToFloat+5
        LXI H,PrintString-1
        PUSH H
FOut    LXI H,FBUFFER
        PUSH H
        RST 05	; FTestSign
        MVI M,' '
        JP DoZero
        MVI M,'-'
DoZero  INX H
        MVI M,'0'
        JZ NullTerm-3
        PUSH H
        CM FNegate
        XRA A
        PUSH PSW
        CALL ToUnder1000000
ToOver100000
        LXI B,9143H	;BCDE=(float)100,000.
        LXI D,4FF8H	;
        CALL FCompare	;If FACCUM >= 100,000
        JPO PrepareToPrint	;then jump to PrepareToPrint.
        POP PSW	;A=DecExpAdj
        CALL DecimalShiftUp+1	;FACCUM*=10; DecExpAdj--;
        PUSH PSW	;
        JMP ToOver100000
L0B71   CALL FDivByTen
        POP PSW
        INR A	;DecExpAdj++;
        PUSH PSW
        CALL ToUnder1000000
PrepareToPrint
        CALL FAddOneHalf
        INR A
        CALL FAsInteger
        CALL FLoadFromBCDE
        LXI B,0206H
        POP PSW	;A=DecExpAdj+6.
        ADD C	;
        JM L0B95	;If A<1 or A>6 Then goto fixme.
        CPI 07H	;
        JNC L0B95	;
        INR A	;
        MOV B,A	;
        MVI A,01H	;A=1, indicating scientific notation.
L0B95   DCR A	;
        POP H	;HL=output buffer
        PUSH PSW	;Preserve decimal exponent adjustment (and preserve zero flag used to indicate scientific notation wanted).
        LXI D,DECIMAL_POWERS
NextDigit
        DCR B
        MVI M,'.'
        CZ IncHLReturn	;0A27 just happens to inc HL and RET.
        PUSH B	;
        PUSH H	;
        PUSH D	;DE=>decimal power
        CALL FCopyToBCDE	;Store BCDE to FACCUM.
        POP H	;HL=>decimal power.
        MVI B,'0'-1	;
        ;Pre-save CDE to ARITH_TMP for carry-safe loop
        MOV A,E
        STA ARITH_TMP
        MOV A,D
        STA ARITH_TMP+1
        MOV A,C
        STA ARITH_TMP+2
DigitLoop
        INR B
        LDA ARITH_TMP	;load E (no flag effect)
        SUB M	;E-(HL), carry_1
        STA ARITH_TMP	;save result
        INX H
        LDA ARITH_TMP+1	;load D (carry_1 preserved)
        SBB M	;D-(HL)-borrow, carry_2
        STA ARITH_TMP+1
        INX H
        LDA ARITH_TMP+2	;load C (carry_2 preserved)
        SBB M	;C-(HL)-borrow, carry_3
        STA ARITH_TMP+2
        PUSH PSW	;save carry_3
        LDA ARITH_TMP
        MOV E,A
        LDA ARITH_TMP+1
        MOV D,A
        LDA ARITH_TMP+2
        MOV C,A
        POP PSW	;restore carry_3
        DCX H
        DCX H
        JNC DigitLoop	;
        CALL FAddMantissas	;
        INX H	;???
        CALL FLoadFromBCDE	;
        XCHG	;
        POP H	;HL=output buffer
        MOV M,B	;
        INX H	;
        POP B	;B=decimal point place
        DCR C	;C=digits remaining, minus one.
        JNZ NextDigit	;
        DCR B	;
        JZ L0BDB	;
L0BCF   DCX H	;
        MOV A,M	;
        CPI '0'	;
        JZ L0BCF	;
        CPI '.'	;
        CNZ IncHLReturn	;
L0BDB   POP PSW	;
        JZ NullTerm	;
        MVI M,'E'	;Write 'E'
        INX H	;
        MVI M,'+'	;Write '+' or '-'
        JP L0BEB	;
        MVI M,'-'	;Write '-' if it's negative, also
        CMA	;two's complement the decimal exponent
        INR A	;so printing it will work.
L0BEB   MVI B,'0'-1	;
ExpDigitLoop
        INR B	;
        SUI 0AH	;
        JNC ExpDigitLoop	;
        ADI 3AH	;Adding '0'+10 gives us the 2nd digit
        INX H	;of the exponent.
        MOV M,B	;Write first digit.
        INX H	;
        MOV M,A	;Write second digit of exponent.
        INX H	;
NullTerm
        MOV M,C	;Null byte terminator.
        POP H	;
        RET	;
ToUnder1000000
        LXI B,9474H	;
        LXI D,23F7H	;
        CALL FCompare	;
        POP H	;
        JPO L0B71	;
        PCHL	;
ONE_HALF
        DB 00H,00H,00H,80H	; DD 0.5
DECIMAL_POWERS
        DB 0A0H,86H,01H	; DT 100000
        DB 10H,27H,00H	; DT 10000
        DB 0E8H,03H,00H	; DT 1000
        DB 64H,00H,00H	; DT 100
        DB 0AH,00H,00H	; DT 10
        DB 01H,00H,00H	; DT 1
Sqr     RST 05	; FTestSign ;
        JM FunctionCallError;
        RZ	;
        LXI H,FACCUM+3	;
        MOV A,M	;
        RAR	;
        PUSH PSW	;
        PUSH H	;
        MVI A,40H	;
        RAL	;
        MOV M,A	;
        LXI H,FBUFFER	;
        CALL FCopyToMem	;
        MVI A,04H	;
SqrLoop PUSH PSW	;
        CALL FPush	;
        LXI H,FBUFFER	;
        CALL FLoadBCDEfromMem
        CALL FDiv+2
        POP B
        POP D
        CALL FAdd+2
        LXI B,8000H
        MOV D,C
        MOV E,C
        CALL FMul+2
        POP PSW
        DCR A
        JNZ SqrLoop
        POP H
        POP PSW
        ADI 0C0H
        ADD M
        MOV M,A
        RET
Rnd     RST 05	; FTestSign
        JM L0C7C
        LXI H,RND_SEED
        CALL FLoadFromMem
        RZ
        LXI B,9835H
        LXI D,447AH
        CALL FMul+2
        LXI B,6828H
        LXI D,0B146H
        CALL FAdd+2
L0C7C   CALL FCopyToBCDE
        MOV A,E
        MOV E,C
        MOV C,A
        MVI M,80H
        DCX H
        MOV B,M
        MVI M,80H
        CALL FNormalise+3
        LXI H,RND_SEED
        JMP FCopyToMem
RND_SEED
        DB 52H,0C7H,4FH,80H
Sin     CALL FPush	;ush x
        LXI B,8349H	;CDE=2p
        LXI D,0FDBH	;
        CALL FLoadFromBCDE	;hs = 2p
        POP B	;hs = x
        POP D	;
        CALL FDiv+2	;=x/2p
        CALL FPush	;
        CALL Int	;hs = INT(u)
        POP B	;hs = u
        POP D	;
        CALL FSub+2	;=u-INT(u)
        LXI B,7F00H	;CDE=0.25
        MOV D,C	;
        MOV E,C	;
        CALL FSub+2	;
        RST 05	; FTestSign ;
        STC	;set carry (ie no later negate)
        JP NegateIfPositive	;
        CALL FAddOneHalf	;
        RST 05	;
        ORA A	;resets carry (ie later negate)
NegateIfPositive
        PUSH PSW	;
        CP FNegate	;
        LXI B,7F00H	;CDE=0.25
        MOV D,C	;
        MOV E,C	;
        CALL FAdd+2	;
        POP PSW	;
        CNC FNegate	;
        CALL FPush	;
        CALL FCopyToBCDE	;
        CALL FMul+2	; = x*x
        CALL FPush	;ush x*x
        LXI H,TAYLOR_SERIES	;
        CALL FLoadFromMem	;
        POP B	;
        POP D	;
        MVI A,04H	;
TaylorLoop
        PUSH PSW	;ush #terms remaining
        PUSH D	;ush BCDE
        PUSH B	;
        PUSH H	;
        CALL FMul+2	;
        POP H	;
        CALL FLoadBCDEfromMem	;
        PUSH H	;
        CALL FAdd+2	;
        POP H	;
        POP B	;
        POP D	;
        POP PSW	;op #terms remaining into A.
        DCR A	;ecrement #terms and loop back if not
        JNZ TaylorLoop	;one all 4 of them.
        JMP FMul	;
TAYLOR_SERIES
        DB 0BAH,0D7H,1EH,86H	;DD 39.710670
        DB 64H,26H,99H,87H	;DD -76.574982
        DB 58H,34H,23H,87H	;DD 81.602234
        DB 0E0H,5DH,0A5H,86H	;DD -41.341675
        DB 0DAH,0FH,49H,83H	;DD 6.283185
L0D17   DB 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H	;   DD 6.283185
;--- PATCHED: Init - stack setup + skip hardware detection ---
Init    LXI SP,STACK_TOP   ; Temporary stack at physical RAM top
        LXI H,STACK_TOP
        SHLD BAS_STKTOP
        IF BASIC_STANDALONE
        CALL SIO_INIT   ; Init serial hardware
        IF VIDEO_BASE
        CALL V_INIT     ; Init video display
        ENDIF
        ENDIF
        JMP InitBasicVars ; Skip hardware detection
;--- MemProbeCheck: ceiling for memory auto-detect ---
; Called from FindMemTopLoop instead of jumping back directly.
; Stops probing when HL reaches the memory ceiling to prevent
; infinite loop on systems where all 64KB is RAM (e.g., cpmsim).
;
; STACK_TOP=0 means 64KB (wraps). Detect wrap by checking if
; INX H would wrap HL past FFFFH. We already incremented HL in
; FindMemTopLoop, so check if HL has wrapped to 0000H.
MemProbeCheck
        IF STACK_TOP
        ; Fixed ceiling: stop when HL >= STACK_TOP
        MOV     A,H
        CPI     STACK_TOP / 256
        JC      FindMemTopLoop  ; H < ceiling: keep probing
        JNZ     DoneMemSize     ; H > ceiling: stop
        MOV     A,L
        CPI     STACK_TOP AND 0FFH
        JC      FindMemTopLoop  ; L < ceiling: keep probing
        JMP     DoneMemSize     ; At/past ceiling: stop
        ELSE
        ; 64KB: stop when HL wraps to 0000H
        MOV     A,H
        ORA     L
        JNZ     FindMemTopLoop  ; HL != 0: keep probing
        JMP     DoneMemSize     ; HL wrapped to 0: stop
        ENDIF
        ; (NOP fill removed: FP carry-chain fixes grew code past 0DB3H)
;--- end Init patch ---
InitBasicVars
        LXI H,0FFFFH	;
        SHLD CURRENT_LINE	;
        CALL NewLine	;
        LXI H,szMemorySize	;
        CALL PrintString
        CALL InputLineWith
        RST 02	;RST NextChar
        ORA A
        JNZ L0DDE
        IF BASIC_STANDALONE
        LXI H,CODE_END-1   ; Probe after all code (standalone)
        ELSE
        LXI H,UnusedMemory ; Probe after BASIC only (loadable)
        ENDIF
FindMemTopLoop
        INX H
        MVI A,37H
        MOV M,A
        CMP M
        JNZ DoneMemSize
        DCR A
        MOV M,A
        CMP M
        JZ MemProbeCheck ; Check ceiling before looping
        JMP DoneMemSize
L0DDE   LXI H,LINE_BUFFER
        CALL LineNumberFromStr
        ORA A
        JNZ SyntaxError
        XCHG
        DCX H
DoneMemSize
        DCX H
        PUSH H
GetTerminalWidth
        LXI H,szTerminalWidth
        CALL PrintString
        CALL InputLineWith
        RST 02	;RST NextChar
        ORA A
        JZ DoOptionalFns
        LXI H,LINE_BUFFER
        CALL LineNumberFromStr
        MOV A,D
        ORA A
        JNZ GetTerminalWidth
        MOV A,E
        CPI 10H
        JC GetTerminalWidth
        STA OutChar_tail+1
CalcTabBrkSize
        SUI 0EH
        JNC CalcTabBrkSize
        ADI 1CH
        CMA
        INR A
        ADD E
        STA ToNextTabBreak+4
DoOptionalFns
        LXI H,OPT_FN_DESCS
OptionalFnsLoop
        RST 6
        LXI D,szWantSin
        RST 4
        JZ L0E32
        RST 6
        XTHL
        CALL PrintString
        CALL InputLineWith
        RST 02	;RST NextChar
        POP H
        CPI 'Y'
L0E32   POP D
        JZ InitProgramBase
        CPI 'N'
        JNZ DoOptionalFns
        RST 6
        XTHL
        LXI D,FunctionCallError
        MOV M,E
        INX H
        MOV M,D
        POP H
        JMP OptionalFnsLoop
InitProgramBase
        XCHG
        MVI M,00H
        INX H
        SHLD PROGRAM_BASE
        XTHL
        LXI D,BAS_MEM_TOP ; Configurable stack top
        RST 4
        JC OutOfMemory
        POP D
        SPHL
        SHLD BAS_STKTOP
        XCHG
        CALL CheckEnoughMem
        MOV A,E
        SUB L
        MOV L,A
        MOV A,D
        SBB H
        MOV H,A
        LXI B,0FFF0H
        DAD B
        CALL NewLine
        CALL PrintInt
        LXI H,szVersionInfo
        CALL PrintString
        LXI H,PrintString
        SHLD Main+4
        CALL New+1
        LXI H,Main
        SHLD Start+2
        PCHL

OPT_FN_DESCS
        DW L0D17
        DW szWantSin
        DW KW_INLINE_FNS+12
        DW Sin
        DW szWantRnd
        DW KW_INLINE_FNS+10
        DW Rnd
        DW szWantSqr
        DW KW_INLINE_FNS+8

        DW Sqr

szWantSin
        DB 57H,41H,4EH,54H,20H,53H,49H,0CEH,00H	; DS "WANT SIN\0"
szWantRnd
        DB 57H,41H,4EH,54H,20H,52H,4EH,0C4H,00H	; DS "WANT RND\0"
szWantSqr
        DB 57H,41H,4EH,54H,20H,53H,51H,0D2H,00H	; DS "WANT SQR\0"

szTerminalWidth
        DB 54H,45H,52H,4DH,49H,4EH,41H,4CH,20H,57H,49H,44H,54H,0C8H,00H	; DS "TERMINAL WIDTH\0"

szVersionInfo
        DB 20H,42H,59H,54H,45H,53H,20H,46H,52H,45H,0C5H,0DH,0DH	; DS " BYTES FREE\r\r"
        DB 42H,41H,53H,49H,43H,20H,56H,45H,52H,53H,49H,4FH,4EH,20H,33H,2EH	; "BASIC VERSION 3."
        DB 0B2H,0DH,5BH,34H,4BH,20H,56H,45H,52H,53H,49H,4FH,4EH,0DDH,0DH,00H	; "2\r[4K VERSION]\r\0"
szMemorySize
        DB 4DH,45H,4DH,4FH,52H,59H,20H,53H,49H,5AH,0C5H,00H	; DS "MEMORY SIZE\0"

UnusedMemory
        DB 00

ARITH_TMP DB 00H,00H,00H,00H	;temp for carry-safe arithmetic

BASIC_END:

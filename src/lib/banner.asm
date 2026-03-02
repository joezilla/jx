;========================================================
; JX Banner - Shared boot banner
;========================================================
; Prints system identification and serial configuration.
;
; Output:
;   JX/8080 Version x.x
;   SIO xx/xx RX=xx TX=xx [8251|6850]
;
; Requires: PUTCHAR label defined by including file
; Requires assembler defines:
;   VER_MAJOR, VER_MINOR
;   SIO_DATA, SIO_STATUS, SIO_RX_MASK, SIO_TX_MASK
;   SIO_8251, SIO_6850
;========================================================

PRINT_BANNER:
        LXI     H,MSG_BAN_VER
        CALL    BAN_PRSTR
        LXI     H,MSG_BAN_SIO
        CALL    BAN_PRSTR
        MVI     A,SIO_DATA
        CALL    BAN_PRHEX
        MVI     A,'/'
        CALL    PUTCHAR
        MVI     A,SIO_STATUS
        CALL    BAN_PRHEX
        LXI     H,MSG_BAN_RX
        CALL    BAN_PRSTR
        MVI     A,SIO_RX_MASK
        CALL    BAN_PRHEX
        LXI     H,MSG_BAN_TX
        CALL    BAN_PRSTR
        MVI     A,SIO_TX_MASK
        CALL    BAN_PRHEX
        IF SIO_8251
        LXI     H,MSG_BAN_8251
        CALL    BAN_PRSTR
        ENDIF
        IF SIO_6850
        LXI     H,MSG_BAN_6850
        CALL    BAN_PRSTR
        ENDIF
        MVI     A,0DH
        CALL    PUTCHAR
        MVI     A,0AH
        CALL    PUTCHAR
        RET

;--------------------------------------------------------
; BAN_PRSTR - Print null-terminated string via PUTCHAR
;--------------------------------------------------------
BAN_PRSTR:
        MOV     A,M
        ORA     A
        RZ
        CALL    PUTCHAR
        INX     H
        JMP     BAN_PRSTR

;--------------------------------------------------------
; BAN_PRHEX - Print byte in A as two hex digits
;--------------------------------------------------------
BAN_PRHEX:
        PUSH    PSW
        RRC
        RRC
        RRC
        RRC
        CALL    BAN_PRNIB
        POP     PSW
BAN_PRNIB:
        ANI     0FH
        ADI     '0'
        CPI     '9'+1
        JC      BAN_PRN1
        ADI     'A'-'9'-1
BAN_PRN1:
        JMP     PUTCHAR

;--------------------------------------------------------
; Banner message strings
;--------------------------------------------------------
MSG_BAN_VER:
        DB      0DH,0AH
        DB      'JX/8080 Version '
        DB      '0'+VER_MAJOR,'.','0'+VER_MINOR
        DB      0DH,0AH,0

MSG_BAN_SIO:
        DB      'SIO ',0

MSG_BAN_RX:
        DB      ' RX=',0

MSG_BAN_TX:
        DB      ' TX=',0

        IF SIO_8251
MSG_BAN_8251:
        DB      ' 8251',0
        ENDIF

        IF SIO_6850
MSG_BAN_6850:
        DB      ' 6850',0
        ENDIF

;========================================================
; End of banner.asm
;========================================================

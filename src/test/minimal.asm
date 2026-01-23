;========================================================
; Minimal Test - Just output 'A' and halt
;========================================================
        ORG     0100H

        MVI     A,'A'           ; Load 'A' into A
        OUT     1               ; Output to port 1 (console)
        MVI     A,0DH           ; Carriage return
        OUT     1
        MVI     A,0AH           ; Line feed
        OUT     1
        HLT                     ; Stop

        END

;========================================================
; JX Operating System - Boot Test
;========================================================
; A minimal boot loader that jumps to the BIOS cold boot
; entry point. Used for testing the BIOS in the simulator.
;
; This loads at 0000H and immediately jumps to BIOS_BASE.
; The BIOS must be loaded separately at its target address.
;
; Usage:
;   1. Build: make test-boot
;   2. Run:   ./scripts/run-boot.sh
;========================================================

        ORG     0000H

;--------------------------------------------------------
; Boot Vector - Jump to BIOS cold boot
;--------------------------------------------------------
        JMP     BIOS_BASE       ; Jump to BIOS cold boot entry

;========================================================
        END

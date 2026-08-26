; =============================================================================
; MITS Altair/IMSAI 88-DCDD Floppy Disk Boot Loader
; Disassembled from Intel HEX format
; Target: Intel 8080 CPU
;
; I/O Port Map:
;   08h = Disk controller status register
;   09h = Disk controller control register
;   0Ah = Disk controller data register
;   10h = SIO (Serial I/O) control/baud rate
;   22h = Sense switches / front panel output
;   23h = Front panel output (active low LEDs)
;   FFh = Sense switch input
;   01h, 05h, 11h = Additional output ports
;
; Memory Map:
;   0000h-0012h = Initial bootstrap (copies code to 6000h)
;   0013h-00FFh = Main boot loader code (runs at 6000h+)
;   0100h-010Eh = Subroutines
;   010Fh-0124h = Padding/unused
;   0125h-013Eh = Disk address table (track/sector map)
;   013Fh-01FFh = CP/M keyword token table (encoded strings)
; =============================================================================

; ---- INITIAL BOOTSTRAP (runs at 0000h) ----
; Copies the main loader code from ROM/PROM at 0013h to RAM at 6000h,
; then jumps to it. This is the classic Altair boot PROM pattern.

0000  21 13 00     LXI  H,0013h       ; HL = source address (0013h)
0003  11 00 60     LXI  D,6000h       ; DE = destination address (6000h)
0006  0E FC        MVI  C,FCh         ; C = byte count (252 bytes)
0008  7E           MOV  A,M           ; A = [HL] (read source byte)
0009  12           STAX D             ; [DE] = A (write to dest)
000A  23           INX  H             ; HL++ (next source)
000B  13           INX  D             ; DE++ (next dest)
000C  0D           DCR  C             ; C-- (count down)
000D  C2 08 00     JNZ  0008h         ; Loop until C=0
0010  C3 00 60     JMP  6000h         ; Jump to relocated code at 6000h

; =============================================================================
; MAIN BOOT LOADER CODE (assembled for execution at 6000h)
; The following code runs at 6000h after relocation.
; Addresses shown are ROM addresses; add 5FEDh to get runtime addresses.
; Runtime addr = ROM addr + 5FEDh  (0013h -> 6000h)
; =============================================================================

; ---- HARDWARE INITIALIZATION ----

0013  F3           DI                 ; Disable interrupts
0014  AF           XRA  A             ; A = 0
0015  D3 22        OUT  22h           ; Clear sense switch output (all bits low)
0017  2F           CMA                ; A = FFh
0018  D3 23        OUT  23h           ; Turn off all front panel LEDs (active low)

; ---- SERIAL PORT INITIALIZATION ----
; Configure SIO board for console I/O

001A  3E 2C        MVI  A,2Ch         ; Sense switch value for baud rate config
001C  D3 22        OUT  22h           ; Write to sense switch output port
001E  3E 03        MVI  A,03h         ; SIO reset/config command
0020  D3 10        OUT  10h           ; Send to SIO control port

; ---- AUTO-DETECT ACTIVE SIO PORT ----
; Read sense switches to determine which SIO port to use

0022  DB FF        IN   FFh           ; Read sense switches
0024  E6 10        ANI  10h           ; Isolate bit 4
0026  0F           RRC                ; Shift right
0027  0F           RRC                ; Shift right (bit 4 -> bit 2)
0028  C6 10        ADI  10h           ; Add base port 10h
002A  D3 10        OUT  10h           ; Output to computed SIO port

; ---- SET STACK POINTER ----

002C  31 8A 61     LXI  SP,618Ah      ; SP = 618Ah (stack grows down)

; ---- DISK CONTROLLER INITIALIZATION ----
; Reset disk controller and check for head loaded

002F  AF           XRA  A             ; A = 0
0030  D3 08        OUT  08h           ; Write 0 to disk status (reset controller)
0032  DB 08        IN   08h           ; Read disk status
0034  E6 08        ANI  08h           ; Test bit 3 (head load status)
0036  C2 1C 60     JNZ  601Ch         ; If head loaded, jump ahead (runtime addr)
                                      ; (ROM 002Fh = runtime 601Ch)

; Head not loaded - enable head load
0039  3E 04        MVI  A,04h         ; Command: head load
003B  D3 09        OUT  09h           ; Send to disk control register

; ---- SEEK TO TRACK 0 ----
; (Runtime 6038h from JMP target)

003D  C3 38 60     JMP  6038h         ; Jump to track 0 seek code (self-patched addr)

; ---- WAIT FOR MOVE COMPLETE ----
; Check if disk drive is ready and positioned

0040  DB 08        IN   08h           ; Read disk status
0042  E6 02        ANI  02h           ; Test bit 1 (move/seek complete)
0044  C2 2D 60     JNZ  602Dh         ; If move not done, loop

0047  3E 02        MVI  A,02h         ; Command: step in
0049  D3 09        OUT  09h           ; Send step command

; ---- CHECK TRACK 0 ----

004B  DB 08        IN   08h           ; Read disk status
004D  E6 40        ANI  40h           ; Test bit 6 (track 0 indicator)
004F  C2 2D 60     JNZ  602Dh         ; If not at track 0, keep stepping

; ---- PREPARE TO READ SECTOR ----
; We're at track 0, now read sectors

0052  11 00 00     LXI  D,0000h       ; DE = 0000h (load address)
0055  06 08        MVI  B,08h         ; B = 8 (sector count: read 8 sectors)
0057  C2 06 00     JNZ  0006h         ; Conditional jump (may be patched)

; ---- SECTOR READ LOOP ----

005A  3E 10        MVI  A,10h         ; A = 10h (retry count = 16)
005C  F5           PUSH PSW           ; Save retry count
005D  D5           PUSH D             ; Save load address
005E  C5           PUSH B             ; Save sector count
005F  D5           PUSH D             ; Save load address again

; Set up DMA address and expected sector header

0060  11 86 80     LXI  D,8086h       ; DE = 8086h (disk command/DMA page?)
0063  21 FC 60     LXI  H,60FCh       ; HL = 60FCh (sector buffer in RAM)

; ---- WAIT FOR SECTOR HEADER ----

0066  DB 09        IN   09h           ; Read sector position register
0068  1F           RAR                ; Rotate right through carry
0069  DA 53 60     JC   6053h         ; If carry set, sector not ready - loop

006C  E6 1F        ANI  1Fh           ; Mask to sector number (0-31)
006E  B8           CMP  B             ; Compare with desired sector
006F  C2 53 60     JNZ  6053h         ; If wrong sector, keep waiting

; ---- READ SECTOR DATA ----
; Correct sector found, read data bytes

0072  DB 08        IN   08h           ; Read disk status
0074  B7           ORA  A             ; Test sign bit (NRDA - new read data available)
0075  FA 5F 60     JM   605Fh         ; If bit 7 set, data not ready yet - wait

0078  DB 0A        IN   0Ah           ; Read data byte from disk
007A  77           MOV  M,A           ; Store byte at [HL]
007B  23           INX  H             ; HL++ (advance buffer pointer)
007C  1D           DCR  E             ; E-- (byte count for sector, 128+9 = 137)
007D  CA 75 60     JZ   6075h         ; If 0, we've read enough overhead bytes

0080  1D           DCR  E             ; Decrement again (handle 16-bit counter)
0081  DB 0A        IN   0Ah           ; Read next data byte
0083  77           MOV  M,A           ; Store it
0084  23           INX  H             ; Advance pointer
0085  C2 5F 60     JNZ  605Fh         ; If more bytes, continue reading

; ---- VERIFY SECTOR DATA ----

0088  E1           POP  H             ; Restore original load address
0089  11 FF 60     LXI  D,60FFh       ; DE = 60FFh (sector buffer start)
008C  01 80 00     LXI  B,0080h       ; BC = 0080h (128 bytes to verify/copy)

008F  1A           LDAX D             ; A = [DE] (byte from sector buffer)
0090  77           MOV  M,A           ; [HL] = A (copy to destination)
0091  BE           CMP  M             ; Verify write (compare what we wrote)
0092  C2 DC 60     JNZ  60DCh         ; If mismatch, go to error handler

0095  80           ADD  B             ; Accumulate checksum
0096  47           MOV  B,A           ; B = running checksum
0097  13           INX  D             ; DE++ (next buffer byte)
0098  23           INX  H             ; HL++ (next dest byte)
0099  0D           DCR  C             ; C-- (byte count)
009A  C2 7C 60     JNZ  607Ch         ; Loop for all 128 bytes

; ---- VERIFY SECTOR CHECKSUM ----

009D  1A           LDAX D             ; A = [DE] (stored checksum from disk)
009E  FE FF        CPI  FFh           ; Is it FFh? (end marker or special flag)
00A0  C2 93 60     JNZ  6093h         ; If not, continue checking
00A3  13           INX  D             ; Skip to next byte
00A4  1A           LDAX D             ; Read checksum byte
00A5  B8           CMP  B             ; Compare with computed checksum
00A6  C1           POP  B             ; Restore BC (sector count / desired sector)
00A7  EB           XCHG               ; Swap HL <-> DE
00A8  C2 D0 60     JNZ  60D0h         ; If checksum mismatch, handle error

; ---- SECTOR READ OK - ADVANCE TO NEXT ----

00AB  F1           POP  PSW           ; Pop (discard saved retry count)
00AC  F1           POP  PSW           ; Pop (discard saved PSW)

00AD  2A FD 60     LHLD 60FDh         ; Load HL from 60FDh (next DMA address)
00B0  D5           PUSH D             ; Save DE
00B1  11 00 60     LXI  D,6000h       ; DE = 6000h (base address)
00B4  CD F6 60     CALL 60F6h         ; Call compare subroutine (HL vs DE?)
00B7  D1           POP  D             ; Restore DE
00B8  DA D9 60     JC   60D9h         ; If carry, handle error/done condition

00BB  CD F6 60     CALL 60F6h         ; Second compare
00BE  D2 C9 60     JNC  60C9h         ; If no carry, skip ahead

; ---- ADVANCE SECTOR NUMBER ----

00C1  04           INR  B             ; B++ (next sector)
00C2  04           INR  B             ; B++ (skip by 2 - interleave)
00C3  78           MOV  A,B           ; A = B
00C4  FE 20        CPI  20h           ; Compare with 32 (sectors per track)
00C6  DA 47 60     JC   6047h         ; If < 32, read next sector on this track
00C9  06 01        MVI  B,01h         ; B = 1 (wrap to sector 1, next track)
00CB  CA 47 60     JZ   6047h         ; If exactly 32, continue reading

; ---- STEP TO NEXT TRACK ----

00CE  DB 08        IN   08h           ; Read disk status
00D0  E6 02        ANI  02h           ; Test bit 1 (move complete)
00D2  C2 BB 60     JNZ  60BBh         ; Wait for step complete

00D5  3E 01        MVI  A,01h         ; Command: step in
00D7  D3 09        OUT  09h           ; Send step command
00D9  C3 45 60     JMP  6045h         ; Continue with read loop

; ---- ERROR HANDLER ----
; Memory verify failed or disk error

00DC  3E 80        MVI  A,80h         ; A = 80h
00DE  D3 08        OUT  08h           ; Write to disk status (reset/abort?)
00E0  C3 00 00     JMP  0000h         ; Cold restart - try again from scratch

; ---- CLEANUP / RETRY PATH ----

00E3  D1           POP  D             ; Restore DE
00E4  F1           POP  PSW           ; Restore retry counter
00E5  3D           DCR  A             ; A-- (decrement retry count)
00E6  C2 49 60     JNZ  6049h         ; If retries remain, try again

; ---- BOOT COMPLETION ----
; Load complete - prepare to transfer control to loaded program

00E9  3E 43        MVI  A,43h         ; 'C' character (CP/M signature?)
00EB  01 3E 4F     LXI  B,4F3Eh      ; BC = 4F3Eh  (embedded: MVI A,'O')
00EE  01 3E 4D     LXI  B,4D3Eh      ; BC = 4D3Eh  (embedded: MVI A,'M')

00F1  FB           EI                 ; Re-enable interrupts
00F2  32 00 00     STA  0000h         ; Store A at 0000h (warm boot vector?)
00F5  22 01 00     SHLD 0001h         ; Store HL at 0001h
00F8  47           MOV  B,A           ; B = A
00F9  3E 80        MVI  A,80h         ; A = 80h
00FB  D3 08        OUT  08h           ; Deselect disk / reset controller
00FD  78           MOV  A,B           ; Restore A
00FE  D3 01        OUT  01h           ; Output to port 01h
0100  D3 11        OUT  11h           ; Output to port 11h
0102  D3 05        OUT  05h           ; Output to port 05h
0104  D3 23        OUT  23h           ; Update front panel LEDs
0106  C3 EB 60     JMP  60EBh         ; Jump to loaded code (CP/M BIOS entry?)

; ---- UTILITY: 16-BIT COMPARE (DE vs HL) ----
; Returns Z flag if DE == HL

0109  7A           MOV  A,D           ; A = D
010A  BC           CMP  H             ; Compare D with H
010B  C0           RNZ                ; Return if high bytes differ
010C  7B           MOV  A,E           ; A = E
010D  BD           CMP  L             ; Compare E with L
010E  C9           RET                ; Return (Z set if equal)

; ---- ADDITIONAL SUBROUTINE ----

010F  C5           PUSH B             ; Save BC
0110  32 00 00     STA  0000h         ; Store A at 0000h

; ---- PADDING / UNUSED AREA ----

0113  00           NOP                ; (13 bytes of padding)
  ... (NOPs through 0124h)

; =============================================================================
; DISK ADDRESS TABLE (Track/Sector Translation Table)
; Entries appear to be 16-bit addresses or sector interleave map
; Used to determine where each logical sector maps on disk
; =============================================================================

0125  27 44 23 40 26 40 29 40  ; Table entries
012D  E9 40 EF 3F F4 40 04 41
0135  0A 40 0D 40 10 40 00 00
013D  00 00

; =============================================================================
; CP/M KEYWORD / COMMAND TOKEN TABLE
; High bit set on last character of each word (standard CP/M encoding)
; These are ASCII strings with bit 7 set on the final character
; =============================================================================
; This section contains encoded command/keyword strings used by the
; CP/M CCP (Console Command Processor) or a similar command interpreter.
; Format: ASCII text with bit 7 of last char set to mark end of token.
;
; Decoded tokens visible in this table include:
;   CONSOLE, LOSE (or CLOSE), COND (CONDITION), LEAR (CLEAR),
;   LOAD, SAVE, INT, SNG, DBL, VI (various prefixes),
;   OD (ODD), HRA (HRA?), ATC (ATTACH), IMD (IMMEDIATE),
;   EFSTR (EFSTR), EFIND (EFIND), EFSNG (EFSNG), EFDBL (EFDBL),
;   SKOA (SKOA?), ELE (DELETE?), ELECT (SELECT), SKI (SKIP),
;   SKG, SKIN, etc.
; =============================================================================

013F  73 01 84 01 85 01 C1 01  ; Token address table
0147  FE 01 23 02 39 02 4B 02
014F  50 02 66 02 67 02 6C 02
0157  A0 02 BE 02 D1 02 E1 02
015F  F5 02 F6 02 26 03 55 03
0167  6C 03 7B 03 85 03 8F 03
016F  93 03 94 03 4E C4 F7 42
0177  D3 06 54 CE 0E 53 C3 15
017F  55 54 CF AB 00 00

; Encoded ASCII string data:
0185  4F 4E 53 4F 4C C5       ; "CONSOL" + E|80h = "CONSOLE"
018B  A0                       ; Space|80h
018C  4C 4F 53 C5             ; "LOS" + E|80h = "LOSE"
0190  C3                       ; "C"|80h
0191  4F 4E D4                ; "ON" + T|80h = "ONT"
0194  9A                       ; (token separator)
0195  4C 45 41 D2             ; "LEA" + R|80h = "LEAR"
0199  92                       ; (token separator)
019A  4C 4F 41 C4             ; "LOA" + D|80h = "LOAD"
019E  9C                       ; (token separator)
019F  53 41 56 C5             ; "SAV" + E|80h = "SAVE"
01A3  9B                       ; (token separator)
01A4  49 4E D4                ; "IN" + T|80h = "INT"
01A7  1C                       ; (offset/token)
01A8  53 4E C7                ; "SN" + G|80h = "SNG"
01AB  1D                       ;
01AC  44 42 CC                ; "DB" + L|80h = "DBL"
01AF  1E                       ;
01B0  56 C9                   ; "V" + I|80h = "VI"
01B2  2B                       ;
01B3  56 D3                   ; "V" + S|80h = "VS"
01B5  2C                       ;
01B6  56 C4                   ; "V" + D|80h = "VD"
01B8  2D                       ;
01B9  4F D3                   ; "O" + S|80h = "OS"
01BB  0C                       ;
01BC  48 52 A4                ; "HR" + $|80h = "HR$"
01BF  16 00                   ;
01C1  41 54 C1                ; "AT" + A|80h = "ATA"
01C4  84                       ;
01C5  49 CD                   ; "I" + M|80h = "IM"
01C7  86                       ;
01C8  45 46 53 54 D2          ; "EFST" + R|80h = "EFSTR"
01CD  AD                       ;
01CE  45 46 49 4E D4          ; "EFIN" + T|80h = "EFINT" (or EFIND)
01D3  AE                       ;
01D4  45 46 53 4E C7          ; "EFSN" + G|80h = "EFSNG"
01D9  AF                       ;
01DA  45 46 44 42 CC          ; "EFDB" + L|80h = "EFDBL"
01DF  B0                       ;
01E0  53 4B 4F A4             ; "SKO" + $|80h = "SKO$"
01E4  BC                       ;
01E5  45 C6                   ; "E" + F|80h = "EF"
01E7  98                       ;
01E8  45 4C 45 54 C5          ; "ELET" + E|80h (DELETE?)
01ED  AA                       ;
01EE  53 4B 49 A4             ; "SKI" + $|80h = "SKI$"
01F2  2A                       ;
01F3  53 4B C6                ; "SK" + F|80h = "SKF"
01F6  2E                       ;
01F7  53 4B 49 4E C9          ; "SKIN" + I|80h = "SKINI" (or SKIN)
01FC  CC                       ;
01FD  00                       ; Null terminator
01FE  4E C4                   ; "N" + D|80h = "ND"
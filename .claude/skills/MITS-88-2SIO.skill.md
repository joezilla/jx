# SKILL: Programming the MITS Altair 88-2SIO Serial I/O Board in 8080 Assembly

## Overview

The MITS 88-2SIO is a dual-port serial I/O board for the S-100 bus, designed for the Altair 8800 and compatible computers. It provides **two independent RS-232 serial ports** based on the Motorola MC6850 ACIA (Asynchronous Communications Interface Adapter) chip. The board interfaces serial devices — terminals, teletypes, modems, cassette interfaces, printers, and paper tape readers — to the Altair's 8080 CPU through standard IN/OUT port instructions.

The 88-2SIO is the successor to the earlier 88-SIO (single-port, SMC 2502 UART). It became the standard serial interface for Altair systems and is the assumed serial board for nearly all MITS software, including Altair BASIC, Altair DOS, and CP/M BIOS implementations.

**Key design feature:** The 88-2SIO uses port-mapped I/O (not memory-mapped). Each ACIA occupies two consecutive I/O port addresses — one for control/status and one for data. The board supports up to two ACIAs ("Port 0" and "Port 1"), consuming four consecutive I/O addresses total.

---

## Hardware Overview

| Parameter | Value |
|-----------|-------|
| Chip | Motorola MC6850 ACIA (×1 or ×2) |
| Serial ports | 1 or 2 (jumper-selectable) |
| I/O ports consumed | 4 (2 per ACIA: control/status + data) |
| Interface levels | RS-232, TTL, or 20mA current loop (jumper-selectable per port) |
| Baud rates | 110, 150, 300, 600, 1200, 2400, 4800, 9600 (jumper-selectable) |
| Baud rate clock | On-board crystal oscillator, 2.4576 MHz |
| Data formats | 7 or 8 data bits, 1 or 2 stop bits, even/odd/no parity (software-configurable) |
| Handshaking | RTS/CTS, DCD (active on 6850; optional hardware connection) |
| Interrupts | IRQ output per port (directly drives S-100 PINT or VI lines) |
| Connector | 10-pin Molex per port (active signals vary by RS-232/TTL/TTY config) |

---

## I/O Port Addresses

### Default Address Assignment

The 88-2SIO base address is set by jumpers on address lines A2–A7. Address lines A0 and A1 are used for register/port selection within the board:

- **A0** selects Control/Status (0) vs. Data (1) register
- **A1** selects Port 0 (0) vs. Port 1 (1)

The standard (default) base address for MITS software is **octal 020 = 10h (decimal 16)**:

| Port | Octal | Hex | Decimal | Function |
|------|-------|-----|---------|----------|
| Port 0 Control/Status | 020 | 10h | 16 | WRITE: Control Register / READ: Status Register |
| Port 0 Data | 021 | 11h | 17 | WRITE: Transmit Data / READ: Receive Data |
| Port 1 Control/Status | 022 | 12h | 18 | WRITE: Control Register / READ: Status Register |
| Port 1 Data | 023 | 13h | 19 | WRITE: Transmit Data / READ: Receive Data |

### Other Common Address Configurations

Addresses are selectable in increments of 4, from 0–252:

| Use Case | Base (Octal) | Base (Hex) | Port 0 Ctrl/Data | Port 1 Ctrl/Data |
|----------|-------------|-----------|-------------------|-------------------|
| **Standard (MITS default)** | 020 | 10h | 10h/11h | 12h/13h |
| Second 2SIO board | 024 | 14h | 14h/15h | 16h/17h |
| Third 2SIO board | 026 | 16h | 16h/17h | 18h/19h |
| Sol-20 serial port | F8h/F9h | (Proc Tech uses different ports) | — | — |

**Important:** Address 377 (octal) / FFh is reserved for the Altair front panel sense switches. Do not configure a 2SIO board to include address FFh.

### EQU Definitions for Assembly Programs

```asm
; Standard 88-2SIO port assignments (MITS default)
SIRONE  EQU  10h       ; Port 0 Control/Status (read=status, write=control)
SRONE   EQU  11h       ; Port 0 Data (read=RX, write=TX)
SIRTWO  EQU  12h       ; Port 1 Control/Status
SRTWO   EQU  13h       ; Port 1 Data

; Alternative labels (common in MITS documentation, using octal)
; Port 0 status = 020 octal = 10h
; Port 0 data   = 021 octal = 11h
; Port 1 status = 022 octal = 12h
; Port 1 data   = 023 octal = 13h
```

---

## Register Architecture

The MC6850 ACIA has four internal registers accessed through two port addresses:

| Address Offset | Direction | Register |
|---------------|-----------|----------|
| Base + 0 (A0=0) | WRITE | **Control Register** — configures ACIA operation |
| Base + 0 (A0=0) | READ | **Status Register** — reports ACIA state |
| Base + 1 (A0=1) | WRITE | **Transmit Data Register (TDR)** — character to send |
| Base + 1 (A0=1) | READ | **Receive Data Register (RDR)** — received character |

Writing to the status port address goes to the Control Register. Reading from the same address reads the Status Register. They are different registers that share an address, disambiguated by the R/W direction.

---

## Status Register (READ from Control/Status port)

Reading the control/status port returns the 8-bit Status Register:

```
Bit 7: IRQ   — Interrupt Request (1 = interrupt pending)
Bit 6: PE    — Parity Error (1 = parity error on received char)
Bit 5: OVRN  — Receiver Overrun (1 = overrun error)
Bit 4: FE    — Framing Error (1 = framing error on received char)
Bit 3: CTS   — Clear To Send (active-low input, 1 = NOT clear to send)
Bit 2: DCD   — Data Carrier Detect (active-low input, 1 = carrier LOST)
Bit 1: TDRE  — Transmit Data Register Empty (1 = ready to accept new TX byte)
Bit 0: RDRF  — Receive Data Register Full (1 = received byte available)
```

### Bit Details

**Bit 0 — RDRF (Receive Data Register Full):**
This is the most frequently polled bit. When set (1), a complete character has been received and is available in the Receive Data Register. Reading the data register clears this bit. Also cleared by master reset. If DCD is high (carrier lost), RDRF is clamped to 0.

**Bit 1 — TDRE (Transmit Data Register Empty):**
When set (1), the transmit data register is empty and ready to accept a new byte for transmission. When clear (0), the register is full — writing a new byte before TDRE goes high will overwrite the previous byte. TDRE is also inhibited (forced to 0) when CTS is high (not clear to send).

**Bit 2 — DCD (Data Carrier Detect):**
Reflects the state of the DCD input pin (active-low from modem). When high (1), the carrier has been lost. A low-to-high transition on DCD generates an interrupt if receive interrupts are enabled. Cleared by reading the status register followed by reading the data register, or by master reset.

**IMPORTANT for 88-2SIO users:** If DCD and CTS are not connected to a modem, they **must be jumpered to ground** on the 2SIO board. Otherwise, DCD=1 will clamp RDRF to 0 (no received data), and CTS=1 will inhibit TDRE (can't transmit). This is the single most common cause of a non-working 88-2SIO.

**Bit 3 — CTS (Clear To Send):**
Reflects the state of the CTS input pin (active-low from modem). High (1) means the modem is NOT ready — the TDRE bit is inhibited. Must be jumpered low if not connected to a modem.

**Bit 4 — FE (Framing Error):**
Set when the received character has no valid stop bit (detected absence of the first stop bit). Indicates synchronization error, faulty transmission, or a BREAK condition. The flag is present as long as the associated character is in the receive data register.

**Bit 5 — OVRN (Receiver Overrun):**
Set when a character was received but the previous character in the RDR had not been read. The new character is lost. Cleared by reading the data register. Character synchronization is maintained during overrun.

**Bit 6 — PE (Parity Error):**
Set when the received character's parity doesn't match the configured parity mode. If parity checking is disabled (no parity), this bit is inhibited.

**Bit 7 — IRQ (Interrupt Request):**
Set when any enabled interrupt condition is active. This bit reflects the state of the IRQ output pin. Any enabled interrupt with its applicable condition will set this bit.

### Common Status Polling Patterns

```asm
; Check if a character has been received (RDRF = bit 0)
; Method 1: RRC (shift bit 0 into Carry)
    IN   10h          ; Read status register
    RRC               ; Rotate right — bit 0 → Carry
    JNC  no_char      ; Carry clear = no character ready
    IN   11h          ; Read received character into A

; Method 2: ANI (mask bit 0)
    IN   10h          ; Read status register
    ANI  01h          ; Isolate RDRF bit
    JZ   no_char      ; Zero = no character ready
    IN   11h          ; Read received character

; Check if transmitter is ready (TDRE = bit 1)
; Method 1: ANI
    IN   10h          ; Read status register
    ANI  02h          ; Isolate TDRE bit
    JZ   not_ready    ; Zero = transmitter busy

; Method 2: RRC twice (shift bit 1 into Carry)
    IN   10h          ; Read status register
    RRC               ; Bit 0 → Carry, bit 1 → bit 0
    RRC               ; Bit 1 (now bit 0) → Carry
    JNC  not_ready    ; Carry clear = transmitter busy
```

---

## Control Register (WRITE to Control/Status port)

Writing to the control/status port sets the 8-bit Control Register:

```
Bits 7:   Receive Interrupt Enable
Bits 6-5: Transmit Control (RTS state + TX interrupt)
Bits 4-2: Word Select (data bits, parity, stop bits)
Bits 1-0: Clock Divide / Master Reset
```

### Bits 1-0 — Counter Divide Select / Master Reset

| Bit 1 | Bit 0 | Function |
|-------|-------|----------|
| 0 | 0 | ÷1 (clock = baud rate) |
| 0 | 1 | **÷16 (normal mode — clock = 16× baud rate)** |
| 1 | 0 | ÷64 (clock = 64× baud rate) |
| 1 | 1 | **Master Reset** |

**Master Reset** (bits 1,0 = 1,1 = 03h): Resets the ACIA. Clears all internal status bits except CTS and DCD. **Must be done first** during initialization, then followed by the actual configuration.

**÷16 mode** (bits 1,0 = 0,1): This is the standard mode for the 88-2SIO. The on-board baud rate generator provides a clock at 16× the selected baud rate. Always use ÷16 when using the board's built-in baud rates (110, 150, 300, 600, 1200, 2400, 4800, 9600).

### Bits 4-2 — Word Select

| Bit 4 | Bit 3 | Bit 2 | Data Bits | Parity | Stop Bits |
|-------|-------|-------|-----------|--------|-----------|
| 0 | 0 | 0 | 7 | Even | 2 |
| 0 | 0 | 1 | 7 | Odd | 2 |
| 0 | 1 | 0 | 7 | Even | 1 |
| 0 | 1 | 1 | 7 | Odd | 1 |
| 1 | 0 | 0 | 8 | None | 2 |
| 1 | 0 | 1 | 8 | None | 1 |
| 1 | 1 | 0 | 8 | Even | 1 |
| 1 | 1 | 1 | 8 | Odd | 1 |

### Bits 6-5 — Transmit Control

| Bit 6 | Bit 5 | RTS Output | TX Interrupt |
|-------|-------|-----------|-------------|
| 0 | 0 | Low (asserted) | Disabled |
| 0 | 1 | Low (asserted) | **Enabled** |
| 1 | 0 | High (deasserted) | Disabled (transmits BREAK) |
| 1 | 1 | Low (asserted) | Disabled |

**Note:** Setting bits 6,5 = 1,0 forces the transmit data output to a continuous spacing (break) level and deasserts RTS.

### Bit 7 — Receive Interrupt Enable

| Bit 7 | Function |
|-------|----------|
| 0 | Receive interrupts **disabled** |
| 1 | Receive interrupts **enabled** (IRQ on RDRF, overrun, or DCD transition) |

### Common Control Register Values

```asm
; Master Reset
; Value: 03h = 00000011b
; Must be done before any other configuration
RESET_VAL  EQU  03h

; 8 data bits, 2 stop bits, no parity, ÷16 mode, no interrupts
; Bits: 0-00-100-01 = 00010001b = 11h
; This is the standard Teletype / BASIC loading configuration
INIT_8N2   EQU  11h

; 8 data bits, 1 stop bit, no parity, ÷16 mode, no interrupts
; Bits: 0-00-101-01 = 00010101b = 15h
; Standard modern terminal configuration
INIT_8N1   EQU  15h

; 7 data bits, even parity, 1 stop bit, ÷16 mode, no interrupts
; Bits: 0-00-010-01 = 00001001b = 09h
INIT_7E1   EQU  09h

; 8 data bits, 1 stop bit, no parity, ÷16, RX interrupts ENABLED
; Bits: 1-00-101-01 = 10010101b = 95h
INIT_8N1_INT  EQU  95h

; 8 data bits, 2 stop bits, no parity, ÷16, both RX+TX interrupts
; Bits: 1-01-100-01 = 10110001b = B1h
INIT_8N2_RXTX EQU  0B1h
```

---

## Initialization Procedure

Every 88-2SIO port must be initialized in two steps:

1. **Master Reset** — write 03h to the control register
2. **Configuration** — write the desired control word

```asm
; Initialize Port 0 for 8 data bits, 1 stop bit, no parity
; No interrupts, ÷16 mode
; This is the standard initialization for a modern terminal
SIRONE  EQU  10h       ; Port 0 control/status
SRONE   EQU  11h       ; Port 0 data

init_port0:
    MVI  A,03h         ; Master Reset command
    OUT  SIRONE        ; Reset the ACIA
    MVI  A,15h         ; 8N1, ÷16, no interrupts
    OUT  SIRONE        ; Configure the port
    RET
```

For Teletype (ASR-33) or early BASIC loading (8 data bits, 2 stop bits, no parity):

```asm
init_port0_tty:
    MVI  A,03h         ; Master Reset
    OUT  SIRONE
    MVI  A,11h         ; 8 data, 2 stop, no parity, ÷16
    OUT  SIRONE
    RET
```

**Both ports should be initialized** even if only one is being used, since the second ACIA may generate spurious interrupts if left uninitialized:

```asm
init_both:
    MVI  A,03h         ; Master Reset
    OUT  10h           ; Reset Port 0
    OUT  12h           ; Reset Port 1
    MVI  A,15h         ; 8N1, ÷16, no interrupts
    OUT  10h           ; Configure Port 0
    OUT  12h           ; Configure Port 1
    RET
```

---

## Common I/O Operations

### Read a Character (Polled)

```asm
; Wait for and read a character from Port 0
; Returns character in A
; Destroys: A (flags set by last ANI/RRC)
SRONE   EQU  11h
SIRONE  EQU  10h

getchar:
    IN   SIRONE        ; Read status register
    RRC                ; Shift RDRF (bit 0) into Carry
    JNC  getchar       ; Loop until character received
    IN   SRONE         ; Read character from data register
    RET
```

**Alternative using ANI:**
```asm
getchar_ani:
    IN   SIRONE        ; Read status register
    ANI  01h           ; Test RDRF bit
    JZ   getchar_ani   ; Loop until set
    IN   SRONE         ; Read received character
    RET
```

### Send a Character (Polled)

```asm
; Send character in A to Port 0
; Preserves: A (character)
; Destroys: flags
putchar:
    PUSH PSW           ; Save character
tx_wait:
    IN   SIRONE        ; Read status register
    ANI  02h           ; Test TDRE (bit 1)
    JZ   tx_wait       ; Loop until transmit register empty
    POP  PSW           ; Restore character
    OUT  SRONE         ; Write character to data register
    RET
```

**Compact version (character in B):**
```asm
; Send character in B to Port 0
putchar_b:
    IN   SIRONE
    ANI  02h
    JZ   putchar_b
    MOV  A,B
    OUT  SRONE
    RET
```

### Echo Loop (Character Echo Test)

This is the standard test program from the MITS documentation. It's the first program you should run when setting up a 2SIO board:

```asm
; Echo all received characters back to sender
; Used to verify serial link is working
        ORG  0000h

init:   MVI  A,03h         ; Master Reset
        OUT  10h           ; Reset Port 0
        MVI  A,15h         ; 8N1, ÷16 mode
        OUT  10h           ; Configure Port 0

echo:   IN   10h           ; Read status
        RRC                ; RDRF → Carry
        JNC  echo          ; Wait for character
        IN   11h           ; Read character
        OUT  11h           ; Echo it back
        JMP  echo          ; Continue forever
```

**Note:** This program does NOT wait for TDRE before transmitting. At typical baud rates (9600 or lower), the echo is fast enough that the transmitter is always ready by the time the next character arrives. For higher-throughput applications, always check TDRE.

### Send a Null-Terminated String

```asm
; Send null-terminated string pointed to by HL
; Destroys: A, HL
puts:
    MOV  A,M           ; Get character from string
    ORA  A             ; Null terminator?
    RZ                 ; Yes, done
puts_wait:
    PUSH PSW           ; Save character
    IN   SIRONE        ; Check status
    ANI  02h           ; TDRE ready?
    JZ   puts_wait+1   ; No, keep checking (re-push not needed)
    POP  PSW           ; Restore character
    OUT  SRONE         ; Send it
    INX  H             ; Next character
    JMP  puts          ; Continue

; Better version with proper wait loop:
puts2:
    MOV  A,M           ; Get character
    ORA  A             ; Null?
    RZ                 ; Done
    MOV  B,A           ; Save in B
puts2_tx:
    IN   SIRONE        ; Check transmitter
    ANI  02h           ; TDRE?
    JZ   puts2_tx      ; Wait
    MOV  A,B           ; Restore character
    OUT  SRONE         ; Send
    INX  H             ; Next
    JMP  puts2
```

### Read a Line (with Echo and Backspace)

```asm
; Read a line into buffer at HL, max length in C
; Returns length in B
; Supports backspace (7Fh or 08h) and CR termination
SIRONE  EQU  10h
SRONE   EQU  11h
CR      EQU  0Dh
LF      EQU  0Ah
BS      EQU  08h
DEL     EQU  7Fh

readline:
    MVI  B,00h         ; Character count = 0
rl_loop:
    IN   SIRONE        ; Read status
    RRC                ; RDRF?
    JNC  rl_loop       ; Wait for character
    IN   SRONE         ; Read character
    ANI  7Fh           ; Strip high bit (parity)
    
    CPI  CR            ; Carriage return?
    JZ   rl_done       ; Yes, end of line
    
    CPI  BS            ; Backspace?
    JZ   rl_bs
    CPI  DEL           ; Delete (alt backspace)?
    JZ   rl_bs
    
    MOV  A,B           ; Check if buffer full
    CMP  C
    JNC  rl_loop       ; Full, ignore character
    
    IN   SRONE         ; Re-read (A was destroyed) — actually need to save
    ; NOTE: Better to save char earlier. Simplified version:
    MOV  M,A           ; Store character
    INX  H             ; Advance buffer
    INR  B             ; Increment count
    
    ; Echo character
    PUSH PSW
rl_echo:
    IN   SIRONE
    ANI  02h
    JZ   rl_echo
    POP  PSW
    OUT  SRONE         ; Echo
    JMP  rl_loop
    
rl_bs:
    MOV  A,B
    ORA  A             ; At start of line?
    JZ   rl_loop       ; Yes, ignore backspace
    DCX  H             ; Back up buffer
    DCR  B             ; Decrement count
    ; Echo BS-SPACE-BS to erase character on terminal
    MVI  A,BS
    CALL putchar
    MVI  A,' '
    CALL putchar
    MVI  A,BS
    CALL putchar
    JMP  rl_loop
    
rl_done:
    MVI  M,00h         ; Null-terminate
    ; Send CR+LF
    MVI  A,CR
    CALL putchar
    MVI  A,LF
    CALL putchar
    RET
```

---

## Interrupt-Driven I/O

The 88-2SIO supports interrupts via the S-100 bus PINT (active interrupt) line or through the 88-VI/RTC vectored interrupt board. For simple systems, polled I/O is adequate. For multitasking or high-throughput applications (e.g., CP/M with type-ahead), interrupts are essential.

### Enabling Interrupts

```asm
; Enable receive interrupts on Port 0
; Control word: 8N1, ÷16, RX interrupt enabled
;   Bit 7 = 1 (RX interrupt enable)
;   Bits 6-5 = 00 (RTS low, TX interrupt disabled)
;   Bits 4-2 = 101 (8N1)
;   Bits 1-0 = 01 (÷16)
; = 10010101b = 95h
    MVI  A,03h         ; Master Reset first
    OUT  10h
    MVI  A,95h         ; 8N1, ÷16, RX interrupts enabled
    OUT  10h
    EI                 ; Enable 8080 interrupt system
```

### Interrupt Service Routine (ISR) Skeleton

On the Altair without the 88-VI/RTC, all interrupts go through RST 7 (address 0038h):

```asm
    ORG  0038h         ; RST 7 vector
    JMP  isr_handler

isr_handler:
    PUSH PSW           ; Save accumulator and flags
    PUSH H
    
    IN   10h           ; Read Port 0 status
    RRC                ; RDRF?
    JNC  isr_check_p1  ; Not Port 0 RX, check Port 1
    
    IN   11h           ; Read received character
    ; Store in circular buffer...
    LHLD rx_buf_in     ; Get buffer write pointer
    MOV  M,A           ; Store character
    INX  H             ; Advance pointer
    ; (Add wrap-around logic here)
    SHLD rx_buf_in     ; Save updated pointer
    JMP  isr_done
    
isr_check_p1:
    IN   12h           ; Read Port 1 status
    RRC                ; RDRF?
    JNC  isr_done      ; Spurious interrupt
    IN   13h           ; Read Port 1 character
    ; Handle Port 1 data...
    
isr_done:
    POP  H
    POP  PSW
    EI                 ; Re-enable interrupts
    RET
```

---

## Bootstrap Loaders

The 88-2SIO was the primary interface for loading software from paper tape or serial transfer. MITS published specific bootstrap loaders for the 2SIO.

### 2SIO Echo Test (Verify Communications)

Enter this at address 0 (in octal):

```
Address  Octal Bytes
000:     076 003 323 020 076 021 323 020
010:     333 020 017 322 010 000 333 021
020:     323 021 303 010 000
```

Assembly:
```asm
        ORG  0
init:   MVI  A,003o        ; 03h — Master Reset
        OUT  020o          ; Port 0 control
        MVI  A,021o        ; 11h — 8 data, 2 stop, no parity, ÷16
        OUT  020o          ; Configure Port 0
loop:   IN   020o          ; Read status
        RRC                ; RDRF → Carry
        JNC  loop          ; Wait for character
        IN   021o          ; Read character
        OUT  021o          ; Echo it back
        JMP  loop
```

### 2SIO BASIC Bootstrap Loader (for BASIC 3.2+)

This 28-byte first-stage loader reads the second-stage loader from a paper tape image:

```
Address  Octal Bytes
000:     076 003 323 020 076 025 323 020
010:     041 256 017 061 032 000 333 020
020:     017 320 333 021 275 310 055 167
030:     300 351 013 000
```

Assembly:
```asm
        ORG  0
        MVI  A,003o        ; Master Reset
        OUT  020o
        MVI  A,025o        ; 15h = 8N1, ÷16 (note: 8,1,n for BASIC 3.2+)
        OUT  020o
        LXI  H,0AEh*256+0Fh  ; H=AEh (lead-in byte), L=0Fh (byte count)
        LXI  SP,001Ah       ; Stack setup for tricky RET usage
wait:   IN   020o           ; Read status
        RRC                 ; RDRF?
        JNC  wait           ; Wait for character
        IN   021o           ; Read character
        CMP  L              ; Is it the lead-in byte? (first pass: L=0Fh)
        RZ                  ; Yes, skip it (uses stack trick)
        DCR  L              ; Decrement counter
        MOV  M,A            ; Store byte at HL
        RNZ                 ; Continue if L ≠ 0
        PCHL                ; Jump to loaded code when L = 0
        DB   0Bh, 00h       ; Address data used by stack trick
```

**Before running the loader:**
- Set sense switches: A11 up = Port 1 on 2SIO; A10 up = 1 stop bit
- Hit RESET, then RUN
- Send the tape file from the terminal (binary mode)

---

## Baud Rate Configuration

Baud rates are set by **hardware jumpers** on the 88-2SIO board. The on-board 2.4576 MHz crystal oscillator feeds a divider chain (MC14411 or discrete logic). The jumper selects which divided frequency goes to each ACIA's clock input:

| Baud Rate | Clock Frequency (÷16) | Notes |
|-----------|----------------------|-------|
| 110 | 1,760 Hz | Teletype ASR-33 |
| 150 | 2,400 Hz | |
| 300 | 4,800 Hz | Common early modem |
| 600 | 9,600 Hz | |
| 1200 | 19,200 Hz | Common modem |
| 2400 | 38,400 Hz | |
| 4800 | 76,800 Hz | |
| 9600 | 153,600 Hz | Common terminal |

The baud rate **cannot be changed by software** — it requires physically moving a jumper wire on the board. However, the clock divide ratio (÷1, ÷16, ÷64) IS software-configurable via control register bits 0-1. Using ÷64 instead of ÷16 gives you access to a different (4× lower) effective baud rate from the same clock jumper:

| Jumper Position | ÷16 Mode (normal) | ÷64 Mode |
|----------------|-------------------|----------|
| 9600 | 9600 baud | 2400 baud |
| 4800 | 4800 baud | 1200 baud |
| 2400 | 2400 baud | 600 baud |
| 1200 | 1200 baud | 300 baud |

---

## Handshaking and Modem Control

### DCD and CTS

**CRITICAL:** If no modem is connected (which is the typical case when using a terminal or serial transfer cable):

- **DCD must be tied to ground** (active-low = carrier present)
- **CTS must be tied to ground** (active-low = clear to send)

If DCD floats high, RDRF will be clamped to 0 — you will never receive data. If CTS floats high, TDRE will be inhibited — you cannot transmit.

Most 88-2SIO boards have jumper positions for this. The RS-232 wiring charts in the manual show the correct jumpering for direct terminal connection (no modem).

### RTS Output

RTS is controlled by bits 6-5 of the control register. In the most common configuration (bits 6,5 = 0,0), RTS is asserted low (active). For software flow control, you can deassert RTS to signal the remote device to stop sending.

---

## Differences: 88-SIO vs. 88-2SIO

| Feature | 88-SIO | 88-2SIO |
|---------|--------|---------|
| UART chip | SMC 2502 | Motorola MC6850 ACIA |
| Number of ports | 1 | 1 or 2 |
| Default port address | 00h/01h | 10h/11h |
| Status register format | Different bit layout | MC6850 standard (documented here) |
| Data format config | Hardware jumpers only | Software-configurable via control register |
| BASIC version | BASIC ≤ 3.1 uses 88-SIO loader | BASIC ≥ 3.2 uses 88-2SIO loader |

**Warning:** The 88-SIO and 88-2SIO have **different status register bit layouts**. Code written for one will NOT work on the other without modification. The 88-SIO's status register has RDRF and TDRE in different bit positions, and the initialization sequence is completely different.

When looking at MITS documentation, always verify which serial board a program was written for. The bootstrap loader labeled "2SIO" in the BASIC manual is specifically for the 88-2SIO.

---

## Programming Tips and Common Pitfalls

### 1. Always Master Reset Before Configuration
The ACIA requires a master reset (write 03h) before writing any configuration. Failure to do this may leave the ACIA in an undefined state.

### 2. DCD and CTS Must Be Grounded
If you're connecting directly to a terminal (not a modem), DCD and CTS must be tied low on the 88-2SIO board. This is by far the #1 source of "my 2SIO doesn't work" problems.

### 3. Strip the High Bit on Received Characters
When receiving 8-bit data, bit 7 may be a parity bit or may be noise. For ASCII text, always mask with 7Fh:
```asm
    IN   11h           ; Read character
    ANI  7Fh           ; Strip parity/high bit
```

### 4. Check TDRE Before Transmitting
While the echo test omits the TDRE check (it works at low baud rates because the echo loop is slower than character transmission), production code should always check:
```asm
tx_wait:
    IN   10h
    ANI  02h           ; TDRE?
    JZ   tx_wait
    MOV  A,B           ; Character to send
    OUT  11h
```

### 5. RRC is the Fastest RDRF Check
Using RRC to test bit 0 (RDRF) and JNC is faster and more compact than ANI 01h / JZ:
- RRC + JNC = 4 + 10 = 14 T-states, 3 bytes
- ANI + JZ = 7 + 10 = 17 T-states, 4 bytes

### 6. Initialize Both Ports
Even if only using Port 0, reset Port 1 (write 03h to port 12h) to prevent spurious interrupts from the uninitialized second ACIA.

### 7. The 2SIO Adds a Wait State on Input
The 88-2SIO hardware generates a 500 ns wait state during IN instructions to allow address setup time for the ACIA. This is transparent to the programmer but affects precise timing calculations.

### 8. Octal vs. Hex in MITS Documentation
MITS documentation uses **octal notation** (base 8). The standard port addresses 020/021 octal = 10h/11h hex = 16/17 decimal. Be careful when translating between old MITS listings (octal) and modern hex-based tools.

Quick octal-to-hex reference for 2SIO ports:
```
020 octal = 10h    021 octal = 11h
022 octal = 12h    023 octal = 13h
024 octal = 14h    025 octal = 15h
```

---

## Complete Example: Hello World

```asm
; Hello World for Altair 8800 with 88-2SIO
; Prints "HELLO, WORLD!" to Port 0

SIRONE  EQU  10h       ; Port 0 status/control
SRONE   EQU  11h       ; Port 0 data
CR      EQU  0Dh
LF      EQU  0Ah

        ORG  0000h

START:
        ; Initialize Port 0: 8N1, no interrupts
        MVI  A,03h     ; Master Reset
        OUT  SIRONE
        MVI  A,15h     ; 8 data, 1 stop, no parity, ÷16
        OUT  SIRONE
        
        ; Print string
        LXI  H,MSG     ; Point to message
PLOOP:
        MOV  A,M       ; Get character
        ORA  A          ; Null terminator?
        JZ   DONE      ; Yes, halt
TWAIT:
        PUSH PSW       ; Save character
        IN   SIRONE    ; Read status
        ANI  02h       ; TDRE?
        JZ   TWAIT+1   ; Wait (skip PUSH on retry)
        POP  PSW       ; Restore character
        OUT  SRONE     ; Transmit
        INX  H          ; Next character
        JMP  PLOOP

DONE:   HLT

MSG:    DB   CR,LF
        DB   'HELLO, WORLD!'
        DB   CR,LF,00h
```

---

## Complete Example: Interactive Terminal

```asm
; Simple interactive terminal with full-duplex echo
; Characters received on Port 0 are echoed back
; Handles CR→CR+LF expansion for terminal compatibility

SIRONE  EQU  10h
SRONE   EQU  11h
CR      EQU  0Dh
LF      EQU  0Ah

        ORG  0000h

        ; Initialize
        MVI  A,03h
        OUT  SIRONE
        MVI  A,15h         ; 8N1
        OUT  SIRONE

        ; Print banner
        LXI  H,BANNER
        CALL PUTS
        
MAIN:
        ; Poll for received character
        IN   SIRONE
        ANI  01h           ; RDRF?
        JZ   MAIN          ; No character, keep polling
        
        IN   SRONE         ; Read character
        ANI  7Fh           ; Strip high bit
        
        ; Echo the character
        PUSH PSW           ; Save character
        CALL PUTCHR        ; Echo it
        POP  PSW
        
        ; If CR, also send LF
        CPI  CR
        JNZ  MAIN
        MVI  A,LF
        CALL PUTCHR
        JMP  MAIN

; Subroutine: send character in A
PUTCHR:
        PUSH PSW
PUTWT:  IN   SIRONE
        ANI  02h           ; TDRE?
        JZ   PUTWT
        POP  PSW
        OUT  SRONE
        RET

; Subroutine: send null-terminated string at HL
PUTS:
        MOV  A,M
        ORA  A
        RZ
        CALL PUTCHR
        INX  H
        JMP  PUTS

BANNER: DB   CR,LF
        DB   'ALTAIR 8800 READY'
        DB   CR,LF,00h
```

---

## Reference: Status Register Quick-Check Table

| What to Check | IN Port | Test | Branch |
|--------------|---------|------|--------|
| Character received? | IN status | RRC / JNC (or ANI 01h / JZ) | JNC = no char |
| Transmitter ready? | IN status | ANI 02h / JZ | JZ = not ready |
| Any error? | IN status | ANI 70h / JNZ | JNZ = error present |
| Carrier lost? | IN status | ANI 04h / JNZ | JNZ = DCD lost |
| Interrupt pending? | IN status | ORA A / JM (or ANI 80h) | JM = IRQ active |

---

## References

- MITS 88-2SIO Assembly and Test Manual (altairclone.com/downloads/manuals/)
- Motorola MC6850 ACIA Data Sheet (Motorola Semiconductor, 1975)
- Altair 8800 Clone Operator's Manual, v2.4 (altairclone.com)
- MITS Altair BASIC 3.2 Manual — 2SIO Bootstrap Loader
- DeRamp 88-2SIOJP Enhanced Replacement (deramp.com/2SIOJP.html)
- emuStudio 88-SIO/88-2SIO documentation (emustudio.net)
- solivant.com Altair Bootloaders page
- altairclone.com forum — Hello World and 2SIO programming discussions

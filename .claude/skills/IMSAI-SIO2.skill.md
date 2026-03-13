# SKILL: Programming the IMSAI SIO-2 Serial I/O Board in 8080 Assembly

## Overview

The IMSAI SIO-2 is a dual-port serial I/O board for the S-100 bus, designed for the IMSAI 8080 computer. It provides **two independent serial channels** based on the Intel 8251 USART (Universal Synchronous-Asynchronous Receiver-Transmitter). The board supports asynchronous mode up to 9600 baud and synchronous mode up to 56,000 baud, with RS-232 level drivers/receivers for both channels.

**Key difference from the MITS 88-2SIO:** The IMSAI SIO-2 uses the Intel 8251 USART, while the 88-2SIO uses the Motorola MC6850 ACIA. They have **completely different register layouts, initialization sequences, and status bit assignments**. Code written for one will NOT work on the other.

**Critical design quirk of the 8251:** The control/status port address is shared between **three different register functions** disambiguated by context (mode word, command word, and status), not by address. The 8251 uses a state machine: after reset, the first write to the control port sets the **mode word**, and all subsequent writes set the **command word**. Reading always returns the **status word**. This makes initialization more complex than the MC6850.

---

## Hardware Overview

| Parameter | Value |
|-----------|-------|
| USART chip | Intel 8251A (×2) |
| Serial channels | 2 (Channel A and Channel B) |
| I/O ports consumed | 16 total (but only 2 per channel are commonly used) |
| I/O or memory-mapped | Jumper-selectable (I/O mapped is standard) |
| Interface levels | RS-232 (built-in level converters) |
| Baud rates | 110, 150, 300, 600, 1200, 2400, 4800, 9600 (jumper-selectable) |
| Data formats | 5, 6, 7, or 8 data bits; 1, 1.5, or 2 stop bits; even/odd/no parity |
| Modes | Asynchronous or Synchronous (per channel, jumper-selectable) |
| Handshaking | RTS, CTS, DTR, DSR (active on 8251; directly on RS-232 connector) |
| Interrupts | Supported via IMSAI PIC-8 board; jumper-selectable priority |

---

## I/O Port Addresses

### Default Address Assignment

The SIO-2 board uses 16 I/O port addresses. The standard IMSAI configuration places Channel A starting at address 02h and Channel B at 04h:

| Port | Hex | Function |
|------|-----|----------|
| Channel A Data | **02h** | WRITE: Transmit Data / READ: Receive Data |
| Channel A Control/Status | **03h** | WRITE: Mode Word or Command Word / READ: Status Word |
| Channel B Data | **04h** | WRITE: Transmit Data / READ: Receive Data |
| Channel B Control/Status | **05h** | WRITE: Mode Word or Command Word / READ: Status Word |

**Note on port layout:** Unlike the 88-2SIO (where the status port comes first at the lower address), the IMSAI SIO-2 places the **data port at the lower address** and the **control/status port at the higher address**. This is the opposite convention.

Additional ports on the SIO-2 board are used for board-level control, interrupt configuration, and baud rate generator access. The board control port is at the base address + 08h:

| Port | Hex | Function |
|------|-----|----------|
| SIO Board 1 Control | **08h** | Board-level control register |
| SIO Board 2 Control | **28h** | Second SIO-2 board control (if installed) |

### EQU Definitions for Assembly Programs

```asm
; IMSAI SIO-2 standard port assignments
; Channel A (typically console/TTY)
TTO     EQU  02h       ; Channel A data port (TX and RX)
TTI     EQU  02h       ; Channel A data port (same port for read and write)
TTS     EQU  03h       ; Channel A command/status port
; Channel B (typically printer/auxiliary)
KBD     EQU  04h       ; Channel B data port
KBDS    EQU  05h       ; Channel B command/status port
; Board control
SIO1C   EQU  08h       ; Board 1 control port

; Alternate labeling (from IMSAI CP/M BIOS)
TTY     EQU  02h       ; TTY data port
TTYS    EQU  03h       ; TTY status port
AUX     EQU  22h       ; AUX data port (second SIO-2 board, channel A)
AUXS    EQU  23h       ; AUX status port
USR     EQU  24h       ; USER data port (second SIO-2 board, channel B)
USRS    EQU  25h       ; USER status port
SIO2C   EQU  28h       ; Second SIO board control port
```

---

## Register Architecture

The Intel 8251 has a context-dependent register structure. The same physical port address accesses different internal registers depending on direction and initialization state:

### Data Port (address 02h for Channel A)

| Direction | Register |
|-----------|----------|
| WRITE | **Transmit Data Register** — byte to be serially transmitted |
| READ | **Receive Data Register** — last byte received |

### Control/Status Port (address 03h for Channel A)

| Direction | Context | Register |
|-----------|---------|----------|
| WRITE | After reset (first write) | **Mode Word** — configures async/sync, data format |
| WRITE | After mode word (all subsequent writes) | **Command Word** — enables TX/RX, handshake, reset |
| READ | Always | **Status Word** — reports TX/RX ready, errors, modem |

**This dual-use of the write port is the fundamental complexity of the 8251.** After hardware reset or an internal reset (command word bit 6), the next write to the control port is interpreted as a Mode Word. After the mode word is accepted, all subsequent writes to the control port are Command Words — until another internal reset switches back to mode-word state.

---

## Mode Word (First Write After Reset)

The Mode Word configures the basic serial format. In **asynchronous mode** (the normal IMSAI SIO-2 configuration), the mode word format is:

```
Bit 7: S2  ┐ Stop bits
Bit 6: S1  ┘
Bit 5: EP  — Even/Odd parity select
Bit 4: PEN — Parity Enable
Bit 3: L2  ┐ Character length
Bit 2: L1  ┘
Bit 1: B2  ┐ Baud rate factor (clock divide)
Bit 0: B1  ┘
```

### Bits 1-0 — Baud Rate Factor

| B2 | B1 | Mode |
|----|-----|------|
| 0 | 0 | **Synchronous mode** (not async — different mode word format!) |
| 0 | 1 | **÷1** (clock = baud rate) |
| 1 | 0 | **÷16** (clock = 16× baud rate) — **standard for IMSAI SIO-2** |
| 1 | 1 | ÷64 (clock = 64× baud rate) |

**Important:** If bits 1,0 = 0,0, the 8251 enters synchronous mode, which uses a completely different mode word format (with sync character bytes following). Always set bits 1,0 to 01, 10, or 11 for asynchronous operation. The standard IMSAI baud rate generator provides 16× clocks, so use **÷16 mode (bits 1,0 = 1,0)**.

### Bits 3-2 — Character Length

| L2 | L1 | Data Bits |
|----|----|-----------|
| 0 | 0 | 5 bits |
| 0 | 1 | 6 bits |
| 1 | 0 | 7 bits |
| 1 | 1 | **8 bits** |

### Bit 4 — Parity Enable

| PEN | Function |
|-----|----------|
| 0 | Parity **disabled** (no parity bit) |
| 1 | Parity **enabled** |

### Bit 5 — Even/Odd Parity Select (only if PEN=1)

| EP | Function |
|----|----------|
| 0 | **Odd** parity |
| 1 | **Even** parity |

### Bits 7-6 — Stop Bits

| S2 | S1 | Stop Bits |
|----|----|-----------|
| 0 | 0 | Invalid |
| 0 | 1 | **1 stop bit** |
| 1 | 0 | 1.5 stop bits |
| 1 | 1 | **2 stop bits** |

### Common Mode Word Values

```asm
; 8 data bits, 1 stop bit, no parity, ÷16
; Bits: 01-0-0-11-10 = 01001110b = 4Eh
MODE_8N1   EQU  4Eh

; 8 data bits, 2 stop bits, no parity, ÷16
; Bits: 11-0-0-11-10 = 11001110b = CEh
MODE_8N2   EQU  0CEh

; 7 data bits, 1 stop bit, even parity, ÷16
; Bits: 01-1-1-10-10 = 01111010b = 7Ah
MODE_7E1   EQU  7Ah

; 7 data bits, 1 stop bit, odd parity, ÷16
; Bits: 01-0-1-10-10 = 01011010b = 5Ah
MODE_7O1   EQU  5Ah

; 8 data bits, 1 stop bit, even parity, ÷16
; Bits: 01-1-1-11-10 = 01111110b = 7Eh
MODE_8E1   EQU  7Eh

; 8 data bits, 2 stop bits, even parity, ÷16
; Bits: 11-1-1-11-10 = 11111110b = FEh
MODE_8E2   EQU  0FEh
```

---

## Command Word (All Writes After Mode Word)

After the mode word has been written, all subsequent writes to the control/status port are interpreted as Command Words:

```
Bit 7: EH  — Enter Hunt mode (synchronous only; 0 for async)
Bit 6: IR  — Internal Reset (returns 8251 to mode-word state)
Bit 5: RTS — Request To Send output (1 = RTS asserted/active)
Bit 4: ER  — Error Reset (1 = clears PE, OE, FE error flags)
Bit 3: SBRK — Send Break (1 = force TxD low = break condition)
Bit 2: RxE — Receive Enable (1 = enable receiver)
Bit 1: DTR — Data Terminal Ready output (1 = DTR asserted/active)
Bit 0: TxEN — Transmit Enable (1 = enable transmitter)
```

### Bit Details

**Bit 0 — TxEN (Transmit Enable):** Must be set to 1 to allow transmission. When 0, the transmitter is disabled. **Additionally, CTS must be asserted (low) for the transmitter to actually send data** — TxEN alone is not sufficient if CTS is not active.

**Bit 1 — DTR (Data Terminal Ready):** Controls the DTR output pin. Set to 1 to assert DTR (active-low RS-232 output goes low, indicating terminal is ready). Must be set if the connected device requires DTR.

**Bit 2 — RxE (Receive Enable):** Must be set to 1 to enable the receiver. When 0, received data is ignored.

**Bit 3 — SBRK (Send Break):** When set to 1, forces the TxD line to a continuous spacing (low) condition, which is the BREAK signal. Set to 0 for normal transmission.

**Bit 4 — ER (Error Reset):** Writing 1 clears the three error flags (PE, OE, FE) in the status word. This bit is not latched — it's a pulse action. The common practice is to write a command with ER=1, then immediately follow with the same command with ER=0.

**Bit 5 — RTS (Request To Send):** Controls the RTS output pin. Set to 1 to assert RTS (active-low RS-232 output goes low, requesting to send).

**Bit 6 — IR (Internal Reset):** Writing 1 performs a software reset of the 8251, returning it to the mode-word state. After this, the next write to the control port will be interpreted as a new mode word. This is used during the initialization "flush" sequence (see below).

**Bit 7 — EH (Enter Hunt):** Used only in synchronous mode. Set to 0 for asynchronous operation.

### Common Command Word Values

```asm
; Standard command: TX enable, RX enable, DTR active, RTS active
; Bits: 0-0-1-0-0-1-1-1 = 00100111b = 27h
CMD_NORMAL  EQU  27h

; Same as above, with error flags reset
; Bits: 0-0-1-1-0-1-1-1 = 00110111b = 37h
CMD_ERRRST  EQU  37h

; Internal reset (returns to mode-word state)
; Bits: 0-1-0-0-0-0-0-0 = 01000000b = 40h
CMD_RESET   EQU  40h

; TX enable only, no RX, DTR+RTS active
; Bits: 0-0-1-0-0-0-1-1 = 00100011b = 23h
CMD_TXONLY  EQU  23h
```

---

## Status Word (READ from Control/Status Port)

Reading the control/status port always returns the Status Word:

```
Bit 7: DSR   — Data Set Ready (1 = DSR input is active/low)
Bit 6: SYNDET/BRKDET — Sync Detect (sync mode) / Break Detect (async mode)
Bit 5: FE    — Framing Error (1 = no valid stop bit detected)
Bit 4: OE    — Overrun Error (1 = character lost — not read before next arrived)
Bit 3: PE    — Parity Error (1 = parity mismatch on received character)
Bit 2: TxEMPTY — Transmitter Empty (1 = transmitter shift register AND data register empty)
Bit 1: RxRDY — Receiver Ready (1 = received character available in data register)
Bit 0: TxRDY — Transmitter Ready (1 = transmit data register can accept a new byte)
```

### Bit Details

**Bit 0 — TxRDY (Transmitter Ready):**
Set when the transmit data register is empty and can accept a new character. This bit is the "buffer empty" flag — it goes high as soon as the previous byte has been transferred to the shift register for serialization. **TxRDY is inhibited if TxEN=0 or CTS is not active.**

**Bit 1 — RxRDY (Receiver Ready):**
Set when a complete character has been received and is available in the receive data register. Cleared by reading the data register. **This is the primary bit to poll for incoming data.**

**Bit 2 — TxEMPTY (Transmitter Empty):**
Set when BOTH the transmit data register AND the transmit shift register are empty — meaning the last character has been completely serialized and sent. This is different from TxRDY: TxRDY goes high when you can write a new byte (even though the previous byte is still being shifted out), while TxEMPTY only goes high when everything has been sent. Use TxEMPTY when you need to know that all data has been physically transmitted (e.g., before disabling the transmitter or before a mode change).

**Bit 3 — PE (Parity Error):**
Set when the received character's parity doesn't match the configured mode. Only meaningful if parity is enabled.

**Bit 4 — OE (Overrun Error):**
Set when a new character was fully received but the previous character hadn't been read from the data register. The new character overwrites the old one.

**Bit 5 — FE (Framing Error):**
Set when no valid stop bit is detected at the expected position. Indicates line noise, baud rate mismatch, or a BREAK condition from the remote end.

**Bit 6 — SYNDET/BRKDET:**
In asynchronous mode, this becomes BRKDET (Break Detect) — set when a break condition is detected (continuous spacing on RxD for longer than a full character frame).

**Bit 7 — DSR (Data Set Ready):**
Reflects the state of the DSR input pin. When 1, DSR is active (the modem/device is ready). Note: this is the **complement** of the RS-232 pin level (active-low input, reported as active-high in the status register).

### Status Bit Comparison: IMSAI SIO-2 (8251) vs. MITS 88-2SIO (6850)

| Function | 8251 (IMSAI) | 6850 (MITS) |
|----------|-------------|-------------|
| **TX Ready** | Bit 0 (TxRDY) | Bit 1 (TDRE) |
| **RX Ready** | Bit 1 (RxRDY) | Bit 0 (RDRF) |
| TX Empty | Bit 2 (TxEMPTY) | (no equivalent) |
| Parity Error | Bit 3 (PE) | Bit 6 (PE) |
| Overrun | Bit 4 (OE) | Bit 5 (OVRN) |
| Framing Error | Bit 5 (FE) | Bit 4 (FE) |
| Break/Sync | Bit 6 (BRKDET) | (no equivalent) |
| DSR / IRQ | Bit 7 (DSR) | Bit 7 (IRQ) |

**The TX/RX ready bits are swapped** between the two chips. This is the most critical difference for porting code.

---

## Initialization Procedure

The 8251 initialization is more complex than the MC6850 because of the shared control port and the synchronous mode state machine.

### The "Worst Case" Initialization Sequence

After a hardware reset, the 8251 expects a mode word on the first control port write. However, if the system was interrupted mid-operation (e.g., a soft reset without hardware reset), the 8251 might be in the middle of a synchronous mode initialization (which expects up to 3 bytes: mode + 2 sync characters). To handle this, the robust initialization sequence writes **three bytes to flush any pending sync mode state**, then issues an internal reset, then writes the actual mode word and command word:

```asm
; Robust initialization for IMSAI SIO-2 Channel A
; Handles unknown state of 8251 (worst-case scenario)
TTS     EQU  03h       ; Channel A command/status port
TTO     EQU  02h       ; Channel A data port

init_sio:
    ; Step 1: Flush any pending synchronous mode initialization
    ; Write three dummy bytes to the control port to satisfy
    ; a worst-case sync mode init (mode + 2 sync chars)
    XRA  A             ; A = 00h (harmless dummy byte)
    OUT  TTS
    OUT  TTS
    OUT  TTS
    
    ; Step 2: Internal Reset — returns 8251 to mode-word state
    MVI  A,40h         ; Command: Internal Reset (bit 6)
    OUT  TTS
    
    ; Step 3: Write the actual Mode Word
    MVI  A,4Eh         ; Mode: 8N1, ÷16
    OUT  TTS           ; Now in mode-word state, so this sets the mode
    
    ; Step 4: Write the Command Word
    MVI  A,37h         ; Command: TX enable, RX enable, DTR, RTS, Error Reset
    OUT  TTS
    
    ; Step 5: Write command again without Error Reset
    MVI  A,27h         ; Same but ER=0
    OUT  TTS
    RET
```

### Minimal Initialization (After Known Hardware Reset)

If you know the 8251 has been hardware-reset (e.g., immediately after power-on with no prior code execution), you can skip the flush:

```asm
; Minimal init — only use immediately after hardware reset
init_sio_min:
    MVI  A,4Eh         ; Mode: 8N1, ÷16
    OUT  TTS           ; First write after reset = Mode Word
    MVI  A,37h         ; Command: enable TX+RX, DTR, RTS, reset errors
    OUT  TTS           ; Second write = Command Word
    MVI  A,27h         ; Command without error reset
    OUT  TTS
    RET
```

### Initialize Both Channels

```asm
init_both:
    ; Channel A
    XRA  A
    OUT  03h
    OUT  03h
    OUT  03h
    MVI  A,40h         ; Internal Reset
    OUT  03h
    MVI  A,4Eh         ; Mode: 8N1, ÷16
    OUT  03h
    MVI  A,37h         ; Command: full enable + error reset
    OUT  03h
    MVI  A,27h         ; Command: full enable, no error reset
    OUT  03h
    
    ; Channel B
    XRA  A
    OUT  05h
    OUT  05h
    OUT  05h
    MVI  A,40h
    OUT  05h
    MVI  A,4Eh
    OUT  05h
    MVI  A,37h
    OUT  05h
    MVI  A,27h
    OUT  05h
    RET
```

---

## Common I/O Operations

### Read a Character (Polled)

```asm
; Wait for and read a character from Channel A
; Returns character in A
TTS     EQU  03h
TTI     EQU  02h

getchar:
    IN   TTS           ; Read status word
    ANI  02h           ; Test RxRDY (bit 1)
    JZ   getchar       ; Loop until character received
    IN   TTI           ; Read character from data register
    RET
```

**Note:** Unlike the 88-2SIO where RDRF is bit 0 (testable with RRC/JNC), the IMSAI SIO-2's RxRDY is bit 1. You CANNOT use RRC/JNC for a single-instruction test of RxRDY — you must use ANI 02h / JZ.

### Send a Character (Polled)

```asm
; Send character in A to Channel A
; Preserves character in A
TTS     EQU  03h
TTO     EQU  02h

putchar:
    PUSH PSW           ; Save character
tx_wait:
    IN   TTS           ; Read status
    ANI  01h           ; Test TxRDY (bit 0)
    JZ   tx_wait       ; Loop until transmit register empty
    POP  PSW           ; Restore character
    OUT  TTO           ; Write character to data register
    RET
```

**Alternative: using TxEMPTY (bit 2) instead of TxRDY:**

TxRDY (bit 0) goes high as soon as you can load the next byte — the previous byte may still be shifting out. TxEMPTY (bit 2) waits until everything has been fully transmitted. TxRDY is faster for throughput; TxEMPTY is safer for mode changes.

```asm
; Wait for complete transmission (TxEMPTY)
putchar_empty:
    PUSH PSW
tx_empty:
    IN   TTS
    ANI  04h           ; Test TxEMPTY (bit 2)
    JZ   tx_empty
    POP  PSW
    OUT  TTO
    RET
```

### Echo Loop (Test Program)

```asm
; Echo test for IMSAI SIO-2 Channel A
; All received characters are echoed back to sender
        ORG  0000h

        ; Initialize
        XRA  A
        OUT  03h
        OUT  03h
        OUT  03h
        MVI  A,40h     ; Internal Reset
        OUT  03h
        MVI  A,4Eh     ; Mode: 8N1, ÷16
        OUT  03h
        MVI  A,37h     ; Command: TX+RX enable, DTR, RTS, error reset
        OUT  03h
        MVI  A,27h     ; Command: same without error reset
        OUT  03h

echo:   IN   03h       ; Read status
        ANI  02h       ; RxRDY?
        JZ   echo      ; Wait for character
        IN   02h       ; Read character
        PUSH PSW       ; Save it
tx_rdy: IN   03h       ; Check transmitter
        ANI  01h       ; TxRDY?
        JZ   tx_rdy    ; Wait
        POP  PSW       ; Restore character
        OUT  02h       ; Echo it back
        JMP  echo
```

### Send a Null-Terminated String

```asm
; Send null-terminated string at HL to Channel A
puts:
    MOV  A,M           ; Get character
    ORA  A             ; Null?
    RZ                 ; Done
    MOV  B,A           ; Save in B
puts_tx:
    IN   TTS           ; Read status
    ANI  01h           ; TxRDY?
    JZ   puts_tx       ; Wait
    MOV  A,B           ; Restore character
    OUT  TTO           ; Send
    INX  H             ; Next character
    JMP  puts
```

---

## Handshaking

### CTS (Clear To Send) — Critical for Transmission

**The 8251 will NOT transmit if CTS is not asserted**, even with TxEN set in the command word. The TxRDY status bit is also inhibited when CTS is inactive. If you're connecting directly to a terminal (not a modem), the CTS line must be held active (low at the RS-232 level). On the IMSAI SIO-2:

- The RS-232 connector should have CTS jumpered to a suitable signal (often tied to RTS from the terminal, or jumpered active)
- Alternatively, use a straight-through cable where the terminal asserts CTS
- If using a USB-to-serial adapter, most adapters assert CTS by default

**Symptom of missing CTS:** TxRDY never goes high, the transmitter appears dead, but the 8251 is properly initialized. This is the #1 debugging issue.

### DSR (Data Set Ready)

DSR is available as status bit 7. In many IMSAI configurations, DSR is either jumpered active or connected to DTR from the terminal. Software rarely checks DSR in practice.

### DTR and RTS Outputs

DTR (command bit 1) and RTS (command bit 5) are output signals controlled by the command word. They are active when set to 1 (which produces an active-low RS-232 signal). Most IMSAI configurations set both active during initialization.

---

## Error Handling

```asm
; Check for and clear receive errors
; Returns: Z flag set if no error, NZ if error detected
; Error details in A (bits 3-5)
check_errors:
    IN   TTS           ; Read status
    ANI  38h           ; Mask PE(3), OE(4), FE(5)
    RZ                 ; No errors
    ; Errors detected — clear them
    PUSH PSW           ; Save error info
    MVI  A,37h         ; Command: normal + Error Reset
    OUT  TTS
    MVI  A,27h         ; Command: normal, clear ER bit
    OUT  TTS
    POP  PSW           ; Restore error flags
    RET                ; Returns NZ with error bits in A
```

---

## Interrupt-Driven I/O

The IMSAI SIO-2 supports interrupts via the IMSAI PIC-8 (Priority Interrupt Controller) board. Interrupt priorities are jumper-selectable on the SIO-2 board.

The 8251 generates interrupt requests for:
- TxRDY — transmit buffer empty
- RxRDY — character received

Unlike the MC6850 which has interrupt enable bits in the control register, the 8251's interrupt outputs are always active. The PIC-8 board handles enabling/disabling and prioritizing interrupts at the system level.

For systems without a PIC-8, use polled I/O exclusively.

---

## Baud Rate Configuration

Baud rates are set by **hardware jumpers** on the SIO-2 board. Each channel has its own baud rate jumper block. Available rates:

| Jumper Position | Baud Rate |
|----------------|-----------|
| 110 | 110 baud (Teletype ASR-33) |
| 150 | 150 baud |
| 300 | 300 baud |
| 600 | 600 baud |
| 1200 | 1200 baud |
| 2400 | 2400 baud |
| 4800 | 4800 baud |
| 9600 | 9600 baud |

The baud rate generator provides a clock at 16× the selected rate. The mode word's baud rate factor must be set to ÷16 (bits 1,0 = 1,0) to match.

---

## Memory-Mapped I/O Option

The SIO-2 can be jumpered for memory-mapped I/O instead of port-mapped I/O. When configured for memory-mapped mode, the I/O ports appear in the memory address space with the upper address byte fixed at **FEh**. In this mode, use LDA/STA instructions instead of IN/OUT:

```asm
; Memory-mapped example (if SIO-2 is configured for memory-mapped at FE02h)
; This is unusual — most systems use I/O-mapped mode
    LDA  0FE03h        ; Read status (equivalent to IN 03h)
    ANI  02h           ; RxRDY?
    JZ   wait
    LDA  0FE02h        ; Read data (equivalent to IN 02h)
```

---

## Differences: IMSAI SIO-2 (8251) vs. MITS 88-2SIO (6850)

| Feature | IMSAI SIO-2 (8251) | MITS 88-2SIO (6850) |
|---------|--------------------|---------------------|
| UART chip | Intel 8251 USART | Motorola MC6850 ACIA |
| Data port address | Lower (02h) | Higher (11h) |
| Control/status address | Higher (03h) | Lower (10h) |
| RX Ready bit | **Bit 1** | **Bit 0** |
| TX Ready bit | **Bit 0** | **Bit 1** |
| Initialization | Mode Word + Command Word (context-sensitive) | Single Control Register write |
| Reset method | Write 03h (flush) + 40h (IR) + mode + cmd | Write 03h (master reset) + config |
| CTS behavior | Inhibits TxRDY (must be active) | Inhibits TDRE (must be grounded) |
| Sync mode | Supported | Not supported |
| Error reset | Command word bit 4 (ER) | Read status + read data |
| Additional formats | 5, 6, 7, 8 data bits; 1, 1.5, 2 stop | 7 or 8 data bits; 1 or 2 stop |

### Porting Code Between 88-2SIO and IMSAI SIO-2

When porting code between the two boards, the critical changes are:

1. **Swap the status bit tests**: RxRDY is bit 1 (not bit 0), TxRDY is bit 0 (not bit 1)
2. **Swap data and status port addresses**: IMSAI has data at lower address
3. **Change initialization**: Completely different sequence (mode word + command word)
4. **Cannot use RRC/JNC for RX check**: Must use ANI 02h / JZ instead

---

## Programming Tips and Common Pitfalls

### 1. The Three-Byte Flush is Essential
After a soft reset (front panel RESET), the 8251 may be in any state of its synchronous mode initialization sequence. The three-byte flush followed by Internal Reset (40h) guarantees a clean state. Never skip this in production code.

### 2. CTS Must Be Active for Transmission
The 8251 requires CTS to be asserted (low at the chip pin) before it will transmit, regardless of the TxEN command bit. If TxRDY never goes high after initialization, check CTS. Use a straight-through cable or jumper CTS to RTS on the connector.

### 3. Error Flags Must Be Explicitly Cleared
Unlike the MC6850 (where reading data clears some flags), the 8251's error flags (PE, OE, FE) stick until explicitly cleared by setting the ER bit in a command word. Always write a command with ER=1 followed by ER=0 after detecting errors.

### 4. Don't Confuse TxRDY and TxEMPTY
TxRDY (bit 0) = "I can accept another byte" — the previous byte may still be shifting out.
TxEMPTY (bit 2) = "Nothing is being transmitted at all."
For character-by-character output, poll TxRDY. For mode changes or shutdown, wait for TxEMPTY.

### 5. Mode Word vs Command Word Context
After writing a mode word, ALL subsequent writes are command words. The only way to write a new mode word is to first issue an Internal Reset (command bit 6 = 40h). If you accidentally write a mode word when the 8251 expects a command word, the results are unpredictable.

### 6. The Command Word 37h/27h Pattern
The standard initialization pattern is:
- Write 37h (everything enabled + error reset)
- Write 27h (everything enabled, error reset cleared)
This ensures errors are cleared from any previous operation.

### 7. Hardware Reset vs. Internal Reset
The IMSAI front panel RESET button typically asserts hardware reset on the 8251. But if your code does a JMP 0000h (warm restart), the 8251 does NOT get hardware-reset — you must use the software initialization sequence with the three-byte flush.

### 8. Strip High Bit on Received Characters
For 8-bit mode receiving ASCII text, mask with 7Fh to strip potential parity or noise on bit 7:
```asm
    IN   02h           ; Read character
    ANI  7Fh           ; Strip high bit
```

---

## Complete Example: Hello World

```asm
; Hello World for IMSAI 8080 with SIO-2
; Prints "HELLO, WORLD!" to Channel A (port 02h/03h)

TTO     EQU  02h       ; Channel A data
TTS     EQU  03h       ; Channel A control/status
CR      EQU  0Dh
LF      EQU  0Ah

        ORG  0000h

START:
        ; Robust initialization
        XRA  A
        OUT  TTS
        OUT  TTS
        OUT  TTS
        MVI  A,40h     ; Internal Reset
        OUT  TTS
        MVI  A,4Eh     ; Mode: 8N1, ÷16
        OUT  TTS
        MVI  A,37h     ; Command: enable all + error reset
        OUT  TTS
        MVI  A,27h     ; Command: enable all
        OUT  TTS

        ; Print message
        LXI  H,MSG
PLOOP:
        MOV  A,M       ; Get character
        ORA  A          ; Null?
        JZ   DONE
        MOV  B,A       ; Save character
TWAIT:
        IN   TTS       ; Read status
        ANI  01h       ; TxRDY?
        JZ   TWAIT     ; Wait
        MOV  A,B       ; Restore character
        OUT  TTO       ; Send
        INX  H         ; Next
        JMP  PLOOP

DONE:   HLT

MSG:    DB   CR,LF
        DB   'HELLO, WORLD!'
        DB   CR,LF,00h
```

---

## Complete Example: Interactive Terminal

```asm
; Full-duplex terminal with echo and CR→CRLF expansion
; IMSAI SIO-2 Channel A

TTO     EQU  02h
TTS     EQU  03h
CR      EQU  0Dh
LF      EQU  0Ah

        ORG  0000h

        ; Initialize
        XRA  A
        OUT  TTS
        OUT  TTS
        OUT  TTS
        MVI  A,40h
        OUT  TTS
        MVI  A,4Eh     ; 8N1 ÷16
        OUT  TTS
        MVI  A,37h
        OUT  TTS
        MVI  A,27h
        OUT  TTS

        ; Print banner
        LXI  H,BANNER
        CALL PUTS

MAIN:
        IN   TTS       ; Poll status
        ANI  02h       ; RxRDY?
        JZ   MAIN      ; No character
        
        IN   TTO       ; Read character (same address as TTO)
        ANI  7Fh       ; Strip high bit
        
        PUSH PSW       ; Save character
        CALL PUTCHR    ; Echo it
        POP  PSW
        
        CPI  CR        ; Carriage return?
        JNZ  MAIN
        MVI  A,LF      ; Send LF after CR
        CALL PUTCHR
        JMP  MAIN

; Send character in A via Channel A
PUTCHR:
        PUSH PSW
PUTWT:  IN   TTS
        ANI  01h       ; TxRDY?
        JZ   PUTWT
        POP  PSW
        OUT  TTO
        RET

; Send null-terminated string at HL
PUTS:
        MOV  A,M
        ORA  A
        RZ
        CALL PUTCHR
        INX  H
        JMP  PUTS

BANNER: DB   CR,LF
        DB   'IMSAI 8080 READY'
        DB   CR,LF,00h
```

---

## Quick Reference: Status Bit Testing

| What to Check | IN Port | Test | Branch |
|--------------|---------|------|--------|
| Character received? | IN TTS | ANI 02h / JZ | JZ = not ready |
| Transmitter ready? | IN TTS | ANI 01h / JZ | JZ = not ready |
| TX completely empty? | IN TTS | ANI 04h / JZ | JZ = still sending |
| Any receive error? | IN TTS | ANI 38h / JNZ | JNZ = error |
| Break detected? | IN TTS | ANI 40h / JNZ | JNZ = break |
| DSR active? | IN TTS | ANI 80h / JNZ | JNZ = DSR active |

---

## References

- IMSAI SIO-2 Manual (s100computers.com/Hardware Folder/IMSAI/SIO/)
- Intel 8251A USART Data Sheet (Intel Corporation)
- IMSAI CP/M System User's Guide, Version 1.31 (bitsavers.org)
- VCF Forums: "How to get output from SIO with Intel 8251A USART" (forum.vcfed.org)
- GlitchWorks: "IMSAI SIO-2 Compatibility with the Processor Tech 3P+S" (glitchwrks.com)
- TheRetroWagon: IMSAI 8080 SIO debugging (wiki.theretrowagon.com, imsai.dev)
- The High Nibble: IMSAI 8080esp SIO port mapping (thehighnibble.com)
- s100computers.com: IMSAI SIO Board page

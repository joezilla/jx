# SKILL: Programming the IMSAI MIO (Multiple Input/Output) Board in 8080 Assembly

## Overview

The IMSAI MIO (Multiple Input/Output) board is an S-100 bus multifunction I/O card released in 1977 for the IMSAI 8080. It consolidates four different I/O interfaces onto a single board:

1. **One Serial I/O port** (for terminals, teletypes, modems)
2. **Two Parallel I/O (PIO) ports** (for printers, custom peripherals)
3. **One Control port** (for internal/external control functions)
4. **A Cassette tape data storage interface** (for audio cassette recorders)

The MIO was designed as a cost-effective alternative to purchasing separate SIO, PIO, and UCRI boards, and could handle a typical IMSAI configuration (TV Typewriter + Line Printer + Teletype + cassette recorder) on a single card.

**Key difference from the IMSAI SIO-2:** The MIO uses a **TR1602B / TMS-6011** standalone UART (also known as the AY-5-1013 or HD-6402 family) for its serial port, NOT the Intel 8251 USART. This is a fundamentally simpler chip — it has **no software-configurable mode or command registers**. Data format (baud rate, word length, parity, stop bits) is set entirely by **hardware jumpers and control pins**, not by writing configuration bytes. The programmer's interface is therefore much simpler than the SIO-2's 8251, but also less flexible at runtime.

The parallel ports and control port use **Intel 8212 / AMD 8212** 8-bit I/O port chips.

---

## Hardware Components

| Component | Function |
|-----------|----------|
| WD TR1602B (or TI TMS-6011) UART | Serial transmit/receive (40-pin DIP) |
| 4 × Intel/AMD 8212 | 8-bit I/O latched port chips for parallel and control I/O |
| Motorola MC1489AL | Quad RS-232 line receiver |
| Motorola MC1488 (or equiv) | Quad RS-232 line driver |
| Baud rate generator | On-board clock divider for serial port |
| Cassette modulator/demodulator | FSK audio interface for tape storage |

---

## I/O Port Architecture

The MIO board uses **four I/O port addresses**, selected by address lines A0 and A1 with the upper address bits (A2-A7) jumper-configured as a base address. The four ports occupy consecutive addresses from the base.

### Default Port Assignments

The MIO board base address is jumper-selectable. A common configuration places the MIO at a base that does not conflict with the SIO-2's standard ports (02h-05h). However, the exact default depends on the system configuration.

The four ports, at offsets 0-3 from the base address, are assigned as follows:

| Offset | Port Function | Direction |
|--------|--------------|-----------|
| Base+0 | **Port A** — Parallel I/O Port 1 | Read/Write (via 8212) |
| Base+1 | **Port B** — Parallel I/O Port 2 | Read/Write (via 8212) |
| Base+2 | **Port C** — Serial Data Port (UART) | Read: Receive Data / Write: Transmit Data |
| Base+3 | **Port D** — Status/Control Port | Read: UART + board status / Write: Control outputs |

**Note:** The exact port assignment mapping (which offset goes to which function) is jumper-configurable on the MIO board. The above represents the standard/recommended configuration. Consult the board's jumper settings to confirm your specific mapping.

### EQU Definitions for Assembly Programs

```asm
; IMSAI MIO port assignments (example base address 10h)
; Adjust BASE to match your board's jumper configuration
BASE    EQU  10h       ; MIO board base address (jumper-selectable)

PORTA   EQU  BASE+0    ; Parallel I/O Port A (8212)
PORTB   EQU  BASE+1    ; Parallel I/O Port B (8212)
SDATA   EQU  BASE+2    ; Serial Data port (UART RX/TX data)
SSTAT   EQU  BASE+3    ; Serial Status/Control port
```

If the MIO replaces or supplements an SIO-2 for console duty, it may be configured to appear at the same addresses (02h/03h) for software compatibility:

```asm
; MIO configured as console replacement at SIO-2 addresses
TTI     EQU  02h       ; Serial data port (read = receive)
TTO     EQU  02h       ; Serial data port (write = transmit)
TTS     EQU  03h       ; Serial status port (read = status)
TTC     EQU  03h       ; Serial control port (write = control)
```

---

## The TR1602 / TMS-6011 UART

### Chip Family Compatibility

The TR1602B (Western Digital), TMS-6011 (Texas Instruments), AY-5-1013 (General Instrument), and HD-6402 (Intersil/Renesas) are all pin-compatible 40-pin DIP UARTs with identical programming interfaces. They differ primarily in maximum clock speed (the AY-5-1013A handles up to 40K baud; the older TR1602 is typically limited to ~9600 baud in async mode with 16× clock).

### Key Differences from the Intel 8251

| Feature | TR1602 / HD-6402 (MIO) | Intel 8251 (SIO-2) |
|---------|------------------------|---------------------|
| Configuration | **Hardware only** — jumpers/pins | Software — mode word + command word |
| Initialization | **None required** — works after power-on reset | Complex multi-byte sequence required |
| Mode/command registers | **None** — no writable config registers | Mode word, command word, status word |
| Data format | Fixed by jumper wires | Software-selectable at any time |
| Status outputs | Individual pins, directly readable via 8212 | Multiplexed in a single status register |
| Baud rate | Fixed by baud rate generator jumper | Fixed by baud rate generator jumper |
| Sync mode | **Not supported** (async only) | Supported |
| Modem control (RTS/CTS/DTR/DSR) | Via separate control/status bits on 8212 | Built into 8251 command/status words |

**The practical impact:** Programming the MIO serial port is dramatically simpler than the SIO-2. There is no initialization sequence. You just read the status port, check the appropriate bit, and read/write the data port. The UART is always ready after power-on reset.

### UART Signal Descriptions

The TR1602/HD-6402 has the following key signals, which the MIO board routes through 8212 I/O port chips to the S-100 bus:

**Transmitter signals:**
- **TBR1-TBR8** — Transmit Buffer Register inputs (parallel data to send)
- **TBRL** — Transmit Buffer Register Load (low pulse initiates transfer)
- **TBRE** — Transmit Buffer Register Empty (high = ready for next byte)
- **TRE** — Transmit Register Empty (high = all bits fully shifted out)
- **TRO** — Transmit Register Output (serial data out to RS-232 driver)

**Receiver signals:**
- **RBR1-RBR8** — Receive Buffer Register outputs (parallel received data)
- **RRD** — Receive Register Disable (high = three-state outputs)
- **DR** — Data Received / Data Ready (high = character available)
- **DRR** — Data Received Reset (low pulse clears DR flag)
- **RRI** — Receive Register Input (serial data in from RS-232 receiver)

**Status flag outputs:**
- **PE** — Parity Error (high = received parity mismatch)
- **FE** — Framing Error (high = invalid stop bit)
- **OE** — Overrun Error (high = DR not cleared before new char arrived)
- **SFD** — Status Flag Disable (high = three-state PE/FE/OE/DR/TBRE)

**Clock inputs:**
- **TRC** — Transmitter Register Clock (16× transmit baud rate)
- **RRC** — Receiver Register Clock (16× receive baud rate)

**Control inputs (directly set by jumpers on MIO board):**
- **CLS1, CLS2** — Character Length Select (5/6/7/8 bits)
- **PI** — Parity Inhibit (high = no parity)
- **EPE** — Even Parity Enable (high = even, low = odd; only if PI=low)
- **SBS** — Stop Bit Select (high = 1.5/2 stop bits)
- **CRL** — Control Register Load (latches CLS/PI/EPE/SBS settings)

**Reset:**
- **MR** — Master Reset (high pulse clears PE/FE/OE/DR, sets TRE high)

---

## Status Port (Read)

When you read the status/control port, you get a byte whose bits reflect the UART and board status. The bit assignments are determined by how the MIO board wires the UART status outputs and any board-level signals to the 8212 input port. Based on the standard MIO configuration and compatibility with the IMSAI SIO-2 status conventions:

```
Status Port (READ):
Bit 0: TxRDY  — Transmitter Ready (TBRE from UART; 1 = ready for next byte)
Bit 1: RxRDY  — Receiver Ready (DR from UART; 1 = received character available)
Bit 2: TxEMPTY — Transmitter Empty (TRE from UART; 1 = completely idle)
Bit 3: PE     — Parity Error (1 = parity mismatch)
Bit 4: OE     — Overrun Error (1 = character overrun)
Bit 5: FE     — Framing Error (1 = invalid stop bit)
Bit 6: (board-specific — may be BREAK detect or unused)
Bit 7: (board-specific — may be DSR or unused)
```

**Important note on bit assignments:** The exact bit positions depend on how the MIO board designer wired the UART's status output pins to the 8212 input port pins. The above layout is the **most common convention** matching the 3P+S compatibility wiring (which was designed to emulate 8251 status). Your specific MIO board revision may differ — check the board's jumper configuration area labeled for status port wiring, or consult the MIO manual's status bit table.

**For SIO-2 software compatibility:** If the MIO is jumpered to emulate SIO-2 status bit positions, TxRDY is at bit 0 and RxRDY is at bit 1, matching the 8251 convention. This is the recommended configuration for running IMSAI CP/M and other standard IMSAI software.

### Testing Status Bits

```asm
; Check if a character has been received (RxRDY = bit 1)
    IN   TTS           ; Read status port
    ANI  02h           ; Test bit 1 (RxRDY / DR)
    JZ   no_data       ; Jump if no character available

; Check if transmitter is ready (TxRDY = bit 0)
    IN   TTS           ; Read status port
    ANI  01h           ; Test bit 0 (TxRDY / TBRE)
    JZ   tx_busy       ; Jump if transmitter busy

; Check for any receive error (PE, OE, FE = bits 3-5)
    IN   TTS           ; Read status port
    ANI  38h           ; Mask bits 3, 4, 5
    JNZ  rx_error      ; Jump if any error flag set
```

---

## Data Port (Read/Write)

### Reading Received Data

```asm
; Read the data port to get the received character
    IN   SDATA         ; Read received character from UART (RBR1-RBR8)
```

Reading the data port retrieves the contents of the Receive Buffer Register. On the MIO board, the act of reading the data port also generates the DRR (Data Received Reset) pulse that clears the DR flag, making the UART ready to receive the next character.

### Writing Transmit Data

```asm
; Write to the data port to transmit a character
    OUT  SDATA         ; Write character to UART (TBR1-TBR8 + TBRL pulse)
```

Writing to the data port loads the byte into the Transmit Buffer Register and generates the TBRL pulse. If the transmitter is idle, the byte is immediately transferred to the shift register and transmission begins. If the transmitter is busy, the byte waits in the buffer and is automatically sent when the current transmission completes.

---

## Control Port (Write)

Writing to the control/status port address sends bits to the control 8212, which drives various board-level functions:

```
Control Port (WRITE):
Bit 0: (board-specific — may control DTR)
Bit 1: (board-specific — may control RTS)
Bit 2: (board-specific — may select cassette motor on/off)
Bit 3: (board-specific — may select cassette channel)
Bit 4-7: (board-specific — auxiliary control outputs)
```

The control port bit assignments are board-revision-dependent and are typically documented in the MIO manual's options selection section. Common uses include:

- Controlling modem handshake lines (DTR, RTS) via RS-232 drivers
- Cassette motor relay control
- Cassette read/write mode selection
- Auxiliary control outputs for user-defined functions

---

## Initialization

### Power-On: No Software Init Required for UART

Unlike the Intel 8251 (which requires a multi-step mode/command initialization sequence), the TR1602/HD-6402 UART requires **no software initialization**. After a hardware reset (MR pulse), the chip is immediately ready to transmit and receive according to its hardwired configuration. The data format (baud rate, word length, parity, stop bits) is set by jumpers on the MIO board.

The only initialization step is optional: reading the status port to clear any stale flags, and optionally reading the data port to flush any garbage byte:

```asm
; Optional cleanup after power-on (recommended)
init_mio:
    IN   SSTAT         ; Read status to clear any stale state
    IN   SDATA         ; Read data port to flush any pending byte
    RET
```

### Setting a Known State

If you want to be thorough (e.g., after a warm restart where the UART may have pending data or error flags), do a read-flush cycle:

```asm
; Thorough MIO serial port reset
init_mio_full:
    IN   SSTAT         ; Read status
    IN   SDATA         ; Flush receive buffer
    IN   SSTAT         ; Read status again to clear any error flags
    IN   SDATA         ; Flush again in case another byte arrived
    ; Control port: set DTR and RTS active (if wired)
    MVI  A,03h         ; Bits 0+1 = DTR + RTS active (check your board wiring)
    OUT  TTC           ; Write to control port
    RET
```

---

## Common I/O Operations

### Read a Character (Polled)

```asm
; Wait for and read a character from MIO serial port
; Returns character in A
; Status bit 1 = RxRDY (DR from UART)
SSTAT   EQU  03h       ; Status port (adjust to your base address)
SDATA   EQU  02h       ; Data port

getchar:
    IN   SSTAT         ; Read status
    ANI  02h           ; Test RxRDY (bit 1)
    JZ   getchar       ; Loop until character received
    IN   SDATA         ; Read character (also clears DR)
    ANI  7Fh           ; Strip high bit (optional, for ASCII)
    RET
```

### Send a Character (Polled)

```asm
; Send character in A via MIO serial port
; Status bit 0 = TxRDY (TBRE from UART)
putchar:
    PUSH PSW           ; Save character
tx_wait:
    IN   SSTAT         ; Read status
    ANI  01h           ; Test TxRDY (bit 0)
    JZ   tx_wait       ; Loop until transmitter ready
    POP  PSW           ; Restore character
    OUT  SDATA         ; Send character
    RET
```

### Echo Loop (Test Program)

```asm
; Echo test for IMSAI MIO serial port
; All received characters are echoed back to sender
; No initialization needed — UART is hardware-configured

        ORG  0000h

SDATA   EQU  02h       ; Adjust to your port
SSTAT   EQU  03h       ; Adjust to your port

        ; Optional: flush any startup garbage
        IN   SSTAT
        IN   SDATA

echo:   IN   SSTAT     ; Read status
        ANI  02h       ; RxRDY?
        JZ   echo      ; Wait for character
        IN   SDATA     ; Read character
        ANI  7Fh       ; Strip parity/noise
        PUSH PSW       ; Save character

tx_rdy: IN   SSTAT     ; Check transmitter
        ANI  01h       ; TxRDY?
        JZ   tx_rdy    ; Wait
        POP  PSW       ; Restore character
        OUT  SDATA     ; Echo it back
        JMP  echo
```

### Send a Null-Terminated String

```asm
; Send null-terminated string at HL via MIO serial port
puts:
    MOV  A,M           ; Get character
    ORA  A             ; Null terminator?
    RZ                 ; Done
    MOV  B,A           ; Save in B
puts_tx:
    IN   SSTAT         ; Read status
    ANI  01h           ; TxRDY?
    JZ   puts_tx       ; Wait
    MOV  A,B           ; Restore character
    OUT  SDATA         ; Send
    INX  H             ; Next character
    JMP  puts
```

### Hello World

```asm
; Hello World for IMSAI 8080 with MIO board
        ORG  0000h

SDATA   EQU  02h
SSTAT   EQU  03h
CR      EQU  0Dh
LF      EQU  0Ah

START:
        ; No UART init needed — hardware configured
        IN   SSTAT     ; Flush status
        IN   SDATA     ; Flush data

        LXI  H,MSG     ; Point to message
PLOOP:
        MOV  A,M       ; Get character
        ORA  A          ; Null?
        JZ   DONE
        MOV  B,A       ; Save character
TWAIT:
        IN   SSTAT     ; Read status
        ANI  01h       ; TxRDY?
        JZ   TWAIT     ; Wait
        MOV  A,B       ; Restore character
        OUT  SDATA     ; Send
        INX  H         ; Next
        JMP  PLOOP

DONE:   HLT

MSG:    DB   CR,LF
        DB   'HELLO, WORLD!'
        DB   CR,LF,00h
```

---

## Parallel I/O Ports (Port A and Port B)

The two parallel ports use Intel/AMD 8212 8-bit latched I/O chips. Each 8212 provides:

- **8-bit output latch** — data written to the port is latched and held on the output pins
- **8-bit input buffer** — data presented on the input pins can be read by the CPU
- **Handshake logic** — optional strobe/interrupt on data transfer

### Writing to a Parallel Port

```asm
; Write byte to Parallel Port A
    MVI  A,55h         ; Data to output
    OUT  PORTA         ; Latch on Port A output pins
```

### Reading from a Parallel Port

```asm
; Read byte from Parallel Port B
    IN   PORTB         ; Read current input levels on Port B
```

### Common Parallel Port Applications

- **Printer interface:** Port A drives printer data lines; Port B or control port handles strobe/busy handshaking
- **LED display:** Port A drives 8 LEDs directly through current-limiting resistors
- **Switch input:** Port B reads 8 toggle switches or DIP switches
- **Custom interface:** Port A/B provide general-purpose TTL-level I/O

---

## Cassette Interface

The MIO board includes a cassette tape interface similar to the standalone IMSAI UCRI-1 board. It uses FSK (Frequency Shift Keying) modulation to encode/decode digital data as audio tones for storage on a standard audio cassette recorder.

The cassette interface is **software-driven** — the CPU must perform bit-level serialization/deserialization in software, typically using the parallel ports and/or control port bits assigned to cassette functions. The MIO board provides the modulation/demodulation hardware (FSK encoder/decoder), but timing is controlled by the program.

Common cassette recording standards supported:
- **BYTE standard** — uses two frequencies for 1 and 0 bits
- **HIT standard** — uses tone/silence for 1 and 0 bits (Kansas City Standard variant)

Cassette programming is beyond the scope of basic serial I/O. The IMSAI SCS (Self-Contained System) software and monitor ROMs contain cassette load/save routines that can serve as reference implementations.

---

## Data Format Configuration (Hardware)

The serial data format is set entirely by jumpers on the MIO board that wire the UART's control pins:

### Character Length (CLS1, CLS2 pins)

| CLS2 | CLS1 | Data Bits |
|------|------|-----------|
| 0 | 0 | 5 bits |
| 0 | 1 | 6 bits |
| 1 | 0 | 7 bits |
| 1 | 1 | **8 bits** (most common) |

### Parity (PI, EPE pins)

| PI | EPE | Parity Mode |
|----|-----|-------------|
| 1 | X | **No parity** (parity inhibited) |
| 0 | 0 | Odd parity |
| 0 | 1 | Even parity |

### Stop Bits (SBS pin)

| SBS | 5-bit char | 6/7/8-bit char |
|-----|-----------|----------------|
| 0 | 1 stop bit | **1 stop bit** |
| 1 | 1.5 stop bits | **2 stop bits** |

### Baud Rate

Set by the on-board baud rate generator jumper. The baud rate generator produces a clock at 16× the desired baud rate, feeding both TRC and RRC. Common rates: 110, 150, 300, 600, 1200, 2400, 4800, 9600.

### Common Configuration

The most common MIO serial configuration is **8N1 at 9600 baud** (8 data bits, No parity, 1 stop bit), matching typical terminal settings.

---

## Error Handling

```asm
; Check for receive errors after reading a character
; Call AFTER reading status but BEFORE reading data
check_errors:
    IN   SSTAT         ; Read status
    MOV  B,A           ; Save full status
    ANI  38h           ; Mask PE(3) + OE(4) + FE(5)
    RZ                 ; No errors — return Z
    ; Error detected — need to read data port to clear
    ; and proceed to recovery
    IN   SDATA         ; Read (and discard) the bad character
    ; Status flags are cleared on the next valid character reception
    ; For OE (overrun), the data in RBR is the NEW character (old was lost)
    MOV  A,B           ; Restore status byte
    ANI  38h           ; Return with error bits
    RET                ; Returns NZ with error bits in A
```

**Note on error flag behavior in the TR1602/HD-6402:**

Unlike the 8251 (which requires an explicit Error Reset command), the TR1602's error flags (PE, FE, OE) are **automatically updated with each received character**. They reflect the status of the **most recently received** character. When the next character is received, the error flags are re-evaluated for that character. There is no need to explicitly clear them.

However, the DR (Data Received) flag must be cleared by pulsing DRR or by reading the data port (which the MIO board's 8212 decoding typically does automatically). If DR is not cleared before the next character arrives, an overrun (OE) occurs.

---

## Comparison: MIO Serial vs. SIO-2 Serial

| Feature | MIO (TR1602 UART) | SIO-2 (Intel 8251 USART) |
|---------|--------------------|--------------------------|
| Initialization | **None needed** | Complex multi-byte sequence |
| Data format | Hardware jumpers only | Software-configurable |
| Status bit layout | Via 8212, configurable | Fixed 8251 register format |
| Error flag clearing | Automatic on next character | Explicit command word (ER bit) |
| Sync mode | Not supported | Supported |
| Modem control | Via separate control port | Built into command/status regs |
| Speed change | Requires jumper change | Requires jumper change |
| CTS requirement | Not inherent to UART | 8251 inhibits TxRDY if CTS inactive |
| Programming complexity | **Very simple** | Moderate (state-machine init) |
| Software compatibility | Requires bit-position matching | Native IMSAI standard |

### Porting Code from SIO-2 to MIO

If the MIO's status port bit positions match the SIO-2 (TxRDY at bit 0, RxRDY at bit 1), the main changes are:

1. **Remove the entire initialization sequence** — no mode word, command word, or three-byte flush needed
2. **Keep the same polling loops** — status bit tests are identical
3. **Keep the same data port reads/writes** — same IN/OUT pattern
4. **Adjust port addresses** if the MIO is at a different base than 02h/03h

If your MIO is jumpered to appear at ports 02h/03h with SIO-2-compatible status bits, existing SIO-2 code will work with only the initialization removed.

### Porting Code from 88-2SIO (MC6850) to MIO

If the MIO status bits are in the SIO-2 convention (TxRDY=bit 0, RxRDY=bit 1):

1. **TX/RX ready bits are in the same relative position** as the SIO-2 (which is swapped from the 6850). See the IMSAI-SIO2-SKILL.md for the full comparison table
2. **Remove the 6850 master reset** (03h write) — not needed
3. **Adjust port addresses** — 88-2SIO uses 10h/11h; MIO address depends on jumpers
4. **Swap data/status port order** if needed — 88-2SIO has status at lower address (10h) and data at higher (11h)

---

## Programming Tips and Common Pitfalls

### 1. No Initialization ≠ No Verification
Even though the UART doesn't need software initialization, you should still verify the hardware is working by checking that TxRDY goes high after power-on. If it doesn't, check baud rate jumpers and cable connections.

### 2. Check Your Exact Status Bit Wiring
The MIO board's status port bit assignments are determined by how the 8212 port's input pins are wired to the UART's status outputs. This wiring may vary between board revisions. The MIO manual's wiring diagram or status port table is authoritative. If you don't have the manual, you can probe the status port while connected to a terminal to determine which bits correspond to TxRDY and RxRDY.

### 3. Overrun is the Most Common Error
The TR1602 has no receive FIFO — just a single one-byte buffer. If your code doesn't read the data port before the next character arrives, the old character is overwritten and OE goes high. At 9600 baud with 8N1, you have approximately 1 millisecond between characters — fast enough for polled I/O but tight for programs doing significant processing between polls.

### 4. No CTS Gating on the UART Itself
Unlike the 8251 (which internally inhibits TxRDY when CTS is inactive), the TR1602 has no CTS awareness. CTS, if implemented, is handled at the board level through the control port or by external logic. TBRE goes high whenever the transmit buffer is empty, regardless of any handshake signals. If your peripheral requires CTS/RTS handshaking, implement it in software by checking the appropriate control port status bits.

### 5. Master Reset After Power-On
The TR1602 datasheet states that MR must be pulsed at least once after power-up, and you should wait 18 clock cycles after the falling edge before beginning operations. On the MIO board, MR is typically connected to the system reset signal, so this happens automatically when you reset the IMSAI from the front panel.

### 6. Strip Bit 7 for ASCII
If operating in 8-bit mode but receiving 7-bit ASCII, mask the received byte with 7Fh to strip potential parity or noise artifacts from bit 7.

### 7. Baud Rate Cannot Be Changed in Software
The baud rate is set by a hardware jumper on the MIO board. You cannot change it programmatically. If you need to support multiple baud rates, you need to physically change the jumper or use a board with a software-selectable baud rate generator.

---

## Quick Reference: Status Bit Testing

Assuming SIO-2-compatible wiring (TxRDY=bit 0, RxRDY=bit 1):

| What to Check | IN Port | Test | Branch |
|--------------|---------|------|--------|
| Character received? | IN SSTAT | ANI 02h / JZ | JZ = not ready |
| Transmitter ready? | IN SSTAT | ANI 01h / JZ | JZ = not ready |
| TX completely empty? | IN SSTAT | ANI 04h / JZ | JZ = still sending |
| Any receive error? | IN SSTAT | ANI 38h / JNZ | JNZ = error |
| Parity error? | IN SSTAT | ANI 08h / JNZ | JNZ = PE |
| Overrun error? | IN SSTAT | ANI 10h / JNZ | JNZ = OE |
| Framing error? | IN SSTAT | ANI 20h / JNZ | JNZ = FE |

---

## TR1602 / HD-6402 UART Pinout Reference (40-pin DIP)

For hardware debugging and understanding the MIO board's UART-to-8212 wiring:

```
Pin  Signal   Dir  Description
---  ------   ---  -----------
 1   VCC      PWR  +5V power supply
 2   NC       —    No connection
 3   GND      PWR  Ground
 4   RRD      IN   Receiver Register Disable (high = three-state RBR outputs)
 5   RBR8     OUT  Receive Buffer Register bit 8 (MSB)
 6   RBR7     OUT  Receive Buffer Register bit 7
 7   RBR6     OUT  Receive Buffer Register bit 6
 8   RBR5     OUT  Receive Buffer Register bit 5
 9   RBR4     OUT  Receive Buffer Register bit 4
10   RBR3     OUT  Receive Buffer Register bit 3
11   RBR2     OUT  Receive Buffer Register bit 2
12   RBR1     OUT  Receive Buffer Register bit 1 (LSB)
13   PE       OUT  Parity Error flag
14   FE       OUT  Framing Error flag
15   OE       OUT  Overrun Error flag
16   SFD      IN   Status Flag Disable (high = three-state PE/FE/OE/DR/TBRE)
17   RRC      IN   Receiver Register Clock (16× RX baud rate)
18   DRR      IN   Data Received Reset (low pulse clears DR)
19   DR       OUT  Data Received (high = character available in RBR)
20   RRI      IN   Receiver Register Input (serial data in)
21   MR       IN   Master Reset (high pulse resets UART)
22   TBRE     OUT  Transmit Buffer Register Empty (high = ready for new byte)
23   TBRL     IN   Transmit Buffer Register Load (low-to-high loads TBR)
24   TRE      OUT  Transmit Register Empty (high = shift register empty)
25   TRO      OUT  Transmit Register Output (serial data out)
26   TBR1     IN   Transmit Buffer Register bit 1 (LSB)
27   TBR2     IN   Transmit Buffer Register bit 2
28   TBR3     IN   Transmit Buffer Register bit 3
29   TBR4     IN   Transmit Buffer Register bit 4
30   TBR5     IN   Transmit Buffer Register bit 5
31   TBR6     IN   Transmit Buffer Register bit 6
32   TBR7     IN   Transmit Buffer Register bit 7
33   TBR8     IN   Transmit Buffer Register bit 8 (MSB)
34   CRL      IN   Control Register Load (latches format config on falling edge)
35   PI       IN   Parity Inhibit (high = no parity)
36   SBS      IN   Stop Bit Select (high = 1.5/2 stop bits)
37   CLS2     IN   Character Length Select 2
38   CLS1     IN   Character Length Select 1
39   EPE      IN   Even Parity Enable (high = even; only if PI=low)
40   TRC      IN   Transmitter Register Clock (16× TX baud rate)
```

---

## References

- IMSAI MIO Manual, IMSAI (IMS Associates, Inc.), February 1977 (archive.org/details/imsai-mio-manual)
- s100computers.com: IMSAI MIO Board page (s100computers.com/Hardware Folder/IMSAI/MIO/)
- HD-6402 CMOS UART Datasheet, Intersil/Renesas (pin-compatible with TR1602/AY-5-1013/TMS-6011)
- TR1602 UART Datasheet, Western Digital
- Intel 8212 Eight-Bit Input/Output Port Data Sheet
- IMSAI CP/M System User's Guide, Version 1.31 (bitsavers.org)
- retrotechnology.com: IMSAI Documentation List (Herb Johnson's IMSAI docs)
- GlitchWorks: IMSAI SIO-2 Compatibility with Processor Tech 3P+S (status bit wiring reference)
- VCF Forums: IMSAI SIO/MIO programming discussions (forum.vcfed.org)

# SKILL: Programming the MITS 88-DCDD Floppy Disk Controller in 8080 Assembly

## Overview

The MITS 88-DCDD is the floppy disk controller for the Altair 8800 computer. It interfaces with Pertec FD-400 8-inch floppy drives via the S-100 bus. Unlike later floppy controllers (NEC µPD765, WD1770, Intel 82077), the 88-DCDD provides **no DMA and no interrupts by default** — all data transfer is done via programmed I/O (PIO), and the CPU must read/write every single byte through IN/OUT instructions. This makes the controller both simple and demanding to program.

The controller consists of two S-100 boards with over 60 ICs. It converts serial data from the drive to/from 8-bit parallel words. A new byte is available every **32 microseconds** at the standard 250 Kbit/s transfer rate. At the 8080A's 2 MHz clock, that is only about 64 CPU clock cycles per byte — tight enough that the MITS software reads **two bytes per status check** rather than checking the status bit before every read.

---

## Physical Disk Parameters

### 8-Inch Diskette (Pertec FD-400)

| Parameter | Value |
|-----------|-------|
| Disk diameter | 8 inches |
| Sides | 1 (single-sided) |
| Density | Single density (FM encoding) |
| Tracks | 77 (numbered 0–76) |
| Sectors per track | 32 (numbered 0–31) |
| Raw bytes per sector | 137 |
| Usable data bytes per sector | 128 (9 bytes used for header/checksum/stop) |
| Total raw capacity | 77 × 32 × 137 = 337,568 bytes (~330 KB) |
| Total usable capacity | 77 × 32 × 128 = 315,392 bytes (~308 KB) |
| Data transfer rate | 250 Kbit/s (1 byte every 32 µs) |
| Rotation speed | 360 RPM (166.7 ms per revolution) |
| Sector timing | ~5.2 ms per sector (166.7 ms / 32) |
| Sectoring | **Hard-sectored** (32 sector holes + 1 index hole punched in media) |
| Required media | Hard-sectored 8" diskettes (Dysan #101, ITC #FD 32-100) |

### 5.25-Inch Minidisk (88-MDS)

The 88-MDS Minidisk controller uses the same register interface but with different geometry:

| Parameter | Value |
|-----------|-------|
| Tracks | 35 (numbered 0–34) |
| Sectors per track | 16 (numbered 0–15) |
| Raw bytes per sector | 137 |
| Total raw capacity | 35 × 16 × 137 = 76,720 bytes (~75 KB) |
| Directory track | Track 34 |

---

## I/O Port Map

The controller uses three consecutive I/O ports. The standard (default) base address is 08h.

| Port | Default Address | Read Function | Write Function |
|------|----------------|---------------|----------------|
| Port 1 | **08h** | Disk status register | Drive select / enable |
| Port 2 | **09h** | Sector position register | Disk command register |
| Port 3 | **0Ah** | Read data byte | Write data byte |

---

## Port 1 (Address 08h) — Status / Drive Select

### WRITE: Drive Select

Selects and enables one of up to 16 disk drives. Selecting a drive automatically deselects any previously selected drive.

```
Bit 7: Disable flag  — 1 = disable/deselect the drive, 0 = select and enable
Bit 6: unused
Bit 5: unused
Bit 4: unused
Bit 3: Drive number bit 3  ┐
Bit 2: Drive number bit 2  │ Drive index 0–15
Bit 1: Drive number bit 1  │
Bit 0: Drive number bit 0  ┘
```

**Examples:**
- `OUT 08h` with A = 00h → Select drive 0
- `OUT 08h` with A = 01h → Select drive 1
- `OUT 08h` with A = 80h → Deselect all drives (disable current drive)

### READ: Disk Status

Returns the current status of the selected drive and controller.

**IMPORTANT: Many status bits use ACTIVE-LOW logic (0 = true/active, 1 = false/inactive).**

```
Bit 7 (D7): NRDA — New Read Data Available
             0 = a data byte IS available for reading from Port 3
             1 = NO new data available (data from Port 3 would be invalid)
             
             Test pattern:  IN 08h / ORA A / JM wait  (sign bit = bit 7)
             When bit 7 = 0 (positive), data is ready.
             When bit 7 = 1 (negative/sign set), data is NOT ready.

Bit 6 (D6): TRK0 — Track 0 Indicator
             0 = head IS at track 0
             1 = head is NOT at track 0
             
             Test pattern:  IN 08h / ANI 40h / JNZ not_track0

Bit 5 (D5): INTE — Interrupt Enabled
             0 = interrupts ARE enabled
             1 = interrupts are disabled
             Always 0 (unused) in most configurations.

Bit 4 (D4): Unused — always 0

Bit 3 (D3): HEDLD — Head Loaded
             0 = head IS loaded (on disk surface)
             1 = head is NOT loaded
             
             NOTE: Some documentation shows this as bit 2. The actual
             bit assignment varies between manual revisions. The boot
             loader checks bit 3 (ANI 08h).

Bit 2 (D2): HD — Head Status
             0 = head positioning is valid; sector number reads are reliable
             1 = head positioning not valid
             
             Must be 0 before reading sector numbers from Port 2.

Bit 1 (D1): MVHD — Move Head
             0 = head movement is complete; OK to issue another step
             1 = head is currently moving; do NOT issue step commands
             
             Test pattern:  IN 08h / ANI 02h / JNZ wait_for_move
             MUST wait for this bit to be 0 before issuing Step In or Step Out.

Bit 0 (D0): ENWD — Enter New Write Data
             0 = controller is ready to accept a write byte on Port 3
             1 = NOT ready for write data (write would be ignored)
             
             Test pattern:  IN 08h / ANI 01h / JNZ wait_for_write
```

**Initial/reset value of status register: E7h (11100111b)**

This means on reset: no data available (D7=1), not on track 0 (D6=1), interrupts disabled (D5=1), head not loaded (D3=1, D2=1), head not moving (D1=1... varies), not ready for write (D0=1).

---

## Port 2 (Address 09h) — Sector Position / Commands

### READ: Sector Position

Returns the current sector number under the head. Only valid when the head is loaded (bit D2 of Port 1 = 0).

```
Bit 7 (D7): Unused — always 1
Bit 6 (D6): Unused — always 1
Bit 5 (D5): Sector number bit 4  ┐
Bit 4 (D4): Sector number bit 3  │
Bit 3 (D3): Sector number bit 2  │ Sector 0–31
Bit 2 (D2): Sector number bit 1  │
Bit 1 (D1): Sector number bit 0  ┘
Bit 0 (D0): Sector True
             0 = sector hole detected; head is at START of a sector
             1 = not at sector start; sector number in bits 1-5 is valid
```

**Reading the sector number:**
```asm
wait_sector:
    IN   09h          ; Read sector position register
    RAR               ; Shift bit 0 (Sector True) into Carry
    JC   wait_sector  ; If carry set, sector true active — wait
    ANI  1Fh          ; Mask to get sector number (bits 0-4 after shift)
    CPI  desired_sec  ; Compare with desired sector
    JNZ  wait_sector  ; Wrong sector, keep waiting
    ; Correct sector found — begin reading data
```

**Sector True timing:** The Sector True bit (D0) pulses LOW (0) for approximately **30 microseconds** each time a sector hole passes under the sensor. This marks the beginning of each sector's data area.

**Sector numbering:** Sectors are numbered 0 through 31 on the 8-inch format (0 through 15 on the 5.25-inch minidisk).

### WRITE: Disk Command Register

Each bit controls a different disk function. Multiple bits can be set simultaneously, but typically only one command is issued at a time.

```
Bit 7 (D7): Write Enable
             1 = begin write sequence (enable writing to disk)
             Sets sector offset to 0. Sets ENWD (Port 1 bit 0) to 0 (ready).
             Write enable persists until end of sector is reached.
             First and last bytes of a sector should have MSB (bit 7) set
             as a "sync bit" for sector identification.

Bit 6 (D6): Head Current Switch
             1 = switch to reduced write current (required for tracks 43–76)
             Set this bit when writing to outer tracks where reduced current
             is needed for reliable recording. Ignored on reads.

Bit 5 (D5): Interrupt Disable
             1 = disable disk controller interrupts
             When set, no interrupts will be generated.

Bit 4 (D4): Interrupt Enable
             1 = enable disk controller interrupts
             Interrupt fires on "Sector True" event (start of each sector).
             Generates RST instruction to CPU. Vector number set in hardware.
             Note: D5 and D4 are independent; D5 overrides D4.

Bit 3 (D3): Head Unload
             1 = remove head from disk surface
             After unloading, sector number reads become invalid.
             NRDA (Port 1 bit 7) goes to 1 (no data available).

Bit 2 (D2): Head Load
             1 = place head onto disk surface
             After loading, sector number reads become valid.
             Must be loaded before reading or writing data.
             Head load takes time — poll HEDLD status bit before proceeding.

Bit 1 (D1): Step Out
             1 = move head OUTWARD by one track (decrement track number)
             Moves toward track 0. Check MVHD (Port 1 bit 1) = 0 first.

Bit 0 (D0): Step In
             1 = move head INWARD by one track (increment track number)
             Moves toward track 76. Check MVHD (Port 1 bit 1) = 0 first.
```

**Command values quick reference:**

| Value | Command |
|-------|---------|
| 01h | Step In (toward track 76) |
| 02h | Step Out (toward track 0) |
| 04h | Head Load |
| 08h | Head Unload |
| 10h | Interrupt Enable |
| 20h | Interrupt Disable |
| 40h | Head Current Switch (for tracks 43–76 writes) |
| 80h | Write Enable |

---

## Port 3 (Address 0Ah) — Data Register

### READ: Read Data Byte

Returns the next byte of data from the current sector. Prerequisites:
1. A drive must be selected (Port 1 write)
2. Head must be loaded (Port 2 bit 2 = Head Load)
3. NRDA (Port 1 bit 7) must be 0 (data available)

Each read advances the position within the sector by one byte. After 137 reads, the sector is complete.

### WRITE: Write Data Byte

Writes a byte to the current sector position. Prerequisites:
1. A drive must be selected
2. Head must be loaded
3. Write Enable must be active (Port 2 bit 7)
4. ENWD (Port 1 bit 0) must be 0 (ready for write)

---

## Timing Constraints

### Critical: 32 Microsecond Byte Window

The disk delivers one byte every **32 microseconds**. At the 8080A's 2 MHz clock speed, this gives approximately **64 T-states** between bytes. This is extremely tight.

**Implication:** There is NOT enough time to check the NRDA status bit before every single byte read. The standard MITS approach reads **two bytes per NRDA check cycle**:

```asm
; Timing-critical read loop pattern (from MITS boot loader)
read_loop:
    IN   08h          ; 10 T-states: Read status
    ORA  A            ;  4 T-states: Test sign bit (NRDA)
    JM   read_loop    ; 10 T-states: If negative (bit 7=1), no data yet
    
    IN   0Ah          ; 10 T-states: Read first data byte
    MOV  M,A          ;  7 T-states: Store to memory
    INX  H            ;  6 T-states: Advance pointer
    DCR  E            ;  4 T-states: Decrement counter
    JZ   done         ; 10 T-states: Check if enough overhead read
    
    ; ~19 T-states between reads ≈ 9.5 µs — well under 32 µs
    
    DCR  E            ;  4 T-states: (second counter adjustment)
    IN   0Ah          ; 10 T-states: Read second data byte WITHOUT checking NRDA
    MOV  M,A          ;  7 T-states: Store to memory
    INX  H            ;  6 T-states: Advance pointer
    JNZ  read_loop    ; 10 T-states: Continue if more bytes
```

**Key insight:** The second IN 0Ah is done WITHOUT checking NRDA first. The instruction timing is carefully calibrated so that the gap between the two reads exceeds 32 µs, guaranteeing the next byte has arrived. **Do not add instructions to this inner loop** without recalculating timing.

### Timing Reference for Common 8080 Instructions

| Instruction | T-states |
|-------------|----------|
| IN port | 10 |
| OUT port | 10 |
| MOV r,r | 4 (5 for M) |
| MOV M,A | 7 |
| MOV A,M | 7 |
| MVI r,d8 | 7 (10 for M) |
| INX rp | 6 (does NOT affect flags) |
| DCR r | 4 (5 for M) |
| INR r | 4 (5 for M) |
| ORA A | 4 |
| ANI d8 | 7 |
| CPI d8 | 7 |
| JMP/JNZ/JZ/JC/JNC/JM/JP | 10 |
| CALL | 18 |
| RET | 10 |
| PUSH rp | 12 |
| POP rp | 10 |
| RAR/RAL/RRC/RLC | 4 |
| XRA A | 4 |
| CMP r | 4 (7 for M) |
| ADD r | 4 (7 for M) |

At 2 MHz: 1 T-state = 0.5 µs, so 32 µs = 64 T-states.

### Other Timing

- **Head load time**: Several hundred milliseconds. Must poll status before proceeding.
- **Step time**: Approximately 10-40 ms per step depending on drive. Must wait for MVHD to clear.
- **Sector True pulse**: ~30 µs active (0).
- **Motor spin-up**: Drive motors typically run continuously while disk is inserted.

---

## Disk Format: Sector Layout

All sectors are 137 bytes raw. The format of those 137 bytes differs based on the track type.

### System Tracks (Tracks 0–5)

Used for bootstrap code and the BASIC interpreter or CP/M system.

```
Byte    Content
────    ─────────────────────────────────────
  0     Track number OR'd with 80h (sync bit set on first byte)
 1-2    Number of bytes in boot file (16-bit, little-endian)
 3-130  Data (128 bytes of program/data)
 131    FFh — Stop Byte (marks end of data)
 132    Checksum of bytes 3 through 130
133-136 Not used (padding)
```

### Data Tracks (Tracks 6–76, except Track 70)

Used for file data storage by BASIC and Altair DOS.

```
Byte    Content
────    ─────────────────────────────────────
  0     Track number OR'd with 80h (sync bit)
  1     Skewed sector number = (Physical_Sector × 17) MOD 32
  2     File number from directory
  3     Data byte count (number of valid data bytes in 7-134)
  4     Checksum of bytes 2-3 and bytes 5-134
 5-6    Pointer to next data group (track, sector)
 7-134  Data (128 bytes)
 135    FFh — Stop Byte
 136    Not used
```

### Directory Track (Track 70)

Same structure as Data Tracks, but the 128-byte data field is divided into 8 directory entries of 16 bytes each:

```
Each 16-byte directory entry:
Bytes  0-10:  Filename (padded with spaces)
Byte   11:    File attributes / type
Bytes 12-15:  Written as 0 by MITS BASIC and DOS
              (Used as password field by Multiuser BASIC)
```

The first directory entry with FFh as its first byte is the **end-of-directory marker** ("directory stopper byte").

### Sector Skewing

Data tracks use a **software interleave** (skew factor) to improve performance:

```
Skewed_Sector = (Physical_Sector × 17) MOD 32
```

The skew factor of 17 gives the CPU time to process the data from one logical sector before the next logical sector rotates under the head.

The boot loader uses a simpler **2:1 interleave** for system tracks:
- Reads sectors in order: 0, 2, 4, 6, ..., 30, 1, 3, 5, ..., 31
- Implemented by incrementing sector number by 2, wrapping at 32

---

## Programming Procedures

### 1. Select a Drive

```asm
; Select drive 0
    MVI  A,00h        ; Drive 0, enable (bit 7 = 0)
    OUT  08h          ; Write to drive select port
```

### 2. Load the Head

```asm
; Load the head onto disk surface
    MVI  A,04h        ; Head Load command
    OUT  09h          ; Write to command register

; Wait for head to load
wait_head:
    IN   08h          ; Read status
    ANI  08h          ; Test HEDLD bit (bit 3)
    JNZ  wait_head    ; If not loaded (bit=1), wait
                      ; NOTE: Active-low! 0 = loaded.
                      ; If your hardware uses bit 2, use ANI 04h instead.
```

### 3. Seek to Track 0

```asm
; Step outward until track 0 is reached
seek_track0:
    IN   08h          ; Read status
    ANI  40h          ; Test TRK0 bit (bit 6)
    JZ   at_track0    ; If 0 (active low), we're at track 0
    
    ; Wait for head movement to complete
wait_move:
    IN   08h
    ANI  02h          ; Test MVHD bit (bit 1)
    JNZ  wait_move    ; If moving (bit=1), wait
    
    MVI  A,02h        ; Step Out command
    OUT  09h          ; Issue step
    JMP  seek_track0  ; Check again
    
at_track0:
    ; Head is now at track 0
```

### 4. Seek to a Specific Track

```asm
; Seek to track number in register B (assumes currently at track 0)
seek_track:
    MOV  A,B          ; A = desired track
    ORA  A            ; Is it track 0?
    RZ                ; If so, already there
    
step_loop:
    ; Wait for head movement to complete
wait_mv:
    IN   08h
    ANI  02h
    JNZ  wait_mv
    
    MVI  A,01h        ; Step In command
    OUT  09h          ; Issue step
    DCR  B            ; Decrement remaining tracks
    JNZ  step_loop    ; Continue stepping
    RET
```

### 5. Wait for a Specific Sector

```asm
; Wait for sector number in register B
wait_sector:
    IN   09h          ; Read sector position
    RAR               ; Shift Sector True (bit 0) into Carry
    JC   wait_sector  ; If Carry=1, sector true pulse — wait
    ANI  1Fh          ; Mask to sector number (5 bits)
    CMP  B            ; Compare with desired sector
    JNZ  wait_sector  ; Wrong sector — keep waiting
    ; Correct sector is now under the head
```

### 6. Read a Full Sector (137 bytes)

```asm
; HL = destination buffer address
; Read 137 bytes from current sector
; Must be called immediately after sector is found (timing critical)

read_sector:
    MVI  C,89h        ; 137 bytes to read (89h = 137)
    
read_byte:
    IN   08h          ; Read status
    ORA  A            ; Test NRDA (bit 7 / sign flag)
    JM   read_byte    ; If sign set (bit 7=1), no data yet
    
    IN   0Ah          ; Read data byte
    MOV  M,A          ; Store at [HL]
    INX  H            ; Advance pointer
    DCR  C            ; Decrement counter
    JNZ  read_byte    ; Loop for all 137 bytes
    RET
```

**WARNING:** The above simple loop checks NRDA before every byte, which may be too slow at 2 MHz for sustained reads. The MITS boot loader uses the two-bytes-per-check pattern shown in the Timing section. For production code, use the optimized pattern.

### 7. Read a Sector with Optimized Timing (Two-Byte Pattern)

```asm
; HL = destination buffer address
; E = byte count (e.g., 137 for full sector, or 128+overhead)
; This reads two bytes per NRDA check for reliable timing

read_fast:
    IN   08h          ; 10: Read status
    ORA  A            ;  4: Test NRDA
    JM   read_fast    ; 10: Loop if no data (24 T-states in loop)
    
    IN   0Ah          ; 10: Read byte 1
    MOV  M,A          ;  7: Store
    INX  H            ;  6: Advance
    DCR  E            ;  4: Count
    JZ   read_done    ; 10: Exit if done
    
    ; ~27 T-states gap ≈ 13.5 µs before second read
    ; Plus overhead above ≈ total > 32 µs since first byte
    
    DCR  E            ;  4: Adjust count for second byte
    IN   0Ah          ; 10: Read byte 2 (no NRDA check!)
    MOV  M,A          ;  7: Store
    INX  H            ;  6: Advance
    JNZ  read_fast    ; 10: Loop
    
read_done:
    RET
```

### 8. Write a Sector

```asm
; HL = source buffer address
; Write 137 bytes to current sector

write_sector:
    ; Enable writing
    MVI  A,80h        ; Write Enable
    OUT  09h          ; Issue command
    
    MVI  C,89h        ; 137 bytes
    
write_byte:
    IN   08h          ; Read status
    ANI  01h          ; Test ENWD (bit 0)
    JNZ  write_byte   ; If not ready (bit=1), wait
    
    MOV  A,M          ; Get byte from buffer
    OUT  0Ah          ; Write to disk
    INX  H            ; Advance pointer
    DCR  C            ; Decrement counter
    JNZ  write_byte   ; Loop for all bytes
    RET
```

**Note:** The first byte written to a sector should have bit 7 set (sync bit). The last byte (byte 136) should also have bit 7 set. These sync bits help identify sector boundaries when reading back.

### 9. Deselect Drive / Reset Controller

```asm
    MVI  A,80h        ; Disable flag set
    OUT  08h          ; Deselect all drives
```

---

## Complete Example: Read One Sector to Memory

```asm
; Read track T, sector S into memory at BUFFER
; 
T       EQU  0           ; Track number
S       EQU  0           ; Sector number
BUFFER  EQU  2000h       ; Destination address

        ; Initialize
        DI                ; Disable CPU interrupts
        LXI  SP,0FFFFh   ; Set stack
        
        ; Select drive 0
        XRA  A            ; A = 0
        OUT  08h          ; Select drive 0
        
        ; Load head
        MVI  A,04h        ; Head Load
        OUT  09h
        
        ; Wait for head load
whd:    IN   08h
        ANI  08h          ; Test head loaded (bit 3)
        JNZ  whd          ; Wait until loaded (0 = loaded)
        
        ; Seek to track 0 first
st0:    IN   08h
        ANI  40h          ; Track 0? (bit 6, active low)
        JZ   at0          ; Yes
wmv1:   IN   08h
        ANI  02h          ; Move complete? (bit 1)
        JNZ  wmv1         ; Wait
        MVI  A,02h        ; Step Out
        OUT  09h
        JMP  st0
        
at0:    ; Now step in to desired track
        MVI  B,T          ; Load track number
        MOV  A,B
        ORA  A
        JZ   trkok        ; Already at track 0 if T=0
        
stp:    ; Wait for move complete
wmv2:   IN   08h
        ANI  02h
        JNZ  wmv2
        MVI  A,01h        ; Step In
        OUT  09h
        DCR  B
        JNZ  stp

trkok:  ; Wait for desired sector
        MVI  B,S          ; Desired sector number
wsec:   IN   09h          ; Read sector position
        RAR               ; Sector True into carry
        JC   wsec         ; If set, wait
        ANI  1Fh          ; Mask sector number
        CMP  B            ; Is it our sector?
        JNZ  wsec         ; No, wait
        
        ; Read 137 bytes
        LXI  H,BUFFER     ; Destination
        MVI  C,89h        ; 137 bytes
        
rbyte:  IN   08h          ; Status
        ORA  A            ; NRDA check
        JM   rbyte        ; Wait for data
        IN   0Ah          ; Read byte
        MOV  M,A          ; Store
        INX  H            ; Next address
        DCR  C            ; Count down
        JNZ  rbyte        ; Loop
        
        ; Done — deselect drive
        MVI  A,80h
        OUT  08h
        HLT
```

---

## Error Handling Patterns

### Checksum Verification (System Tracks)

```asm
; After reading a system track sector into buffer at BUFFER:
; Bytes 3-130 are data, byte 132 is the expected checksum
; Checksum = sum of bytes 3 through 130, truncated to 8 bits

verify_checksum:
    LXI  H,BUFFER+3   ; Start of data
    MVI  C,80h        ; 128 bytes (3 through 130)
    XRA  A             ; Clear accumulator (running sum)
    
cksum_loop:
    ADD  M             ; Add byte to checksum
    INX  H             ; Next byte
    DCR  C
    JNZ  cksum_loop
    
    ; A now has computed checksum
    LXI  H,BUFFER+132 ; Expected checksum location
    CMP  M             ; Compare
    JNZ  checksum_err  ; Mismatch — read error
    ; Checksum OK
```

### Stop Byte Verification

```asm
    LXI  H,BUFFER+131 ; Stop byte location (system tracks)
    MVI  A,0FFh
    CMP  M
    JNZ  format_err    ; Stop byte missing — corrupt sector
```

### Retry Logic

The standard approach: retry reads up to 16 times before declaring failure.

```asm
    MVI  A,10h         ; 16 retries
retry_loop:
    PUSH PSW           ; Save retry count
    ; ... attempt read ...
    ; ... verify checksum ...
    JZ   read_ok       ; If checksum matches, success
    POP  PSW           ; Restore retry count
    DCR  A             ; Decrement
    JNZ  retry_loop    ; Try again
    ; All retries exhausted — fatal error
    JMP  error_handler
```

---

## Interrupt Support

The 88-DCDD can optionally generate interrupts on the "Sector True" event (when each sector begins). This is rarely used by MITS software but is available.

- **Enable:** Write 10h to Port 2 (set bit 4)
- **Disable:** Write 20h to Port 2 (set bit 5)
- **Vector:** The controller generates an RST instruction. The vector number (0–7) is configurable in hardware. Default is RST 7 (vector address 0038h).
- **Frequency:** One interrupt per sector = 32 interrupts per revolution = ~192 interrupts/second at 360 RPM.

```asm
; Enable disk interrupts
    MVI  A,10h        ; Interrupt Enable
    OUT  09h
    EI                ; Enable CPU interrupts
    
; In your ISR at the RST vector:
disk_isr:
    PUSH PSW
    ; Handle sector event...
    ; Read sector number, process data, etc.
    POP  PSW
    EI                ; Re-enable interrupts
    RET
```

---

## Programming Pitfalls and Common Mistakes

### 1. Active-Low Status Bits
Most status bits are **active low** (0 = condition true). This is counter-intuitive. Double-check every status test. The NRDA bit (bit 7) is particularly tricky:
- Use `ORA A` / `JM` to test (JM jumps when sign flag set, i.e., bit 7 = 1, meaning NO data)
- When bit 7 = 0, data IS available (positive result)

### 2. Not Waiting for Move Complete
**ALWAYS** wait for MVHD (Port 1, bit 1) to be 0 before issuing Step In or Step Out. Issuing a step while the head is still moving causes undefined behavior and potential data loss.

### 3. Exceeding the 32 µs Byte Window
Adding debug code, extra status checks, or conditional logic inside the inner read loop can cause the CPU to miss bytes. The disk does not wait — if you miss a byte, the data is gone. Count T-states carefully.

### 4. Forgetting Head Load
Data reads/writes are invalid unless the head is loaded. Always issue Head Load (04h to Port 2) and wait for confirmation before attempting data operations.

### 5. Not Checking Sector True Before Reading Sector Number
The sector number in Port 2 bits 1-5 is only valid when bit 0 (Sector True) is 1 (inactive). When Sector True is 0 (active), the sector hole is passing and the number is transitioning.

### 6. Track Position Tracking
The controller has **no track register**. The software must maintain its own track counter. The only absolute position reference is the TRK0 bit. Always home to track 0 first, then step inward to the desired track.

### 7. Write Current for Outer Tracks
When writing to tracks 43–76, set the Head Current Switch bit (bit 6 of Port 2) to ensure reliable recording at higher track densities.

### 8. Sync Bits on Write
When writing sector data, the first and last bytes should have their MSB (bit 7) set. This is the "sync bit" that helps the controller identify sector boundaries on read-back.

---

## Hardware Notes

### Drive Support
- **Pertec FD-400**: Original drive shipped with the Altair 8800. 8-inch, single-sided, single-density.
- **Shugart SA-800**: Compatible 8-inch drive. Can be connected directly via the FDC+ or with adapter cables.
- Up to **16 drives** can be daisy-chained on a single controller.

### Hard-Sectored Media
The original 88-DCDD requires **hard-sectored** diskettes with 32 sector holes plus 1 index hole physically punched into the media. The sector holes provide the timing reference for sector boundaries. Soft-sectored media will NOT work with the original controller (though the FDC+ replacement can generate virtual sector pulses).

### S-100 Bus
The controller occupies two card slots in the S-100 bus. The two boards are cross-cabled. One board handles the bus interface, the other handles drive communication. The controller has its own 8080 processor on the bus interface board that handles the serial-to-parallel conversion.

### Compatible Replacement Controllers
- **FDC+** (by Mike Douglas / deramp.com): Drop-in replacement. Single board. Supports both hard and soft-sectored media. Register-compatible with 88-DCDD.
- **Altair8800-IOBus disk controller**: ATmega328P-based emulator. Supports 88-DCDD and 88-MDS modes.
- **Various emulators** (SIMH, emuStudio, Altair-Duino): Software emulations with identical register interfaces.

---

## Register Quick Reference Card

```
╔══════════════════════════════════════════════════════════════════╗
║  PORT 1 (08h) WRITE — DRIVE SELECT                              ║
║  D7=disable  D3:D0=drive number (0-15)                          ║
║                                                                  ║
║  PORT 1 (08h) READ — STATUS  (most bits active LOW: 0=true)     ║
║  D7=NRDA(0=ready) D6=TRK0(0=yes) D5=INTE  D4=0                ║
║  D3=HEDLD(0=yes)  D2=HD         D1=MVHD(0=ok) D0=ENWD(0=ok)   ║
║                                                                  ║
║  PORT 2 (09h) WRITE — COMMANDS                                   ║
║  D7=WrEnable D6=HeadCurr D5=IntDis D4=IntEn                    ║
║  D3=HeadUnld D2=HeadLoad D1=StepOut D0=StepIn                  ║
║                                                                  ║
║  PORT 2 (09h) READ — SECTOR POSITION                             ║
║  D7=1 D6=1 D5:D1=sector(0-31) D0=SectorTrue(0=at start)       ║
║                                                                  ║
║  PORT 3 (0Ah) READ = read data byte                              ║
║  PORT 3 (0Ah) WRITE = write data byte                            ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## References

- MITS 88-DCDD Floppy Disk System Manual (deramp.com archives)
- MITS Technical Information sheet (1977 product specifications)
- emuStudio 88-DCDD emulator documentation (emustudio.net)
- Altair Floppy Disk Formats — ACOPY.ASM source commentary (retrocmp.de)
- FDC+ Enhanced Disk Controller Manual (deramp.com)
- Mini-Altair Version 3 documentation (88-DCDD timing analysis)
- Burcon CP/M 2.2 BIOS documentation (deramp.com)
- SIMH Altair8800 emulator source (altairz80_dsk.c)

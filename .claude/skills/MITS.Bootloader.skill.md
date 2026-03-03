# SKILL: Intel 8080 / MITS Altair 88-DCDD Disk Boot Loader

## Overview

This skill covers disassembly, modification, and reassembly of Intel 8080 machine code for the MITS Altair 8800 / IMSAI 8080 platform, specifically the **MITS Extended Disk BASIC boot loader** that runs on the **88-DCDD floppy disk controller**.

The code is distributed in **Intel HEX format** and targets the 8080 CPU (NOT Z80 — do not use Z80-only mnemonics or instructions).

---

## Intel HEX Format

Each line: `:LLAAAATT[DD...]CC`

| Field | Meaning |
|-------|---------|
| `:` | Start code |
| `LL` | Byte count (hex) |
| `AAAA` | 16-bit load address (big-endian) |
| `TT` | Record type: `00` = data, `01` = EOF |
| `DD...` | Data bytes |
| `CC` | Checksum (two's complement of sum of all bytes from LL through last DD) |

When generating Intel HEX output, always recompute checksums. The checksum is calculated as: `(0x100 - (sum of all bytes from LL to last DD) & 0xFF) & 0xFF`.

---

## Architecture: Intel 8080 CPU

### Registers
- **A** — 8-bit accumulator
- **B, C** — 8-bit, also used as 16-bit pair **BC**
- **D, E** — 8-bit, also used as 16-bit pair **DE**
- **H, L** — 8-bit, also used as 16-bit pair **HL** (primary memory pointer)
- **SP** — 16-bit stack pointer
- **PC** — 16-bit program counter
- **Flags** — Sign (S), Zero (Z), Auxiliary Carry (AC), Parity (P), Carry (CY)

### Key Differences from Z80
- No index registers (IX, IY)
- No alternate register set
- No relative jumps (JR)
- No block instructions (LDIR, etc.)
- No ED/CB/DD/FD prefix instructions
- Different mnemonics entirely (MOV not LD, MVI not LD, etc.)

### 8080 Instruction Set Summary

#### Data Transfer
| Opcode | Mnemonic | Bytes | Description |
|--------|----------|-------|-------------|
| 40-7F | MOV r,r | 1 | Move register to register (76h = HLT, not MOV M,M) |
| 06,0E,16,1E,26,2E,36,3E | MVI r,d8 | 2 | Move immediate to register |
| 01,11,21,31 | LXI rp,d16 | 3 | Load 16-bit immediate to register pair |
| 0A | LDAX B | 1 | Load A from address in BC |
| 1A | LDAX D | 1 | Load A from address in DE |
| 02 | STAX B | 1 | Store A to address in BC |
| 12 | STAX D | 1 | Store A to address in DE |
| 3A | LDA a16 | 3 | Load A from direct address |
| 32 | STA a16 | 3 | Store A to direct address |
| 2A | LHLD a16 | 3 | Load HL from direct address |
| 22 | SHLD a16 | 3 | Store HL to direct address |
| EB | XCHG | 1 | Exchange DE and HL |

#### Arithmetic/Logic
| Opcode | Mnemonic | Bytes | Description |
|--------|----------|-------|-------------|
| 80-87 | ADD r | 1 | Add register to A |
| 88-8F | ADC r | 1 | Add register to A with carry |
| 90-97 | SUB r | 1 | Subtract register from A |
| 98-9F | SBB r | 1 | Subtract register from A with borrow |
| A0-A7 | ANA r | 1 | AND register with A |
| A8-AF | XRA r | 1 | XOR register with A |
| B0-B7 | ORA r | 1 | OR register with A |
| B8-BF | CMP r | 1 | Compare register with A |
| C6 | ADI d8 | 2 | Add immediate to A |
| CE | ACI d8 | 2 | Add immediate to A with carry |
| D6 | SUI d8 | 2 | Subtract immediate from A |
| DE | SBI d8 | 2 | Subtract immediate from A with borrow |
| E6 | ANI d8 | 2 | AND immediate with A |
| EE | XRI d8 | 2 | XOR immediate with A |
| F6 | ORI d8 | 2 | OR immediate with A |
| FE | CPI d8 | 2 | Compare immediate with A |
| 04,0C,14,1C,24,2C,34,3C | INR r | 1 | Increment register |
| 05,0D,15,1D,25,2D,35,3D | DCR r | 1 | Decrement register |
| 09,19,29,39 | DAD rp | 1 | Add register pair to HL |

#### Rotate
| Opcode | Mnemonic | Bytes | Description |
|--------|----------|-------|-------------|
| 07 | RLC | 1 | Rotate A left circular |
| 0F | RRC | 1 | Rotate A right circular |
| 17 | RAL | 1 | Rotate A left through carry |
| 1F | RAR | 1 | Rotate A right through carry |

#### Branch
| Opcode | Mnemonic | Bytes | Description |
|--------|----------|-------|-------------|
| C3 | JMP a16 | 3 | Unconditional jump |
| C2/CA/D2/DA/E2/EA/F2/FA | Jcc a16 | 3 | Conditional jump (NZ/Z/NC/C/PO/PE/P/M) |
| CD | CALL a16 | 3 | Call subroutine |
| C4/CC/D4/DC/E4/EC/F4/FC | Ccc a16 | 3 | Conditional call |
| C9 | RET | 1 | Return from subroutine |
| C0/C8/D0/D8/E0/E8/F0/F8 | Rcc | 1 | Conditional return |
| C7/CF/D7/DF/E7/EF/F7/FF | RST n | 1 | Restart (call to n*8) |

#### Stack
| Opcode | Mnemonic | Bytes | Description |
|--------|----------|-------|-------------|
| C5/D5/E5/F5 | PUSH rp | 1 | Push register pair (F5 = PUSH PSW = push A + flags) |
| C1/D1/E1/F1 | POP rp | 1 | Pop register pair (F1 = POP PSW) |

#### I/O and Control
| Opcode | Mnemonic | Bytes | Description |
|--------|----------|-------|-------------|
| D3 | OUT d8 | 2 | Output A to port |
| DB | IN d8 | 2 | Input from port to A |
| FB | EI | 1 | Enable interrupts |
| F3 | DI | 1 | Disable interrupts |
| 00 | NOP | 1 | No operation |
| 76 | HLT | 1 | Halt CPU |
| 2F | CMA | 1 | Complement A (one's complement) |
| 37 | STC | 1 | Set carry flag |
| 3F | CMC | 1 | Complement carry flag |
| 27 | DAA | 1 | Decimal adjust A |

### Instruction Encoding Notes
- Register encoding in opcode bits: B=000, C=001, D=010, E=011, H=100, L=101, M=110 (memory via HL), A=111
- 16-bit immediates and addresses are stored **little-endian** (low byte first)
- Register pair encoding: BC=00, DE=01, HL=10, SP=11 (or PSW for PUSH/POP)

---

## Hardware: MITS 88-DCDD Floppy Disk Controller

### I/O Port Map

| Port | Read | Write |
|------|------|-------|
| **08h** | Disk status register | Disk select / control |
| **09h** | Sector position register | Disk command register |
| **0Ah** | Disk data register (read byte) | Disk data register (write byte) |

### Port 08h — Status Register (Read)

| Bit | Name | Meaning when SET (1) |
|-----|------|---------------------|
| 7 | NRDA | New Read Data Available (active high — 1 = data ready). Check with `ORA A` then `JM` (sign flag) |
| 6 | TRK0 | Head is at Track 0 |
| 5 | INT | Interrupt flag (active: 30µs after each sector true detect) |
| 4 | — | Not used |
| 3 | HEDLD | Head Loaded (1 = head is loaded onto disk surface) |
| 2 | HD | Head status |
| 1 | MVHD | Move Head (1 = head is currently moving / seek in progress). Wait for 0 before issuing new step |
| 0 | ENWD | Enter New Write Data (1 = ready to accept write byte) |

### Port 08h — Control Register (Write)

| Value | Effect |
|-------|--------|
| 00h | Deselect all / reset controller |
| 80h | Deselect drive (reset) |
| Other | Select drive (bit patterns select drive 0-3) |

### Port 09h — Sector Position Register (Read)

| Bit | Meaning |
|-----|---------|
| 0 | Sector True — 1 = sector hole just detected. When clear (0), bits 1-5 contain valid sector number |
| 1-5 | Current sector number (0-31) when bit 0 is 0 |
| 6-7 | Not used |

Read pattern: `IN 09h` / `RAR` / `JC loop` (if carry set, sector true is active, data not valid yet) / `ANI 1Fh` (mask sector number)

### Port 09h — Command Register (Write)

| Value | Command |
|-------|---------|
| 01h | Step In (toward higher tracks) |
| 02h | Step Out (toward track 0) |
| 04h | Head Load (engage head onto disk surface) |
| 08h | Head Unload |
| 10h | Enable interrupts |
| 20h | Disable interrupts |
| 40h | Head Current Switch |
| 80h | Write Enable |

### Port 0Ah — Data Register

- **Read**: Returns the next data byte from the current sector being read
- **Write**: Sends a byte to be written to the current sector

### Timing Critical Notes

- After issuing a step command (01h or 02h), you MUST wait for MVHD (bit 1 of port 08h) to clear before issuing another command
- Sector data must be read byte-by-byte as fast as the controller delivers it — there is no FIFO buffer
- The NRDA bit (bit 7 of port 08h) indicates when a new byte is available; check with `ORA A` / `JM` (tests sign flag)
- Sectors are 137 bytes raw on the Altair floppy (128 data bytes + header/checksum overhead)
- 32 sectors per track, numbered 0-31
- The disk spins continuously; you must wait for the desired sector to come around

---

## Other I/O Ports Used

### Serial I/O (SIO Board — 88-2SIO or similar)

| Port | Function |
|------|----------|
| 10h | SIO control / baud rate configuration |
| 11h | SIO data (channel A) |
| FFh | Sense switch input |
| 22h | Front panel / sense switch output |
| 23h | Front panel LED output (active low — write FFh to turn all off) |
| 01h | SIO data (alternate channel) |
| 05h | Additional output port |

---

## Boot Loader Structure and Memory Map

### ROM Layout (before relocation)

| Address Range | Content |
|---------------|---------|
| 0000h–0010h | Bootstrap stub (copies code to 6000h, jumps there) |
| 0013h–010Eh | Main loader code + subroutines (relocates to 6000h–60FBh) |
| 010Fh–0124h | Padding (NOPs) |
| 0125h–013Eh | Disk address / sector interleave translation table |
| 013Fh–01FFh | MITS Extended Disk BASIC keyword token table |

### Runtime Memory Map (after relocation)

| Address | Content |
|---------|---------|
| 0000h | Warm boot vector (written at boot completion) |
| 6000h | Main loader entry point (relocated from 0013h) |
| 60FCh | Sector staging buffer (raw sector data read here first) |
| 60FDh | DMA address storage (next load target) |
| 60FFh | Sector data buffer start (128 bytes copied from here to target) |
| 618Ah | Stack top (SP initialized here, grows downward) |

### Address Relocation

The bootstrap copies 252 (FCh) bytes from 0013h to 6000h. Therefore:

- **ROM address to runtime**: `runtime_addr = rom_addr + 0x5FED` (e.g., 0013h → 6000h)
- **Runtime to ROM address**: `rom_addr = runtime_addr - 0x5FED`

All JMP/CALL/Jcc targets within the main loader use **runtime addresses** (60xxh). When modifying code, ensure branch targets reference runtime addresses, not ROM addresses.

### Relocation Table for Key Routines

| ROM Addr | Runtime Addr | Function |
|----------|-------------|----------|
| 0013h | 6000h | Entry: DI + hardware init |
| 002Fh | 601Ch | Disk controller init |
| 003Dh | 602Ah | Seek to track 0 (via JMP 6038h) |
| 0040h | 602Dh | Wait for move complete |
| 0052h | 603Fh | Prepare sector read |
| 005Ah | 6047h | Sector read loop entry |
| 0066h | 6053h | Wait for sector header |
| 0072h | 605Fh | Read sector data bytes |
| 0088h | 6075h | Verify/copy sector data |
| 00ABh | 6098h | Advance to next sector |
| 00CEh | 60BBh | Step to next track |
| 00DCh | 60C9h | Error handler (cold restart) |
| 00E3h | 60D0h | Retry / cleanup path |
| 00E9h | 60D6h | Boot completion |
| 0109h | 60F6h | 16-bit compare subroutine (DE vs HL) |

---

## Boot Sequence Summary

1. **Bootstrap** (0000h): Copies loader from PROM to RAM at 6000h, jumps to 6000h
2. **Init** (6000h): Disables interrupts, clears front panel, configures SIO serial port, detects active SIO via sense switches, sets stack to 618Ah
3. **Disk init** (601Ch): Resets 88-DCDD controller, checks head load status, issues head load command if needed
4. **Seek track 0** (602Ah): Steps outward repeatedly until TRK0 bit (bit 6 of port 08h) is set
5. **Read loop** (6047h): For each sector:
   - Wait for correct sector number on port 09h (2:1 interleave — sectors increment by 2)
   - Read 137 raw bytes from port 0Ah into staging buffer at 60FCh
   - Copy 128 data bytes from 60FFh to target address
   - Verify memory write and accumulate checksum
   - Compare checksum with value stored on disk
   - On failure: retry up to 16 times, then cold restart from 0000h
6. **Track advance**: After reading all needed sectors on a track, step in and continue
7. **Boot complete** (60D6h): Write warm-boot vector to 0000h, deselect disk, re-enable interrupts, jump to loaded BASIC interpreter

---

## MITS Extended Disk BASIC Token Table

The token table at the end of the loader (013Fh–01FFh) uses the standard encoding where **bit 7 of the last character is set** to mark the end of each keyword.

### Decoding Algorithm

```
for each byte:
    if byte & 0x80:
        char = byte & 0x7F    # strip high bit
        emit char             # this is the last character of the token
        end_of_token()
    else:
        emit byte             # normal ASCII character
```

### Known Tokens in This Image

CONSOLE, CLOSE, COND, CLEAR, LOAD, SAVE, INT, SNG, DBL, VI, VS, VD, OS, HR$, ATA, IM, EFSTR, EFINT, EFSNG, EFDBL, SKO$, EF, ELETE (DELETE), ELECT (SELECT), SKI$, SKF, SKIN, ND

---

## Sector Interleave Scheme

The boot loader uses a **2:1 software interleave**:
- Sectors are read in order: 0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 1, 3, 5, ...
- Sector number is incremented by 2 (`INR B` / `INR B`)
- When sector ≥ 32 (`CPI 20h`), wraps to sector 1 and steps to next track
- This interleave gives the CPU time to process the previous sector before the next one rotates under the head

---

## Modification Guidelines

### When editing this code:

1. **Preserve the 252-byte copy size**: The bootstrap copies exactly FCh bytes. If the loader code grows, update the byte count at 0006h (the `MVI C,FCh` instruction).

2. **Maintain runtime address references**: All JMP/CALL/Jcc within the loader body use 60xxh addresses. If you insert or remove instructions, you must update ALL branch targets that reference addresses beyond the modification point.

3. **Recalculate Intel HEX checksums**: Every line of the output hex file needs a valid checksum. Sum all bytes from the count field through the last data byte, take two's complement.

4. **Do not use Z80 instructions**: This is an 8080 target. No JR, DJNZ, IX/IY, alternate registers, or CB/DD/ED/FD prefix opcodes.

5. **Respect timing constraints**: The sector read loop is timing-critical. The 8080 must read each byte from port 0Ah before the next byte arrives from the controller. Adding instructions inside the read loop may cause data overruns.

6. **Token table format**: If modifying the BASIC token table, remember that the last character of each keyword has bit 7 set (OR with 80h). The address table at 013Fh must point to the correct offsets of each token string.

7. **Stack usage**: SP is set to 618Ah. The sector read loop pushes up to 4 words (8 bytes) onto the stack. Ensure any modifications don't overflow the stack into the sector buffer area.

8. **Test with both the bootstrap and relocated copy**: The code must work both as a PROM image (loaded at 0000h) and after relocation to 6000h.

### Common Modifications

- **Change boot drive**: Modify the value written to port 08h during disk select
- **Change load address**: Modify the `LXI D,0000h` at 0052h
- **Change sector count**: Modify the `MVI B,08h` at 0055h
- **Change retry count**: Modify the `MVI A,10h` at 005Ah (currently 16 retries)
- **Change baud rate**: Modify the `MVI A,2Ch` at 001Ah and `MVI A,03h` at 001Eh
- **Add/remove BASIC tokens**: Edit the token string data at 0185h+ and update the address table at 013Fh+

---

## Assembler Syntax Notes

This project uses **Intel 8080 assembler syntax** (not Zilog Z80 syntax):

| 8080 Syntax | Z80 Equivalent | Meaning |
|-------------|---------------|---------|
| MOV A,B | LD A,B | Copy B to A |
| MVI A,42h | LD A,42h | Load immediate |
| LXI H,1234h | LD HL,1234h | Load 16-bit immediate |
| LDA 1234h | LD A,(1234h) | Load from memory |
| STA 1234h | LD (1234h),A | Store to memory |
| LDAX D | LD A,(DE) | Load via DE |
| STAX D | LD (DE),A | Store via DE |
| LHLD 1234h | LD HL,(1234h) | Load HL from memory |
| SHLD 1234h | LD (1234h),HL | Store HL to memory |
| INR A | INC A | Increment |
| DCR A | DEC A | Decrement |
| INX H | INC HL | Increment pair |
| DCX H | DEC HL | Decrement pair |
| DAD D | ADD HL,DE | 16-bit add |
| CMA | CPL | Complement A |
| ANI 0Fh | AND 0Fh | AND immediate |
| ORI 80h | OR 80h | OR immediate |
| XRI FFh | XOR FFh | XOR immediate |
| CPI 20h | CP 20h | Compare immediate |
| JMP addr | JP addr | Unconditional jump |
| JNZ addr | JP NZ,addr | Jump if not zero |
| JZ addr | JP Z,addr | Jump if zero |
| JC addr | JP C,addr | Jump if carry |
| JNC addr | JP NC,addr | Jump if no carry |
| JM addr | JP M,addr | Jump if minus (sign set) |
| JP addr | JP P,addr | Jump if plus (**NOTE**: JP means "Jump if Positive" in 8080!) |
| CALL addr | CALL addr | Call subroutine |
| RET | RET | Return |
| PUSH B | PUSH BC | Push register pair |
| POP B | POP BC | Pop register pair |
| PUSH PSW | PUSH AF | Push A + flags |
| POP PSW | POP AF | Pop A + flags |
| IN port | IN A,(port) | Input from port |
| OUT port | OUT (port),A | Output to port |
| XCHG | EX DE,HL | Exchange DE and HL |
| PCHL | JP (HL) | Jump to address in HL |
| SPHL | LD SP,HL | Load SP from HL |
| XTHL | EX (SP),HL | Exchange HL with top of stack |
| RLC | RLCA | Rotate left circular |
| RRC | RRCA | Rotate right circular |
| RAL | RLA | Rotate left through carry |
| RAR | RRA | Rotate right through carry |
| RST n | RST n*8 | Restart |

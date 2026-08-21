# SKILL: Configuring the 88-2SIOJP Board for ROM-Resident Monitor Boot

## Overview

The 88-2SIOJP ("Dual Serial Port with Jump-Start and PROM") is a modern
S-100 board (by Martin Eberhard) that combines two serial ports with
an EPROM/EEPROM socket and a hardware "Jump-Start" reset-vector
redirect. It is the board this project targets for burning JX Monitor
into a real EPROM and booting it on physical Altair/IMSAI-class
hardware without needing any code to live at address 0000H.

Three things on this board matter for JX Monitor's `BIOS_BASE`/`DATA_BASE`
build options:

1. **Serial ports** — built around a Motorola 68A50/68B50 ACIA, the
   same chip and register layout as the MITS Altair 88-2SIO (NOT the
   IMSAI SIO2's 8251). See `MITS-88-2SIO.skill.md` for status-bit
   details; use the `SIO_6850=1` profile, not `SIO_8251=1`.
2. **EPROM/EEPROM socket** — holds the monitor's ROM image. Its base
   address is jumper/switch-selected and must be aligned to the
   EPROM's own size.
3. **Jump-Start** — forces the CPU to jump to the EPROM's base address
   on reset, so the monitor never needs to occupy address 0000H.

---

## EPROM Socket (SW4) — Address Alignment

The socket accepts 2716 (2K), 2732 (4K), 2764 (8K), or 27128 (16K)
EPROMs (also 2816A/28C64 EEPROMs). SW4 sets the chip type and its
base address; the base must be aligned to the chip's own size:

| EPROM | Size | Base address alignment | Valid bases |
|-------|------|------------------------|-------------|
| 2716  | 2K   | 2K (0800H)  | 0000, 0800, 1000, ... F800H |
| 2732  | 4K   | 4K (1000H)  | 0000, 1000, 2000, ... F000H |
| 2764  | 8K   | 8K (2000H)  | 0000, 2000, 4000, 6000, 8000, A000, C000, E000H |
| 27128 | 16K  | 16K (4000H) | 0000, 4000, 8000, C000H |

JX Monitor's `config.mk.rom` targets a **2764 (8K)**, so `BIOS_BASE`
must be one of the eight 8K-aligned addresses above. The monitor's
code (`BIOS_BASE` to `CODE_END`) must fit within that 8K window.

---

## Jump-Start (SW1 + SW3) — Reset-Vector Redirect

When enabled, the board forces a `JMP <addr>` (3 bytes: `C3h` + low +
high address byte) onto the bus for the CPU's first three machine
cycles after reset — the CPU never actually fetches real memory at
0000H during this. This is what lets `BIOS_BASE > 0` work on real
hardware without any code at address 0000H at all.

- **SW1 positions 1–8** set the Jump-Start address's **high byte**
  only; the low byte is always `00h`. So the Jump-Start target is
  always a 256-byte page boundary — set SW1 to `BIOS_BASE`'s high
  byte. Since a 2764's valid bases are already 8K-aligned (and
  therefore page-aligned), the Jump-Start target is simply
  `BIOS_BASE` itself.
- **SW1 position 9 ("JS")** enables Jump-Start.
- **SW3 position 7 ("SD")** or **position 8 ("PH")** must also be
  enabled — Jump-Start requires the board to disable other memory at
  address 0000H for those 3 cycles (via blocking the SMEMR status
  signal, or via the S-100 PHANTOM signal) so no other RAM board
  drives conflicting data onto the bus. Either is fine; SD works with
  virtually all MITS-era memory boards, PH requires PHANTOM support.

### Worked example: `config.mk.rom` (BIOS_BASE=0A000H)

| Switch | Setting |
|--------|---------|
| SW4 (EPROM address/type) | 8K (2764), base A000H |
| SW1 positions 1–8 (Jump-Start address = high byte `A0h`) | 1-5 Closed, 6 Open, 7 Closed, 8 Open (derived below) |
| SW1 position 9 (JS) | Closed (enabled) |
| SW3 position 7 (SD) or 8 (PH) | Closed (enabled) |

For SW1, a closed switch = 0, open = 1, switch 1 = lowest bit (A8),
switch 8 = highest bit (A15). `A000H`'s high byte is `A0h` = binary
`1010 0000`, so bits A8..A15 = `0,0,0,0,0,1,0,1` → SW1 positions
1-5 closed, 6 open, 7 closed, 8 open.

If you change `BIOS_BASE` in `config.mk.rom`, recompute SW1/SW4 for
the new address the same way.

---

## Why the monitor needs a `DATA_BASE` split for this board

The EPROM (or EEPROM without a write cycle) is read-only during normal
execution ("EPROM Address Overlay" — while enabled, the CPU reads the
EPROM instead of any other memory at the same address, but writes are
not blocked and go to whatever RAM shares that address, not to the
visible code). JX Monitor therefore keeps all mutable state (cursor
position, command buffer, detected memory size, etc.) in a separate
RAM segment at `DATA_BASE` (default `0100H`), never in the
`BIOS_BASE`..`CODE_END` code range. See `DESIGN.md` section 3.2.

---

## Testing without the hardware: `SIM_STUB`

z80pack's `cpmsim` has no equivalent of Jump-Start — it always starts
execution at `PC=0000H`. `config.mk.sim.rom` sets `SIM_STUB=1`, which
assembles a `JMP BOOT` at address 0000H purely so the relocated build
can be exercised under the simulator. Do not set `SIM_STUB=1` when
building the hex file you intend to actually burn into an EPROM — real
hardware relies on Jump-Start instead, and this stub occupies part of
page zero that `INIT_PAGE0` also writes to at runtime.

---

## References

- Manual: *88-2SIOJP Dual Serial Port with Jump-Start and PROM User's
  Guide*, Rev H, by Martin Eberhard (11 Feb 2024) — sections "EPROMs
  and EEPROMs", "Jump-Start", and "System Memory Disable".
- `MITS-88-2SIO.skill.md` — serial port register/status-bit details
  (shared 6850 ACIA behavior).

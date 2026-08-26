# JX Monitor — Development Effort Analysis

## Project Summary

**JX Monitor** — A machine-language monitor + Altair BASIC interpreter for Intel 8080, written in pure 8080 assembly. Targets Altair/IMSAI hardware and z80pack simulator. Includes dual serial/video output, multiple UART drivers, disk boot, and a comprehensive test suite.

## Codebase Metrics

| Category | Files | Lines |
|---|---|---|
| 8080 Assembly (core) | 15 | 11,882 |
| Build system (Makefile + configs) | 10 | 1,283 |
| Test harnesses (Expect + shell) | 13 | 947 |
| Scripts (JS + Python) | 3 | 1,190 |
| Documentation | 6 | 1,102 |
| **Total** | **52** | **~16,600** |

Plus ~8,700 lines of deleted code from the v0.1–0.2 CP/M architecture that was scrapped and rewritten.

---

## Time Estimate by Component

| Component | Lines | Difficulty | Est. Hours | Rationale |
|---|---|---|---|---|
| **Monitor core** (monitor, bios, serial, video, print, string libs) | ~2,500 | High | 80–125 | Hand-written 8080 asm at ~20–30 debugged lines/hr. Command parser, hex dump, memory test, Intel HEX loader, I/O port commands, VDM-1 video driver with software scroll. |
| **BASIC integration** (4K + 8K editions) | ~8,500 | Very High | 100–160 | Porting from original listing format to z80asm syntax. Reverse-engineering and patching 12 floating-point routines for 8080 MOV flag bug. Two editions with standalone + loadable entry points. |
| **Build system** | ~1,300 | Medium | 20–30 | Sophisticated Makefile with conditional assembly, 10 config variants for 3 UART chips, multiple build targets (monitor, BASIC standalone, BASIC loadable, disk image). |
| **Tooling scripts** | ~1,190 | Medium | 20–30 | `create-boot-disk.js` (380 lines, disk image creation), `convert-basic-lst.py` (465 lines, BASIC listing conversion), `extract-boot-hex.js`. |
| **Test suite** | ~950 | Medium | 15–25 | 11 Expect-based test scripts + harness + build matrix testing across configurations. |
| **Documentation** | ~1,100 | Low–Med | 15–25 | Design spec, build system reference, toolchain reference, z80asm bugs document. |
| **Scrapped v0.1–0.2 work** | ~8,700 (deleted) | High | 40–60 | CP/M-style architecture with BDOS, BIOS, SDCC C compiler support — all abandoned in the v0.3 rewrite. This is real work that produced no surviving code. |
| **Research & debugging overhead** | — | — | 40–80 | Learning z80asm quirks (documented in Z80ASM_BUGS.md), debugging hardware-specific issues across 3 UART chips, understanding vintage floating-point internals, resolving 8080-vs-Z80 flag differences. |

---

## Difficulty Multipliers

Several factors make this project significantly harder than typical software:

1. **8080 assembly** — No compiler, no debugger with breakpoints, no type system. Every operation is manual register/flag/stack management. Industry rule of thumb: assembly is 3–5x slower to write than equivalent C.

2. **Vintage hardware expertise** — Requires deep knowledge of Intel 8251 USART, Motorola 6850 ACIA, VDM-1 memory-mapped video, S-100 bus conventions, and 8080 flag behavior quirks.

3. **The floating-point bug hunt** — Finding that `MOV` instructions set flags differently on 8080 vs Z80, then tracing the corruption through 12 FP routines in a 40-year-old BASIC interpreter, is grueling reverse-engineering work.

4. **Architectural dead end** — The full CP/M-style architecture (v0.1–0.2) was built and then scrapped. An average developer would lose 1–2 weeks here.

---

## Final Estimate

| Scenario | Hours | Calendar (full-time) | Calendar (hobby, ~4 hr/day) |
|---|---|---|---|
| **Experienced 8080 developer** | 330–430 | 8–11 weeks | 4–5 months |
| **Average programmer** (knows asm, not 8080) | 450–600 | 11–15 weeks | 5–7 months |
| **Average programmer** (no asm background) | 700–1,000 | 17–25 weeks | 8–12 months |

## Comparison to Actual Timeline

The git history spans **40 calendar days** (Jan 22 – Mar 3, 2026) with 23 commits from a single author. At hobby-project intensity (~4–6 hrs/day), that's roughly **160–240 hours of effort** — well below even the experienced-developer estimate of 330–430 hours. This suggests the developer either has deep domain expertise, had significant AI-assisted acceleration, or both.

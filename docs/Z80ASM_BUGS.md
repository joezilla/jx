# z80asm Version 2.1 Known Bugs

This document describes critical bugs discovered in z80asm version 2.1 from z80pack that prevent the BDOS from assembling correctly.

## Bug Summary

z80asm 2.1 has severe symbol handling bugs that cause spurious "multiple defined symbol" errors even when symbols are only defined once.

## Bug #1: Symbol Names Starting with "BIOS_"

**Symptom**: When multiple EQU statements or labels use symbol names starting with "BIOS_", the assembler reports "multiple defined symbol" errors starting from the second such symbol.

**Example**:
```asm
        ORG     0F500H

BIOS_CONST      EQU     0FD06H        ; OK
BIOS_CONIN      EQU     0FD09H        ; ERROR: multiple defined symbol
BIOS_CONOUT     EQU     0FD0CH        ; ERROR: multiple defined symbol
```

**Workaround**: Rename symbols to not start with "BIOS_"

## Bug #2: Symbol Names Starting with "BJMP_"

**Symptom**: Similar to Bug #1, symbols starting with "BJMP_" also trigger the error.

**Example**:
```asm
        ORG     0F500H

BJMP_CONST      EQU     0FD06H        ; OK
BJMP_CONIN      EQU     0FD09H        ; ERROR: multiple defined symbol
```

**Workaround**: Use different naming convention

## Bug #3: Labels Starting with "F_"

**Symptom**: Labels (with colons) starting with "F_" followed by multiple words separated by underscores trigger the error.

**Example**:
```asm
F_RAWIO_IN:                           ; OK
F_RAWIO_NONE:                         ; ERROR: multiple defined symbol
F_RAWIO_STAT:                         ; ERROR: multiple defined symbol
```

**Workaround**: Remove underscores or use different prefix

## Bug #4: Inline Comments on EQU Statements (Secondary Factor)

**Symptom**: When EQU statements have inline comments (after the value), it exacerbates the symbol definition bugs.

**Example**:
```asm
SYMBOL1         EQU     0100H  ; Comment 1    ; OK
SYMBOL2         EQU     0200H  ; Comment 2    ; May trigger error
```

**Workaround**: Move comments to separate lines above the EQU

## Impact on JX BDOS

The BDOS uses symbols like:
- `BIOS_CONST`, `BIOS_CONIN`, `BIOS_CONOUT`, `BIOS_LIST`
- Labels like `F_RAWIO_NONE`, `F_READLN_LOOP`, etc.

These trigger z80asm 2.1 bugs and prevent assembly.

## Resolution

### Option 1: Rename All Conflicting Symbols

Systematically rename all symbols to avoid the buggy patterns:
- BIOS_CONST → BIOSC
- BIOS_CONIN → BIOSI
- BIOS_CONOUT → BIOO
- BIOS_LIST → BIOSL
- F_RAWIO_NONE → FRAWIONONE
- etc.

### Option 2: Use Different Assembler

The SDCC toolchain includes its own Z80 assembler (sdasz80) which may not have these bugs.

### Option 3: Upgrade z80pack

Check if newer versions of z80pack have fixed these bugs.

### Option 4: Use Conditional Directives Workaround

The original BDOS used IFNDEF/IFDEF directives which z80asm 2.1 also doesn't support. Defining values directly in the file avoids command-line -d flags but still triggers the symbol bugs.

## Status

As of 2026-01-29:
- **Conditional directives**: Removed from BDOS (IFNDEF/IFDEF/ENDIF eliminated)
- **Symbol bugs**: Partially worked around (BIOS_ → BIOSC/BIOSI/etc.)
- **Label bugs**: Still present (F_ labels need renaming)
- **BDOS assembly**: Still fails with 5 errors due to z80asm bugs

## Recommendations

1. **Short term**: Manually rename all conflicting symbols/labels in BDOS
2. **Medium term**: Test with newer z80asm versions or alternative assemblers
3. **Long term**: Consider switching to a more robust assembler toolchain

## Test Cases

Minimal test cases to reproduce each bug are available in the repository root:
- `test_bios_names.asm` - Demonstrates BIOS_ bug
- `test_bjmp.asm` - Demonstrates BJMP_ bug
- `test_with_comments.asm` - Demonstrates inline comment bug

## Related Issues

- BIOS assembles successfully because it doesn't use these symbol patterns
- C programs (via SDCC) are unaffected
- Only affects assembly files with these specific naming patterns

---

*Last Updated: 2026-01-29*
*JX Operating System - z80asm Bug Documentation*

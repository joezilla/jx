#!/usr/bin/env python3
"""
Convert Altair BASIC 3.2 listing (altair_basic.lst) to z80asm source.

Parses the zasm listing format and outputs z80asm-compatible 8080 assembly.
Also extracts expected hex bytes for binary verification.

Usage:
    python3 scripts/convert-basic-lst.py altair_basic/altair_basic.lst \
        -o src/basic/altair_basic.asm \
        --hex build/expected.hex
"""

import re
import sys
import argparse


# Labels to rename (avoid conflicts with assembler -d defines)
LABEL_RENAMES = {
    'STACK_TOP': 'BAS_STKTOP',
}


def parse_line(line):
    """Parse a single listing line.

    Returns: (addr, hex_bytes_str, label, mnemonic, comment) or None for skip.
    addr: int or None
    hex_bytes_str: raw hex string (no dots/spaces) or None
    label: string or None
    mnemonic: string or None
    comment: string or None
    """
    line = line.rstrip('\r\n')

    # Try to match address prefix: "NNNN: "
    addr_match = re.match(r'^([0-9A-Fa-f]{4}): (.*)$', line)

    if addr_match:
        addr = int(addr_match.group(1), 16)
        rest = addr_match.group(2)

        # Find the first tab - separates hex field from label/mnemonic area
        tab_pos = rest.find('\t')
        if tab_pos == -1:
            # No tab after hex - unusual line, treat as data only
            hex_field = rest.strip().replace('.', '').replace(' ', '')
            return (addr, hex_field if hex_field else None, None, None, None)

        # Extract hex bytes from the field before the first tab
        hex_field = rest[:tab_pos].strip().replace(' ', '')
        # Handle "00..." notation (repeating bytes marker)
        hex_clean = hex_field.replace('.', '')

        # Everything after the first tab is the label/mnemonic/comment area
        fields_str = rest[tab_pos + 1:]

        # Split by tabs
        fields = fields_str.split('\t')

        # First field is the label
        label = fields[0].strip() if fields else ''

        # Remaining fields: join non-comment parts as mnemonic,
        # anything starting with ';' begins the comment.
        # Also handle inline comments within a field (e.g., "DB 013Ah ;LXI B,..")
        mnemonic_parts = []
        comment_parts = []
        in_comment = False
        for f in fields[1:]:
            fs = f.strip()
            if not fs:
                continue
            if fs.startswith(';') or in_comment:
                comment_parts.append(fs)
                in_comment = True
            else:
                # Check for inline comment: "mnemonic ;comment" within one field
                semi_pos = fs.find(' ;')
                if semi_pos >= 0:
                    mnemonic_parts.append(fs[:semi_pos].strip())
                    comment_parts.append(fs[semi_pos + 1:].strip())
                    in_comment = True
                else:
                    mnemonic_parts.append(fs)

        mnemonic = ' '.join(mnemonic_parts).strip()
        comment = ' '.join(comment_parts).strip()

        # Detect continuation lines: has hex but no label and no mnemonic
        if hex_clean and not label and not mnemonic:
            return (addr, hex_clean, None, '__continuation__', None)

        return (addr, hex_clean if hex_clean else None,
                label if label else None,
                mnemonic if mnemonic else None,
                comment if comment else None)

    # No address - check for comment/directive line
    # Format: "              \t..." (spaces then tab)
    stripped = line.strip()
    if not stripped:
        return (None, None, None, None, None)  # blank line

    # Check for tab-indented content (comment or standalone text)
    tab_match = re.match(r'^[ \t]+(.*)$', line)
    if tab_match:
        content = tab_match.group(1).strip()
        if content.startswith(';'):
            return (None, None, None, None, content)
        elif content:
            return (None, None, None, None, '; ' + content)

    # Standalone text line (header/footer)
    if stripped.startswith(';'):
        return (None, None, None, None, stripped)

    return (None, None, None, None, '; ' + stripped)


def convert_hex_value(val_str):
    """Convert a single hex value to z80asm Intel hex format.
    '0x3A' -> '03AH'
    'C4H' -> '0C4H'
    '80h' -> '80H'
    """
    val_str = val_str.strip()

    if val_str.lower().startswith('0x'):
        hex_val = val_str[2:].upper()
        if hex_val and hex_val[0] in 'ABCDEF':
            return '0' + hex_val + 'H'
        return hex_val + 'H'

    if val_str.lower().endswith('h'):
        hex_val = val_str[:-1].upper()
        if hex_val and hex_val[0] in 'ABCDEF':
            return '0' + hex_val + 'H'
        return hex_val + 'H'

    return val_str


def split_multibyte_db(hex_literal):
    """Split a multi-byte hex literal into individual bytes for DB.
    '454EC4h' -> '45H,4EH,0C4H'
    '013Ah' -> '01H,3AH'
    """
    val = hex_literal.strip()

    if val.lower().endswith('h'):
        hex_str = val[:-1].upper()
    elif val.lower().startswith('0x'):
        hex_str = val[2:].upper()
    else:
        return convert_hex_value(val)

    # Pad to even length
    if len(hex_str) % 2 != 0:
        hex_str = '0' + hex_str

    if len(hex_str) <= 2:
        # Single byte - just format it
        if hex_str[0] in 'ABCDEF':
            return '0' + hex_str + 'H'
        return hex_str + 'H'

    # Multi-byte - split into individual bytes
    bytes_list = []
    for i in range(0, len(hex_str), 2):
        byte_hex = hex_str[i:i+2]
        if byte_hex[0] in 'ABCDEF':
            bytes_list.append('0' + byte_hex + 'H')
        else:
            bytes_list.append(byte_hex + 'H')

    return ','.join(bytes_list)


def convert_db_operand(operand_str):
    """Convert DB operand(s) to z80asm format.
    Handles: hex literals, 0x format, character literals, comma-separated.
    """
    parts = []
    # Split by comma, but be careful with quoted strings
    current = ''
    in_quote = False
    quote_char = None

    for ch in operand_str:
        if ch in ("'", '"') and not in_quote:
            in_quote = True
            quote_char = ch
            current += ch
        elif ch == quote_char and in_quote:
            in_quote = False
            current += ch
        elif ch == ',' and not in_quote:
            parts.append(current.strip())
            current = ''
        else:
            current += ch
    if current.strip():
        parts.append(current.strip())

    result = []
    for part in parts:
        part = part.strip()
        if not part:
            continue

        # Character literal: 'X' or ','
        if (part.startswith("'") and part.endswith("'")) or \
           (part.startswith('"') and part.endswith('"')):
            result.append(part)
            continue

        # Hex literal (potentially multi-byte)
        if part.lower().endswith('h') or part.lower().startswith('0x'):
            result.append(split_multibyte_db(part))
            continue

        # Decimal or other
        result.append(part)

    return ','.join(result)


def convert_operand(operand_str):
    """Convert operand hex values to z80asm format.
    Handles 0xNN -> NNH and lowercase h -> H.
    """
    # Replace 0xNN with NNH
    def replace_0x(m):
        hex_val = m.group(1).upper()
        if hex_val[0] in 'ABCDEF':
            return '0' + hex_val + 'H'
        return hex_val + 'H'

    result = re.sub(r'0x([0-9A-Fa-f]+)', replace_0x, operand_str)

    # Replace NNNNh with NNNNH (fix case, add leading zero if needed)
    def replace_h(m):
        hex_val = m.group(1).upper()
        if hex_val[0] in 'ABCDEF':
            return '0' + hex_val + 'H'
        return hex_val + 'H'

    result = re.sub(r'\b([0-9A-Fa-f]+)h\b', replace_h, result)

    return result


def convert_mnemonic(mnemonic):
    """Convert a mnemonic string to z80asm format."""
    if not mnemonic:
        return ''

    # Handle DB: split multi-byte hex literals
    m = re.match(r'^(DB)\s+(.+)$', mnemonic, re.IGNORECASE)
    if m:
        return 'DB ' + convert_db_operand(m.group(2))

    # Handle DW: convert hex values
    m = re.match(r'^(DW|DS)\s+(.+)$', mnemonic, re.IGNORECASE)
    if m:
        return m.group(1).upper() + ' ' + convert_operand(m.group(2))

    # Handle ORG
    m = re.match(r'^(ORG)\s+(.+)$', mnemonic, re.IGNORECASE)
    if m:
        return 'ORG ' + convert_operand(m.group(2))

    # General instruction: convert operand hex
    parts = mnemonic.split(None, 1)
    if len(parts) == 1:
        return mnemonic

    return parts[0] + ' ' + convert_operand(parts[1])


def apply_renames(text):
    """Apply label renames to a text string."""
    for old, new in LABEL_RENAMES.items():
        text = re.sub(r'\b' + re.escape(old) + r'\b', new, text)
    return text


def generate_asm(parsed_lines):
    """Generate z80asm source from parsed listing data."""
    output = []
    output.append(';' + '=' * 60)
    output.append('; Altair BASIC 3.2 (4K) - Converted from annotated listing')
    output.append('; Auto-generated by convert-basic-lst.py')
    output.append(';')
    output.append('; Copyright 1975, Bill Gates, Paul Allen, Monte Davidoff')
    output.append('; Source: http://altairbasic.org/')
    output.append(';' + '=' * 60)
    output.append('')

    prev_blank = True  # Start with "blank" to avoid double-blank at top

    for addr, hex_str, label, mnemonic, comment in parsed_lines:
        # Skip continuation lines
        if mnemonic == '__continuation__':
            continue

        # Blank line
        if addr is None and label is None and mnemonic is None and comment is None:
            if not prev_blank:
                output.append('')
                prev_blank = True
            continue

        # Comment-only line (no address, no mnemonic)
        if addr is None and mnemonic is None and comment:
            # Skip the original file header (zasm metadata)
            if 'zasm:' in comment or 'opts:' in comment or \
               'date:' in comment or '------' in comment:
                continue
            output.append(apply_renames(comment))
            prev_blank = False
            continue

        prev_blank = False

        # Convert mnemonic
        mn = ''
        if mnemonic:
            mn = apply_renames(convert_mnemonic(mnemonic))

        # Convert label
        lbl = ''
        if label:
            lbl = apply_renames(label)

        # Convert comment
        cmt = ''
        if comment:
            cmt = apply_renames(comment)
            if not cmt.startswith(';'):
                cmt = ';' + cmt

        # Format output line
        if lbl and mn:
            # Label + mnemonic on same line (if label is short enough)
            if len(lbl) < 8:
                line = lbl + ' ' * (8 - len(lbl)) + mn
            else:
                # Long label: put mnemonic on next line
                line = lbl + '\n        ' + mn
            if cmt:
                line += '\t' + cmt
        elif lbl and not mn:
            # Label only (shouldn't happen much, but handle it)
            line = lbl + ':'
            if cmt:
                line += '\t' + cmt
        elif mn:
            # Mnemonic only (no label)
            line = '        ' + mn
            if cmt:
                line += '\t' + cmt
        elif cmt:
            # Comment only (with address)
            line = '        ' + cmt
        else:
            line = ''

        output.append(line)

    return '\n'.join(output) + '\n'


def extract_hex_bytes(parsed_lines):
    """Extract address -> byte mapping from parsed listing."""
    hex_map = {}
    for addr, hex_str, label, mnemonic, comment in parsed_lines:
        if addr is not None and hex_str:
            raw = hex_str.replace('.', '')
            if len(raw) % 2 != 0:
                continue
            for i in range(0, len(raw), 2):
                hex_map[addr + i // 2] = int(raw[i:i+2], 16)
    return hex_map


def write_verification_hex(hex_map, outpath):
    """Write Intel HEX file of expected bytes for binary comparison."""
    addresses = sorted(hex_map.keys())
    with open(outpath, 'w') as f:
        i = 0
        while i < len(addresses):
            start_addr = addresses[i]
            data = []
            addr = start_addr
            while i < len(addresses) and addresses[i] == addr and len(data) < 16:
                data.append(hex_map[addr])
                addr += 1
                i += 1

            length = len(data)
            record = [length, (start_addr >> 8) & 0xFF, start_addr & 0xFF, 0x00]
            record.extend(data)
            checksum = (~sum(record) + 1) & 0xFF
            hex_line = ':' + ''.join(f'{b:02X}' for b in record) + f'{checksum:02X}'
            f.write(hex_line + '\n')

        f.write(':00000001FF\n')


def write_expected_bin(hex_map, outpath):
    """Write raw binary of expected bytes for easy comparison."""
    if not hex_map:
        return
    min_addr = min(hex_map.keys())
    max_addr = max(hex_map.keys())
    data = bytearray(max_addr - min_addr + 1)
    for addr, val in hex_map.items():
        data[addr - min_addr] = val
    with open(outpath, 'wb') as f:
        f.write(data)


def main():
    parser = argparse.ArgumentParser(
        description='Convert Altair BASIC listing to z80asm source')
    parser.add_argument('input', help='Input listing file')
    parser.add_argument('-o', '--output', required=True, help='Output .asm file')
    parser.add_argument('--hex', help='Output verification Intel HEX file')
    parser.add_argument('--bin', help='Output verification raw binary file')
    args = parser.parse_args()

    with open(args.input, 'r') as f:
        lines = f.readlines()

    # Parse all lines
    parsed = []
    for line in lines:
        result = parse_line(line)
        if result is not None:
            parsed.append(result)

    # Generate assembly
    asm_source = generate_asm(parsed)
    with open(args.output, 'w') as f:
        f.write(asm_source)
    print(f'Wrote {args.output}')

    # Extract hex bytes for verification
    hex_map = extract_hex_bytes(parsed)

    if args.hex:
        write_verification_hex(hex_map, args.hex)
        print(f'Wrote {args.hex} ({len(hex_map)} bytes, '
              f'{min(hex_map.keys()):04X}-{max(hex_map.keys()):04X})')

    if args.bin:
        write_expected_bin(hex_map, args.bin)
        print(f'Wrote {args.bin} ({len(hex_map)} bytes)')


if __name__ == '__main__':
    main()

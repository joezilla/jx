#!/usr/bin/env node
/**
 * extract-boot-hex.js - Extract boot loader code from FDC+ disk images as Intel HEX
 *
 * Reverses the process of create-boot-disk.js: reads a .dsk image, extracts the
 * boot code from the interleaved sector format, and outputs Intel HEX.
 *
 * Usage:
 *   node extract-boot-hex.js <disk-image> [options]
 *
 * Examples:
 *   node extract-boot-hex.js myos.dsk
 *   node extract-boot-hex.js myos.dsk -o boot.hex
 *   node extract-boot-hex.js myos.dsk --binary -o boot.bin
 */

const fs = require('fs');
const path = require('path');

// FDC+ disk parameters (must match create-boot-disk.js)
const SECTOR_SIZE = 137;
const SECTORS_PER_TRACK = 32;
const DATA_PER_SECTOR = 128;
const TRACK_SIZE = SECTOR_SIZE * SECTORS_PER_TRACK;

/**
 * Extract boot code from a disk image.
 *
 * Reads sectors in the same 2:1 interleave order used by CDBL / create-boot-disk:
 *   even sectors (0,2,4,...,30) then odd sectors (1,3,5,...,31) per track.
 *
 * Validates each sector's sync byte, marker, and checksum.
 *
 * @param {Buffer} disk - Raw disk image data
 * @returns {{ data: Buffer, warnings: string[] }}
 */
function extractBootCode(disk) {
    if (disk.length < TRACK_SIZE) {
        throw new Error(`File too small for a valid disk image (${disk.length} bytes, need at least ${TRACK_SIZE})`);
    }
    const totalTracks = Math.floor(disk.length / TRACK_SIZE);
    const trailingBytes = disk.length % TRACK_SIZE;
    const warnings = [];

    if (trailingBytes !== 0) {
        warnings.push(`${trailingBytes} trailing bytes after last complete track (ignored)`);
    }

    // Read file byte count from the first sector header (bytes 1-2, 16-bit LE)
    const fileByteCount = disk[1] | (disk[2] << 8);
    if (fileByteCount === 0) {
        throw new Error('File byte count in sector header is 0 — disk does not appear to contain boot code');
    }

    const sectorsNeeded = Math.ceil(fileByteCount / DATA_PER_SECTOR);
    const tracksNeeded = Math.ceil(sectorsNeeded / SECTORS_PER_TRACK);

    if (tracksNeeded > totalTracks) {
        throw new Error(
            `Boot code claims ${fileByteCount} bytes (${tracksNeeded} tracks) ` +
            `but disk only has ${totalTracks} tracks`
        );
    }

    console.log(`Disk image: ${totalTracks} tracks, ${disk.length} bytes`);
    console.log(`Boot code size (from header): ${fileByteCount} bytes (${sectorsNeeded} sectors across ${tracksNeeded} tracks)`);

    // Reassemble data in 2:1 interleave order (matching create-boot-disk write order)
    const data = Buffer.alloc(fileByteCount);
    let outOffset = 0;
    let sectorsRead = 0;

    for (let track = 0; track < tracksNeeded && outOffset < fileByteCount; track++) {
        for (let pass = 0; pass < 2 && outOffset < fileByteCount; pass++) {
            for (let s = pass; s < SECTORS_PER_TRACK && outOffset < fileByteCount; s += 2) {
                const imgOffset = (track * SECTORS_PER_TRACK + s) * SECTOR_SIZE;

                // Validate sync byte (track number with MSB set)
                const syncByte = disk[imgOffset];
                const expectedSync = track | 0x80;
                if (syncByte !== expectedSync) {
                    warnings.push(
                        `Track ${track} sector ${s}: sync byte 0x${syncByte.toString(16).padStart(2, '0')} ` +
                        `(expected 0x${expectedSync.toString(16).padStart(2, '0')})`
                    );
                }

                // Validate marker byte
                if (disk[imgOffset + 131] !== 0xFF) {
                    warnings.push(
                        `Track ${track} sector ${s}: marker byte 0x${disk[imgOffset + 131].toString(16).padStart(2, '0')} (expected 0xFF)`
                    );
                }

                // Read 128 data bytes and compute checksum
                let checksum = 0;
                const bytesToCopy = Math.min(DATA_PER_SECTOR, fileByteCount - outOffset);
                for (let i = 0; i < DATA_PER_SECTOR; i++) {
                    const b = disk[imgOffset + 3 + i];
                    checksum = (checksum + b) & 0xFF;
                    if (i < bytesToCopy) {
                        data[outOffset + i] = b;
                    }
                }

                // Validate checksum
                const storedChecksum = disk[imgOffset + 132];
                if (checksum !== storedChecksum) {
                    warnings.push(
                        `Track ${track} sector ${s}: checksum 0x${checksum.toString(16).padStart(2, '0')} ` +
                        `(expected 0x${storedChecksum.toString(16).padStart(2, '0')})`
                    );
                }

                outOffset += bytesToCopy;
                sectorsRead++;
            }
        }
    }

    console.log(`Extracted ${outOffset} bytes from ${sectorsRead} sectors`);

    return { data, warnings };
}

/**
 * Generate an Intel HEX format string from binary data.
 *
 * Emits :10 (16-byte) data records starting at the given base address,
 * followed by an EOF record.
 *
 * @param {Buffer} data - Binary data to encode
 * @param {number} baseAddress - Start address for the HEX records (default 0)
 * @returns {string} - Intel HEX file content
 */
function generateIntelHex(data, baseAddress) {
    const lines = [];
    const BYTES_PER_LINE = 16;

    for (let offset = 0; offset < data.length; offset += BYTES_PER_LINE) {
        const address = baseAddress + offset;

        // If address exceeds 16-bit, emit an extended linear address record
        if (address > 0xFFFF) {
            const upperAddr = (address >> 16) & 0xFFFF;
            const extLine = formatHexRecord(0x0000, 0x04, Buffer.from([
                (upperAddr >> 8) & 0xFF,
                upperAddr & 0xFF
            ]));
            lines.push(extLine);
        }

        const chunkSize = Math.min(BYTES_PER_LINE, data.length - offset);
        const chunk = data.slice(offset, offset + chunkSize);
        lines.push(formatHexRecord(address & 0xFFFF, 0x00, chunk));
    }

    // EOF record
    lines.push(':00000001FF');
    lines.push(''); // trailing newline

    return lines.join('\n');
}

/**
 * Format a single Intel HEX record line.
 *
 * @param {number} address - 16-bit address field
 * @param {number} recordType - Record type (0x00=data, 0x01=EOF, 0x04=extended addr)
 * @param {Buffer} data - Record data bytes
 * @returns {string} - Formatted record starting with ':'
 */
function formatHexRecord(address, recordType, data) {
    const byteCount = data.length;
    let sum = byteCount + ((address >> 8) & 0xFF) + (address & 0xFF) + recordType;
    for (let i = 0; i < data.length; i++) {
        sum += data[i];
    }
    const checksum = (~sum + 1) & 0xFF;

    const addrHex = address.toString(16).toUpperCase().padStart(4, '0');
    const typeHex = recordType.toString(16).toUpperCase().padStart(2, '0');
    const countHex = byteCount.toString(16).toUpperCase().padStart(2, '0');
    const dataHex = data.toString('hex').toUpperCase();
    const csHex = checksum.toString(16).toUpperCase().padStart(2, '0');

    return `:${countHex}${addrHex}${typeHex}${dataHex}${csHex}`;
}

function printUsage() {
    console.log(`
extract-boot-hex.js - Extract boot loader from FDC+ disk images

Usage:
  node extract-boot-hex.js <disk-image> [options]

Arguments:
  disk-image          Input disk image file (.dsk)

Options:
  -o, --output FILE   Output file (default: <input>.hex, or <input>.bin with --binary)
  -a, --address ADDR  Base address for HEX output (default: 0x0000, hex or decimal)
  --binary            Output raw binary instead of Intel HEX
  -h, --help          Show this help message

Examples:
  node extract-boot-hex.js myos.dsk
  node extract-boot-hex.js myos.dsk -o boot.hex
  node extract-boot-hex.js myos.dsk -o boot.bin --binary
  node extract-boot-hex.js myos.dsk -a 0x100 -o boot.hex
`);
}

function parseArgs(args) {
    const options = {
        input: null,
        output: null,
        binary: false,
        baseAddress: 0,
        help: false
    };

    for (let i = 0; i < args.length; i++) {
        const arg = args[i];

        switch (arg) {
            case '-h':
            case '--help':
                options.help = true;
                break;

            case '-o':
            case '--output':
                options.output = args[++i];
                break;

            case '-a':
            case '--address': {
                const addrStr = args[++i];
                const addr = addrStr.startsWith('0x') || addrStr.startsWith('0X')
                    ? parseInt(addrStr, 16)
                    : parseInt(addrStr, 10);
                if (isNaN(addr) || addr < 0) {
                    throw new Error(`Invalid address: ${addrStr}`);
                }
                options.baseAddress = addr;
                break;
            }

            case '--binary':
            case '--bin':
                options.binary = true;
                break;

            default:
                if (arg.startsWith('-')) {
                    throw new Error(`Unknown option: ${arg}`);
                }
                if (options.input) {
                    throw new Error(`Multiple input files specified: ${options.input} and ${arg}`);
                }
                options.input = arg;
        }
    }

    return options;
}

function main() {
    const args = process.argv.slice(2);

    if (args.length === 0) {
        printUsage();
        process.exit(1);
    }

    let options;
    try {
        options = parseArgs(args);
    } catch (error) {
        console.error(`Error: ${error.message}`);
        process.exit(1);
    }

    if (options.help) {
        printUsage();
        process.exit(0);
    }

    if (!options.input) {
        console.error('Error: No input file specified');
        printUsage();
        process.exit(1);
    }

    if (!fs.existsSync(options.input)) {
        console.error(`Error: Input file not found: ${options.input}`);
        process.exit(1);
    }

    // Determine output filename
    if (!options.output) {
        const parsed = path.parse(options.input);
        const ext = options.binary ? '.bin' : '.hex';
        options.output = path.join(parsed.dir, parsed.name + ext);
    }

    try {
        console.log(`Reading: ${options.input}`);
        const disk = fs.readFileSync(options.input);

        const { data, warnings } = extractBootCode(disk);

        if (warnings.length > 0) {
            console.log(`\nWarnings (${warnings.length}):`);
            for (const w of warnings) {
                console.log(`  ${w}`);
            }
        }

        if (options.binary) {
            fs.writeFileSync(options.output, data);
            console.log(`\nWrote binary: ${options.output} (${data.length} bytes)`);
        } else {
            const hex = generateIntelHex(data, options.baseAddress);
            fs.writeFileSync(options.output, hex);
            const lineCount = hex.split('\n').filter(l => l.startsWith(':')).length;
            console.log(`\nWrote Intel HEX: ${options.output} (${lineCount} records, base address 0x${options.baseAddress.toString(16).padStart(4, '0')})`);
        }

    } catch (error) {
        console.error(`Error: ${error.message}`);
        process.exit(1);
    }
}

// Export for testing
module.exports = {
    extractBootCode, generateIntelHex, formatHexRecord, parseArgs, main,
    SECTOR_SIZE, SECTORS_PER_TRACK, DATA_PER_SECTOR, TRACK_SIZE,
};

if (require.main === module) {
    main();
}

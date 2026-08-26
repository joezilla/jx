# MITS Altair Disk BASIC / Altair DOS — Disk Image Format Specification

## Purpose

This skill provides the complete low-level format specification for MITS Altair
floppy disk images as used by **Altair Disk Extended BASIC** (versions 3.x–4.1)
and **Altair DOS 1.0**. Use this to build software that can read, write, create,
format, extract files from, and inject files into raw disk images compatible with
the SIMH AltairZ80 emulator, Altair-Duino, AltairClone, and original hardware.

This is a **proprietary MITS format** — it is NOT compatible with CP/M, even
though CP/M can run on the same 88-DCDD hardware. The physical sector envelope
(sync byte, checksum, stop byte) is similar, but the filesystem (directory
structure, file allocation, sector linkage) is completely different.

---

## Physical Disk Geometry

### 8-Inch Floppy (Pertec FD-400)

| Parameter          | Value                              |
|--------------------|------------------------------------|
| Tracks             | 77 (numbered 0–76)                 |
| Sectors per track  | 32 (numbered 0–31)                 |
| Bytes per sector   | 137 (raw)                          |
| Sectoring          | Hard-sectored (32 sector holes)    |
| Sides              | Single-sided                       |
| Total raw capacity | 77 × 32 × 137 = 337,568 bytes     |
| Usable data        | ~300 KB                            |

### 5.25-Inch Minidisk

| Parameter          | Value                              |
|--------------------|------------------------------------|
| Tracks             | 35 (numbered 0–34)                 |
| Sectors per track  | 16 (numbered 0–15)                 |
| Bytes per sector   | 137 (raw)                          |
| Sectoring          | Hard-sectored (16 sector holes)    |
| Sides              | Single-sided                       |
| Total raw capacity | 35 × 16 × 137 = 76,720 bytes      |
| Usable data        | ~70 KB                             |

### SIMH Disk Image Layout

SIMH stores disk images as flat binary files: a contiguous stream of 137-byte
sectors, ordered track 0 sector 0, track 0 sector 1, ..., track 0 sector N,
track 1 sector 0, etc.

```
File offset for track T, sector S:
    offset = (T * SECTORS_PER_TRACK + S) * 137
```

For 8-inch: `offset = (T * 32 + S) * 137`
For minidisk: `offset = (T * 16 + S) * 137`

---

## Track Allocation Map

### 8-Inch Floppy

| Tracks | Purpose                                       |
|--------|-----------------------------------------------|
| 0–5    | System tracks (bootable BASIC image)           |
| 6–69   | Data tracks (user files)                       |
| 70     | Directory track                                |
| 71–76  | Data tracks (user files, continued)            |

### 5.25-Inch Minidisk — Bootable

| Tracks | Purpose                                       |
|--------|-----------------------------------------------|
| 0–11   | System tracks (bootable BASIC image)           |
| 12–33  | Data tracks (user files)                       |
| 34     | Directory track                                |

### 5.25-Inch Minidisk — Data Only

| Tracks | Purpose                                       |
|--------|-----------------------------------------------|
| 0–33   | Data tracks (user files)                       |
| 34     | Directory track                                |

**Key constants:**

```python
# 8-inch
DIR_TRACK_8IN        = 70
SECTORS_PER_TRACK_8IN = 32
TOTAL_TRACKS_8IN     = 77
SYSTEM_TRACKS_8IN    = 6    # tracks 0-5

# Minidisk
DIR_TRACK_MINI       = 34
SECTORS_PER_TRACK_MINI = 16
TOTAL_TRACKS_MINI    = 35
SYSTEM_TRACKS_MINI_BOOT = 12  # tracks 0-11 (bootable)
SYSTEM_TRACKS_MINI_DATA = 0   # (data-only disk)

SECTOR_SIZE          = 137
```

---

## Sector Formats

There are two distinct sector formats depending on whether the sector is on a
system track or a data/directory track.

### System Track Sectors (Boot Image)

Tracks 0–5 on 8-inch; tracks 0–11 on bootable minidisk.

```
Offset  Length  Description
------  ------  ----------------------------------------
  0       1     Track number OR'd with 0x80 (sync byte)
  1       2     Number of bytes remaining in boot file (little-endian, 16-bit)
  3     128     Data payload (boot image fragment)
131       1     0xFF — Stop byte
132       1     Checksum (sum of bytes 3–130, truncated to 8 bits)
133       4     Unused (typically 0x00)
```

**Total: 137 bytes**

System track sectors are read in a **2:1 interleave**: read all even-numbered
sectors first (0, 2, 4, ...), then all odd-numbered sectors (1, 3, 5, ...).
Repeat for each successive track.

```python
def system_sector_read_order(sectors_per_track):
    """Returns the order in which system track sectors should be read."""
    order = []
    for s in range(0, sectors_per_track, 2):  # evens first
        order.append(s)
    for s in range(1, sectors_per_track, 2):  # then odds
        order.append(s)
    return order
```

**Checksum calculation:**

```python
def compute_checksum(data_bytes):
    """Compute checksum over the 128-byte data payload (bytes 3-130)."""
    return sum(data_bytes) & 0xFF
```

### Data Track Sectors (Files and Directory)

Tracks 6–76 (except track 70) on 8-inch; remaining tracks on minidisk.

```
Offset  Length  Description
------  ------  ----------------------------------------
  0       1     Track number OR'd with 0x80 (sync byte)
  1       1     Skewed sector number (see below)
  2       1     File number (index into directory, 1-based; 0 = unallocated)
  3       1     Data byte count (number of valid data bytes, 0–128)
  4       1     Checksum of bytes 2–3 and 5–134
  5       1     Next track pointer (track of next sector in chain)
  6       1     Next sector pointer (sector of next sector in chain)
  7     128     Data payload
135       1     0xFF — Stop byte
136       1     Unused (typically 0x00)
```

**Total: 137 bytes**

**Sector skewing (8-inch only):**

On 8-inch disks, data track sectors use a 17-sector skew. The skewed sector
number stored in byte 1 is:

```python
skewed_sector = (physical_sector * 17) % 32
```

On minidisks, there is NO skewing — the sector number in byte 1 equals the
physical sector number.

**Next-sector pointer:**

Bytes 5–6 form a (track, sector) pointer to the next sector in the file's
linked list. When a file's data chain ends:
- Next track = 0x00 and next sector = 0x00, OR
- The data byte count (byte 3) indicates fewer than 128 valid bytes
  (a "short" final sector)

**Checksum calculation for data sectors:**

```python
def compute_data_checksum(sector_bytes):
    """
    Checksum covers bytes 2-3 (file_num, byte_count) and 5-134 (next_ptr + data).
    Byte 4 is the checksum itself and is excluded.
    """
    total = 0
    total += sector_bytes[2]   # file number
    total += sector_bytes[3]   # data byte count
    for i in range(5, 135):    # next-ptr (5-6) + data (7-134)
        total += sector_bytes[i]
    return total & 0xFF
```

---

## Directory Structure

### Location

The directory occupies a single track:
- **8-inch:** Track 70 (32 sectors × 8 entries = 256 max files)
- **Minidisk:** Track 34 (16 sectors × 8 entries = 128 max files)

### Directory Sector Layout

Directory sectors use the same physical format as data track sectors. The
128-byte data payload (bytes 7–134) is divided into **8 directory entries of
16 bytes each**.

```
Sector data area (128 bytes at offset 7–134):
  Entry 0: bytes  7– 22  (16 bytes)
  Entry 1: bytes 23– 38  (16 bytes)
  Entry 2: bytes 39– 54  (16 bytes)
  Entry 3: bytes 55– 70  (16 bytes)
  Entry 4: bytes 71– 86  (16 bytes)
  Entry 5: bytes 87–102  (16 bytes)
  Entry 6: bytes103–118  (16 bytes)
  Entry 7: bytes119–134  (16 bytes)
```

### Directory Entry Format (16 bytes)

```
Offset  Length  Description
------  ------  ----------------------------------------
  0       1     File status / first character of filename
                  0xFF = End-of-directory stopper (no more entries after this)
                  0x00 = Deleted/empty entry
                  Other = First character of the filename (ASCII, uppercase)
  1      10     Remaining filename characters (padded with spaces, 0x20)
                  Total filename: bytes 0–10 = 11 characters
 11       1     File type indicator / attributes byte
 12       1     First data track (track number of file's first sector)
 13       1     First data sector (sector number of file's first sector)
 14       2     Reserved / password (see notes)
```

**IMPORTANT NOTES ON DIRECTORY ENTRIES:**

1. **Filename**: 11 bytes total (bytes 0–10). Uppercase ASCII, space-padded on
   the right. Altair BASIC and DOS typically use short names. The first character
   also serves as the allocation flag — 0xFF means end-of-directory, 0x00 means
   deleted/free.

2. **End-of-directory marker**: The first entry whose byte 0 is 0xFF terminates
   the directory scan. All entries after this are ignored. When creating new
   files, you must push the stopper byte forward.

3. **File number calculation**: File numbers are 1-based and computed from the
   directory position:

   ```python
   file_number = (sector_index * 8) + entry_index_within_sector + 1
   ```

   Where `sector_index` is 0–31 (8-inch) or 0–15 (minidisk), and
   `entry_index_within_sector` is 0–7. This file number appears in byte 2 of
   every data sector belonging to that file.

4. **Password bytes (14–15)**: The last 5 bytes of each directory entry (offsets
   11–15) are nominally zeroed by single-user Disk BASIC but Multiuser BASIC
   uses bytes 11–15 as a 5-byte password field, where all zeros means "no
   password." Single-user BASIC does not always clear these bytes. If non-zero,
   Multiuser BASIC will consider the file password-protected.

5. **File type byte (offset 11)**: Encodes file attributes. Common values
   observed in practice vary between BASIC versions. For safety, treat as opaque
   and preserve when copying.

### Scanning the Directory

```python
def read_directory(image, disk_type):
    """
    Read all directory entries from a disk image.
    Returns list of (file_number, filename, first_track, first_sector, raw_entry).
    """
    if disk_type == '8inch':
        dir_track = 70
        spt = 32
    else:
        dir_track = 34
        spt = 16

    entries = []
    for sector in range(spt):
        offset = (dir_track * spt + sector) * 137
        sector_data = image[offset : offset + 137]
        # Data payload starts at byte 7
        for slot in range(8):
            entry_offset = 7 + (slot * 16)
            entry = sector_data[entry_offset : entry_offset + 16]

            if entry[0] == 0xFF:
                return entries  # End-of-directory stopper

            if entry[0] == 0x00:
                continue  # Deleted/empty entry

            file_number = (sector * 8) + slot + 1
            filename = bytes(entry[0:11]).decode('ascii', errors='replace').rstrip()
            file_type = entry[11]
            first_track = entry[12]
            first_sector = entry[13]

            entries.append({
                'file_number': file_number,
                'filename': filename,
                'file_type': file_type,
                'first_track': first_track,
                'first_sector': first_sector,
                'raw': entry
            })

    return entries
```

---

## File Data Chain — Linked List Traversal

Files are stored as a linked list of data sectors. Each sector contains a
pointer (bytes 5–6) to the next sector in the chain.

### Reading a File

```python
def read_file(image, first_track, first_sector, file_number, disk_type):
    """
    Follow the linked list from (first_track, first_sector) to extract
    all data bytes belonging to a file.
    """
    spt = 32 if disk_type == '8inch' else 16
    data = bytearray()
    track = first_track
    sector = first_sector
    visited = set()

    while True:
        if (track, sector) in visited:
            raise ValueError(f"Circular reference at track {track}, sector {sector}")
        visited.add((track, sector))

        offset = (track * spt + sector) * 137
        sec = image[offset : offset + 137]

        # Validate sync byte
        expected_sync = track | 0x80
        if sec[0] != expected_sync:
            raise ValueError(f"Sync byte mismatch at T{track}/S{sector}: "
                           f"expected 0x{expected_sync:02X}, got 0x{sec[0]:02X}")

        # Validate file number
        sec_file_num = sec[2]
        if sec_file_num != file_number:
            raise ValueError(f"File number mismatch at T{track}/S{sector}: "
                           f"expected {file_number}, got {sec_file_num}")

        # Validate checksum
        computed = compute_data_checksum(sec)
        if computed != sec[4]:
            # Warning: checksum mismatch (may still want to read data)
            pass

        byte_count = sec[3]
        next_track = sec[5]
        next_sector = sec[6]
        payload = sec[7 : 7 + min(byte_count, 128)]
        data.extend(payload)

        # End of chain?
        if byte_count < 128:
            break  # Short sector = last sector
        if next_track == 0 and next_sector == 0:
            break  # Null pointer = end of chain

        track = next_track
        sector = next_sector

    return bytes(data)
```

### Writing a File

To write a file, you must:

1. **Allocate a directory entry** — find a free slot (byte 0 == 0x00) or
   the end-of-directory stopper, insert the new entry, and push the stopper
   forward.

2. **Allocate data sectors** — find free sectors on data tracks (sectors where
   byte 2 == 0x00, meaning unallocated). Avoid system tracks and the directory
   track.

3. **Build the linked list** — write each sector with the proper header:
   sync byte, skewed sector number, file number, byte count, checksum,
   next-sector pointer, and data payload.

4. **Terminate the chain** — the last sector gets a byte count < 128 or
   a null next-sector pointer (0x00, 0x00).

```python
def find_free_sectors(image, disk_type):
    """
    Scan all data tracks for unallocated sectors (file_number == 0).
    Returns list of (track, sector) tuples.
    """
    if disk_type == '8inch':
        spt = 32
        dir_track = 70
        system_tracks = 6
        total_tracks = 77
    else:
        spt = 16
        dir_track = 34
        system_tracks = 12  # for bootable; 0 for data-only
        total_tracks = 35

    free = []
    for track in range(system_tracks, total_tracks):
        if track == dir_track:
            continue  # Skip directory track
        for sector in range(spt):
            offset = (track * spt + sector) * 137
            sec = image[offset : offset + 137]
            if sec[2] == 0x00:  # file number == 0 means free
                free.append((track, sector))
    return free


def write_sector(image, track, sector, file_number, byte_count,
                 next_track, next_sector, payload, disk_type):
    """
    Write a single data sector into the image.
    """
    spt = 32 if disk_type == '8inch' else 16
    sec = bytearray(137)

    # Byte 0: sync byte
    sec[0] = track | 0x80

    # Byte 1: skewed sector number
    if disk_type == '8inch':
        sec[1] = (sector * 17) % 32
    else:
        sec[1] = sector  # No skew on minidisk

    # Byte 2: file number
    sec[2] = file_number

    # Byte 3: data byte count
    sec[3] = byte_count

    # Bytes 5-6: next sector pointer
    sec[5] = next_track
    sec[6] = next_sector

    # Bytes 7–134: data payload (pad with zeros if short)
    for i in range(min(byte_count, 128)):
        sec[7 + i] = payload[i] if i < len(payload) else 0x00

    # Byte 4: checksum
    sec[4] = compute_data_checksum(sec)

    # Byte 135: stop byte
    sec[135] = 0xFF

    # Byte 136: unused
    sec[136] = 0x00

    # Write to image
    offset = (track * spt + sector) * 137
    image[offset : offset + 137] = sec
```

---

## Formatting a Blank Disk Image

To create a new, empty, formatted disk image:

1. Create a zero-filled byte array of the appropriate size.
2. Write proper sync bytes (track | 0x80) and stop bytes (0xFF at byte 131
   for system tracks, byte 135 for data tracks) in every sector.
3. Write the end-of-directory stopper (0xFF) in the first byte of the first
   directory entry on the directory track.

```python
def format_disk_image(disk_type, bootable=True):
    """Create a new formatted but empty disk image."""
    if disk_type == '8inch':
        total_tracks = 77
        spt = 32
        dir_track = 70
        sys_tracks = 6
    else:
        total_tracks = 35
        spt = 16
        dir_track = 34
        sys_tracks = 12 if bootable else 0

    image = bytearray(total_tracks * spt * 137)

    for track in range(total_tracks):
        for sector in range(spt):
            offset = (track * spt + sector) * 137

            if track < sys_tracks:
                # System track format
                image[offset + 0] = track | 0x80     # sync
                image[offset + 1] = 0x00             # byte count low
                image[offset + 2] = 0x00             # byte count high
                # bytes 3-130: zeros (no boot data)
                image[offset + 131] = 0xFF           # stop byte
                image[offset + 132] = 0x00           # checksum (of zeros)
            else:
                # Data/directory track format
                image[offset + 0] = track | 0x80     # sync
                if disk_type == '8inch':
                    image[offset + 1] = (sector * 17) % 32  # skewed sector
                else:
                    image[offset + 1] = sector        # no skew
                image[offset + 2] = 0x00             # file number (free)
                image[offset + 3] = 0x00             # byte count
                image[offset + 4] = 0x00             # checksum
                image[offset + 5] = 0x00             # next track
                image[offset + 6] = 0x00             # next sector
                image[offset + 135] = 0xFF           # stop byte

    # Write end-of-directory stopper in first entry of directory track
    dir_offset = (dir_track * spt + 0) * 137
    image[dir_offset + 7] = 0xFF  # stopper byte in first entry slot

    return image
```

---

## Deleting a File

To delete a file:

1. Set the first byte of its directory entry to 0x00.
2. Set byte 2 (file number) to 0x00 in every data sector belonging to the file.
3. Optionally compact the directory to remove gaps and reposition the stopper.

**WARNING:** You must walk the file's entire linked list to free all its sectors.
Simply zeroing the directory entry without freeing sectors will leak disk space.

---

## Boot Image Structure

The boot image (Disk BASIC) is stored on system tracks as a contiguous byte
stream read in 2:1 interleaved sector order. The byte count in bytes 1–2 of
each system sector represents the remaining bytes of the boot image (it
decrements as you progress through the sectors).

To extract the boot image:

```python
def read_boot_image(image, disk_type):
    """Extract the boot image from system tracks."""
    spt = 32 if disk_type == '8inch' else 16
    sys_tracks = 6 if disk_type == '8inch' else 12
    read_order = system_sector_read_order(spt)
    boot_data = bytearray()

    for track in range(sys_tracks):
        for sector in read_order:
            offset = (track * spt + sector) * 137
            sec = image[offset : offset + 137]
            remaining = sec[1] | (sec[2] << 8)  # little-endian 16-bit
            if remaining == 0:
                return bytes(boot_data)
            payload = sec[3:131]  # 128 bytes of boot data
            chunk = min(remaining, 128)
            boot_data.extend(payload[:chunk])

    return bytes(boot_data)
```

---

## Validation and Error Checking

### Sync Byte Validation

Every sector's byte 0 must equal `(track_number | 0x80)`. If the high bit is
not set, the sector has not been properly formatted or is corrupt.

### Checksum Validation

- **System sectors:** Checksum at byte 132 = sum of bytes 3–130, masked to 8 bits.
- **Data sectors:** Checksum at byte 4 = sum of bytes 2–3 and 5–134, masked to
  8 bits.

### Stop Byte Validation

- **System sectors:** Byte 131 must be 0xFF.
- **Data sectors:** Byte 135 must be 0xFF.

### Sector Number Validation (8-inch)

For data sectors on 8-inch disks, byte 1 should equal `(physical_sector * 17) % 32`.
A mismatch suggests the sector was not written by standard MITS software or the
image may be corrupt.

### Linked List Integrity

When following a file's sector chain:
- Each sector's file number (byte 2) should match the expected file number.
- The chain should not contain circular references.
- The chain should terminate (byte count < 128, or null next pointer).

---

## CP/M on MITS Hardware — Format Differences

Although CP/M can run on the same 88-DCDD hardware, the disk format is
**completely different** and **not interchangeable** with MITS Disk BASIC/DOS.

| Aspect             | MITS Disk BASIC / DOS           | CP/M (Burcon BIOS)                |
|--------------------|---------------------------------|-----------------------------------|
| File allocation    | Linked list (per-sector chain)  | Allocation blocks + directory     |
| Directory location | Track 70 (8") / Track 34 (mini) | Track 2+ (after system tracks)    |
| Directory entry    | 16 bytes, 11-char name          | 32 bytes, 8.3 name + extent info  |
| Sector payload     | 128 bytes at offset 7–134       | 128 bytes at offset 3–130 or similar |
| Sector envelope    | Similar sync/checksum/stop      | Similar sync/checksum/stop        |
| System tracks      | 0–5 (BASIC image)               | 0–1 (CCP + BDOS + BIOS)          |
| Sector skew        | (sector × 17) % 32              | BIOS translation table            |

**The physical sector envelope format is similar** (both use byte 0 = track|0x80
as sync, and 0xFF stop bytes), which is why the Burcon CP/M BIOS could reuse
some of the same low-level I/O code. But the filesystem layer is entirely
incompatible.

---

## Disk Image File Sizes

Use these as quick sanity checks when identifying disk images:

| Disk Type          | Calculation              | Image Size (bytes) |
|--------------------|--------------------------|--------------------|
| 8" floppy          | 77 × 32 × 137           | 337,568            |
| 5.25" minidisk     | 35 × 16 × 137           | 76,720             |

If an image file is larger (e.g., 254 tracks), it may be a SIMH extended image
that supports CP/M with additional tracks beyond the original 77.

---

## Constants Reference

```python
# Sector structure offsets — System Tracks
SYS_SYNC          = 0     # Track | 0x80
SYS_BYTE_COUNT_LO = 1     # Remaining boot bytes (low)
SYS_BYTE_COUNT_HI = 2     # Remaining boot bytes (high)
SYS_DATA_START    = 3     # Start of 128-byte payload
SYS_DATA_END      = 130   # End of 128-byte payload (inclusive)
SYS_STOP_BYTE     = 131   # Must be 0xFF
SYS_CHECKSUM      = 132   # Sum of bytes 3–130
SYS_UNUSED_START  = 133   # 4 unused bytes

# Sector structure offsets — Data Tracks
DAT_SYNC          = 0     # Track | 0x80
DAT_SKEWED_SECTOR = 1     # (physical_sector * 17) % 32 (8-inch) or sector (mini)
DAT_FILE_NUMBER   = 2     # 1-based directory index; 0 = free
DAT_BYTE_COUNT    = 3     # Valid data bytes in payload (0–128)
DAT_CHECKSUM      = 4     # Sum of bytes 2-3, 5-134
DAT_NEXT_TRACK    = 5     # Next sector in chain: track
DAT_NEXT_SECTOR   = 6     # Next sector in chain: sector
DAT_DATA_START    = 7     # Start of 128-byte payload
DAT_DATA_END      = 134   # End of 128-byte payload (inclusive)
DAT_STOP_BYTE     = 135   # Must be 0xFF
DAT_UNUSED        = 136   # Unused byte

# Directory entry offsets (within 16-byte entry)
DIR_FILENAME      = 0     # 11 bytes: filename (0xFF = stopper, 0x00 = deleted)
DIR_FILE_TYPE     = 11    # 1 byte: file type / attributes
DIR_FIRST_TRACK   = 12    # 1 byte: first data track
DIR_FIRST_SECTOR  = 13    # 1 byte: first data sector
DIR_RESERVED      = 14    # 2 bytes: reserved / password (Multiuser BASIC)
DIR_ENTRY_SIZE    = 16    # Total entry size
DIR_ENTRIES_PER_SECTOR = 8

# Special values
SYNC_BIT          = 0x80
STOP_BYTE         = 0xFF
DIR_STOPPER       = 0xFF  # First byte of entry = end of directory
DIR_DELETED       = 0x00  # First byte of entry = deleted/free
FREE_SECTOR       = 0x00  # File number in data sector = unallocated

# Skew factor (8-inch only)
SKEW_FACTOR       = 17
SKEW_MODULUS_8IN  = 32    # sectors per track
```

---

## Implementation Checklist

When building a disk image tool, implement these operations:

- [ ] **Read/identify disk image** — detect 8-inch vs. minidisk by file size
- [ ] **List directory** — scan directory track, parse 16-byte entries
- [ ] **Extract file** — follow linked list from directory entry's first track/sector
- [ ] **Write file** — allocate directory entry + data sectors, build linked list
- [ ] **Delete file** — zero directory entry byte 0, free all chained sectors
- [ ] **Format disk** — create empty image with proper sync/stop bytes and stopper
- [ ] **Extract boot image** — read system tracks in 2:1 interleave order
- [ ] **Write boot image** — write BASIC image to system tracks with interleave
- [ ] **Validate image** — check all sync bytes, checksums, stop bytes, chain integrity
- [ ] **Disk statistics** — count free sectors, used sectors, file count, etc.
- [ ] **Hex dump sector** — display raw 137-byte sector with annotations

---

## Reference Sources

- ACOPY.ASM (Copy & Repair Utility for Altair diskettes) — deramp.com
- Altair BASIC Reference Manual, July 1977, Appendix H (Disk Information)
- Altair Mini-Disk Format addendum — deramp.com
- Burcon CP/M BIOS documentation — deramp.com
- SIMH AltairZ80 altairz80_dsk.c source (Peter Schorn)
- altairdsk utility (phatchman/altair_tools on GitHub)
- AltairClone Operator's Manual (Mike Douglas, deramp.com)

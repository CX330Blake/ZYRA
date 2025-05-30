# ZYRA: Your Reverser Assassin

Zyra is an Zig-written obfuscator/packer/loader for binaries.

## Workflow

1. Generate the embedded stub (generate_embedded_stub.zig)
2. Encrypt the payload (src/main.zig)
3. Embed & pack jthose payload in stub (src/packer/packer.zig)
4. Decrypt and execute in runtime (src/packer/elf_stub.zig)

## Packed binary structure

| Section                   | Description        |
| ------------------------- | ------------------ |
| ELF STUB BINARY           | The "outer" binary |
| "PAYLOAD_START_MARKER"    | Payload begin      |
| payload_len (u64 LE)      | -                  |
| key (u8)                  | Decrypt key        |
| encrypted_payload (bytes) | -                  |

## To-Do

1. Add support for PE file format
2. Add suuport for anti-debugging (by IsDebuggerPresent API perhaps)

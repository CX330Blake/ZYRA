# ZYRA: Your Runtime Armor 🛡️

<p align="center">
  <img alt="GitHub License" src="https://img.shields.io/github/license/CX330Blake/zyra">
  <img alt="GitHub top language" src="https://img.shields.io/github/languages/top/cx330blake/zyra">
  <img alt="GitHub Downloads (all assets, all releases)" src="https://img.shields.io/github/downloads/cx330blake/zyra/total">
  <img alt="GitHub repo size" src="https://img.shields.io/github/repo-size/cx330blake/zyra">
  <img alt="X (formerly Twitter) Follow" src="https://img.shields.io/twitter/follow/CX330Blake">

</p>

<p align="center">
  <a href="#whats-zyra">What's ZYRA?</a> •
  <a href="#showcase">Showcase</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#workflow-under-the-hood">Workflow under the hood</a> •
  <a href="#packed-binary-structure">Packed binary structure</a> •
  <a href="#to-do">To Do</a> • 
  <a href="#contribution">Contribution</a> • 
  <a href="#star-history">Star history</a>
</p>

<p height="300" align="center">
  <img src="./assets/ZYRA.png">
</p>

## What's ZYRA?

ZYRA is a Zig-based obfuscator, packer, and loader designed to protect executable files from static analysis and reverse engineering.

- ✨ Written in Zig for performance and control
- 👌 Easy to install with one-liner command
- 🔄 Generate a much more complicated control flow for packed binary to anti-reversing
- 🛡️ Provides runtime decryption and execution, shielding payloads from inspection

## Showcase

If you wonder the effectiveness of ZYRA, you should check this simple "hello world" binary out. In the following example, I'm gonna use Binary Ninja as the decompiler. You can get the example binaries in [examples](./examples/).

Before using ZYRA, we can see that it's as simple as f\*\*k to reverse engineer.

![Before ZYRA](./assets/BeforeZyra.png)

But after ZYRA, it's much more complicated! You can see the control flow graph is so complicated to trace (but it's not perfect yet).

![After ZYRA](./assets/AfterZyra.png)

## Installation

ZYRA is now currently support Linux only, but the Windows version will be released soon.

You can simply copy and paste the following one-liner to install ZYRA.

```bash
bash <(curl -sSL https://raw.githubusercontent.com/CX330Blake/ZYRA/main/install.sh)
```

> [!WARNING]  
> Never execute any untrusted script on your machine. Read the script first.

On the other hand, you can clone this repo and use the following command to build your own ZYRA biary.

```bash
git clone https://github.com/CX330Blake/ZYRA
cd ZYRA
# You can change the build flag on your own
zig build --release=fast
```

## Usage

```
___  _   _ ____ ____
  /   \_/  |__/ |__|
 /__   |   |  \ |  |

Zyra Packer v0.1.0
Copyright (C) 2025 @CX330Blake.
All rights reserved.
Zyra Packer v0.1.0 - Binary packer and obfuscator

Usage: zyra [options] <FILE>

Options:
  -h, --help           Show this help message
  -v, --verbose        Verbose output
  -o, --output FILE    Output file name (default: input.zyra)
  -k, --key HEX        Encryption key in hex (default: 0x42)

Examples:
  zyra /bin/ls                    # Pack ls -> ls.zyra
  zyra -o myapp.exe program       # Pack program -> myapp.exe
  zyra -k FF -v /usr/bin/cat      # Pack with key 0xFF, verbose
```

## Workflow under the hood

1. Generate the embedded stub (generate_embedded_stub.zig)
2. Encrypt the payload (src/main.zig)
3. Embed & pack jthose payload in stub (src/packer/packer.zig)
4. Decrypt and execute in runtime (src/packer/elf_stub.zig)

## Packed binary structure

| Section                   | Description        |
| ------------------------- | ------------------ |
| Stub binary               | The "outer" binary |
| "PAYLOAD_START_MARKER"    | Payload begin      |
| payload_len (u64 LE)      | -                  |
| key (u8)                  | Decrypt key        |
| encrypted_payload (bytes) | -                  |

## To-Do

1. Add support for anti-debugging.
2. Add more advanced techniques.

    - Encryption
        - RC4
        - ChaCha20
        - TEA
        - etc
    - Packing
        - Run-length encoding
        - LZ77
        - Huffman coding
        - etc

## Contribution

This project is maintained by [@CX330Blake](https://github.com/CX330Blake/). PRs are welcome if you also want to contribute to this project.

## Star history

[![Star History Chart](https://api.star-history.com/svg?repos=CX330Blake/ZYRA&type=Date)](https://www.star-history.com/#CX330Blake/ZYRA&Date)

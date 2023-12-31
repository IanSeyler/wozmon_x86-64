# Wozmon x86-64


## About

An instruction by instruction rewrite of Wozmon in x86-64 for the BareMetal kernel. Minor changes were made, mainly to deal with 64-bit addresses.

The Woz Monitor, also known as Wozmon, is a simple memory monitor and was the system software located in the 256 byte PROM on the Apple-1 from 1976. Wozmon is used to inspect and modify memory contents or to execute programs already located in memory.

<p align="center">
	<img src="img/ScreenShot.png"></img>
</p>

The source code for the original Wozmon can be found [here](https://github.com/jefftranter/6502/blob/master/asm/wozmon/wozmon.s).


## Prerequisites

The script in this repo depend on a Debian-based Linux system. macOS is also supported if you are using [Homebrew](https://brew.sh).

- [NASM](https://nasm.us) - Assembly compiler to build the loader, kernel, and Wozmon.

In Linux this can be completed with the following command:

	sudo apt install nasm


## Initial configuration
	
	git clone https://github.com/IanSeyler/wozmon_x86-64.git
	cd wozmon_x86-64
	./wozmon.sh setup
	
`wozmon.sh setup` automatically runs the build and install functions.


## Starting Wozmon

`wozmon.sh run` will start Wozmon in a QEMU virtual machine. Keyboard input can be done when the QEMU window is selected. You can also type in the serial console.


## Memory Layout

The BareMetal kernel uses the first 2MiB of RAM. Wozmon runs within the BareMetal kernel memory. All other available RAM is mapped at 0xFFFF800000000000


## Usage

Wozmon operates on a line-by-line basis and adheres to the same syntax as the original Wozmon on the Apple-1. The commands comprise of memory addresses, specifying whether to perform a read, write, or execute operation on them. In the following examples, `[ENTER]` denotes the action of pressing the enter key after inputting text. All other lines are output from the monitor.

* On startup a `\` will be displayed.

* Wozmon will interpret any hexadecimal value as a memory address. Wozmon will display the memory address and the 8-bit value at that address.

```
1E0000[ENTER]

00000000001E0000: B1
```

* Entering a range will print out a range of bytes (destination inclusive).

```
100000.10000F[ENTER]

0000000000100000: EB 4E 90 42 41 52 45 4D
0000000000100008: 45 54 41 4C 90 90 90 90
```

* Entering a hexadecimal value followed by a ':' will allow you to write bytes starting at that memory address.

```
FFFF800000000000: C3[ENTER]

FFFF800000000000: 00
FFFF800000000000[ENTER]

FFFF800000000000: C3
```

Note: Wozmon will show what the first byte at the starting address was before the write.

* Entering `R` will run the code at the last provided address.


## Example programs

These programs can be typed in manually or copy/pasted via the serial I/O.


### Test Program #1 - Return to sender

* `90` is the `NOP` instruction. The CPU effectively skips to the next instruction.
* `C3` is the `RET` instruction. The CPU returns back to Wozmon.

```
FFFF800000000000: 90 C3
R
```


### Test Program #2 - Fatal error

Code doesn't need to be stored and run from `0xFFFF800000000000`.
```
200000: 31 C9 F6 F1
R
```

* `31 C9` is the `XOR ECX, ECX` instruction. This sets the ECX register to 0.
* `F6 F1` is the `DIV CL` instruction. It will divide the AX register by CL.

This program will cause a divide by zero exception that is handled by the BareMetal kernel.


### Test Program #3 - Hello world

```
FFFF800000000000: 48 BE 17 00 00 00 00 80
FFFF800000000008: FF FF B9 0E 00 00 00 FF
FFFF800000000010: 14 25 18 00 10 00 C3 48
FFFF800000000018: 65 6C 6C 6F 2C 20 77 6F
FFFF800000000020: 72 6C 64 21 0D
FFFF800000000000
R
```

* `48 BE 17 00 00 00 00 80 FF FF` is the `MOV RSI, 0xFFFF800000000017` instruction. It loads the RSI register with the address of the string.
* `B9 0E 00 00 00` is the `MOV ECX, 0x0E` instruction. It loads the ECX register with the number of characters we want to output.
* `FF 14 25 18 00 10 00` is the `CALL [0x100018]` instruction. It calls a kernel function for outputting characters.
* `C3` is the `RET` instruction. The CPU returns back to Wozmon.
* The remaining hex bytes contain the string data "Hello, world!"


## Uploading your own code

1) Write your program and assemble/compile it.

2) Create the output that wozmon can use:

`hexdump -e '"FFFF800000000%03_ax: " 8/1 "%02X " "\n"' your.app`

3) Manually type the output or copy/past via serial.

4) Type the starting address and `R`.

The `hexdump` command above was originally written by Ben Eater.

// EOF

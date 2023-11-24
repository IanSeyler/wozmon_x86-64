# Wozmon x86-64

A rewrite of Wozmon in x86-64 for the BareMetal kernel.


## Prerequisites

The scripts in this repo depend on a Debian-based Linux system like [Ubuntu](https://www.ubuntu.com/download/desktop) or [Elementary](https://elementary.io). macOS is also supported if you are using [Homebrew](https://brew.sh).

- [NASM](https://nasm.us) - Assembly compiler to build the loader and kernel, as well as the apps written in Assembly.

In Linux this can be completed with the following command:

	sudo apt install nasm


## Memory Layout

The BareMetal kernel uses the first 2MiB of RAM. Wozmon runs within the BareMetal kernel memory. All other available RAM is mapped at 0xFFFF800000000000


## Usage

* On startup a `\\` will be displayed

* Wozmon will intrepret any hexadecimal value as a memory address. Wozmon will display the memory address and the 8-bit value at that address.

```
1E0000
00000000001E0000: 8A
```

* Entering a hexadecimal value followed by a ':' will allow you to write bytes starting at that memory address.

```
FFFF800000000000:

```

* Entering `R` will run the code at the last provided address.

// EOF

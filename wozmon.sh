#!/bin/bash

set -e
export EXEC_DIR="$PWD"
export OUTPUT_DIR="$EXEC_DIR/sys"

function baremetal_clean {
	rm -rf os
	rm -rf sys
	rm -rf src/api
}

function baremetal_setup {
	baremetal_clean

	mkdir src/api
	mkdir sys
	cd src/api
	if [ -x "$(command -v curl)" ]; then
		curl -s -o libBareMetal.asm https://raw.githubusercontent.com/ReturnInfinity/BareMetal/master/api/libBareMetal.asm
	else
		wget -q https://raw.githubusercontent.com/ReturnInfinity/BareMetal/master/api/libBareMetal.asm
	fi
	cd ../..
	
	mkdir os

	echo "Pulling code from GitHub..."
	cd os
	git clone https://github.com/ReturnInfinity/Pure64.git -q
	git clone https://github.com/ReturnInfinity/BareMetal.git -q
	cd ..

	echo "Creating disk image..."
	cd sys
	dd if=/dev/zero of=disk.img count=128 bs=1048576 > /dev/null 2>&1
	cd ..

	baremetal_build

	baremetal_install

	echo Done!
}

function build_dir {
	echo "Building $1..."
	cd "$1"
	if [ -e "build.sh" ]; then
		./build.sh
	fi
	if [ -e "install.sh" ]; then
		./install.sh
	fi
	if [ -e "Makefile" ]; then
		make --quiet
	fi
	cd "$EXEC_DIR"
}

function baremetal_build {
	cd src
	nasm wozmon.asm -o ../sys/wozmon.bin -l ../sys/wozmon-debug.txt
	cd ..
	build_dir "os/Pure64"
	build_dir "os/BareMetal"

	mv "os/Pure64/bin/mbr.sys" "${OUTPUT_DIR}/mbr.sys"
	mv "os/Pure64/bin/pure64.sys" "${OUTPUT_DIR}/pure64.sys"
	mv "os/Pure64/bin/pure64-debug.txt" "${OUTPUT_DIR}/pure64-debug.txt"
	mv "os/BareMetal/bin/kernel.sys" "${OUTPUT_DIR}/kernel.sys"
	mv "os/BareMetal/bin/kernel-debug.txt" "${OUTPUT_DIR}/kernel-debug.txt"
}

function baremetal_install {
	cd "$OUTPUT_DIR"
	echo "Building OS image..."

	if [ "$#" -ne 1 ]; then
		cat pure64.sys kernel.sys wozmon.bin > software.sys
	else
		cat pure64.sys kernel.sys $1 > software.sys
	fi

	dd if=mbr.sys of=disk.img conv=notrunc > /dev/null 2>&1
	dd if=software.sys of=disk.img bs=4096 seek=2 conv=notrunc > /dev/null 2>&1
}


function baremetal_run {
	echo "Starting QEMU..."
	cmd=( qemu-system-x86_64
		-machine q35
		-name "BareMetal OS"
		-m 256
		-smp sockets=1,cpus=4
		-drive id=disk0,file="sys/disk.img",if=none,format=raw
		-device ahci,id=ahci
		-device ide-hd,drive=disk0,bus=ahci.0
		-chardev stdio,id=char0,signal=off
		-serial chardev:char0
	)

	#execute the cmd string
	"${cmd[@]}"
}


function baremetal_help {
	echo "BareMetal Wozmon Script"
	echo "Available commands:"
	echo "clean    - Clean the os and bin folders"
	echo "setup    - Clean and setup"
	echo "build    - Build source code"
	echo "install  - Install binary to disk image"
	echo "run      - Run the OS via QEMU"
}

if [ $# -eq 0 ]; then
	baremetal_help
elif [ $# -eq 1 ]; then
	if [ "$1" == "setup" ]; then
		baremetal_setup
	elif [ "$1" == "clean" ]; then
		baremetal_clean
	elif [ "$1" == "build" ]; then
		baremetal_build
	elif [ "$1" == "install" ]; then
		baremetal_install
	elif [ "$1" == "help" ]; then
		baremetal_help
	elif [ "$1" == "run" ]; then
		baremetal_run
	else
		echo "Invalid argument '$1'"
	fi
fi

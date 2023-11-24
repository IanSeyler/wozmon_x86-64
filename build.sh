#!/bin/bash

cd src
nasm wozmon.asm -o ../bin/wozmon.bin -l ../bin/wozmon-debug.txt

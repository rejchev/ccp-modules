#!/bin/bash

cd $1
files=(*.sp)

for file in "${files[@]}"; do
    ./spcomp $file -E -v0 
done
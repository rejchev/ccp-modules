#!/bin/bash

cd $1
files=(*.sp)

for file in "${files[@]}"; do

    filename=$(basename -- "$file")
    filename="${filename%.*}"

    ./spcomp $file -E -v0

    if [ ! -e $filename'.smx' ]; then
        exit 1
    fi
done

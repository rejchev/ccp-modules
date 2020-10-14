#!/bin/bash

cd $1
files=(*.sp)

# ERRORS="errors.log"

for file in "${files[@]}"; do

    filename=$(basename -- "$file")
    filename="${filename%.*}"

    # echo $filename

    ./spcomp $file -E -o'/compiled/'$filename -v0

    if [ ! -e '/compiled/'$filename ]; then
        exit 1
        break
    fi
done
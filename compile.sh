#!/bin/bash

echo $1
cd $1
files=(*.sp)

for file in "${files[@]}"; do
    # if [[ -e "${files[$file]}" ]]; then
    #     continue
    # fi
    echo $file
    ./spcomp $file -E -v0 
done
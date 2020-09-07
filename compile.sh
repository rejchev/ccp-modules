#!/bin/bash

cd $1
files=(*.sp)

for file in "${files[@]}"; do
    # if [[ -e "${files[$file]}" ]]; then
    #     continue
    # fi

    ./spcomp -E -v0 "${files[$file]}"
done
#!/bin/bash

cd $1
files=(*.sp)

for file in ${files[@]};
do
    ./spcomp -E -v0 ${files[$file]}
done

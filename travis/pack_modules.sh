#!/bin/bash

modules=$1
build=$2

# ERROR=1

cd $modules

derictories=($(ls -d */))

for dir in "${derictories[@]}"; do

    dir=$modules'/'$dir
    name=$(basename -- "$dir")

    tar -czvf ${name}-${build}.tar.gz $name

    rm -Rfv $dir
done
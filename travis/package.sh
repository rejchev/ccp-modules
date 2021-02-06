#!/bin/bash

modules=$1
build=$2

# ERROR=1

cd $modules

derictories=($(ls -d */))

for dir in "${derictories[@]}"; do

    dir=$modules'/'$dir
    name=$(basename -- "$dir")

    cd $dir
    
    tar -czvf ${name}-${build}.tar.gz *
    cp ${name}-${build}.tar.gz ../

    cd ../
    rm -Rfv $dir
done
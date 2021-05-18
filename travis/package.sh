#!/bin/bash

modules=$1
build=$2
DISABLED='disabled'

# ERROR=1

cd $modules

derictories=($(ls -d */))

for dir in "${derictories[@]}"; do

    dir=$modules'/'$dir
    name=$(basename -- "$dir")

    if [ ! ${name} = ${DISABLED} ]; then
        cd $dir
    
        tar -czvf ${name}-${build}.tar.gz *
        cp ${name}-${build}.tar.gz ../

        cd ../
    fi

    rm -Rfv $dir
done
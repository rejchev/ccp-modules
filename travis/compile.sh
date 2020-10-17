#!/bin/bash

travis=$1
modules=$2
spsrc=$3
includes=$4

ERROR=1

cd $modules

derictories=($(ls -d */))

for dir in "${derictories[@]}"; do

    dir=$(basename -- "$dir")
    module=$modules'/'$dir
    modulebin=$module'/plugins'
    modulesrcs=$module'/scripting'

    mkdir $modulebin

    cd $modulesrcs

    srcs=(*.sp)

    cd $modules

    for src in "${srcs[@]}"; do

        src=$modulesrcs'/'$src
        filename=$(basename -- "$src")
        filenoext="${filename%.*}"

        bin=$modulebin'/'$filenoext'.smx'
        
        $spsrc'/spcomp' $src -E -v1 -i=$includes -o=$bin

        if [ ! -e $bin ]; then
            echo "File ${bin} is not exists"
            exit $ERROR
        fi
    done
done
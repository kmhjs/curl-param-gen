#! /usr/bin/env zsh -f

mkdir -p lib
curl https://raw.githubusercontent.com/kmhjs/zcl/master/zcl > ./lib/zcl
curl https://raw.githubusercontent.com/kmhjs/shrink/master/lib/option/src/option_extension.zsh > ./lib/option_extension.zsh
curl https://raw.githubusercontent.com/kmhjs/shrink/master/lib/array/src/array_extension.zsh > ./lib/array_extension.zsh

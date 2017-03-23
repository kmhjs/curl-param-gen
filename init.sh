#! /usr/bin/env zsh -f

mkdir -p lib
curl https://raw.githubusercontent.com/kmhjs/zcl/master/zcl > ./lib/zcl
curl https://raw.githubusercontent.com/kmhjs/shrink/master/lib/option/src/value_pop.zsh > ./lib/value_pop.zsh

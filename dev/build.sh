#!/usr/bin/env bash

dir=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)

cd ${dir}/.. && docker build --no-cache -t newtoncodes/iredmail .
cd ${dir}/.. && docker build --no-cache -t newtoncodes/iredmail:0.9.7 .

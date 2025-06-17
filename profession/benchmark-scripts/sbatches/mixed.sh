#!/usr/bin/env bash

# Usage:  pyfr-select.sh <backend> <mesh> <cfg>

if   [[ ${OMPI_COMM_WORLD_RANK} -eq  0 ]]; then CMD="pyfr run -Plb -bcuda   "
else                                            CMD="pyfr run -Plb -bopenmp "
fi

echo $CMD $@
eval $CMD $@
#!/usr/bin/env bash

# Usage:  pyfr-select.sh <backend> <mesh> <cfg>

if   [[ ${OMPI_COMM_WORLD_RANK} -eq  0 ]]
then 
export CUDA_VISIBLE_DEVICES=0
CMD="pyfr run -Plb -bcuda "

elif [[ ${OMPI_COMM_WORLD_RANK} -eq  12 ]]
then 

export CUDA_VISIBLE_DEVICES=1
CMD="pyfr run -Plb -bcuda "

else

CMD="pyfr run -Plb -bopenmp "
fi

# Echo rank and CUDA
echo "Rank ${OMPI_COMM_WORLD_RANK} using CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES}"

echo $CMD $@
eval $CMD $@
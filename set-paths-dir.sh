#!/usr/bin/env bash

# Helper: manage directory tree for HPC scratch space
# Usage: source set-paths-dir.sh and call set_paths <scratch_dir>
# Requires: none

# ------------------------------------------------------------------------------
# Essential environment variables
# ------------------------------------------------------------------------------

# Verify that the scratch directory exists

set_paths() 
{
    SCRATCH="${1}"

    if [   -z "$SCRATCH" ]; then echo -e "\e[31m ERROR: scratch directory not set! \e[0m" ; exit 1 ; fi
    if [ ! -d "$SCRATCH" ]; then echo -e "\e[31m ERROR: $SCRATCH does not exist! \e[0m"   ; exit 1 ; fi

    export EFFORTS="$SCRATCH/EFFORTS/"
    export VENVS="$SCRATCH/.venvs/"
    export WORKSPACES="$SCRATCH/.workspaces/"
    export SUPPLEMENTARY="$SCRATCH/supplementary/"
    export MESHES="$SUPPLEMENTARY/gmsh-files/"
    export PARTITIONS="$SUPPLEMENTARY/pyfr-native-files/"
    export GITHUB="$SCRATCH/.github/"
    export SAMBITMISHRA98="$GITHUB/sambitmishra98/"
    export PYFR_BRANCHES="$SCRATCH/.pyfr-branches/"
    export SAMBITMISHRA98_PYFR="$PYFR_BRANCHES/sambitmishra98/"
    export SAMBITMISHRA98_PYFR_DEVELOP="$SAMBITMISHRA98_PYFR/develop/"
    export LOCAL="$SCRATCH/.local/"
    export DOWNLOADS="$LOCAL/downloads/"
    export EXTRACTS="$LOCAL/extracts/"
    export INSTALLS="$LOCAL/installs/"
}

check_paths()
{
    for path in "$EFFORTS" \
                "$VENVS" \
                "$WORKSPACES" \
                "$SUPPLEMENTARY" "$MESHES" "$PARTITIONS" \
                "$GITHUB" "$SAMBITMISHRA98" \
                "$PYFR_BRANCHES" "$SAMBITMISHRA98_PYFR" \
                "$LOCAL" "$DOWNLOADS" "$EXTRACTS" "$INSTALLS"; do
        if [ -d "${path}" ] ; then echo -e "\e[1;32m Exists: \e[0m ${path}"
        else                       echo -e "\e[1;31m Doesn't exist: \e[0m ${path}"
        fi
    done
}

create_paths()
{
    # Create paths if they do not exist. Echo the newly created paths
    # Use a for loop

    for path in "$SCRATCH" \
                "$EFFORTS" \
                "$VENVS" \
                "$WORKSPACES" \
                "$SUPPLEMENTARY" "$MESHES" "$PARTITIONS" \
                "$GITHUB" "$SAMBITMISHRA98" \
                "$PYFR_BRANCHES" "$SAMBITMISHRA98_PYFR" \
                "$LOCAL" "$DOWNLOADS" "$EXTRACTS" "$INSTALLS"; do
        if [ ! -d "${path}" ]; then
            mkdir -p "${path}"
            echo -e "\e[1;32m Directory created: \e[0m ${path}"
        fi
    done
}

print_paths() 
{


    # Display essential variables
    echo -e "\e[1;32m--------------------\e[0m"
    echo -e "\e[1;32mEssential variables:\e[0m"
    echo -e "\e[1;32m--------------------\e[0m"
    # Display essential variables in a tree structure
    echo -e "\e[1;32mEssential variables:\e[0m"
    echo -e "└─ SCRATCH:                            $SCRATCH"
    echo -e "   ├─ EFFORTS:                         $EFFORTS"
    echo -e "   ├─ VENVS:                           $VENVS"
    echo -e "   ├─ WORKSPACES:                      $WORKSPACES"
    echo -e "   ├─ SUPPLEMENTARY:                   $SUPPLEMENTARY"
    echo -e "   │   ├─ MESHES:                      $MESHES"
    echo -e "   │   └─ PARTITIONS:                  $PARTITIONS"
    echo -e "   ├─ GITHUB:                          $GITHUB"
    echo -e "   │   └─ SAMBITMISHRA98:              $SAMBITMISHRA98"
    echo -e "   ├─ PYFR_BRANCHES:                   $PYFR_BRANCHES"
    echo -e "   │   ├─ SAMBITMISHRA98_PYFR:         $SAMBITMISHRA98_PYFR"
    echo -e "   │   └─ SAMBITMISHRA98_PYFR_DEVELOP: $SAMBITMISHRA98_PYFR_DEVELOP"
    echo -e "   └─ LOCAL:                           $LOCAL"
    echo -e "       ├─ DOWNLOADS:                   $DOWNLOADS"
    echo -e "       └─ EXTRACTS:                    $EXTRACTS"
    echo -e "       └─ INSTALLS:                    $INSTALLS"
    echo -e "\e[1;32m--------------------\e[0m"
}

#!/usr/bin/env bash

# Helper: display library and PyFR additional paths
# Usage: source set-paths-lib.sh
# Requires: paths set by set_paths

# ------------------------------------------------------------------------------
# Essential environment variables
# ------------------------------------------------------------------------------

# Verify that the scratch directory exists


print_libraries_versions()
{
    echo -e "\e[1;32m--------------------\e[0m"
    echo -e "\e[1;32mLibrary paths:\e[0m"
    echo -e "\e[1;32m--------------------\e[0m"
}

print_pyfr_extra_functionality_paths()
{
    echo -e "\e[1;32m--------------------\e[0m"
    echo -e "\e[1;32mPyFR extra functionality paths:\e[0m"
    echo -e "\e[1;32m--------------------\e[0m"

}


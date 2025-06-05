#!/usr/bin/env bash
# THIS IS A TEMPLATE ONLY.

# Call this file from your ~/.bashrc or other shell rc file after you have
# copied it locally.
# Replace the placeholder values below with your own usernames, hostnames and
# preferred scratch paths.
# Examples are provided in the comments.

# LOCAL
export local_user="sambit98"                # e.g. "myusername"
export local_ip="spitfire.engr.tamu.edu"    # e.g. "cluster.example.edu"

# CONSCIOUSNESS
export dest_local="/scratch/.sync/dest_consciousness"   # e.g. "/scratch/<user>/dest"
export  src_local="/scratch/.sync/src_consciousness"    # e.g. "/scratch/<user>/src"

export consciousness_user="sambit"          # remote login user
export consciousness_ip="10.125.213.39"     # remote host or IP

export dest_consciousness="$consciousness_user@$consciousness_ip:/scratch/.sync/dest_spitfire" # edit remote path as needed
export  src_consciousness="$consciousness_user@$consciousness_ip:/scratch/.sync/src_spitfire"  # edit remote path as needed

## set up alias for pvpython and pvbatch
alias pvpython="~/pvpython"
alias pvbatch="~/pvbatch"

# SECURITY NOTE:
# Avoid committing real credentials or hostnames to version control. Store this
# file outside the repository or add it to your .gitignore once populated.
# Consider using environment variables or SSH configuration files for any
# authentication information.

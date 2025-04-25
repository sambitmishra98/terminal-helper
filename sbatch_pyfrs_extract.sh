#!/usr/bin/env bash
#-------------------------------------------------------------------------------
# extract_pyfrs_stats.sh
#-------------------------------------------------------------------------------
# Version:        1.1.0
# Last Modified:  2025-04-20
# Author:         sambit98
# Description:
#   Utility functions to extract stats from .pyfrs (HDF5) files and collate them
#   into CSV. Designed to be robust, portable (POSIX shell), and well-documented.
#-------------------------------------------------------------------------------

# set -o errexit   # Exit on any error
set -o nounset   # Error on unset variables
set -o pipefail  # Propagate pipeline errors

#-------------------------------------------------------------------------------
# Dependencies:
#   h5dump, realpath, grep, awk, mkdir, tr
#-------------------------------------------------------------------------------
check_dependencies() {
  for cmd in h5dump realpath grep awk tr mkdir; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "[ERROR] Required command '$cmd' not found." >&2
      exit 1
    fi
  done
}

#-------------------------------------------------------------------------------
# extract_pyfrs_stats: Get a single stat from /stats
#-------------------------------------------------------------------------------
extract_pyfrs_stats() {
  infile="$1"; key="$2"
  [ -z "$infile" ] || [ -z "$key" ] && { echo "NA"; return 0; }
  [ -f "$infile" ] || { echo "NA"; return 0; }

  filepath=$(realpath "$infile")
  pattern="${key} ="

  h5dump -d /stats "$filepath" 2>/dev/null \
    | grep -F -- "$pattern" \
    | head -n 1 \
    | awk -F'= ' '{print $2}' \
    | tr -d ' \r\n' || echo "NA"
}

#-------------------------------------------------------------------------------
# extract_pyfrs_stats_diff: Difference between two stats
#-------------------------------------------------------------------------------
extract_pyfrs_stats_diff() {
  file1="$1"; file2="$2"; key="$3"
  v1=$(extract_pyfrs_stats "$file1" "$key")
  v2=$(extract_pyfrs_stats "$file2" "$key")
  case "$v1:$v2" in
    NA:*|*':NA') echo "NA" ;; 
    *) awk "BEGIN {print $v2 - $v1}" ;; 
  esac
}

#-------------------------------------------------------------------------------
# extract_pyfrs_to_csv: Append stats to a CSV file
#-------------------------------------------------------------------------------
# Usage: extract_pyfrs_to_csv <input.pyfrs> <dest.csv> <key1> [key2 ...]
#  - auto-generates header on first run:
#      single values → 'key'
#      multi-values (comma list) → 'key-r0','key-r1',...
#  - missing entries → 'NA'
#  - errors in red if file not found
#-------------------------------------------------------------------------------
extract_pyfrs_stats_to_csv() {
  infile="$1"; csv="$2"; shift 2
  # ensure input exists
  if [ ! -f "$infile" ]; then
    echo -e "\e[31m[ERROR]\e[0m File '$infile' not found." >&2
    return 1
  fi
  mkdir -p "$(dirname "$csv")"

  # build header if needed
  if [ ! -f "$csv" ]; then
    hdr="filename"
    for key in "$@"; do
      val=$(extract_pyfrs_stats "$infile" "$key")
      [ -z "$val" ] && val="NA"
      # count commas
      num_comma=$(printf '%s' "$val" | awk -F',' '{print NF-1}')
      num_fields=$((num_comma + 1))
      if [ "$num_fields" -gt 1 ]; then
        idx=0
        while [ "$idx" -lt "$num_fields" ]; do
          hdr+=",${key}-r${idx}"
          idx=$((idx+1))
        done
      else
        hdr+=",${key}"
      fi
    done
    echo "$hdr" > "$csv"
  fi

  # append row
  row="$infile"
  for key in "$@"; do
    val=$(extract_pyfrs_stats "$infile" "$key")
    [ -z "$val" ] && val="NA"
    OLD_IFS=$IFS; IFS=','
    for part in $val; do
      row+=",${part}"
    done
    IFS=$OLD_IFS
  done
  echo "$row" >> "$csv"

  # summary
  echo "Processed: $infile"
  for key in "$@"; do
    val=$(extract_pyfrs_stats "$infile" "$key")
    [ -z "$val" ] && val="NA"
    echo "  $key = $val"
  done
}

#-------------------------------------------------------------------------------
# Initialization: check deps when sourced
#-------------------------------------------------------------------------------
if [ "${BASH_SOURCE[0]}" != "\$0" ]; then
  check_dependencies
else
  echo "This file is meant to be sourced, not executed directly." >&2
  exit 1
fi

#-------------------------------------------------------------------------------
# extract_all_pyfrs_to_csv_rec: Recursively scan for <pattern> and append stats
#-------------------------------------------------------------------------------
# Usage:
#   extract_all_pyfrs_to_csv_rec <directory> <glob-pattern> <output.csv> <keys...>
#
# Example:
#   extract_all_pyfrs_to_csv_rec \
#     /mnt/.../NUMA-wait \
#     '*.pyfrs' \
#     stats.csv \
#     wall-time \
#     rhs-graph-0-send-median \
#     rhs-graph-1-send-median
#-------------------------------------------------------------------------------
extract_all_pyfrs_to_csv_rec() {
  local dir="$1"
  local pattern="$2"
  local csv="$3"
  shift 3
  local keys=("$@")

  # sanity
  if [[ ! -d "$dir" ]]; then
    echo "[ERROR] '$dir' is not a directory" >&2
    return 1
  fi
  mkdir -p "$(dirname "$csv")"

  # find + sort to get a deterministic order
  find "$dir" -type f -name "$pattern" | sort | while read -r file; do
    extract_pyfrs_stats_to_csv "$file" "$csv" "${keys[@]}"
  done
}

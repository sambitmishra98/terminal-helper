#!/bin/bash

# Usage:   extract_pyfrs_stats <file.pyfrs> <key>
# Output:  value corresponding to given key

# val1=$(extract_pyfrs_stats writer-waitall-2.pyfrs  wall-time)
# val2=$(extract_pyfrs_stats writer-waitsome-2.pyfrs rhs-graph-0-mean)
# val3=$(extract_pyfrs_stats writer-waitsome-2.pyfrs rhs-graph-1-recv-median)
extract_pyfrs_stats() {

  local file="$1"
  local key="$2"

  if [ ! -f "$file" ]; then
    echo "NA"
    return
  fi

  h5dump -d /stats "$file" 2>/dev/null \
    | grep -F "$key =" \
    | head -n 1 \
    | awk -F'= ' '{print $2}' \
    | tr -d ' \r\n'
}

# Writes one file's stats as one row in the CSV
# Usage: extract_pyfrs_to_csv <file> <output_csv> <key1> <key2> ...
extract_pyfrs_to_csv() {
  local file="$1"
  local outfile="$2"
  shift 2
  local keys=("$@")

  # Header if CSV doesn't exist
  if [ ! -f "$outfile" ]; then
    echo "file,$(IFS=','; echo "${keys[*]}")" > "$outfile"
  fi

  # Compose one row
  row="$file"
  for key in "${keys[@]}"; do
    val=$(extract_pyfrs_stats "$file" "$key")
    row="${row},${val}"
  done
  echo "$row" >> "$outfile"
}

# Recursively apply the per-file extractor
# Usage: extract_all_pyfrs_to_csv <output_csv> <key1> <key2> ...
extract_pyfrs_all_to_csv() {
  local outfile="$1"
  shift
  local keys=("$@")

  find . -type f -name "*.pyfrs" | sort | while read file; do
    extract_pyfrs_to_csv "$file" "$outfile" "${keys[@]}"
  done
}

# Usage: extract_diff_pyfrs_stats_value <file1> <file2> <key>
# Output: file2[key] - file1[key] (float difference)
extract_pyfrs_stats_diff() {

  local file1="$1"
  local file2="$2"
  local key="$3"

  local val1=$(extract_pyfrs_stats "$file1" "$key")
  local val2=$(extract_pyfrs_stats "$file2" "$key")

  if [[ "$val1" == "NA" || "$val2" == "NA" ]]; then
    echo "NA"
  else
    awk "BEGIN {print $val2 - $val1}"
  fi
}
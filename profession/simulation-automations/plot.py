#!/usr/bin/env python3
import argparse
import sys
import os
import pandas as pd
import matplotlib.pyplot as plt

def main():
    parser = argparse.ArgumentParser(
        description='Plot columns from a CSV file.')
    parser.add_argument('csv_file', help='Path to the CSV file')
    parser.add_argument('xcol', help='Column name for the X axis')
    parser.add_argument('ycols', nargs='+', help='Column names for Y axes')
    parser.add_argument('--logy', action='store_true',
                        help='Use logarithmic scale for Y axis')
    parser.add_argument('--xmin', type=float,
                        help='Minimum limit for X axis; if negative, offset from max X')
    parser.add_argument('--xmax', type=float,
                        help='Maximum limit for X axis; if negative, offset from max X')
    args = parser.parse_args()

    csv_path = args.csv_file
    output_path = os.path.splitext(csv_path)[0] + '.png'

    # Read CSV and normalize headers
    try:
        df = pd.read_csv(csv_path)
    except Exception as e:
        print(f'Error reading CSV file: {e}', file=sys.stderr)
        sys.exit(1)
    df.columns = df.columns.str.strip()

    # Normalize column args
    xcol = args.xcol.strip()
    ycols = [y.strip() for y in args.ycols]

    # Validate columns
    missing = [col for col in [xcol] + ycols if col not in df.columns]
    if missing:
        print(f'Error: Columns not found in CSV: {missing}', file=sys.stderr)
        sys.exit(1)

    # Extract X data and compute data bounds
    xvals = df[xcol]
    data_min_x, data_max_x = xvals.min(), xvals.max()

    # Create plot
    fig, ax = plt.subplots(figsize=(20, 5), dpi=300)
    if args.logy:
        ax.set_yscale('log')

    for y in ycols:
        ax.plot(xvals, df[y], label=y)

    ax.set_xlabel(xcol)
    ax.legend()

    # Determine X-axis limits
    xmin, xmax = data_min_x, data_max_x
    if args.xmin is not None:
        if args.xmin < 0:
            xmin = data_max_x + args.xmin
        else:
            xmin = args.xmin
    if args.xmax is not None:
        if args.xmax < 0:
            xmax = data_max_x + args.xmax
        else:
            xmax = args.xmax
    ax.set_xlim(xmin, xmax)

    plt.tight_layout()

    # Save and show
    plt.savefig(output_path)
    print(f'Plot saved to {output_path}')
    plt.show()

if __name__ == '__main__':
    main()
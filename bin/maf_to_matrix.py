#! /usr/bin/env python3

## Copyright 2010, 2011, 2013, 2014 Martin C. Frith
## SPDX-License-Identifier: GPL-3.0-or-later
##
## DERIVATIVE WORK:

## LAST's original maf-convert script was edited by M365 Copilot
## under instructions of Charles Plessy to extract an alignment-derived
## substitution matrix and compute evolutionary distances.

import sys
import gzip
import math

# ---------------------------------------
# I/O
# ---------------------------------------

def myOpen(fileName):
    if fileName == "-":
        return sys.stdin
    if fileName.endswith(".gz"):
        return gzip.open(fileName, "rt")
    return open(fileName)


# ---------------------------------------
# Minimal MAF parser (compatible behavior)
# ---------------------------------------

def mafInput(lines):
    aLine = ""
    sLines = []

    for line in lines:
        if not line.strip():
            if sLines:
                yield aLine, sLines
                aLine = ""
                sLines = []
            continue

        if line.startswith("a"):
            aLine = line

        elif line.startswith("s"):
            parts = line.split()
            seqName = parts[1]
            beg = int(parts[2])
            span = int(parts[3])
            strand = parts[4]
            seqLen = int(parts[5])
            row = parts[6]

            # keep tuple shape compatible with original indexing
            sLines.append((seqName, seqLen, strand, 1, beg, beg + span, row))

    if sLines:
        yield aLine, sLines


# ---------------------------------------
# Matrix + distances (faithful reproduction)
# ---------------------------------------

def writeMatrixMetadata(meta):
    keys = (
        "format","scope","alphabet","rows","cols",
        "source","blocks","columns_analyzed",
        "non_acgt_letters_as","case_insensitive",
        "P_acgt","F81_acgt","JC69_acgt","K80_acgt","T92_acgt"
    )
    for k in keys:
        if k in meta and meta[k] is not None:
            print("# %s: %s" % (k, meta[k]))


def writeMatrix(matrix, symbols):
    header = [''] + symbols
    print('\t'.join(header))
    for r in symbols:
        row = [r] + [str(matrix[r][c]) for c in symbols]
        print('\t'.join(row))


def _prob_list_from_matrix(matrix, symbols):
    total = sum(sum(matrix[r][c] for c in symbols) for r in symbols)
    probs = {}
    if total == 0:
        for r in symbols:
            for c in symbols:
                probs[f"probability_{r}_{c}"] = 0.0
        return probs

    for r in symbols:
        for c in symbols:
            probs[f"probability_{r}_{c}"] = matrix[r][c] / total
    return probs


def _P_from_prob_list(pl):
    off_keys = [
        "probability_A_C","probability_A_G","probability_A_T",
        "probability_C_A","probability_C_G","probability_C_T",
        "probability_G_A","probability_G_C","probability_G_T",
        "probability_T_A","probability_T_C","probability_T_G",
    ]
    return sum(pl.get(k, 0.0) for k in off_keys)


def _F81_from_prob_list(pl):
    bases = ['A','C','G','T']
    row_probs = {
        b: sum(pl[f"probability_{b}_{c}"] for c in bases)
        for b in bases
    }
    col_probs = {
        b: sum(pl[f"probability_{r}_{b}"] for r in bases)
        for b in bases
    }
    avg = [(row_probs[b] + col_probs[b]) / 2.0 for b in bases]
    E = 1.0 - sum(a*a for a in avg)
    p = _P_from_prob_list(pl)
    if p >= E:
        return 'Inf'
    return "%.6g" % (-E * math.log((E - p) / E))


def _JC69_distance(pl):
    p = _P_from_prob_list(pl)
    arg = 1.0 - 4.0 * p / 3.0
    if arg <= 0.0:
        return 'Inf'
    return "%.6g" % (-0.75 * math.log(arg))


def _K80_distance(pl):
    p = sum(pl.get(k, 0.0) for k in (
        "probability_A_G","probability_G_A",
        "probability_T_C","probability_C_T"))
    q = sum(pl.get(k, 0.0) for k in (
        "probability_A_C","probability_C_A",
        "probability_G_T","probability_T_G",
        "probability_A_T","probability_T_A",
        "probability_C_G","probability_G_C"))

    arg1 = 1.0 - 2.0 * p - q
    arg2 = 1.0 - 2.0 * q
    if arg1 <= 0.0 or arg2 <= 0.0:
        return 'Inf'

    return "%.6g" % (-0.5 * math.log(arg1 * math.sqrt(arg2)))


def _T92_distance(pl):
    theta = pl.get("probability_G_G", 0.0) + pl.get("probability_C_C", 0.0)
    h = 2.0 * theta * (1.0 - theta)

    p = sum(pl.get(k, 0.0) for k in (
        "probability_A_G","probability_G_A",
        "probability_T_C","probability_C_T"))
    q = sum(pl.get(k, 0.0) for k in (
        "probability_A_C","probability_C_A",
        "probability_G_T","probability_T_G",
        "probability_A_T","probability_T_A",
        "probability_C_G","probability_G_C"))

    arg1 = 1.0 - (p / h if h > 0.0 else float('inf')) - q
    arg2 = 1.0 - 2.0 * q

    if h == 0.0 or arg1 <= 0.0 or arg2 <= 0.0:
        return 'Inf'

    return "%.6g" % (-h * math.log(arg1) - 0.5 * (1.0 - h) * math.log(arg2))


# ---------------------------------------
# Main matrix conversion
# ---------------------------------------

def mafConvertToMatrix(lines, source_name):
    symbols = ['A','C','G','T','N','-']
    matrix = {r: {c: 0 for c in symbols} for r in symbols}

    blocks = 0
    columns = 0

    for _, sLines in mafInput(lines):
        if len(sLines) < 2:
            continue

        rowA = sLines[0][6]
        rowB = sLines[1][6]

        for a, b in zip(rowA, rowB):
            a = a.upper()
            b = b.upper()

            if a not in matrix:
                a = 'N'
            if b not in matrix:
                b = 'N'

            matrix[a][b] += 1

        blocks += 1
        columns += len(rowA)

    pl = _prob_list_from_matrix(matrix, symbols)

    meta = {
        "format": "matrix",
        "scope": "file",
        "alphabet": "A,C,G,T,N,-",
        "rows": "target",
        "cols": "query",
        "source": source_name,
        "blocks": blocks,
        "columns_analyzed": columns,
        "non_acgt_letters_as": "N",
        "case_insensitive": "true",
        "P_acgt": "%.6g" % _P_from_prob_list(pl),
        "F81_acgt": _F81_from_prob_list(pl),
        "JC69_acgt": _JC69_distance(pl),
        "K80_acgt": _K80_distance(pl),
        "T92_acgt": _T92_distance(pl),
    }

    writeMatrixMetadata(meta)
    writeMatrix(matrix, symbols)


# ---------------------------------------
# Main
# ---------------------------------------

def main():
    # If no arguments are given, read from stdin ("-")
    if len(sys.argv) < 2:
        file_names = ["-"]
    else:
        file_names = sys.argv[1:]

    for fname in file_names:
        with myOpen(fname) as f:
            mafConvertToMatrix(f, source_name=fname)

if __name__ == "__main__":
    main()

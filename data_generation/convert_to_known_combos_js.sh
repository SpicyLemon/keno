#!/bin/bash
if [[ -z "$1" ]]; then
    echo "Usage: $0 <combos json file>"
    return 0
elif [[ ! -r "$1" ]]; then
    echo "Cannot read file [$1]."
    return 1
fi
jq -r ' .[] | "        \"" + .n + "_C_" + .k + "\": " + .nCk + "," ' "$1"

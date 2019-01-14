#!/bin/bash

TOOL_DIR="$HOME/Tools"
SELF_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

SYGUS_OUTPUT_FILE="/tmp/eu.$(basename $2).$(basename $1).out"
SYGUS_WITH_GRAMMAR_FILE="/tmp/eu.$(basename $2).$(basename $1)"
SYGUS_NAME_MAPPING_FILE="/tmp/eu.$(basename $2).$(basename $1).map"

"$SELF_DIR"/../_build/install/default/bin/transform \
  -c -r -s "$SYGUS_NAME_MAPPING_FILE" -t -g $2 $1 \
  > "$SYGUS_WITH_GRAMMAR_FILE"

PYPATH="$TOOL_DIR/EUSolver/thirdparty/Python-3.5.1/python"
Z3_LIBRARY_PATH="$TOOL_DIR"/EUSolver/thirdparty/z3/build/python

if [ -z "$PYPATH" ]; then
  echo "python3 not found"
else
  sed -i 's/^import pkg_resources/# &/' "$TOOL_DIR"/EUSolver/thirdparty/z3/build/python/z3/z3core.py
  sed -i 's!^\(\s*\)_dirs =.*$!\1_dirs = ["'$Z3_LIBRARY_PATH'"]!' "$TOOL_DIR"/EUSolver/thirdparty/z3/build/python/z3/z3core.py
  PYTHONPATH="$TOOL_DIR"/EUSolver/thirdparty/libeusolver/build:"$TOOL_DIR"/EUSolver/thirdparty/z3/build/python \
    "$PYPATH" "$TOOL_DIR"/EUSolver/bin/benchmarks.py "$SYGUS_WITH_GRAMMAR_FILE" > "$SYGUS_OUTPUT_FILE"

  while read -u 23 p ; do
    sed -i $p "$SYGUS_OUTPUT_FILE"
  done 23< "$SYGUS_NAME_MAPPING_FILE"
  cat "$SYGUS_OUTPUT_FILE"
fi

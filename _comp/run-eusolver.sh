#!/bin/bash

TOOL_DIR="$HOME/Tools"
SELF_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

if [ -n "$2" ]; then
  SYGUS_WITH_GRAMMAR_FILE="/tmp/eu.$(basename $2).$(basename $1)"
  "$SELF_DIR"/../_build/install/default/bin/transform -c -r -s -t -g $2 $1 > "$SYGUS_WITH_GRAMMAR_FILE"
else
  SYGUS_WITH_GRAMMAR_FILE="$1"
fi

PYPATH="$TOOL_DIR/EUSolver/thirdparty/Python-3.5.1/python"
Z3_LIBRARY_PATH="$TOOL_DIR"/EUSolver/thirdparty/z3/build/python

if [ -z "$PYPATH" ]; then
  echo "python3 not found"
else
  sed -i 's/^import pkg_resources/# &/' "$TOOL_DIR"/EUSolver/thirdparty/z3/build/python/z3/z3core.py
  sed -i 's!^\(\s*\)_dirs =.*$!\1_dirs = ["'$Z3_LIBRARY_PATH'"]!' "$TOOL_DIR"/EUSolver/thirdparty/z3/build/python/z3/z3core.py
  PYTHONPATH="$TOOL_DIR"/EUSolver/thirdparty/libeusolver/build:"$TOOL_DIR"/EUSolver/thirdparty/z3/build/python "$PYPATH" "$TOOL_DIR"/EUSolver/bin/benchmarks.py "$SYGUS_WITH_GRAMMAR_FILE"
fi

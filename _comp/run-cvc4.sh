#!/bin/bash

TOOL_DIR="$HOME/Tools"
SELF_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

SYGUS_WITH_GRAMMAR_FILE="/tmp/cvc4.$(basename $2).$(basename $1)"
"$SELF_DIR"/../_build/install/default/bin/transform -c -r -g $2 $1 > "$SYGUS_WITH_GRAMMAR_FILE"

cvc4="$TOOL_DIR"/CVC4/bin/cvc4
bench="$SYGUS_WITH_GRAMMAR_FILE"

function runl {
  limit=$1; shift;
  ulimit -S -t "$limit";$cvc4 --lang=sygus --no-checking --no-interactive --default-dag-thresh=0 $bench 2>/dev/null
}

function trywith {
  sol=$(runl $@)
  status=$?
  if [ $status -ne 134 ]; then
    echo $sol |&
    (read result w1 w2;
    case "$result" in
    unsat)
      case "$w1" in
        "(define-fun") echo "$w1 $w2";cat;exit 0;;
        esac; exit 1;;
    esac; exit 1)
    if [ ${PIPESTATUS[1]} -eq 0 ]; then exit 0; fi
  fi
}

function finishwith {
  $cvc4 --lang=sygus --no-checking --no-interactive --default-dag-thresh=0 $bench 2>/dev/null |
  (read result w1;
  case "$result" in
  unsat) echo "$w1";cat;exit 0;;
  esac)
}

trywith 10
trywith 120 --sygus-unif
finishwith --no-sygus-repair-const

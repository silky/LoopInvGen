#!/bin/bash

SELF_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

if [ -n "$2" ]; then
  SYGUS_WITH_GRAMMAR_FILE="/tmp/sketch.$(basename $2).$(basename $1)"
  "$SELF_DIR"/../_build/install/default/bin/add-grammar -a -c -r -t -g $2 $1 > "$SYGUS_WITH_GRAMMAR_FILE"
else
  SYGUS_WITH_GRAMMAR_FILE="$1"
fi

sed -i 's/!/_prime/g' "$SYGUS_WITH_GRAMMAR_FILE"
sed -i 's/=>\ /impliesfn /g' "$SYGUS_WITH_GRAMMAR_FILE"
sed -i 's/div\ /divfn /g' "$SYGUS_WITH_GRAMMAR_FILE"
sed -i 's/mod\ /modfn /g' "$SYGUS_WITH_GRAMMAR_FILE"
sed -i 's/ite\ /iteBitfn /g' "$SYGUS_WITH_GRAMMAR_FILE"

cd "$SELF_DIR"/SketchAC/bin
java -cp scala-library.jar:parser.jar SygusParserCLI "$SYGUS_WITH_GRAMMAR_FILE" > tmp.sk
cat library.c >> tmp.sk

for I in {2..10}; do
  ./sketch-1.6.9/sketch-frontend/sketch -V 5 --fe-def BND=$I --slv-ntimes 3000 --slv-randassign --slv-parallel --slv-p-cpus 4 --slv-randdegrees 64,128,512,1024 --bnd-unroll-amnt 64 --fe-custom-codegen testcg.jar --fe-tempdir . tmp.sk &> sk.out
  if (grep -q "DONE" sk.out); then
    sed -i 's/impliesfn\ /=> /g' sygus.out
    sed -i 's/divfn\ /div /g' sygus.out
    sed -i 's/modfn\ /mod /g' sygus.out
    sed -i 's/iteBitfn\ /ite /g' sygus.out
    cat sk.out >&2 ; cat sygus.out ; exit
  fi
done
cat sk.out >&2

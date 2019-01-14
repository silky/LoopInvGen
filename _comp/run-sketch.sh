#!/bin/bash

TOOL_DIR="$HOME/Tools"
SELF_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

SYGUS_WITH_GRAMMAR_FILE="/tmp/sketch.$(basename $2).$(basename $1)"
SYGUS_NAME_MAPPING_FILE="/tmp/sketch.$(basename $2).$(basename $1).map"

"$SELF_DIR"/../_build/install/default/bin/transform \
  -a -c -r -s "$SYGUS_NAME_MAPPING_FILE" -t -g $2 $1 \
  > "$SYGUS_WITH_GRAMMAR_FILE"

sed -i 's/!/_prime/g' "$SYGUS_WITH_GRAMMAR_FILE"
sed -i 's/=>\ /impliesfn /g' "$SYGUS_WITH_GRAMMAR_FILE"
sed -i 's/div\ /divfn /g' "$SYGUS_WITH_GRAMMAR_FILE"
sed -i 's/mod\ /modfn /g' "$SYGUS_WITH_GRAMMAR_FILE"
sed -i 's/ite\ /iteBitfn /g' "$SYGUS_WITH_GRAMMAR_FILE"

cd "$TOOL_DIR"/SketchAC/bin
java -cp scala-library.jar:parser.jar SygusParserCLI "$SYGUS_WITH_GRAMMAR_FILE" > tmp.sk
cat library.c >> tmp.sk

for I in {2..10}; do
  ./sketch-1.6.9/sketch-frontend/sketch -V 5 --fe-def BND=$I --slv-ntimes 3000 --slv-randassign --slv-parallel --slv-p-cpus 4 --slv-randdegrees 64,128,512,1024 --bnd-unroll-amnt 64 --fe-custom-codegen testcg.jar --fe-tempdir . tmp.sk &> sk.out
  if (grep -q "DONE" sk.out); then
    sed -i 's/impliesfn\ /=> /g' sygus.out
    sed -i 's/divfn\ /div /g' sygus.out
    sed -i 's/modfn\ /mod /g' sygus.out
    sed -i 's/iteBitfn\ /ite /g' sygus.out

    while read -u 23 p ; do
      sed -i $p sygus.out
    done 23< "$SYGUS_NAME_MAPPING_FILE"

    cat sk.out >&2 ; cat sygus.out ; exit
  fi
done
cat sk.out >&2

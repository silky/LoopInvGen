#!/bin/bash

TOOL_DIR="$HOME/Tools"
SELF_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

SYGUS_OUTPUT_FILE="/tmp/enum.$(basename $2).$(basename $1).out"
SYGUS_WITH_GRAMMAR_FILE="/tmp/enum.$(basename $2).$(basename $1)"
SYGUS_NAME_MAPPING_FILE="/tmp/enum.$(basename $2).$(basename $1).map"

"$SELF_DIR"/../_build/install/default/bin/transform \
  -a -c -r -s "$SYGUS_NAME_MAPPING_FILE" -t -g $2 $1 \
  > "$SYGUS_WITH_GRAMMAR_FILE"

#sed -i 's/div\ /\/ /g' "$SYGUS_WITH_GRAMMAR_FILE"
#sed -i 's/mod\ /modfn /g' "$SYGUS_WITH_GRAMMAR_FILE"

cd "$TOOL_DIR"/Enum-SyGuS/lib
rm -rf ld-linux* libc* libgcc* libm* libpthread* librt* libstdc++*

cd ../bin

LD_LIBRARY_PATH=$LD_LIBRARY_PATH:../lib ./esolver-synthlib -s 10000 -m 64000000000 -i "$SYGUS_WITH_GRAMMAR_FILE" > res

if (grep -q "Solution 0:" res); then
  #sed -i 's/\/ /div /g' res
  #sed -i 's/modfn\ /mod /g' res

  cat res | tail -n +2 | head -n +2 > "$SYGUS_OUTPUT_FILE"

  "$SELF_DIR"/../_build/install/default/bin/transform \
    -u "$SYGUS_NAME_MAPPING_FILE" "$SYGUS_OUTPUT_FILE"
else
  cat res >&2
fi

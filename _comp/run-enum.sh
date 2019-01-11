#!/bin/bash

SELF_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

if [ -n "$2" ]; then
	SYGUS_WITH_GRAMMAR_FILE="/tmp/enum.$(basename $2).$(basename $1)"
	"$SELF_DIR"/../_build/install/default/bin/add-grammar -a -c -t -r -g $2 $1 > "$SYGUS_WITH_GRAMMAR_FILE"
else
	SYGUS_WITH_GRAMMAR_FILE="$1"
fi

#sed -i 's/div\ /\/ /g' "$SYGUS_WITH_GRAMMAR_FILE"
#sed -i 's/mod\ /modfn /g' "$SYGUS_WITH_GRAMMAR_FILE"

cd "$SELF_DIR"/Enum-SyGuS/bin

LD_LIBRARY_PATH=$LD_LIBRARY_PATH:../lib ./enum -s 10000 -m 64000000000 -i "$SYGUS_WITH_GRAMMAR_FILE" > res
if (grep -q "Solution 0:" res); then
	#sed -i 's/\/ /div /g' res
	#sed -i 's/modfn\ /mod /g' res

	cat res | tail -n +2 | head -n +2
else
	cat res >&2
fi

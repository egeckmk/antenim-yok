#!/bin/zsh
# Checks the App Store text lengths (characters).
cd "$(dirname "$0")/../AppStore/tr"
ok=1
check() { local n=$(python3 -c "import sys;print(len(open('$1',encoding='utf-8').read().rstrip('\n')))"); [[ $n -le $2 ]] && s=ok || { s=TOO-LONG; ok=0; }; echo "$1 $n/$2 $s"; }
check name.txt 30; check subtitle.txt 30; check keywords.txt 100; check promotional.txt 170; check description.txt 4000; check whats-new.txt 4000
exit $((1-ok))

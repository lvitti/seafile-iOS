#!/bin/sh
set -eu
# macOS/Xcode Command Line Tools; exercises the production Objective-C policy.
# Does not read or modify the user's Keychain and has no network dependencies.
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
xcrun --sdk macosx clang -fobjc-arc -fmodules -Wall -Wextra \
  -Wno-unused-parameter -Wno-incompatible-pointer-types \
  -framework Foundation -framework Security \
  -I "$root/Pod/Classes" \
  "$root/Pod/Classes/SeafCustomHeaders.m" "$root/Tests/CustomHeaders/main.m" \
  -o "$test_dir/custom-header-tests"
"$test_dir/custom-header-tests"

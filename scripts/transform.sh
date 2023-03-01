#!/bin/bash

# To run this script in development, first build the following packages:
#     packages/@aws-cdk/assert
#     packages/aws-cdk-lib
#     tools/individual-pkg-gen

set -euo pipefail
scriptdir=$(cd $(dirname $0) && pwd)

# Creates a symlink in each individual package's node_modules folder pointing
# to the root folder's node_modules/.bin. This allows Yarn to find the executables
# it needs (e.g., jsii-rosetta) for the build.
#
# The reason Yarn doesn't find the executables in the first place is that they are
# not dependencies of each individual package -- nor should they be. They can't be
# found in the lerna workspace, either, since it only includes the individual
# packages. For potential alternatives to try out in the future, see
# https://github.com/cdklabs/cdk-ops/issues/1636
createSymlinks() {
  find "$1" ! -path "$1" -type d -maxdepth 1 \
    -exec mkdir -p {}/node_modules \; \
    -exec ln -sf "${scriptdir}"/../node_modules/.bin {}/node_modules \;
}

runtarget="build"
run_tests="true"
skip_build=""
while [[ "${1:-}" != "" ]]; do
    case $1 in
        -h|--help)
            echo "Usage: transform.sh [--skip-test/build]"
            exit 1
            ;;
        --skip-test|--skip-tests)
            run_tests="false"
            ;;
        --skip-build)
            skip_build="true"
            ;;
        *)
            echo "Unrecognized options: $1"
            exit 1
            ;;
    esac
    shift
done

export NODE_OPTIONS="--max-old-space-size=8192 --experimental-worker ${NODE_OPTIONS:-}"

individual_packages_folder=${scriptdir}/../packages/individual-packages
# copy & build the packages that are individually released from 'aws-cdk-lib'
cd "$individual_packages_folder"
../../tools/@aws-cdk/individual-pkg-gen/bin/individual-pkg-gen

createSymlinks "$individual_packages_folder"

if [ "$skip_build" != "true" ]; then
  echo "building..."
  time lerna run --stream build || fail

  if [ "$run_tests" == "true" ]; then
    echo "testing..."
    cores=$(node -p "require('os').cpus().length")
    time lerna run test --stream --no-sort --concurrency $((cores / 2)) || fail
  fi
fi

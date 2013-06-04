#!/bin/bash -x

# Convenience script to re-generate the Caja validator from the online
# whitelists.

dart cajoler.dart \
    --out=../lib/src/html5_validator.dart

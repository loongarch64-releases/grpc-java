#!/bin/bash
set -euo pipefail

UPSTREAM_OWNER=grpc
UPSTREAM_REPO=grpc-java

curl -s https://api.github.com/repos/"$UPSTREAM_OWNER"/"$UPSTREAM_REPO"/releases/latest \
     | jq -r ".tag_name"

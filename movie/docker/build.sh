#!/bin/bash
cd "$(dirname "$(readlink -f "$0")")"
docker build -f Dockerfile -t movierecommend ..
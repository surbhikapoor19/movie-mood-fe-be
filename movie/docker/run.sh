#!/bin/bash
cd "$(dirname "$(readlink -f "$0")")" # Changes working directory to the directory of the file (allows bash to be called from anywhere)
docker run --env-file .env --rm -p 22061:6161 --name movie_mood movierecommend 
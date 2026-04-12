#!/bin/bash
docker run --env-file .env --rm -p 22061:6161 --name movie_mood movierecommend 
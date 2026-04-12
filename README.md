# Movie Reccomendation Chatbot

This is our Movie Reccomendation Chatbot that we are creating for CS553, better known as Machine Learning Development and Operations. Our goal is to create a chatbot which will take in user preferances and reccomend the user a movie to watch.

## Key Features

This version of the chatbot is meant to run on a single python file, making it easier for us to deploy it to the cloud.

## Instructions to run

In order to run the docker image here, all you must do is first rename `.env.template` to `.env`, then add the secrets to the environment file.

After that, build and run the image using `build.sh` and `run.sh`.

These commands will create a docker container named `movie_mood`. The movie recomendation bot will be available on port 23061.
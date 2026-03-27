---
title: Movie Rec Stage
emoji: 💬
colorFrom: yellow
colorTo: purple
sdk: gradio
sdk_version: 6.5.1
app_file: app.py
pinned: false
hf_oauth: true
hf_oauth_scopes:
- inference-api
---

# Movie Reccomendation Chatbot

This is our Movie Reccomendation Chatbot that we are creating for CS553, better known as Machine Learning Development and Operations. Our goal is to create a chatbot which will take in user preferances and reccomend the user a movie to watch.

## Key Features

This chatbot can be hosted locally or on a server. The user is able to:
- Tell the chatbot what kind of movie they like/ are in the mood to watch
- Provide additional comments about movies they have viewed in the past

The chatbot then responds with
- A list of movies which are recommended to the user
- An image of the movie title card for each recommendation

## Overview
This chatbot runs on a seperate frontend and backend, and the User Interface is running with Gradio. In addition, the chatbot itself is using Huggingface Models, specifically 
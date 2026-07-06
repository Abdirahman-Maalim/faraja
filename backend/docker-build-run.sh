#!/bin/bash

#!/bin/bash

# create image called 'faraja-backend'
docker build faraja-backend .

# copy environment variables
cp .env.example .env

# start container using 'faraja-backend' image while attaching .env file 
# and mapping host port (8000) to container port (8000)
docker run --env-file .env -p 8000:8000 faraja-backend

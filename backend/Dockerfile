# syntax=docker/dockerfile:1
# check=error=true

# sets python3.12 as the base 
FROM python:3.12.13-slim

# set working directory
WORKDIR /backend

# copies project files
COPY . .

# runs setup commands
RUN pip install -r requirements.txt

# exposes port 8000
EXPOSE 8000

# launches the app
CMD ["uvicorn", "app.main:app", "--reload", "--port", "8000", "--host", "0.0.0.0"]


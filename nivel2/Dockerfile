FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
RUN apt update
RUN apt install -y wget
RUN apt install -y software-properties-common
RUN add-apt-repository ppa:deadsnakes/ppa
RUN apt update
RUN apt install -y python3.9
RUN apt install -y python3-pip
RUN apt install -y openjdk-11-jdk
RUN apt install -y lsb-release curl gpg
RUN curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg & \
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list & \
    apt update & \
    apt install -y redis
# Set the working directory in the container
WORKDIR /app


# Copy the requirements file into the container and install dependencies
COPY ../csv/data.csv /data/
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copy the current directory contents into the container at /app
COPY app.py /app

# Set environment variables
ENV FLASK_HOST=0.0.0.0
ENV FLASK_PORT=7080
ENV REDIS_HOST=127.0.0.1
ENV REDIS_PORT=6379

# Run the command to start the Flask development server
CMD ["/bin/bash", "-c", "redis-server --daemonize yes; python3 /app/app.py"]
FROM python:3.13-slim

RUN apt-get update && apt-get install -y \
    sshpass \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

RUN pip install ansible

WORKDIR /ansible
ENTRYPOINT ["ansible-playbook"]


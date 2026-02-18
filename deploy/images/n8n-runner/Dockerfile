FROM n8nio/runners:2.9.1

USER root


# Reinstall apk - n8n removes this
RUN wget https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/x86_64/apk-tools-static-3.0.4-r0.apk \
    && tar -xzf apk-tools-static-3.0.4-r0.apk \
    && mv sbin/apk.static /sbin/apk \
    && rm -rf sbin apk-tools-static-3.0.4-r0.apk

# Other dependencies
RUN apk update && apk add --no-cache \
    ffmpeg 

# Install Deno for youtube-dl
RUN curl -fsSL https://deno.land/x/install/install.sh | sh

# Python dependencies
COPY n8n-runner/requirements.txt /opt/runners/task-runner-python/custom.requirements.txt
RUN cd /opt/runners/task-runner-python && uv pip install -r /opt/runners/task-runner-python/custom.requirements.txt

# fix security issue with python packages
# https://github.com/n8n-io/n8n/blob/master/docker/images/runners/n8n-task-runners.json
RUN sed -i 's/"N8N_RUNNERS_EXTERNAL_ALLOW": *""/"N8N_RUNNERS_EXTERNAL_ALLOW": "\*"/' /etc/n8n-task-runners.json
RUN sed -i 's/"N8N_RUNNERS_STDLIB_ALLOW": *""/"N8N_RUNNERS_STDLIB_ALLOW": "\*"/' /etc/n8n-task-runners.json

# cleanup apk tools
RUN rm -rf /var/cache/apk/* /sbin/apk

USER runner
LABEL org.opencontainers.image.source=https://github.com/bwees/homelab

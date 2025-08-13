FROM ubuntu:22.04

# Set build arguments for default values
ARG SQUID_USERNAME=proxyuser
ARG SQUID_PASSWORD=proxypass
ARG SQUID_PORT=3128

# Set environment variables
ENV SQUID_USERNAME=$SQUID_USERNAME
ENV SQUID_PASSWORD=$SQUID_PASSWORD
ENV SQUID_PORT=$SQUID_PORT

# Install required packages
RUN apt-get update && apt-get install -y \
    wget \
    apache2-utils \
    && rm -rf /var/lib/apt/lists/*

# Copy the installation script
COPY squid3-install.sh /tmp/squid3-install.sh
RUN chmod +x /tmp/squid3-install.sh

# Run the installation script (which will install squid)
RUN /tmp/squid3-install.sh

# Create a script to add users from environment variables
RUN echo '#!/bin/bash\n\
if [ ! -z "$SQUID_USERNAME" ] && [ ! -z "$SQUID_PASSWORD" ]; then\n\
    /usr/bin/htpasswd -b -c /etc/squid/passwd $SQUID_USERNAME $SQUID_PASSWORD\n\
    echo "Created proxy user: $SQUID_USERNAME"\n\
else\n\
    echo "SQUID_USERNAME and SQUID_PASSWORD environment variables are required"\n\
    exit 1\n\
fi' > /usr/local/bin/create-proxy-user && \
    chmod +x /usr/local/bin/create-proxy-user

# Create startup script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Create proxy user from environment variables\n\
if [ ! -z "$SQUID_USERNAME" ] && [ ! -z "$SQUID_PASSWORD" ]; then\n\
    echo "Creating proxy user: $SQUID_USERNAME"\n\
    /usr/bin/htpasswd -b -c /etc/squid/passwd $SQUID_USERNAME $SQUID_PASSWORD\n\
fi\n\
\n\
# Start Squid in foreground\n\
echo "Starting Squid proxy server on port $SQUID_PORT"\n\
exec squid -NYC' > /usr/local/bin/start-squid && \
    chmod +x /usr/local/bin/start-squid

# Expose the proxy port
EXPOSE $SQUID_PORT

# Set the startup command
CMD ["/usr/local/bin/start-squid"]

FROM ubuntu:22.04

# Set build arguments for default values (no sensitive data)
ARG SQUID_USERNAME=proxyuser
ARG SQUID_PORT=3128
ARG SSH_PORT=2222

# Set environment variables (password will be set at runtime)
ENV SQUID_USERNAME=$SQUID_USERNAME
ENV SQUID_PORT=$SQUID_PORT
ENV SSH_PORT=$SSH_PORT

# Install required packages
RUN apt-get update && apt-get install -y \
    wget \
    apache2-utils \
    openssh-server \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Copy the installation script
COPY squid3-install.sh /tmp/squid3-install.sh
RUN chmod +x /tmp/squid3-install.sh

# Run the installation script (which will install squid)
RUN /tmp/squid3-install.sh

# Configure SSH
RUN mkdir -p /var/run/sshd && \
    # Change SSH port to 2222
    sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config && \
    # Allow password authentication
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    # Allow root login (optional, you can remove this if not needed)
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    # Disable PAM to avoid issues in container
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config

# Create squid user with SSH access
RUN useradd -m -s /bin/bash $SQUID_USERNAME && \
    echo "$SQUID_USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create a script to add users from environment variables
RUN echo '#!/bin/bash\n\
if [ ! -z "$SQUID_USERNAME" ] && [ ! -z "$SQUID_PASSWORD" ]; then\n\
    /usr/bin/htpasswd -b -c /etc/squid/passwd $SQUID_USERNAME $SQUID_PASSWORD\n\
    echo "Created proxy user: $SQUID_USERNAME"\n\
    # Set SSH password for the user\n\
    echo "$SQUID_USERNAME:$SQUID_PASSWORD" | chpasswd\n\
    echo "Set SSH password for user: $SQUID_USERNAME"\n\
else\n\
    echo "SQUID_USERNAME and SQUID_PASSWORD environment variables are required"\n\
    exit 1\n\
fi' > /usr/local/bin/create-proxy-user && \
    chmod +x /usr/local/bin/create-proxy-user

# Create startup script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Check if required environment variables are set\n\
if [ -z "$SQUID_USERNAME" ] || [ -z "$SQUID_PASSWORD" ]; then\n\
    echo "ERROR: SQUID_USERNAME and SQUID_PASSWORD environment variables are required"\n\
    echo "Example: docker run -e SQUID_USERNAME=myuser -e SQUID_PASSWORD=mypass ..."\n\
    exit 1\n\
fi\n\
\n\
# Create proxy user from environment variables\n\
echo "Creating proxy user: $SQUID_USERNAME"\n\
/usr/bin/htpasswd -b -c /etc/squid/passwd $SQUID_USERNAME $SQUID_PASSWORD\n\
\n\
# Set SSH password for the user\n\
echo "$SQUID_USERNAME:$SQUID_PASSWORD" | chpasswd\n\
echo "Set SSH password for user: $SQUID_USERNAME"\n\
\n\
# Start SSH server in background\n\
echo "Starting SSH server on port $SSH_PORT"\n\
/usr/sbin/sshd -D &\n\
\n\
# Start Squid in foreground\n\
echo "Starting Squid proxy server on port $SQUID_PORT"\n\
exec squid -NYC' > /usr/local/bin/start-squid && \
    chmod +x /usr/local/bin/start-squid

# Expose the proxy port and SSH port
EXPOSE $SQUID_PORT $SSH_PORT

# Set the startup command
CMD ["/usr/local/bin/start-squid"]

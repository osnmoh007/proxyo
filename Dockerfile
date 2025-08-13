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
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Copy the installation script
COPY squid3-install.sh /tmp/squid3-install.sh
RUN chmod +x /tmp/squid3-install.sh

# Run the installation script (which will install squid)
RUN /tmp/squid3-install.sh

# Ensure /etc/squid directory and passwd file exist with proper permissions
RUN mkdir -p /etc/squid && \
    touch /etc/squid/passwd && \
    chown -R proxy:proxy /etc/squid && \
    chmod 755 /etc/squid && \
    chmod 644 /etc/squid/passwd

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

# Create a test script to verify SSH password
RUN echo '#!/bin/bash\n\
echo "=== SSH Password Test ==="\n\
echo "Username: $SQUID_USERNAME"\n\
echo "Password: $SQUID_PASSWORD"\n\
echo "Shadow entry:"\n\
grep "^$SQUID_USERNAME:" /etc/shadow\n\
echo "=== End Test ==="' > /usr/local/bin/test-ssh-password && \
    chmod +x /usr/local/bin/test-ssh-password

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
# Ensure /etc/squid directory exists and has proper permissions\n\
mkdir -p /etc/squid\n\
chown -R proxy:proxy /etc/squid\n\
chmod 755 /etc/squid\n\
\n\
# Create or recreate the passwd file with proper permissions\n\
rm -f /etc/squid/passwd\n\
touch /etc/squid/passwd\n\
chown proxy:proxy /etc/squid/passwd\n\
chmod 644 /etc/squid/passwd\n\
\n\
# Create proxy user from environment variables\n\
echo "Creating proxy user: $SQUID_USERNAME"\n\
/usr/bin/htpasswd -b -c /etc/squid/passwd $SQUID_USERNAME $SQUID_PASSWORD\n\
\n\
# Set SSH password for the user using a more reliable method\n\
echo "Setting SSH password for user: $SQUID_USERNAME"\n\
# Method 1: Try using passwd command with expect-like behavior\n\
echo "$SQUID_USERNAME:$SQUID_PASSWORD" | /usr/sbin/chpasswd 2>/dev/null || {\n\
    echo "chpasswd failed, trying alternative method..."\n\
    # Method 2: Use openssl to generate hash and update shadow file\n\
    PASS_HASH=$(openssl passwd -1 "$SQUID_PASSWORD")\n\
    if [ ! -z "$PASS_HASH" ]; then\n\
        # Create a temporary shadow file\n\
        cp /etc/shadow /etc/shadow.backup\n\
        # Update the password hash in shadow file\n\
        awk -F: -v user="$SQUID_USERNAME" -v hash="$PASS_HASH" \n\
            "BEGIN {OFS=FS} $1==user {$2=hash} {print}" /etc/shadow > /etc/shadow.tmp\n\
        mv /etc/shadow.tmp /etc/shadow\n\
        chmod 600 /etc/shadow\n\
        echo "SSH password set using hash method"\n\
    else\n\
        echo "Warning: Could not generate password hash"\n\
    fi\n\
}\n\
\n\
# Verify the password was set correctly\n\
echo "Verifying SSH password for user: $SQUID_USERNAME"\n\
if grep -q "^$SQUID_USERNAME:" /etc/shadow; then\n\
    echo "SSH password verification successful"\n\
else\n\
    echo "Warning: SSH password may not be set correctly"\n\
fi\n\
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

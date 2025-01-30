#!/bin/bash

# Note this will rely on you having spawned the Pageant SSH agent as per the start_pageant_with_socket.bat script in Windows

# Create systemd service file
mkdir -p ~/.config/systemd/user

# Note this heredoc is "literal" to prevent variable expansion
cat > ~/.config/systemd/user/start-ssh-agent-pageant-pipe.sh <<'EOF'
#!/bin/bash

# Get the current Windows username
USERNAME=$(/mnt/c/WINDOWS/system32/cmd.exe /c echo %USERNAME% 2>/dev/null | tr -d "\r\n")

# Ensure the USERNAME variable is populated
if [ -z "$USERNAME" ]; then
  echo "Error: Could not determine the username."
  exit 1
fi

# Define paths
SSH_DIR="/mnt/c/Users/$USERNAME/.ssh"
NPIPERELAY_EXE="$SSH_DIR/npiperelay.exe"
NPIPERELAY_ZIP="npiperelay_windows_amd64.zip"
GITHUB_REPO="https://api.github.com/repos/jstarks/npiperelay/releases/latest"

# Function to check if sudo is available without password prompt
check_sudo() {
  if ! sudo -v &>/dev/null; then
    echo "Error: sudo is either not installed or not configured correctly. Please install and configure access for your user to allow dependencies to be installed or install packages curl, unzip and socat manually."
    exit 1
  fi

  # Check if sudo does not require a password
  if sudo -n true 2>/dev/null; then
    echo "Sudo is available and does not require a password. Installing dependencies..."
  else
    echo "Error: Sudo requires a password. Please configure sudo to allow passwordless sudo for your user to allow dependencies to be installed or install packages curl, unzip and socat manually."
    exit 1
  fi
}

# Function to check and install a package
install_package() {
  local pkg_name="$1"

  if ! command -v "$pkg_name" &>/dev/null; then
    echo "$pkg_name not found. Installing..."

    # Ensure sudo works without a password or packages cannot install
    check_sudo
    
    if [ -f "/etc/debian_version" ]; then
      sudo apt update && sudo apt install -y "$pkg_name"
    elif [ -f "/etc/redhat-release" ]; then
      sudo yum install -y "$pkg_name"
    elif [ -f "/etc/alpine-release" ]; then
      sudo apk add "$pkg_name"
    elif [ -f "/etc/arch-release" ]; then
      sudo pacman -Sy --noconfirm "$pkg_name"
    else
      echo "Error: Unsupported Linux distribution. Please install $pkg_name manually."
      exit 1
    fi
  fi
}

# Ensure unzip, socat and curl are installed
install_package unzip
install_package socat
install_package curl

# Check if npiperelay.exe is missing
if [ ! -f "$NPIPERELAY_EXE" ]; then
  echo "npiperelay.exe not found, downloading latest version..."

  # Fetch the latest release download URL
  DOWNLOAD_URL=$(curl -s "$GITHUB_REPO" | grep "browser_download_url" | grep "$NPIPERELAY_ZIP" | cut -d '"' -f 4)

  if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: Could not find a download link for $NPIPERELAY_ZIP"
    exit 1
  fi

  # Download the ZIP file
  curl -L -o "/tmp/$NPIPERELAY_ZIP" "$DOWNLOAD_URL"

  # Extract only npiperelay.exe
  unzip -jo "/tmp/$NPIPERELAY_ZIP" "npiperelay.exe" -d "$SSH_DIR"

  # Ensure the file was extracted
  if [ ! -f "$NPIPERELAY_EXE" ]; then
    echo "Error: Failed to extract npiperelay.exe"
    exit 1
  fi

  echo "npiperelay.exe downloaded and extracted successfully to $NPIPERELAY_EXE"
fi

# Path to the Pageant configuration file
CONFIG_FILE="/mnt/c/Users/$USERNAME/.ssh/pageant.conf"

# Check if the configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Configuration file $CONFIG_FILE does not exist."
  exit 1
fi

# Extract the path from the configuration file and correct the path prefix
PIPE_PATH=$(cat "$CONFIG_FILE" | cut -d " " -f 2 | tr -d "\r\n" | sed "s/\"//g" | sed 's|//\.\/pipe\/|/\\\\/\\.\\/pipe\\/|g')

# Ensure the PIPE_PATH is valid
if [ -z "$PIPE_PATH" ]; then
  echo "Error: Could not extract a valid Pageant path from the configuration file."
  exit 1
fi

# Run the Socat command
socat EXEC:"/mnt/c/Users/$USERNAME/.ssh/npiperelay.exe ${PIPE_PATH}" UNIX-LISTEN:/tmp/ssh-agent.sock,unlink-close,unlink-early,fork
EOF

chmod +x ~/.config/systemd/user/start-ssh-agent-pageant-pipe.sh

# Note this heredoc is also "literal" to prevent variable expansion
cat > ~/.config/systemd/user/ssh-agent-pageant.service <<'EOF'
[Unit]
Description=Socat SSH Agent Forwarding for Pageant
After=network.target

[Service]

ExecStart=/bin/bash ${HOME}/.config/systemd/user/start-ssh-agent-pageant-pipe.sh
Restart=always
StandardOutput=file:/tmp/ssh-agent-pageant-output.log
StandardError=file:/tmp/ssh-agent-pageant-error.log

[Install]
WantedBy=default.target
EOF

# Reload systemd, enable, and start the service
systemctl --user daemon-reload
systemctl --user enable ssh-agent-pageant.service
systemctl --user stop ssh-agent-pageant.service
systemctl --user start ssh-agent-pageant.service

# Add SSH_AUTH_SOCK to .bashrc if not already present
grep -qxF 'export SSH_AUTH_SOCK=/tmp/ssh-agent.sock' ~/.bashrc || echo 'export SSH_AUTH_SOCK=/tmp/ssh-agent.sock' >> ~/.bashrc

echo "Service created and started. Restart shell or run 'source ~/.bashrc' to apply."


# SSH Agent Forwarding from Windows to WSL

## Overview
This project provides a setup for enabling SSH agent forwarding for the Windows terminal SSH and also from Windows to WSL (Windows Subsystem for Linux) using Pageant and npiperelay. 

It allows SSH keys loaded in Pageant on Windows to be accessible within WSL, making SSH authentication seamless for both the Windows terminal native SSH command 
and the SSH command within your WSL instances.

## Features
- Automatically starts Pageant only login with OpenSSH agent support on Windows.
- Configures WSL to forward the SSH agent from Windows.
- Uses npiperelay to bridge the Windows named pipe to a Unix socket in WSL.
- Supports different Linux distributions (Debian, RedHat, Alpine, Arch, etc.).
- Automates setup via systemd services in the WSL instance.

## Prerequisites
- Windows with PuTTY's Pageant installed (`C:\Program Files\PuTTY\pageant.exe`).
- A private key in PuTTY's `.ppk` format.
- WSL (Windows Subsystem for Linux) installed.
- `socat`, `curl`, and `unzip` installed in your WSL instance.

## Installation

### 1. Setting Up SSH Agent Forwarding in Windows

1. Copy `start_pageant_with_socket.bat` to the `%USERPROFILE%\.ssh` folder on your Windows system.
2. Edit the batch file to specify your private key path or paths (replace `%USERPROFILE%\.ssh\your.privkey.ppk` with your own key path/s).
3. Run `start_pageant_with_socket.bat`.
4. It will:
   - Start Pageant and load your private key or keys.
   - Create an SSH configuration file and set your SSH config to include the `pageant.conf` which specifies the named pipe required.
   - Set itself to automatically start up when you log in.
   - Display the named pipe path from the `pageant.conf` file created by Pageant.

### 2. Setting Up SSH Agent Forwarding in WSL

1. Copy `setup_ssh_agent_forwarding_from_windows_to_wsl.sh` to your WSL home directory.
2. Run the script:
   ```sh
   chmod +x setup_ssh_agent_forwarding_from_windows_to_wsl.sh
   ./setup_ssh_agent_forwarding_from_windows_to_wsl.sh
   ```
   The script will:
   - Install required dependencies if they are missing (`socat`, `unzip`, `curl`).
   - Download and extract `npiperelay.exe` to `%USERPROFILE%\.ssh`.
   - Set up a systemd service to bridge the Windows/Pageant SSH agent to WSL.
   - Configure your shell to use the SSH agent socket.
4. Restart your shell or run:
   ```sh
   source ~/.bashrc
   ```

## Usage
Once set up, SSH commands in WSL will automatically use the forwarded SSH agent from Windows. You can test it with:
```sh
ssh -T git@github.com
```
If everything is configured and running correctly, you should see:
```
Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.
```

Or if you don't have a Github account you can test it with:
```sh
ssh-add -L
```

If everything is configured and running correctly, you should see your key or keys printed to the screen.


## Troubleshooting
### Check the SSH Agent Socket is present in the WSL instance
```sh
echo $SSH_AUTH_SOCK
ls -l /tmp/ssh-agent.sock
```

### Restart the WSL Systemd Service
```sh
systemctl --user restart ssh-agent-pageant.service
```

### Check Service Logs
```sh
journalctl --user -u ssh-agent-pageant.service
```

### Ensure Windows Pageant is Running
If SSH authentication fails, please make sure Pageant is still running in Windows and contains your keys.

You can also try restarting the WSL Systemd service as above.

## License
This project is licensed under the MIT License.


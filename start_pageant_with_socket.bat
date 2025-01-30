@echo off

:: Define the path to the SSH config file
set "pageantIncludeFile=%USERPROFILE%\.ssh\pageant.conf"
set "sshConfigFile=%USERPROFILE%\.ssh\config"
set "tempFile=%USERPROFILE%\.ssh\config.new"

:: Ensure the .ssh directory exists
if not exist "%USERPROFILE%\.ssh" mkdir "%USERPROFILE%\.ssh"

:: Start Pageant with OpenSSH agent support so native windows SSH can use the agent.
:: Later the OpenSSH config has the pageant.conf included to delegate the required named pipe.
start /B "Pageant" "C:\Program Files\PuTTY\pageant.exe" --openssh-config  "%pageantIncludeFile%" "%USERPROFILE%\.ssh\your.privkey.ppk" 

echo.
echo For WSL SSH forwarding please ensure you setup the WSL instance with:
echo.
echo %~dp0setup_ssh_agent_forwarding_from_windows_to_wsl.sh
echo.
echo Please press Enter to continue once Pageant has finished loading your keys...
pause >nul

:: Check if SSH config file exists; create it if not and include pageant.conf
if not exist "%sshConfigFile%" (
    echo.
    echo Include pageant.conf > "%sshConfigFile%"
    echo "Include pageant.conf" has been added as the new SSH config.
)

:: Check if "Include pageant.conf" already exists anywhere in the file
findstr /i "^Include pageant.conf" "%sshConfigFile%" >nul
if %errorlevel% equ 0 (
    echo.
    echo "Include pageant.conf" already exists in %sshConfigFile%.
) else (
	(
		:: Ensure pageant.conf included if missing
		echo Include pageant.conf
		type "%sshConfigFile%"
	) > "%tempFile%"

	:: Overwrite the original file
	move /Y "%tempFile%" "%sshConfigFile%" >nul
    echo.
	echo "Include pageant.conf" has been prepended successfully.
)

:: Define the shortcut path and batch file path
set "startupFolder=%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
set "batchScript=%~dp0start_pageant_with_socket.bat"   :: Assuming the script is in the same directory

:: Create a shortcut in the autostart folder for the user
if not exist "%startupFolder%\start_pageant_with_socket.lnk" (
    echo.
    echo Shortcut not found in user's autostart folder: %startupFolder% - Creating shortcut...
    :: Create the shortcut (using PowerShell)
    powershell -command "$ws = New-Object -ComObject WScript.Shell; $shortcut = $ws.CreateShortcut('%startupFolder%\start_pageant_with_socket.lnk'); $shortcut.TargetPath = '%batchScript%'; $shortcut.Save()"
) else (
    echo.
    echo Autostart shortcut already exists. Skipping creation...
)

:: Echo out the named pipe for the user in case they need to use it
for /f "tokens=1,* delims== " %%A in ('type %pageantIncludeFile% ^| findstr /i "IdentityAgent"') do (
    :: Extract and echo the second part of the IdentityAgent line
    echo.
    echo The named pipe created by Pageant is:
    echo %%B
    echo.
)

echo Please press Enter to close this window.
pause >nul

exit /b 0

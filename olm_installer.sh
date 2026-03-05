#!/bin/bash

set -e

echo "=== OLM Client Setup / Update Script ==="

SERVICE_FILE="/etc/systemd/system/olm.service"
NEW_BINARY="/usr/local/bin/olm"

# Function to create or update the systemd service
create_or_update_service() {
    echo "🛠 Creating or updating systemd service at $SERVICE_FILE..."
    sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=OLM VPN Client
After=network.target

[Service]
ExecStart=/usr/local/bin/olm --id $ID --secret $SECRET --endpoint $ENDPOINT
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    echo "🔄 Reloading systemd and restarting Newt service..."
    systemctl daemon-reload
    systemctl enable newt
    systemctl start newt
}

# Function to remove everything related to Newt
remove_newt_installation() {
    echo "⚠️ This will completely remove Newt, including the systemd service and binary."
    read -p "Are you sure you want to proceed? (y/n): " CONFIRM
    if [[ "$CONFIRM" == "y" ]]; then
        if [ -f "$SERVICE_FILE" ]; then
            echo "🔄 Stopping and removing Newt service..."
            systemctl stop olm
            systemctl disable olm
            rm -f "$SERVICE_FILE"
            echo "✅ Removed systemd service file: $SERVICE_FILE"
        else
            echo "ℹ️ No systemd service file found."
        fi

        if [ -f "$NEW_BINARY" ]; then
            echo "🗑 Removing Newt binary..."
            rm -f "$NEW_BINARY"
            echo "✅ Removed Newt binary: $NEW_BINARY"
        else
            echo "ℹ️ No Newt binary found."
        fi

        echo "🔄 Reloading systemd daemon..."
        systemctl daemon-reload

        echo "=== ✅ Newt has been completely removed! ==="
    else
        echo "ℹ️ Removal canceled."
    fi
}

# Check if systemd service file exists
if [ -f "$SERVICE_FILE" ]; then
    echo "ℹ️ Detected existing Newt systemd service."
    echo "What would you like to do?"
    echo "1. Update Newt Credentials (id, secret, endpoint)"
    echo "2. Update Newt to the latest version"
    echo "3. Remove Newt Installation"
    echo "4. Exit"
    read -p "Enter your choice (1/2/3/4): " CHOICE

    case "$CHOICE" in
        1)
            echo "Updating Newt Credentials..."
            read -p "Enter your Newt Endpoint URL: " ENDPOINT
            read -p "Enter your Newt ID: " ID
            read -p "Enter your Newt Secret: " SECRET

            echo "Please go back to the Pangolin site and click 'Create Site'."
            echo "Once done, return here and press Enter to continue."
            read -p "Press Enter to continue..."

            echo "🔄 Stopping Newt service..."
            systemctl stop olm

            # Call the reusable function
            create_or_update_service

            echo "=== ✅ Newt credentials updated successfully! ==="
            systemctl status olm --no-pager
            exit 0
            ;;
        2)
            echo "Updating Newt to the latest version..."
            ;;
        3)
            remove_newt_installation
            exit 0
            ;;
        4)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "❌ Invalid choice. Exiting..."
            exit 1
            ;;
    esac
else
    echo "ℹ️ No existing systemd service found. Proceeding with a new installation."
fi

# New installation or updating binary
# Get credentials and info if not updating credentials
if [[ ! -f "$SERVICE_FILE" ]]; then
    read -p "Enter your Newt Endpoint URL: " ENDPOINT
    read -p "Enter your Newt ID: " ID
    read -p "Enter your Newt Secret: " SECRET

    echo "Please go back to the Pangolin site and click 'Create Site'."
    echo "Once done, return here and press Enter to continue."
    read -p "Press Enter to continue..."
fi

# Automatically detect CPU architecture and operating system
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

case "$ARCH" in
  x86_64) ARCH_SUFFIX="amd64" ;;
  armv7l|arm) ARCH_SUFFIX="arm32" ;;
  armv6l) ARCH_SUFFIX="arm32v6" ;;
  aarch64) ARCH_SUFFIX="arm64" ;;
  riscv64) ARCH_SUFFIX="riscv64" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Ensure the OS is supported
case "$OS" in
  linux|darwin|freebsd) ;;
  *) echo "❌ Unsupported operating system: $OS"; exit 1 ;;
esac

# Combine OS and architecture for the final selection
ARCH_SUFFIX="${OS}_${ARCH_SUFFIX}"

echo "ℹ️ Detected architecture and OS: $ARCH_SUFFIX"

# Get latest release URL from GitHub
echo "Fetching latest Newt release for: $ARCH_SUFFIX..."
LATEST_URL=$(curl -s https://api.github.com/repos/fosrl/olm/releases/latest \
  | grep "browser_download_url" \
  | grep "$ARCH_SUFFIX" \
  | cut -d '"' -f 4)

if [ -z "$LATEST_URL" ]; then
  echo "❌ Failed to retrieve latest release URL for $ARCH_SUFFIX."
  exit 1
fi

# Stop service if it exists
if [ -f "$SERVICE_FILE" ]; then
    echo "🔄 Stopping Newt service..."
    systemctl stop olm
fi

# Download and install the binary
echo "⬇️ Downloading Newt from: $LATEST_URL"
wget -q -O olm "$LATEST_URL"
chmod +x olm
mv newt /usr/local/bin/olm
echo "✅ Newt installed to /usr/local/bin/olm"

# Only create the service file if it's a new install
if [[ ! -f "$SERVICE_FILE" ]]; then
    # Use the reusable function for new installation
    create_or_update_service
fi

# Start the service
echo "▶️ Starting Newt service..."
systemctl start olm

echo "=== ✅ Newt setup/update complete! ==="
systemctl status newt --no-pager

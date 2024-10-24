#!/bin/bash

# Color and formatting definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
RESET='\033[0m'

# Icons for menu options
ICON_TELEGRAM="🚀"
ICON_INSTALL="🛠️"
ICON_LOGS="📄"
ICON_STOP="⏹️"
ICON_START="▶️"
ICON_WALLET="💰"
ICON_UPDATE="🔄"
ICON_RESTART="♻️"
ICON_EXIT="❌"

# Functions to draw borders and display menu
draw_top_border() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
}

draw_middle_border() {
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"
}

draw_bottom_border() {
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
}

print_telegram_icon() {
    echo -e "          ${MAGENTA}${ICON_TELEGRAM} Follow us on Telegram!${RESET}"
}

display_ascii() {
    echo -e "    ${RED}    Wings       Node        Team ${RESET}"
    
}

show() {
    echo -e "\033[1;35m$1\033[0m"
}

# Function to check and install jq if not present
install_jq() {
    if ! command -v jq &> /dev/null; then
        show "jq not found, installing..."
        sudo apt-get update
        sudo apt-get install -y jq > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            show "Failed to install jq. Please check your package manager."
            exit 1
        fi
    fi
}

# Function to check the latest version from GitHub
check_latest_version() {
    for i in {1..3}; do
        LATEST_VERSION=$(curl -s https://api.github.com/repos/hemilabs/heminetwork/releases/latest | jq -r '.tag_name')
        if [ -n "$LATEST_VERSION" ]; then
            show "Latest version available: $LATEST_VERSION"
            return 0
        fi
        show "Attempt $i: Failed to fetch the latest version. Retrying..."
        sleep 2
    done

    show "Failed to fetch the latest version after 3 attempts. Please check your internet connection or GitHub API limits."
    exit 1
}

# Function to install or update the node
install_update_node() {
    echo -e "${GREEN}🛠️  Installing or Updating Node...${RESET}"
    
    install_jq
    check_latest_version  # Function to fetch the latest version

    ARCH=$(uname -m)
    download_required=true

    if [ "$ARCH" == "x86_64" ]; then
        if [ -d "heminetwork_${LATEST_VERSION}_linux_amd64" ]; then
            show "Latest version for x86_64 is already downloaded. Skipping download."
            cd "heminetwork_${LATEST_VERSION}_linux_amd64" || { show "Failed to change directory."; exit 1; }
            download_required=false  # Set flag to false
        fi
    elif [ "$ARCH" == "arm64" ]; then
        if [ -d "heminetwork_${LATEST_VERSION}_linux_arm64" ]; then
            show "Latest version for arm64 is already downloaded. Skipping download."
            cd "heminetwork_${LATEST_VERSION}_linux_arm64" || { show "Failed to change directory."; exit 1; }
            download_required=false  # Set flag to false
        fi
    else
        show "Unsupported architecture: $ARCH"
        exit 1
    fi

    if [ "$download_required" = true ]; then
        if [ "$ARCH" == "x86_64" ]; then
            show "Downloading for x86_64 architecture..."
            wget --quiet --show-progress "https://github.com/hemilabs/heminetwork/releases/download/$LATEST_VERSION/heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz" -O "heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz"
            tar -xzf "heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz" > /dev/null
            cd "heminetwork_${LATEST_VERSION}_linux_amd64" || { show "Failed to change directory."; exit 1; }
        elif [ "$ARCH" == "arm64" ]; then
            show "Downloading for arm64 architecture..."
            wget --quiet --show-progress "https://github.com/hemilabs/heminetwork/releases/download/$LATEST_VERSION/heminetwork_${LATEST_VERSION}_linux_arm64.tar.gz" -O "heminetwork_${LATEST_VERSION}_linux_arm64.tar.gz"
            tar -xzf "heminetwork_${LATEST_VERSION}_linux_arm64.tar.gz" > /dev/null
            cd "heminetwork_${LATEST_VERSION}_linux_arm64" || { show "Failed to change directory."; exit 1; }
        fi
    else
        show "Skipping download as the latest version is already present."
    fi

    echo
    show "Select only one option:"
    show "1. Use new wallet for PoP mining"
    show "2. Use existing wallet for PoP mining"
    read -p "Enter your choice (1/2): " wallet_choice
    echo

    if [ "$wallet_choice" == "1" ]; then
        show "Generating a new wallet..."
        ./keygen -secp256k1 -json -net="testnet" > ~/popm-address.json
        if [ $? -ne 0 ]; then
            show "Failed to generate wallet."
            exit 1
        fi
        cat ~/popm-address.json
        echo
        read -p "Have you saved the above details? (y/N): " saved
        echo
        if [[ "$saved" =~ ^[Yy]$ ]]; then
            pubkey_hash=$(jq -r '.pubkey_hash' ~/popm-address.json)
            show "Join: https://discord.gg/hemixyz"
            show "Request faucet from faucet channel to this address: $pubkey_hash"
            echo
            read -p "Have you requested faucet? (y/N): " faucet_requested
            if [[ "$faucet_requested" =~ ^[Yy]$ ]]; then
                priv_key=$(jq -r '.private_key' ~/popm-address.json)
                read -p "Enter static fee (numerical only, recommended: 100-200): " static_fee
                echo
            else
                show "Faucet request not completed. Exiting."
                exit 1
            fi
        else
            show "Details not saved. Exiting."
            exit 1
        fi

    elif [ "$wallet_choice" == "2" ]; then
        read -p "Enter your Private key: " priv_key
        read -p "Enter static fee (numerical only, recommended: 100-200): " static_fee
        echo
    else
        show "Invalid choice for wallet option."
        exit 1
    fi

    if systemctl is-active --quiet hemi.service; then
        show "hemi.service is currently running. Stopping and disabling it..."
        sudo systemctl stop hemi.service
        sudo systemctl disable hemi.service
    else
        show "hemi.service is not running."
    fi

    cat << EOF | sudo tee /etc/systemd/system/hemi.service > /dev/null
[Unit]
Description=Hemi Network popmd Service
After=network.target

[Service]
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/popmd
Environment="POPM_BFG_REQUEST_TIMEOUT=60s"
Environment="POPM_BTC_PRIVKEY=$priv_key"
Environment="POPM_STATIC_FEE=$static_fee"
Environment="POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable hemi.service
    sudo systemctl start hemi.service
    echo
    show "PoP mining is successfully started"
    echo
    read -p "Press Enter to return to the main menu..."
}

view_logs() {
    echo -e "${GREEN}📄 Viewing Logs...${RESET}"
    sudo journalctl -u hemi.service -f -n 50
    echo
    read -p "Press Enter to return to the main menu..."
}

view_wallet_info() {
    echo -e "${GREEN}💰 Viewing Wallet Information...${RESET}"
    if [ -f ~/popm-address.json ]; then
        cat ~/popm-address.json
    else
        echo -e "${RED}❌ Wallet information not found.${RESET}"
    fi
    echo
    read -p "Press Enter to return to the main menu..."
}

change_service_parameters() {
    echo -e "${GREEN}♻️  Changing Service Parameters...${RESET}"
    read -p "Enter new static fee (numerical only, recommended: 100-200): " new_static_fee
    read -p "Enter your Private Key: " new_priv_key

    sudo systemctl stop hemi.service
    sudo sed -i "s|Environment=\"POPM_STATIC_FEE=.*\"|Environment=\"POPM_STATIC_FEE=$new_static_fee\"|" /etc/systemd/system/hemi.service
    sudo sed -i "s|Environment=\"POPM_BTC_PRIVKEY=.*\"|Environment=\"POPM_BTC_PRIVKEY=$new_priv_key\"|" /etc/systemd/system/hemi.service

    sudo systemctl daemon-reload
    sudo systemctl start hemi.service

    echo -e "${GREEN}Service parameters updated and service restarted.${RESET}"
    echo
    read -p "Press Enter to return to the main menu..."
}

stop_node() {
    echo -e "${YELLOW}⏹️  Stopping Node...${RESET}"
    sudo systemctl stop hemi.service
    echo -e "${GREEN}Node stopped successfully.${RESET}"
    echo
    read -p "Press Enter to return to the main menu..."
}

start_node() {
    echo -e "${GREEN}▶️  Starting Node...${RESET}"
    sudo systemctl start hemi.service
    echo -e "${GREEN}Node started successfully.${RESET}"
    echo
    read -p "Press Enter to return to the main menu..."
}

# Main menu loop
while true; do
    show_menu() {
        clear
        draw_top_border
        display_ascii
        draw_middle_border
        print_telegram_icon
        echo -e "${CYAN}║${RESET}"
        echo -e "    ${BLUE}Welcome to the Hemi Network Node Management${RESET}"
        echo -e "    ${GREEN}Manage your node efficiently and easily.${RESET}"
        echo -e "${CYAN}║${RESET}"
        draw_middle_border
        echo -e " ${BLUE}Subscribe to our channel: ${YELLOW}https://t.me/WingsNodeTeam${RESET}"
        draw_middle_border
        echo -e "    ${YELLOW}Please choose an option:${RESET}"
        echo
        echo -e "    ${CYAN}1.${RESET} ${ICON_INSTALL} Install/Update Node"
        echo -e "    ${CYAN}2.${RESET} ${ICON_LOGS} View Service Logs"
        echo -e "    ${CYAN}3.${RESET} ${ICON_WALLET} View Wallet Information"
        echo -e "    ${CYAN}4.${RESET} ${ICON_RESTART} Change Service Parameters"
        echo -e "    ${CYAN}5.${RESET} ${ICON_STOP} Stop Node"
        echo -e "    ${CYAN}6.${RESET} ${ICON_START} Start Node"
        echo -e "    ${CYAN}0.${RESET} ${ICON_EXIT} Exit"
        draw_bottom_border
        echo -ne "    ${YELLOW}Enter your choice [0-6]:${RESET} "
        read choice
    }

    show_menu

    case $choice in
        1) install_update_node ;;
        2) view_logs ;;
        3) view_wallet_info ;;
        4) change_service_parameters ;;
        5) stop_node ;;
        6) start_node ;;
        0) echo -e "${GREEN}❌ Exiting...${RESET}"; exit 0 ;;
        *) echo -e "${RED}❌ Invalid option. Please try again.${RESET}"; sleep 2 ;;
    esac
done

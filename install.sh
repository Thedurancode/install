#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to show progress
show_progress() {
    local message="$1"
    echo -e "${BLUE}📦 ${message}...${NC}"
}

# Function to show success
show_success() {
    local message="$1"
    echo -e "${GREEN}✅ ${message}${NC}"
}

# Function to show error
show_error() {
    local message="$1"
    echo -e "${RED}❌ ${message}${NC}"
    exit 1
}

# Function to show server status
show_server_status() {
    # Try to detect running port
    PORT=$(lsof -iTCP -sTCP:LISTEN -n -P | grep 'codelive' | awk '{print $9}' | cut -d':' -f2 | head -n 1)
    
    if [ -n "$PORT" ]; then
        echo -e "${GREEN}✅ Server is running on port ${PORT}${NC}"
        echo -e "${BLUE}🌐 Access the server at: http://localhost:${PORT}${NC}"
    else
        echo -e "${YELLOW}⚠️  Server status could not be determined${NC}"
    fi
}

# Function to clean existing installation
clean_installation() {
    local install_path="$1"
    show_progress "Cleaning existing installation at ${install_path}"
    
    if [ -d "$install_path" ]; then
        # First, try to remove .changeset directory specifically
        if [ -d "${install_path}/.changeset" ]; then
            rm -rf "${install_path}/.changeset"
        fi
        
        # Then remove the entire directory
        rm -rf "$install_path"
        
        if [ $? -eq 0 ]; then
            show_success "Existing installation cleaned"
        else
            show_error "Failed to clean existing installation"
        fi
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install package manager if needed
install_package_manager() {
    case "$(uname -s)" in
        Darwin)
            if ! command_exists brew; then
                show_progress "Installing Homebrew"
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                if [ $? -eq 0 ]; then
                    show_success "Homebrew installed successfully"
                    # Add Homebrew to PATH if not already present
                    if ! echo "$PATH" | grep -q "/opt/homebrew/bin"; then
                        export PATH="/opt/homebrew/bin:$PATH"
                    fi
                else
                    show_error "Failed to install Homebrew"
                fi
            fi
            ;;
        Linux)
            if command_exists apt-get; then
                show_progress "Updating package lists"
                sudo apt-get update
            elif command_exists yum; then
                show_progress "Updating package lists"
                sudo yum update
            fi
            ;;
    esac
}

# Function to install Git
install_git() {
    if ! command_exists git; then
        show_progress "Installing Git"
        case "$(uname -s)" in
            Darwin)
                brew install git
                ;;
            Linux)
                if command_exists apt-get; then
                    sudo apt-get install -y git
                elif command_exists yum; then
                    sudo yum install -y git
                fi
                ;;
        esac
        
        if command_exists git; then
            show_success "Git installed successfully"
        else
            show_error "Failed to install Git"
        fi
    else
        show_success "Git is already installed"
    fi
}

# Function to install Node.js
install_node() {
    if ! command_exists node; then
        show_progress "Installing Node.js"
        case "$(uname -s)" in
            Darwin)
                brew install node
                ;;
            Linux)
                if command_exists apt-get; then
                    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
                    sudo apt-get install -y nodejs
                elif command_exists yum; then
                    curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
                    sudo yum install -y nodejs
                fi
                ;;
        esac
        
        if command_exists node; then
            show_success "Node.js installed successfully"
        else
            show_error "Failed to install Node.js"
        fi
    else
        show_success "Node.js is already installed"
    fi
}

# Function to check if server is running
check_server_running() {
    show_progress "Checking if server is already running"
    
    # Check for running server on port 2150
    if lsof -i:2150 > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  CodeLive server is already running on port 2150${NC}"
        echo -e "${YELLOW}Would you like to stop it and proceed with fresh installation? (y/n)${NC}"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
            PID=$(lsof -ti:2150)
            if [ ! -z "$PID" ]; then
                kill -9 $PID
                show_success "Stopped existing server"
            fi
        else
            show_error "Installation cancelled. Please stop the existing server before proceeding"
        fi
    else
        show_success "No existing server detected"
    fi
}

# Function to start server
start_codelive_server() {
    INSTALL_PATH="$HOME/Documents/srcbook"
    
    # Check if installation exists
    if [ ! -d "$INSTALL_PATH" ]; then
        echo -e "${RED}❌ CodeLive installation not found at ${INSTALL_PATH}${NC}"
        echo -e "${YELLOW}Please install CodeLive first using option 2${NC}"
        exit 1
    fi
    
    # Change to installation directory
    show_progress "Changing to CodeLive directory"
    cd "$INSTALL_PATH" || show_error "Failed to change to installation directory"
    show_success "Changed to CodeLive directory: $INSTALL_PATH"
    
    # Start the servers
    show_progress "Starting API server"
    cd packages/api || show_error "Failed to change to API directory"
    pnpm run dev &
    show_success "API server started"
    
    sleep 5  # Give API server time to start
    
    cd ../.. || show_error "Failed to return to root directory"
    show_progress "Starting main application"
    pnpm run dev
}

# Function to install CodeLive
install_codelive() {
    # Check system requirements
    show_progress "Checking system requirements"

    # Install package managers if needed
    install_package_manager

    # Install required dependencies
    install_git
    install_node

    # Set installation path
    INSTALL_PATH="$HOME/Documents/srcbook"
    echo -e "${BLUE}📂 Installation path: ${INSTALL_PATH}${NC}"

    # Clean existing installation
    clean_installation "$INSTALL_PATH"

    # Check internet connection
    if ! curl -s --head --request GET https://google.com | grep "200" > /dev/null; then
        show_error "No internet connection available"
    fi

    # Clone repository
    GITHUB_REPO="https://github.com/srcbookdev/srcbook.git"
    show_progress "Cloning CodeLive repository"
    if git clone "$GITHUB_REPO" "$INSTALL_PATH"; then
        show_success "Repository cloned successfully"
        
        # Install pnpm if not present
        show_progress "Installing pnpm package manager"
        if ! command_exists pnpm; then
            npm install -g pnpm
            if [ $? -eq 0 ]; then
                show_success "pnpm installed successfully"
            else
                show_error "Failed to install pnpm"
            fi
        fi
        
        # Change to installation directory
        cd "$INSTALL_PATH" || show_error "Failed to change to installation directory"
        
        # Install dependencies using pnpm
        show_progress "Installing dependencies"
        if pnpm install; then
            show_success "Dependencies installed successfully"

            # Build packages
            show_progress "Building packages"
            if pnpm run build --filter="@srcbook/*"; then
                show_success "Packages built successfully"
                
                # Show completion message
                echo -e "\n${GREEN}╭───────────────────────────╮${NC}"
                echo -e "${GREEN}│    CODELIVE COMPLETE!     │${NC}"
                echo -e "${GREEN}╰───────────────────────────╯${NC}\n"
                echo -e "${BLUE}To start the server, select option 1 from the main menu${NC}"
            else
                show_error "Failed to build packages"
            fi
        else
            show_error "Failed to install dependencies"
        fi
    else
        show_error "Failed to clone repository"
    fi
}

# Check if script is being run via curl
if [ -z "$PS1" ] || [ "$1" = "--install" ]; then
    check_server_running
    install_codelive
    exit 0
fi

# Show ASCII art and menu only in interactive mode
echo "
 ██████  ██████  ██████  ███████ ██      ██ ██    ██ ███████ 
██      ██    ██ ██    ██ ██      ██      ██ ██    ██ ██      
██      ██    ██ ██    ██ █████   ██      ██ ██    ██ █████   
██      ██    ██ ██    ██ ██      ██      ██  ██  ██  ██      
 ██████  ██████  ██████  ███████ ███████ ██   ████   ███████  
                  [ CLI INSTALLER ]

A Duran Company
"

# Interactive menu
while true; do
    echo -e "\nWelcome to CodeLive!"
    echo "Please select an option:"
    echo "1) Start CodeLive Server"
    echo "2) Install CodeLive"
    echo "3) Get API Key"
    echo "4) Exit"
    read -r choice

    case $choice in
        1) start_codelive_server ;;
        2) install_codelive ;;
        3) echo "API Key functionality coming soon..." ;;
        4) exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac
done

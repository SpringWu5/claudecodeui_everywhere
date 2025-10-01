#!/bin/bash

#==============================================================================
# Claude Code Everywhere - Interactive Setup Script (v3 - Final)
#
# This script automates the entire setup process, turning a local-only
# Claude Code UI into a globally accessible web application.
# It should be run from the 'scripts/' directory or the project root.
#==============================================================================

# --- Helper Functions for User-Friendly Output ---
print_info() { echo -e "\n\e[34m[INFO]\e[0m $1"; }
print_success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
print_warning() { echo -e "\e[33m[WARNING]\e[0m $1"; }
print_error() {
  echo -e "\e[31m[ERROR]\e[0m $1"
  exit 1
}
command_exists() { command -v "$1" >/dev/null 2>&1; }

# --- Get Project Root Directory ---
# This ensures the script works correctly even if run from the scripts subdir.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
# Change to project root to run all commands in the correct context
cd "$PROJECT_ROOT" || print_error "Could not navigate to project root directory."

# --- Script Start ---
clear
echo "================================================="
echo "  Welcome to the Claude Code Everywhere Setup! "
echo "================================================="
echo "This script will guide you through setting up a"
echo "publicly accessible UI for your Claude Code CLI."
echo "-------------------------------------------------"

# --- Phase 1: Environment & Prerequisite Checks ---
print_info "Phase 1: Checking your environment for necessary tools..."
for cmd in git npm curl; do
  if ! command_exists $cmd; then
    print_error "'$cmd' is not installed. Please install it and run this script again."
  fi
done
print_success "Basic tools (git, npm, curl) are installed."
if ! command_exists claude; then
  print_warning "'claude-code' CLI not found."
  read -p "Would you like to install it globally now? (y/n): " install_claude_cli
  if [[ "$install_claude_cli" == "y" ]]; then
    print_info "Installing @anthropic-ai/claude-code globally via npm..."
    if ! npm install -g @anthropic-ai/claude-code; then
      print_error "Installation failed. Please check your npm permissions and try installing it manually."
    fi
    print_success "'claude-code' CLI installed successfully."
  else
    print_error "Claude Code CLI is required. Please install it and run this script again."
  fi
fi
print_success "Claude Code CLI is ready."

# --- Phase 2: Domain & Cloudflare Prerequisite Check ---
print_info "Phase 2: Domain Name & Cloudflare Setup."
echo "This setup requires a domain name you own and a free Cloudflare account."
echo "The domain must be added to your Cloudflare account with its status as 'Active'."
read -p "Have you completed this step? (y/n): " domain_ready
if [[ "$domain_ready" != "y" ]]; then
  print_error "Please prepare your domain first. For a detailed guide, see our README.md file. Then, run this script again."
fi
print_success "Great! Let's proceed."

# --- Phase 3: Cloudflared Installation & Login ---
print_info "Phase 3: Setting up the Cloudflare Tunnel daemon (cloudflared)."
if ! command_exists cloudflared; then
  print_info "cloudflared not found. Attempting to install it for your system..."
  if [[ "$(uname)" == "Linux" ]]; then
    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb && sudo dpkg -i cloudflared.deb && rm cloudflared.deb
  else
    print_error "Automatic installation for your OS is not supported yet. Please install 'cloudflared' manually and re-run this script."
  fi
  if ! command_exists cloudflared; then
    print_error "cloudflared installation failed. Please try installing it manually."
  fi
  print_success "cloudflared installed successfully."
fi
CERT_PATH="$HOME/.cloudflared/cert.pem"
if [ -f "$CERT_PATH" ]; then
  print_success "You are already logged in to Cloudflare. Skipping login step."
else
  print_info "Now, please log in to your Cloudflare account to authorize this tunnel."
  (
    unset http_proxy https_proxy all_proxy
    cloudflared tunnel login
  )
  if [ ! -f "$CERT_PATH" ]; then
    print_error "Login process did not create the certificate file. Please try again."
  fi
  print_success "Successfully logged in to Cloudflare."
fi

# --- Phase 4: Tunnel Creation & DNS Routing ---
print_info "Phase 4: Selecting or Creating a permanent tunnel."
EXISTING_TUNNELS=$( (
  unset http_proxy https_proxy all_proxy
  cloudflared tunnel list 2>/dev/null
) | awk 'NR>1 {print $2}')
TUNNEL_NAME=""
if [ -n "$EXISTING_TUNNELS" ]; then
  print_info "We found the following existing tunnels in your account:"
  echo "$EXISTING_TUNNELS"
  read -p "Enter the name of a tunnel to reuse, or press [Enter] to create a new one: " CHOSEN_TUNNEL
  if [ -n "$CHOSEN_TUNNEL" ]; then
    if echo "$EXISTING_TUNNELS" | grep -q "^$CHOSEN_TUNNEL$"; then
      TUNNEL_NAME=$CHOSEN_TUNNEL
      print_success "Reusing existing tunnel: $TUNNEL_NAME"
    else
      print_warning "Tunnel '$CHOSEN_TUNNEL' not found. We will create a new one."
    fi
  fi
fi
if [ -z "$TUNNEL_NAME" ]; then
  read -p "Enter a name for your NEW tunnel (e.g., claude-ui-tunnel): " NEW_TUNNEL_NAME
  if [ -z "$NEW_TUNNEL_NAME" ]; then print_error "Tunnel name cannot be empty."; fi
  print_info "Creating new tunnel '$NEW_TUNNEL_NAME'..."
  (
    unset http_proxy https_proxy all_proxy
    cloudflared tunnel create "$NEW_TUNNEL_NAME"
  ) >/dev/null 2>&1
  if [ $? -ne 0 ]; then print_error "Failed to create tunnel."; fi
  TUNNEL_NAME=$NEW_TUNNEL_NAME
  print_success "Tunnel '$TUNNEL_NAME' created successfully."
fi
TUNNEL_ID=$( (
  unset http_proxy https_proxy all_proxy
  cloudflared tunnel list 2>/dev/null
) | grep "$TUNNEL_NAME" | awk '{print $1}')
if [ -z "$TUNNEL_ID" ]; then print_error "Could not retrieve the ID for tunnel '$TUNNEL_NAME'."; fi
read -p "Enter the full public subdomain you want to use (e.g., claude.your-domain.com): " PUBLIC_DOMAIN
if [ -z "$PUBLIC_DOMAIN" ]; then print_error "Public domain cannot be empty."; fi
print_info "Routing DNS for '$PUBLIC_DOMAIN' to your tunnel..."
(
  unset http_proxy https_proxy all_proxy
  cloudflared tunnel route dns "$TUNNEL_NAME" "$PUBLIC_DOMAIN"
)
if [ $? -ne 0 ]; then print_error "Failed to route DNS."; fi
print_success "DNS route created successfully."

# --- Phase 5: Project Installation & Configuration (FIXED) ---
print_info "Phase 5: Installing project dependencies and creating configuration."

print_info "Installing npm dependencies... (This may take a moment)"
npm install >/dev/null 2>&1
if [ $? -ne 0 ]; then
  print_error "npm install failed. Run 'npm install' manually to see errors."
fi
print_success "Project dependencies installed."

CONFIG_FILE=".cce_config"
echo "TUNNEL_NAME=\"${TUNNEL_NAME}\"" >$CONFIG_FILE
echo "PUBLIC_DOMAIN=\"${PUBLIC_DOMAIN}\"" >>$CONFIG_FILE
echo "TUNNEL_ID=\"${TUNNEL_ID}\"" >>$CONFIG_FILE
print_success "Configuration saved to $CONFIG_FILE."

# --- ROBUST VITE.CONFIG.JS MODIFICATION ---
print_info "Configuring vite.config.js for your public domain..."
# Backup the original file just in case
cp vite.config.js vite.config.js.bak

# Overwrite the file with a new, correct configuration using a here document
cat <<EOF >vite.config.js
import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ command, mode }) => {
  // Load env file based on \`mode\` in the current working directory.
  const env = loadEnv(mode, process.cwd(), '')

  return {
    plugins: [react()],
    server: {
      // Allow connections from any host
      host: true,
      
      // Explicitly allow your public domain
      allowedHosts: ['${PUBLIC_DOMAIN}'],

      port: parseInt(env.VITE_PORT) || 5173,
      proxy: {
        '/api': \`http://localhost:\${env.PORT || 3001}\`,
        '/ws': {
          target: \`ws://localhost:\${env.PORT || 3001}\`,
          ws: true
        },
        '/shell': {
          target: \`ws://localhost:\${env.PORT || 3002}\`,
          ws: true
        }
      }
    },
    build: {
      outDir: 'dist'
    }
  }
})
EOF
print_success "vite.config.js has been correctly configured."

# --- Phase 6: Generate Helper Scripts ---
print_info "Generating helper scripts in scripts/ directory..."
mkdir -p scripts # Ensure scripts directory exists

# Create scripts/start.sh
cat <<'EOF' >scripts/start.sh
#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
cd "$PROJECT_ROOT" || exit

CONFIG_FILE=".cce_config"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "\e[31m[ERROR]\e[0m Config file '$CONFIG_FILE' not found. Please run './scripts/setup.sh' first."
    exit 1
fi
source "$CONFIG_FILE"
SESSION_NAME="claude-code-everywhere"
if ! command -v tmux >/dev/null 2>&1; then
    echo -e "\e[31m[ERROR]\e[0m tmux not installed. Please run 'sudo apt install tmux'."
    exit 1
fi
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo -e "\e[33m[WARNING]\e[0m Session '$SESSION_NAME' is already running."
    echo "To attach, run: tmux attach -t $SESSION_NAME"
    exit 0
fi
echo "Starting new tmux session '$SESSION_NAME'..."
tmux new-session -d -s "$SESSION_NAME" -n "Server"
tmux send-keys -t "$SESSION_NAME:0" "npm run dev" C-m
tmux new-window -t "$SESSION_NAME:1" -n "Tunnel"
TUNNEL_CMD="( unset http_proxy https_proxy all_proxy; cloudflared tunnel run --url http://localhost:5173 ${TUNNEL_NAME} )"
tmux send-keys -t "$SESSION_NAME:1" "$TUNNEL_CMD" C-m
echo -e "\n\e[32m[SUCCESS]\e[0m Services are starting in the background."
echo "Your app is available at: https://${PUBLIC_DOMAIN}"
echo "-------------------------------------------------"
echo "To view logs, run:   tmux attach -t $SESSION_NAME"
echo "To stop services, run: ./scripts/stop.sh"
EOF
chmod +x scripts/start.sh

# Create scripts/stop.sh
cat <<'EOF' >scripts/stop.sh
#!/bin/bash
SESSION_NAME="claude-code-everywhere"
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Stopping tmux session '$SESSION_NAME'..."
    tmux kill-session -t "$SESSION_NAME"
    echo "Services stopped."
else
    echo "No active session found."
fi
EOF
chmod +x scripts/stop.sh

# Create scripts/uninstall.sh
cat <<'EOF' >scripts/uninstall.sh
#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
cd "$PROJECT_ROOT" || exit

echo "This will uninstall Claude Code Everywhere and delete your tunnel from Cloudflare."
read -p "Are you sure you want to continue? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi
CONFIG_FILE=".cce_config"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found. Nothing to uninstall."
    exit 0
fi
source "$CONFIG_FILE"
echo "1. Stopping services..."
./scripts/stop.sh
echo "2. Deleting Cloudflare tunnel '$TUNNEL_NAME'..."
( unset http_proxy https_proxy all_proxy; cloudflared tunnel delete -f "$TUNNEL_NAME" )
echo "3. Cleaning up local files..."
if [ -n "$PUBLIC_DOMAIN" ]; then
    sed -i.bak "s/allowedHosts: \['${PUBLIC_DOMAIN}'\]/allowedHosts: []/" vite.config.js && rm vite.config.js.bak
fi
rm -f .cce_config scripts/start.sh scripts/stop.sh
echo "Uninstallation complete. This uninstall script has not been deleted."
EOF
chmod +x scripts/uninstall.sh
print_success "Helper scripts created in scripts/ directory."

# --- Final Instructions ---
echo ""
echo "================================================="
echo "🎉 Setup Complete! 🎉"
echo "================================================="
print_info "To start your instance, run:"
echo "  ./scripts/start.sh"
print_info "To stop it, run:"
echo "  ./scripts/stop.sh"
print_info "To uninstall, run:"
echo "  ./scripts/uninstall.sh"
print_info "Your application will be accessible at:"
echo "  https://${PUBLIC_DOMAIN}"
echo "================================================="

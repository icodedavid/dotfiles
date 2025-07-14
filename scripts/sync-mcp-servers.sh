#!/usr/bin/env bash
. "$HOME/dotfiles/globals.sh"
[ -f "$HOME/.env" ] && . "$HOME/.env"

command -v gum >/dev/null || "$HOME/dotfiles/scripts/install-gum.sh"

# Handle --remove-all flag
if [ "$1" = "--remove-all" ]; then
    echo "Removing all MCP servers..."
    claude_servers=$(claude mcp list 2>/dev/null | cut -d: -f1 | grep -v "^$" | grep -v "No MCP servers configured")
    for server in $claude_servers; do
        claude mcp remove "$server" && echo "Removed $server"
    done
    gum style --foreground 32 "✅ All MCP servers removed"
    exit 0
fi

# MCP servers configuration (compatible with macOS bash 3.2)
mcp_servers_brave_search=${BRAVE_SEARCH:-true}
mcp_servers_fetch=${FETCH:-true}
mcp_servers_git=${GIT:-true}
mcp_servers_github=${GITHUB:-true}
mcp_servers_playwright=${PLAYWRIGHT:-true}
mcp_servers_sequential_thinking=${SEQUENTIAL_THINKING:-true}

# Server package mappings
get_server_package() {
    case "$1" in
    fetch) echo "@kazuph/mcp-fetch" ;;
    git) echo "@cyanheads/git-mcp-server" ;;
    playwright) echo "@playwright/mcp" ;;
    brave-search) echo "@modelcontextprotocol/server-brave-search" ;;
    github) echo "@modelcontextprotocol/server-github@2025.4.8" ;;
    sequential-thinking) echo "@modelcontextprotocol/server-sequential-thinking" ;;
    *) echo "@modelcontextprotocol/server-$1" ;;
    esac
}

# Check if server is already configured
is_server_configured() {
    echo "$claude_servers" | grep -q "^$1$"
}

# Add server with optional environment
add_server() {
    server="$1"
    env_vars="$2"
    package=$(get_server_package "$server")

    if [ -n "$env_vars" ]; then
        claude mcp add "$server" -- $env_vars npx -y $package && echo "Added $server"
    else
        claude mcp add "$server" -- npx -y $package && echo "Added $server"
    fi
}

# Get current Claude servers
claude_servers=$(claude mcp list 2>/dev/null | cut -d: -f1 | grep -v "^$" | grep -v "No MCP servers configured")

# Build enabled servers list
enabled_servers=""
for server in brave-search fetch git github playwright sequential-thinking; do
    var_name="mcp_servers_${server//-/_}"
    if [ "${!var_name}" = "true" ]; then
        enabled_servers="$enabled_servers $server"
    fi
done

# Remove servers not in enabled list
for server in $claude_servers; do
    echo "$enabled_servers" | grep -q "\b$server\b" || { claude mcp remove "$server" && echo "Removed $server"; }
done

# Refresh server list
claude_servers=$(claude mcp list 2>/dev/null | cut -d: -f1 | grep -v "^$" | grep -v "No MCP servers configured")

# Add enabled servers
if [ "$mcp_servers_brave_search" = "true" ]; then
    is_server_configured "brave-search" || {
        if grep -q "^BRAVE_API_KEY=" ~/.env 2>/dev/null; then
            BRAVE_API_KEY=$(grep "^BRAVE_API_KEY=" ~/.env | cut -d= -f2)
            add_server "brave-search" "BRAVE_API_KEY=$BRAVE_API_KEY"
        fi
    }
fi

if [ "$mcp_servers_fetch" = "true" ]; then
    is_server_configured "fetch" || add_server "fetch"
fi

if [ "$mcp_servers_git" = "true" ]; then
    is_server_configured "git" || add_server "git"
fi

if [ "$mcp_servers_github" = "true" ]; then
    is_server_configured "github" || {
        command -v gh >/dev/null && gh auth status >/dev/null 2>&1 && add_server "github"
    }
fi

if [ "$mcp_servers_playwright" = "true" ]; then
    is_server_configured "playwright" || add_server "playwright"
fi

if [ "$mcp_servers_sequential_thinking" = "true" ]; then
    is_server_configured "sequential-thinking" || add_server "sequential-thinking"
fi

gum style --foreground 32 "✅ MCP sync complete"
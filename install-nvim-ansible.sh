
#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Neovim YAML / Ansible IDE installer
#
# OS: Ubuntu 24.04
# Architecture: x86_64
# User: regular Linux user (not root)
#
# Existing Ansible Core is preserved.
# ============================================================

readonly CONFIG_DIR="${HOME}/.config/nvim"
readonly DATA_DIR="${HOME}/.local/share/nvim"
readonly STATE_DIR="${HOME}/.local/state/nvim"

log() {
    echo -e "\n[INFO] $*"
}

warn() {
    echo -e "\n[WARN] $*" >&2
}

die() {
    echo -e "\n[ERROR] $*" >&2
    exit 1
}

# ------------------------------------------------------------
# 1. Environment checks
# ------------------------------------------------------------

[[ "$EUID" -ne 0 ]] || die "Run as a regular user, not root."

[[ -f /etc/os-release ]] || die "Cannot detect OS."

source /etc/os-release

[[ "$ID" == "ubuntu" && "$VERSION_ID" == "24.04" ]] \
    || die "Ubuntu 24.04 is required."

[[ "$(uname -m)" == "x86_64" ]] \
    || die "Only x86_64 is supported."

command -v sudo >/dev/null 2>&1 \
    || die "sudo is required."

log "Environment check passed."

# ------------------------------------------------------------
# 2. Check existing Ansible Core
# ------------------------------------------------------------

log "Checking existing Ansible installation..."

command -v ansible >/dev/null 2>&1 \
    || die "Ansible Core is not installed."

ANSIBLE_VERSION="$(
    ansible --version |
    sed -n '1s/.*core \([0-9.]*\).*/\1/p'
)"

[[ -n "$ANSIBLE_VERSION" ]] \
    || die "Cannot detect Ansible Core version."

if ! python3 - "$ANSIBLE_VERSION" <<'PY'
import sys

version = tuple(map(int, sys.argv[1].split(".")))
sys.exit(0 if version >= (2, 9) else 1)
PY
then
    die "Ansible Core 2.9 or newer is required."
fi

echo "Detected Ansible Core: ${ANSIBLE_VERSION}"
ansible --version | head -n 5

# ------------------------------------------------------------
# 3. Install system dependencies
# ------------------------------------------------------------

log "Installing system dependencies..."

sudo apt-get update

sudo apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    tar \
    gzip \
    build-essential \
    gcc \
    g++ \
    make \
    ripgrep \
    fd-find \
    python3 \
    python3-venv \
    python3-pip \
    pipx \
    yamllint \
    ca-certificates \
    gnupg

# ------------------------------------------------------------
# 4. Install Neovim stable release
# ------------------------------------------------------------

log "Installing Neovim..."

TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

curl -fL \
    https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz \
    -o "${TMP_DIR}/nvim.tar.gz"

sudo tar -C /opt -xzf "${TMP_DIR}/nvim.tar.gz"

sudo ln -sfn \
    /opt/nvim-linux-x86_64/bin/nvim \
    /usr/local/bin/nvim

nvim --version | head -n 2

# ------------------------------------------------------------
# 5. Install Node.js 22 LTS
# ------------------------------------------------------------

log "Installing Node.js 22 LTS..."

curl -fsSL \
    https://deb.nodesource.com/setup_22.x \
    | sudo -E bash -

sudo apt-get install -y nodejs

node --version
npm --version

# ------------------------------------------------------------
# 6. Install Language Servers and Prettier
# ------------------------------------------------------------

log "Installing YAML and Ansible Language Servers..."

sudo npm install -g \
    yaml-language-server \
    @ansible/ansible-language-server \
    prettier

yaml-language-server --version
prettier --version

command -v ansible-language-server \
    || die "Ansible Language Server installation failed."

# ------------------------------------------------------------
# 7. Install ansible-lint via pipx
# ------------------------------------------------------------

log "Installing ansible-lint..."

pipx ensurepath

export PATH="${HOME}/.local/bin:${PATH}"

if pipx list --short 2>/dev/null \
    | grep -q '^ansible-lint '
then
    pipx upgrade ansible-lint
else
    pipx install ansible-lint
fi

ansible-lint --version

# ------------------------------------------------------------
# 8. Backup existing Neovim configuration
# ------------------------------------------------------------

if [[ -d "$CONFIG_DIR" ]]; then

    BACKUP_DIR="${CONFIG_DIR}.backup.$(date +%Y%m%d-%H%M%S)"

    log "Backing up existing configuration..."

    mv "$CONFIG_DIR" "$BACKUP_DIR"

    echo "Backup created: $BACKUP_DIR"
fi

mkdir -p "$CONFIG_DIR"

# ------------------------------------------------------------
# 9. Install lazy.nvim
# ------------------------------------------------------------

log "Installing lazy.nvim..."

mkdir -p "${DATA_DIR}/lazy"

git clone --filter=blob:none \
    https://github.com/folke/lazy.nvim.git \
    "${DATA_DIR}/lazy/lazy.nvim"

# ------------------------------------------------------------
# 10. Create Neovim configuration
# ------------------------------------------------------------

log "Creating init.lua..."

cat > "${CONFIG_DIR}/init.lua" <<'LUA'

-- ==========================================================
-- Neovim YAML / Ansible IDE
-- ==========================================================

-- ----------------------------------------------------------
-- Basic settings
-- ----------------------------------------------------------

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2

vim.opt.smartindent = true
vim.opt.wrap = false

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"

vim.opt.updatetime = 300
vim.opt.timeoutlen = 500

vim.opt.splitright = true
vim.opt.splitbelow = true

-- ----------------------------------------------------------
-- Filetype detection
-- ----------------------------------------------------------

vim.filetype.add({
    pattern = {
        [".*/playbooks/.*%.ya?ml"] = "yaml.ansible",
        [".*/roles/.*%.ya?ml"] = "yaml.ansible",
        [".*/tasks/.*%.ya?ml"] = "yaml.ansible",
        [".*/handlers/.*%.ya?ml"] = "yaml.ansible",
        [".*/defaults/.*%.ya?ml"] = "yaml.ansible",
        [".*/vars/.*%.ya?ml"] = "yaml.ansible",
        [".*/meta/.*%.ya?ml"] = "yaml.ansible",
        [".*/group_vars/.*%.ya?ml"] = "yaml.ansible",
        [".*/host_vars/.*%.ya?ml"] = "yaml.ansible",
        [".*/inventory/.*%.ya?ml"] = "yaml.ansible",
        [".*/.*playbook.*%.ya?ml"] = "yaml.ansible",
        [".*%.ansible%.ya?ml"] = "yaml.ansible",
    },
})

-- ----------------------------------------------------------
-- lazy.nvim bootstrap
-- ----------------------------------------------------------

local lazypath =
    vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

vim.opt.rtp:prepend(lazypath)

-- ----------------------------------------------------------
-- Plugins
-- ----------------------------------------------------------

require("lazy").setup({

    {
        "neovim/nvim-lspconfig",
    },

    {
        "nvim-treesitter/nvim-treesitter",
        branch = "master",
        build = ":TSUpdate",

        config = function()

            require("nvim-treesitter.configs").setup({

                ensure_installed = {
                    "yaml",
                    "lua",
                    "bash",
                    "json",
                },

                highlight = {
                    enable = true,
                },

                indent = {
                    enable = true,
                },
            })

            vim.treesitter.language.register(
                "yaml",
                { "yaml.ansible" }
            )
        end,
    },

    {
        "stevearc/conform.nvim",

        config = function()

            require("conform").setup({

                formatters_by_ft = {
                    yaml = { "prettier" },
                },

                format_on_save = {
                    timeout_ms = 3000,
                    lsp_format = "never",
                },
            })
        end,
    },

})

-- ----------------------------------------------------------
-- YAML Language Server
-- ----------------------------------------------------------

vim.lsp.config("yamlls", {

    filetypes = {
        "yaml",
    },

    settings = {

        yaml = {
            validate = true,
            hover = true,
            completion = true,

            format = {
                enable = true,
            },

            schemaStore = {
                enable = true,
                url = "https://www.schemastore.org/api/json/catalog.json",
            },
        },
    },
})

vim.lsp.enable("yamlls")

-- ----------------------------------------------------------
-- Ansible Language Server
-- ----------------------------------------------------------

vim.lsp.config("ansiblels", {

    settings = {

        ansible = {

            ansible = {
                path = "ansible",
            },

            executionEnvironment = {
                enabled = false,
            },

            python = {
                interpreterPath = "python3",
            },

            validation = {
                enabled = true,

                lint = {
                    enabled = true,
                    path = "ansible-lint",
                },
            },
        },
    },
})

vim.lsp.enable("ansiblels")

-- ----------------------------------------------------------
-- Diagnostics
-- ----------------------------------------------------------

vim.diagnostic.config({

    virtual_text = true,
    signs = true,
    underline = true,

    update_in_insert = false,
    severity_sort = true,

    float = {
        border = "rounded",
        source = true,
    },
})

-- ----------------------------------------------------------
-- LSP key mappings
-- ----------------------------------------------------------

vim.api.nvim_create_autocmd("LspAttach", {

    callback = function(event)

        local opts = {
            buffer = event.buf,
            silent = true,
        }

        vim.keymap.set("n", "K",
            vim.lsp.buf.hover, opts)

        vim.keymap.set("n", "gd",
            vim.lsp.buf.definition, opts)

        vim.keymap.set("n", "gr",
            vim.lsp.buf.references, opts)

        vim.keymap.set("n", "gi",
            vim.lsp.buf.implementation, opts)

        vim.keymap.set("n", "<leader>rn",
            vim.lsp.buf.rename, opts)

        vim.keymap.set("n", "<leader>ca",
            vim.lsp.buf.code_action, opts)

        vim.keymap.set("n", "<leader>d",
            vim.diagnostic.open_float, opts)

        local client =
            vim.lsp.get_client_by_id(event.data.client_id)

        if client and
            client:supports_method("textDocument/completion") then

            vim.lsp.completion.enable(
                true,
                client.id,
                event.buf,
                { autotrigger = true }
            )
        end
    end,
})

-- ----------------------------------------------------------
-- Completion
-- ----------------------------------------------------------

vim.keymap.set("i", "<C-Space>", function()
    vim.lsp.completion.get()
end)

-- ----------------------------------------------------------
-- Formatting
-- ----------------------------------------------------------

vim.keymap.set({ "n", "v" }, "<leader>f", function()

    require("conform").format({
        async = true,
        lsp_format = "never",
    })

end)

-- ----------------------------------------------------------
-- Diagnostics navigation
-- ----------------------------------------------------------

vim.keymap.set("n", "[d",
    vim.diagnostic.goto_prev)

vim.keymap.set("n", "]d",
    vim.diagnostic.goto_next)

-- ----------------------------------------------------------
-- File explorer
-- ----------------------------------------------------------

vim.keymap.set("n", "<leader>e",
    vim.cmd.Ex)

-- ----------------------------------------------------------
-- Ansible helpers
-- ----------------------------------------------------------

vim.api.nvim_create_user_command(
    "AnsibleFiletype",
    function()

        vim.bo.filetype = "yaml.ansible"

        print("Filetype set to yaml.ansible")

    end,
    {}
)

-- ----------------------------------------------------------
-- Startup notification
-- ----------------------------------------------------------

vim.notify("YAML / Ansible IDE loaded")

LUA

# ------------------------------------------------------------
# 11. Install plugins and parsers
# ------------------------------------------------------------

log "Installing Neovim plugins..."

nvim --headless "+Lazy! sync" +qa

log "Installing Tree-sitter parsers..."

nvim --headless \
    -c "TSInstallSync yaml lua bash json" \
    -c "qa"

# ------------------------------------------------------------
# 12. Final validation
# ------------------------------------------------------------

log "Validating installation..."

check_command() {

    local cmd="$1"

    if command -v "$cmd" >/dev/null 2>&1; then
        echo "[OK] $cmd: $(command -v "$cmd")"
    else
        warn "$cmd not found"
    fi
}

check_command nvim
check_command node
check_command npm
check_command ansible
check_command ansible-playbook
check_command ansible-lint
check_command yamllint
check_command yaml-language-server
check_command ansible-language-server
check_command prettier

echo
echo "Neovim version:"
nvim --version | head -n 2

echo
echo "Ansible version:"
ansible --version | head -n 5

echo
echo "Installed Python tools:"
ansible-lint --version
yamllint --version

echo
echo "============================================"
echo " Neovim YAML / Ansible IDE installed"
echo "============================================"

echo
echo "Run:"
echo "  nvim"

echo
echo "Inside Neovim:"
echo "  :checkhealth"
echo "  :LspInfo"
echo "  :ConformInfo"
echo "  :TSStatus"

echo
echo "Configuration:"
echo "  ${CONFIG_DIR}/init.lua"

echo
echo "Ansible Core was not modified."

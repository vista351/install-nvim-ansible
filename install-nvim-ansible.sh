
#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# Neovim YAML / Ansible IDE installer
# OS: Ubuntu 24.04 x86_64
# Existing Ansible Core is preserved
# Versions are pinned
# ============================================================

trap 'echo "ERROR: Installation failed at line $LINENO"; exit 1' ERR

# ------------------------------------------------------------
# 0. Version lock
# ------------------------------------------------------------

NVIM_VERSION="0.11.7"
NODE_VERSION="26.13.1"
LAZY_VERSION="v11.17.5"

YAML_LS_VERSION="2.0.0"
ANSIBLE_LS_VERSION="26.6.0"
PRETTIER_VERSION="3.10.1"

ANSIBLE_LINT_VERSION="26.11.0"
YAMLLINT_VERSION="1.38.0"

LSPCONFIG_TAG="v2.12.0"
CONFORM_TAG="v9.1.0"

echo "Pinned versions:"
echo "Neovim: $NVIM_VERSION"
echo "Node.js: $NODE_VERSION"
echo "lazy.nvim: $LAZY_VERSION"
echo "YAML LS: $YAML_LS_VERSION"
echo "Ansible LS: $ANSIBLE_LS_VERSION"
echo "Prettier: $PRETTIER_VERSION"
echo "ansible-lint: $ANSIBLE_LINT_VERSION"
echo "yamllint: $YAMLLINT_VERSION"

# ------------------------------------------------------------
# 1. Basic checks
# ------------------------------------------------------------

if [[ "$EUID" -eq 0 ]]; then
    echo "Run this script as a regular user, not root."
    exit 1
fi

if [[ ! -f /etc/os-release ]]; then
    echo "Cannot determine operating system."
    exit 1
fi

source /etc/os-release

if [[ "$ID" != "ubuntu" || "$VERSION_ID" != "24.04" ]]; then
    echo "This script supports Ubuntu 24.04 only."
    exit 1
fi

if [[ "$(dpkg --print-architecture)" != "amd64" ]]; then
    echo "This script supports amd64 architecture only."
    exit 1
fi

if ! command -v ansible >/dev/null 2>&1; then
    echo "Ansible Core is not installed."
    echo "Install Ansible Core separately."
    exit 1
fi

ANSIBLE_BIN_BEFORE="$(command -v ansible)"
ANSIBLE_VERSION_BEFORE="$(ansible --version | head -n 1)"

echo
echo "Existing Ansible:"
echo "$ANSIBLE_VERSION_BEFORE"
echo "Binary: $ANSIBLE_BIN_BEFORE"

echo
echo "Ansible Core will NOT be installed or upgraded."
echo

sudo -v

TEMP_DIR="$(mktemp -d)"

trap 'rm -rf "$TEMP_DIR"' EXIT

export PATH="/usr/local/bin:$HOME/.local/bin:$PATH"

# ------------------------------------------------------------
# 2. System dependencies
# ------------------------------------------------------------

echo
echo "[1/9] Installing system dependencies..."

sudo apt-get update

sudo apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    tar \
    xz-utils \
    gzip \
    build-essential \
    gcc \
    g++ \
    make \
    ripgrep \
    fd-find \
    python3 \
    python3-venv \
    pipx \
    ca-certificates \
    gnupg

# ------------------------------------------------------------
# 3. Install exact Node.js version
# ------------------------------------------------------------

echo
echo "[2/9] Installing Node.js $NODE_VERSION..."

NODE_ARCHIVE="node-v${NODE_VERSION}-linux-x64.tar.xz"
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/${NODE_ARCHIVE}"

curl -fL "$NODE_URL" \
    -o "$TEMP_DIR/$NODE_ARCHIVE"

curl -fsSL \
    "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" \
    -o "$TEMP_DIR/SHASUMS256.txt"

grep "  ${NODE_ARCHIVE}$" \
    "$TEMP_DIR/SHASUMS256.txt" \
    > "$TEMP_DIR/node.sha256"

if [[ ! -s "$TEMP_DIR/node.sha256" ]]; then
    echo "Could not find Node.js archive checksum."
    exit 1
fi

(
    cd "$TEMP_DIR"
    sha256sum -c node.sha256
)

NODE_DIR="/opt/node-v${NODE_VERSION}-linux-x64"

sudo rm -rf "$NODE_DIR"

sudo tar -xJf "$TEMP_DIR/$NODE_ARCHIVE" \
    -C /opt

sudo ln -sfn "$NODE_DIR/bin/node" /usr/local/bin/node
sudo ln -sfn "$NODE_DIR/bin/npm" /usr/local/bin/npm
sudo ln -sfn "$NODE_DIR/bin/npx" /usr/local/bin/npx

echo "Node.js: $(node --version)"
echo "npm: $(npm --version)"

# ------------------------------------------------------------
# 4. Install exact Neovim version
# ------------------------------------------------------------

echo
echo "[3/9] Installing Neovim $NVIM_VERSION..."

NVIM_ARCHIVE="nvim-linux-x86_64.tar.gz"

curl -fL \
    "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/${NVIM_ARCHIVE}" \
    -o "$TEMP_DIR/$NVIM_ARCHIVE"

sudo rm -rf /opt/nvim-linux-x86_64

sudo tar -xzf "$TEMP_DIR/$NVIM_ARCHIVE" -C /opt

sudo ln -sfn \
    /opt/nvim-linux-x86_64/bin/nvim \
    /usr/local/bin/nvim

if ! nvim --version | head -n 1 | grep -q "v${NVIM_VERSION}"; then
    echo "Neovim version verification failed."
    exit 1
fi

echo "Neovim: $(nvim --version | head -n 1)"

# ------------------------------------------------------------
# 5. Install exact language server and formatter versions
# ------------------------------------------------------------

echo
echo "[4/9] Installing language servers and formatter..."

sudo npm install -g --save-exact \
    "yaml-language-server@${YAML_LS_VERSION}" \
    "@ansible/ansible-language-server@${ANSIBLE_LS_VERSION}" \
    "prettier@${PRETTIER_VERSION}"

echo "YAML Language Server:"
yaml-language-server --version || true

echo "Ansible Language Server:"
command -v ansible-language-server

echo "Prettier:"
prettier --version

# ------------------------------------------------------------
# 6. Install exact Python tool versions using pipx
# ------------------------------------------------------------

echo
echo "[5/9] Installing Python tools..."

pipx ensurepath

export PATH="$HOME/.local/bin:$PATH"

# Reinstall exact pinned versions.
# pipx environments are isolated from system Python/Ansible.

if pipx list --short | grep -q '^ansible-lint '; then
    pipx uninstall ansible-lint
fi

if pipx list --short | grep -q '^yamllint '; then
    pipx uninstall yamllint
fi

pipx install "ansible-lint==${ANSIBLE_LINT_VERSION}"
pipx install "yamllint==${YAMLLINT_VERSION}"

echo
echo "ansible-lint:"
ansible-lint --version

echo
echo "yamllint:"
yamllint --version

# ------------------------------------------------------------
# 7. Prepare Neovim configuration
# ------------------------------------------------------------

echo
echo "[6/9] Preparing Neovim configuration..."

NVIM_CONFIG="$HOME/.config/nvim"

mkdir -p "$NVIM_CONFIG"

# Back up only init.lua.
# Preserve lazy-lock.json for reproducible plugin installation.

if [[ -f "$NVIM_CONFIG/init.lua" ]]; then

    BACKUP_FILE="$NVIM_CONFIG/init.lua.backup.$(date +%Y%m%d_%H%M%S)"

    cp -a "$NVIM_CONFIG/init.lua" "$BACKUP_FILE"

    echo "Previous init.lua backed up to:"
    echo "$BACKUP_FILE"

fi

LAZY_DIR="$HOME/.local/share/nvim/lazy/lazy.nvim"

mkdir -p "$(dirname "$LAZY_DIR")"

# Install or checkout the exact lazy.nvim version.

if [[ -d "$LAZY_DIR/.git" ]]; then

    git -C "$LAZY_DIR" fetch --depth 1 origin \
        "refs/tags/${LAZY_VERSION}:refs/tags/${LAZY_VERSION}"

    git -C "$LAZY_DIR" checkout --detach "$LAZY_VERSION"

else

    rm -rf "$LAZY_DIR"

    git clone --depth 1 \
        --branch "$LAZY_VERSION" \
        https://github.com/folke/lazy.nvim.git \
        "$LAZY_DIR"

fi

# ------------------------------------------------------------
# 8. Create init.lua
# ------------------------------------------------------------

echo
echo "[7/9] Creating Neovim configuration..."

cat > "$NVIM_CONFIG/init.lua" <<'LUA'

-- ==========================================================
-- Basic settings
-- ==========================================================

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 300
vim.opt.completeopt = { "menu", "menuone", "noselect" }

-- ==========================================================
-- Ansible YAML filetype detection
-- ==========================================================

local function detect_ansible_yaml(path, bufnr)

    path = path:gsub("\\", "/")

    local ansible_directories = {
        "/inventory/",
        "/group_vars/",
        "/host_vars/",
        "/roles/",
        "/tasks/",
        "/handlers/",
        "/defaults/",
        "/vars/",
        "/meta/",
        "/playbooks/",
        "/playbook/",
    }

    for _, directory in ipairs(ansible_directories) do

        if path:find(directory, 1, true) then
            return "yaml.ansible"
        end

    end

    local filename = vim.fn.fnamemodify(path, ":t")

    local ansible_files = {
        ["playbook.yml"] = true,
        ["playbook.yaml"] = true,
        ["site.yml"] = true,
        ["site.yaml"] = true,
        ["main.yml"] = true,
        ["main.yaml"] = true,
    }

    if ansible_files[filename] then
        return "yaml.ansible"
    end

    return nil

end

vim.filetype.add({

    extension = {
        yml = detect_ansible_yaml,
        yaml = detect_ansible_yaml,
    },

})

-- ==========================================================
-- Bootstrap lazy.nvim
-- ==========================================================

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then

    error("lazy.nvim is missing. Run install.sh again.")

end

vim.opt.rtp:prepend(lazypath)

-- ==========================================================
-- Plugins
-- ==========================================================

require("lazy").setup({

    -- ------------------------------------------------------
    -- LSP configurations
    -- ------------------------------------------------------

    {
        "neovim/nvim-lspconfig",
        tag = "v2.12.0",
        lazy = false,
    },

    -- ------------------------------------------------------
    -- Tree-sitter
    -- ------------------------------------------------------

    {
        "nvim-treesitter/nvim-treesitter",
        branch = "master",
        lazy = false,

        config = function()

            require("nvim-treesitter.configs").setup({

                ensure_installed = {},

                sync_install = false,
                auto_install = false,

                highlight = {
                    enable = true,
                },

                indent = {
                    enable = true,
                },

            })

        end,
    },

    -- ------------------------------------------------------
    -- Formatting
    -- ------------------------------------------------------

    {
        "stevearc/conform.nvim",
        tag = "v9.1.0",
        lazy = false,

        config = function()

            require("conform").setup({

                formatters_by_ft = {
                    yaml = { "prettier" },
                },

                format_on_save = function(bufnr)

                    if vim.bo[bufnr].filetype == "yaml" then

                        return {
                            timeout_ms = 2000,
                            lsp_format = "never",
                        }

                    end

                end,

            })

        end,
    },

}, {

    -- Preserve exact plugin commits between installations.
    lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json",

})

-- ==========================================================
-- YAML Language Server
-- ==========================================================

vim.lsp.config("yamlls", {

    filetypes = {
        "yaml",
    },

    settings = {

        yaml = {
            validate = true,
            completion = true,
            hover = true,
        },

    },

})

vim.lsp.enable("yamlls")

-- ==========================================================
-- Ansible Language Server
-- ==========================================================

vim.lsp.config("ansiblels", {

    filetypes = {
        "yaml.ansible",
    },

    root_markers = {
        "ansible.cfg",
        ".ansible-lint",
        ".git",
    },

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

-- ==========================================================
-- LSP keymaps
-- ==========================================================

vim.api.nvim_create_autocmd("LspAttach", {

    callback = function(args)

        local opts = {
            buffer = args.buf,
            silent = true,
        }

        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
        vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)

        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)

    end,

})

-- ==========================================================
-- General keymaps
-- ==========================================================

vim.keymap.set("n", "<leader>e", vim.cmd.Ex)

vim.keymap.set("n", "<leader>f", function()

    require("conform").format({
        async = true,
        lsp_format = "never",
    })

end)

vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist)

LUA

# ------------------------------------------------------------
# 9. Install plugins and Tree-sitter parsers
# ------------------------------------------------------------

echo
echo "[8/9] Installing Neovim plugins..."

nvim --headless "+Lazy! sync" +qa

# Verify that the lock file has been generated.

if [[ ! -s "$NVIM_CONFIG/lazy-lock.json" ]]; then
    echo "ERROR: lazy-lock.json was not generated."
    exit 1
fi

echo
echo "Plugin lock file:"
echo "$NVIM_CONFIG/lazy-lock.json"

echo
echo "Checking Tree-sitter parsers..."

# Install only missing or unavailable parsers.
# JSON is intentionally excluded.
# No forced reinstall and no interactive confirmation.

nvim --headless \
    -c "lua \
        local wanted = {'yaml', 'lua', 'bash'}; \
        local missing = {}; \
        for _, lang in ipairs(wanted) do \
            local ok = pcall(vim.treesitter.language.add, lang); \
            if not ok then \
                table.insert(missing, lang); \
            end; \
        end; \
        if #missing > 0 then \
            print('Installing missing parsers: ' .. table.concat(missing, ', ')); \
            vim.cmd('TSInstallSync ' .. table.concat(missing, ' ')); \
        else \
            print('All required Tree-sitter parsers are already available.'); \
        end" \
    -c "qa"

# Verify required parsers.

nvim --headless \
    -c "lua \
        for _, lang in ipairs({'yaml', 'lua', 'bash'}) do \
            local ok, err = pcall(vim.treesitter.language.add, lang); \
            if not ok then \
                error('Tree-sitter parser failed: ' .. lang .. ': ' .. tostring(err)); \
            end; \
            print('Tree-sitter parser OK: ' .. lang); \
        end" \
    -c "qa"

# ------------------------------------------------------------
# 10. Final verification
# ------------------------------------------------------------

echo
echo "[9/9] Verifying installation..."

echo
echo "Neovim:"
nvim --version | head -n 1

echo
echo "Node.js:"
node --version

echo
echo "npm:"
npm --version

echo
echo "Ansible Core:"
ansible --version | head -n 1

if [[ "$(command -v ansible)" != "$ANSIBLE_BIN_BEFORE" ]]; then
    echo "WARNING: Ansible executable path has changed."
fi

echo
echo "YAML Language Server:"
command -v yaml-language-server

echo
echo "Ansible Language Server:"
command -v ansible-language-server

echo
echo "Ansible Lint:"
ansible-lint --version

echo
echo "Yamllint:"
yamllint --version

echo
echo "Prettier:"
prettier --version

echo
echo "lazy.nvim:"
git -C "$LAZY_DIR" describe --tags --exact-match

echo
echo "Plugin lock file:"
ls -lh "$NVIM_CONFIG/lazy-lock.json"

echo
echo "Installation completed successfully."

echo
echo "Start Neovim:"
echo "  nvim"

echo
echo "Useful commands:"
echo "  :checkhealth"
echo "  :LspInfo"
echo "  :TSInstallInfo"

echo
echo "Configuration:"
echo "  $NVIM_CONFIG/init.lua"

echo
echo "Plugin versions:"
echo "  $NVIM_CONFIG/lazy-lock.json"


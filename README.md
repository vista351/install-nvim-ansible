# Neovim YAML / Ansible IDE

Автоматизированная установка и настройка Neovim для комфортной работы с YAML-файлами и Ansible Playbooks в терминальной среде Ubuntu 24.04.

Проект предназначен для системных администраторов и DevOps-инженеров, которые работают с инфраструктурой через SSH и используют Ansible для автоматизации управления серверами.

## Возможности

После установки Neovim получает функциональность небольшой IDE:

- Подсветка синтаксиса YAML и Ansible.
- Автоматическое дополнение кода.
- Интеграция с Language Server Protocol (LSP).
- Диагностика синтаксических ошибок.
- Подсказки по структуре YAML и Ansible.
- Переход к определениям и поиск ссылок.
- Проверка Ansible Playbooks.
- Автоматическое форматирование YAML.
- Проверка качества YAML и Ansible-конфигураций.

## Архитектура

| Компонент | Назначение |
|---|---|
| Neovim | Основной терминальный редактор |
| lazy.nvim | Менеджер плагинов |
| nvim-lspconfig | Конфигурации Language Server |
| yaml-language-server | Поддержка YAML через LSP |
| ansible-language-server | Поддержка Ansible через LSP |
| ansible-lint | Проверка Ansible Playbooks |
| yamllint | Проверка качества YAML |
| nvim-treesitter | Подсветка и разбор синтаксиса |
| conform.nvim | Управление форматированием |
| Prettier | Форматирование YAML |
| Node.js 22 LTS | Среда выполнения Language Server |
| pipx | Изолированная установка Python-инструментов |

## Требования

- Ubuntu 24.04 LTS.
- Архитектура x86_64.
- Доступ к Интернету.
- Учетная запись обычного пользователя с правами sudo.
- Установленный Ansible Core версии 2.9 или новее.

**Важно:** скрипт не устанавливает, не обновляет и не изменяет существующий Ansible Core. Используется уже установленная системная версия Ansible.

## Установка

### 1. Клонирование репозитория

```bash
git clone https://github.com/USERNAME/nvim-ansible-ide.git
cd nvim-ansible-ide
```

### 2. Подготовка скрипта

```bash
chmod +x install-nvim-ansible.sh
```

### 3. Запуск установки

```bash
./install-nvim-ansible.sh
```

Скрипт автоматически:

1. Проверяет операционную систему и архитектуру.
2. Проверяет наличие Ansible Core.
3. Устанавливает системные зависимости.
4. Устанавливает стабильную версию Neovim.
5. Устанавливает Node.js 22 LTS.
6. Устанавливает YAML Language Server.
7. Устанавливает Ansible Language Server.
8. Устанавливает ansible-lint через pipx.
9. Устанавливает yamllint.
10. Устанавливает и настраивает плагины Neovim.
11. Устанавливает YAML Tree-sitter parser.
12. Создает конфигурацию редактора.

Существующая конфигурация Neovim при наличии предварительно сохраняется в резервный каталог.

## Проверка установки

После завершения установки запустить редактор:

```bash
nvim
```

Проверить состояние компонентов:

```vim
:checkhealth
```

Дополнительные команды:

| Команда | Назначение |
|---|---|
| `:LspInfo` | Проверка подключенных LSP |
| `:ConformInfo` | Проверка форматирования |
| `:TSStatus` | Проверка Tree-sitter |
| `:checkhealth` | Общая диагностика |

Проверка установленных инструментов из терминала:

```bash
nvim --version
node --version
npm --version
ansible --version
ansible-lint --version
yamllint --version
yaml-language-server --version
ansible-language-server --help
prettier --version
```

## Горячие клавиши

| Сочетание | Действие |
|---|---|
| `K` | Показать документацию |
| `gd` | Перейти к определению |
| `gr` | Найти ссылки |
| `gi` | Перейти к реализации |
| `Space + rn` | Переименовать элемент |
| `Space + ca` | Доступные действия LSP |
| `Space + d` | Показать диагностику |
| `Space + f` | Форматировать файл |
| `Space + e` | Открыть файловый браузер |
| `Ctrl + Space` | Вызвать автодополнение |
| `[d` / `]d` | Перемещение между ошибками |

`Space` используется в качестве клавиши Leader.

## Проверка Ansible

Для проверки Playbook можно использовать стандартные команды:

```bash
ansible-playbook --syntax-check playbooks/update.yml
```

Проверка качества Ansible-кода:

```bash
ansible-lint playbooks/update.yml
```

Проверка YAML:

```bash
yamllint playbooks/update.yml
```

## Форматирование

Для обычных YAML-файлов используется Prettier через conform.nvim.

Форматирование вызывается сочетанием:

```text
Space + f
```

Автоматическое форматирование при сохранении включено для файлов с типом `yaml`.

Для Ansible Playbooks автоматическое форматирование через Prettier отключено, чтобы избежать нежелательных изменений Jinja-шаблонов и Ansible-выражений.

## Структура конфигурации

Основной конфигурационный файл:

```text
~/.config/nvim/init.lua
```

Плагины:

```text
~/.local/share/nvim/lazy/
```

Данные и состояние редактора:

```text
~/.local/share/nvim/
~/.local/state/nvim/
```

## Ограничения

- Скрипт рассчитан на Ubuntu 24.04 x86_64.
- Для установки требуется подключение к Интернету.
- Ansible Core должен быть установлен заранее.
- Распознавание Ansible-файлов основано на стандартной структуре каталогов.
- Автоматическое форматирование через Prettier включено только для обычного YAML.
- Для Ansible Playbooks рекомендуется использовать ansible-lint и стандартную проверку синтаксиса.

## Обновление

Обновление Neovim-плагинов:

```vim
:Lazy sync
```

Обновление Tree-sitter:

```vim
:TSUpdate
```

Обновление Python-инструмента:

```bash
pipx upgrade ansible-lint
```

Обновление Node.js-пакетов:

```bash
sudo npm update -g
```

## Документация

- [Neovim](https://neovim.io/doc/)
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)
- [YAML Language Server](https://github.com/redhat-developer/yaml-language-server)
- [Ansible Language Server](https://github.com/ansible/ansible-language-server)
- [ansible-lint](https://ansible.readthedocs.io/projects/lint/)
- [yamllint](https://yamllint.readthedocs.io/)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- [conform.nvim](https://github.com/stevearc/conform.nvim)
- [lazy.nvim](https://github.com/folke/lazy.nvim)

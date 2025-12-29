#!/bin/bash

# Кольори для виводу
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

case "$1" in
    "list")
        echo -e "${BLUE}=== Список доступних тестів ===${NC}"
        # --collect-only просто показує дерево тестів без запуску
        pytest tests/ --collect-only -q | grep "::" | sed 's/::/ -> /g'
	#pytest $TEST_PATH --collect-only -q | grep "::" | sed 's/.*:://'
        ;;
    "run")
        echo -e "${GREEN}=== Запуск усіх тестів ===${NC}"
        pytest tests/ -v
	exit $?
        ;;
    *)
        echo "Використання:"
        echo "  $0 run   - запустити всі тести"
        echo "  $0 list  - показати список усіх наявних тестів"
        ;;
esac


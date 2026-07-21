#!/usr/bin/env bash
# Запуск CVDP Benchmark с произвольной OpenAI-совместимой моделью.
#
# ИСПОЛЬЗОВАНИЕ:
#   ./run_benchmark.sh -f <dataset.jsonl> [дополнительные аргументы]
#
# ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ (или файл .env):
#   BASE_URL   - URL API (например http://192.168.45.10:30070/v1)
#   API_KEY    - Ключ авторизации
#   MODEL      - Имя модели (например gemma-4-12B-it-qat-w4a16-ct)
#
# ПРИМЕРЫ:
#   # Полный бенчмарк:
#   ./run_benchmark.sh -f dataset.jsonl
#
#   # Один тестовый кейс:
#   ./run_benchmark.sh -f dataset.jsonl -i cvdp_copilot_test_issue_0001
#
#   # Золотые решения (без LLM):
#   ./run_benchmark.sh -f dataset_with_solutions.jsonl
#
#   # Несколько сэмплов (pass@k):
#   ./run_benchmark.sh -f dataset.jsonl --samples -n 5 -k 1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCHMARK_DIR="${SCRIPT_DIR}/cvdp_benchmark"
FACTORY_FILE="${SCRIPT_DIR}/custom_factory.py"

# Проверка субмодуля
if [ ! -d "${BENCHMARK_DIR}/src" ]; then
    echo "Ошибка: субмодуль cvdp_benchmark не найден."
    echo "Запустите: git submodule update --init"
    exit 1
fi

# Проверка .env
if [ -f "${SCRIPT_DIR}/.env" ]; then
    set -a
    source "${SCRIPT_DIR}/.env"
    set +a
    echo "Загружен .env"
fi

# Проверка обязательных переменных
if [ -z "${BASE_URL:-}" ]; then
    echo "Ошибка: переменная BASE_URL не задана. Укажите в .env или export."
    exit 1
fi
if [ -z "${API_KEY:-}" ]; then
    echo "Ошибка: переменная API_KEY не задана. Укажите в .env или export."
    exit 1
fi

MODEL="${MODEL:-gpt-4o-mini}"

echo "============================================"
echo "CVDP Benchmark Runner"
echo "============================================"
echo "  BASE_URL: ${BASE_URL}"
echo "  MODEL:    ${MODEL}"
echo "  API_KEY:  ${API_KEY:0:8}..."
echo "============================================"

# Копируем фабрику в директорию бенчмарка для корректных импортов
cp "${FACTORY_FILE}" "${BENCHMARK_DIR}/custom_factory.py"

# Передаём аргументы
cd "${BENCHMARK_DIR}"
export PYTHONPATH="${BENCHMARK_DIR}:${PYTHONPATH:-}"

exec python3 run_benchmark.py \
    -l \
    -m "${MODEL}" \
    -c "${BENCHMARK_DIR}/custom_factory.py" \
    "$@"

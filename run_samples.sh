#!/usr/bin/env bash
# Запуск CVDP Benchmark с несколькими сэмплами (pass@k).
#
# ИСПОЛЬЗОВАНИЕ:
#   ./run_samples.sh -f <dataset.jsonl> -n 5 -k 1
#
# ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ (или файл .env):
#   BASE_URL   - URL API
#   API_KEY    - Ключ авторизации
#   MODEL      - Имя модели

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCHMARK_DIR="${SCRIPT_DIR}/cvdp_benchmark"
FACTORY_FILE="${SCRIPT_DIR}/custom_factory.py"

if [ ! -d "${BENCHMARK_DIR}/src" ]; then
    echo "Ошибка: субмодуль cvdp_benchmark не найден."
    echo "Запустите: git submodule update --init"
    exit 1
fi

if [ -f "${SCRIPT_DIR}/.env" ]; then
    set -a
    source "${SCRIPT_DIR}/.env"
    set +a
    echo "Загружен .env"
fi

MODEL="${MODEL:-gpt-4o-mini}"

echo "============================================"
echo "CVDP Benchmark Runner (Multi-sample)"
echo "============================================"
echo "  BASE_URL: ${BASE_URL}"
echo "  MODEL:    ${MODEL}"
echo "============================================"

cp "${FACTORY_FILE}" "${BENCHMARK_DIR}/custom_factory.py"

# Резолвим относительные пути в абсолютные (до смены директории)
RESOLVED_ARGS=()
PREV_ARG=""
for arg in "$@"; do
    if [ "${PREV_ARG}" = "-f" ] || [ "${PREV_ARG}" = "--filename" ] || \
       [ "${PREV_ARG}" = "-a" ] || [ "${PREV_ARG}" = "--answers" ]; then
        if [ -f "$arg" ]; then
            arg="$(cd "$(dirname "$arg")" && pwd)/$(basename "$arg")"
        elif [ -f "${SCRIPT_DIR}/$arg" ]; then
            arg="${SCRIPT_DIR}/$arg"
        fi
    fi
    RESOLVED_ARGS+=("$arg")
    PREV_ARG="$arg"
done

cd "${BENCHMARK_DIR}"
export PYTHONPATH="${BENCHMARK_DIR}:${PYTHONPATH:-}"

exec python3 run_samples.py \
    -l \
    -m "${MODEL}" \
    -c "${BENCHMARK_DIR}/custom_factory.py" \
    "${RESOLVED_ARGS[@]}"

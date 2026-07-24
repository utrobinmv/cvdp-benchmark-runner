#!/usr/bin/env bash
# Pre-flight check -- проверяет все зависимости перед запуском бенчмарка.
# Опционально прогоняет тест на golden решении (без LLM).
#
# ИСПОЛЬЗОВАНИЕ:
#   ./pre_check.sh              # только проверка
#   ./pre_check.sh --test       # проверка + тест на golden решении

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCHMARK_DIR="${SCRIPT_DIR}/cvdp_benchmark"

RUN_TEST=false
if [ "${1:-}" = "--test" ]; then
    RUN_TEST=true
fi

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  [OK]   $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  [FAIL] $1"; }
warn() { WARN=$((WARN + 1)); echo "  [WARN] $1"; }

echo "============================================"
echo " CVDP Benchmark -- Pre-flight Check"
echo "============================================"
echo ""

# 1. Git submodule
echo "--- Git ---"
if [ -d "${BENCHMARK_DIR}/src" ]; then
    pass "Субмодуль cvdp_benchmark загружен"
else
    fail "Субмодуль cvdp_benchmark не найден. Запустите: git submodule update --init"
fi

# 2. Python
echo ""
echo "--- Python ---"
if command -v python3 &>/dev/null; then
    PYTHON_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    pass "Python 3: $(python3 --version 2>&1)"
    if [ "$PYTHON_VER" = "3.12" ]; then
        pass "Версия Python 3.12 (рекомендуется)"
    else
        warn "Рекомендуется Python 3.12 (установлен $PYTHON_VER)"
    fi
else
    fail "Python 3 не найден"
fi

# 3. venv
echo ""
echo "--- Virtual Environment ---"
if [ -f "${SCRIPT_DIR}/.venv" ]; then
    pass "Файл .venv найден"
    # Активируем для проверки пакетов
    source "${SCRIPT_DIR}/.venv"
else
    fail "Файл .venv не найден. Создайте venv согласно INSTALL.md"
fi

# 4. Python packages
echo ""
echo "--- Python Packages ---"
PACKAGES="openai cocotb pytest huggingface_hub"
for pkg in $PACKAGES; do
    if python3 -c "import ${pkg//-/_}" 2>/dev/null; then
        ver=$(python3 -c "import ${pkg//-/_}; print(${pkg//-/_}.__version__)" 2>/dev/null || echo "?")
        pass "${pkg} (${ver})"
    else
        fail "${pkg} не установлен"
    fi
done

# 5. Docker
echo ""
echo "--- Docker ---"
if command -v docker &>/dev/null; then
    pass "Docker: $(docker --version 2>&1)"
else
    fail "Docker не найден"
fi

# 6. Docker image
echo ""
echo "--- Docker Image ---"
if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "nvidia/cvdp-sim:v1.0.0"; then
    pass "Docker образ nvidia/cvdp-sim:v1.0.0 найден"
else
    fail "Docker образ nvidia/cvdp-sim:v1.0.0 не найден. Соберите: cd cvdp_benchmark && docker build -f docker/Dockerfile.sim -t nvidia/cvdp-sim:v1.0.0 ."
fi

# 7. cocotb version in Docker image
echo ""
echo "--- cocotb Version ---"
COCOTB_VER=$(docker run --rm nvidia/cvdp-sim:v1.0.0 /venv/bin/python -c "import cocotb; print(cocotb.__version__)" 2>/dev/null || echo "unknown")
if [ "$COCOTB_VER" = "1.9.2" ]; then
    pass "cocotb в Docker: $COCOTB_VER (верно)"
elif [ "$COCOTB_VER" = "2.0.1" ]; then
    fail "cocotb в Docker: $COCOTB_VER -- нужно исправить на 1.9.2 (см. INSTALL.md шаг 5)"
else
    warn "cocotb в Docker: $COCOTB_VER (неизвестная версия)"
fi

# 8. .env
echo ""
echo "--- Configuration ---"
if [ -f "${SCRIPT_DIR}/.env" ]; then
    pass "Файл .env найден"
    # Проверка обязательных переменных
    set -a; source "${SCRIPT_DIR}/.env"; set +a
    if [ -n "${BASE_URL:-}" ]; then
        pass "BASE_URL: ${BASE_URL}"
    else
        fail "BASE_URL не задан в .env"
    fi
    if [ -n "${API_KEY:-}" ]; then
        pass "API_KEY: задан"
    else
        fail "API_KEY не задан в .env"
    fi
    if [ -n "${MODEL:-}" ]; then
        pass "MODEL: ${MODEL}"
    else
        fail "MODEL не задан в .env"
    fi
    if [ -n "${MODEL_TIMEOUT:-}" ]; then
        pass "MODEL_TIMEOUT: ${MODEL_TIMEOUT}"
    else
        warn "MODEL_TIMEOUT не задан (по умолчанию 60 -- может быть мало для больших моделей)"
    fi
else
    fail "Файл .env не найден. Скопируйте: cp .env.example .env"
fi

# 9. Dataset
echo ""
echo "--- Dataset ---"
DATASETS=$(find "${SCRIPT_DIR}/datasets" -name "*.jsonl" 2>/dev/null | wc -l)
if [ "$DATASETS" -gt 0 ]; then
    pass "Датасеты найдены: ${DATASETS} файлов"
else
    fail "Датасеты не найдены в datasets/. Скачайте: hf download nvidia/cvdp-benchmark-dataset --repo-type dataset --local-dir ./datasets"
fi

# 10. Golden dataset (для теста без LLM)
echo ""
echo "--- Golden Dataset ---"
GOLDEN_DATASET=$(find "${SCRIPT_DIR}/datasets" -name "*with_solutions*" -o -name "*_agentic_*_commercial*" 2>/dev/null | head -1)
if [ -n "$GOLDEN_DATASET" ]; then
    pass "Golden dataset найден: $(basename "$GOLDEN_DATASET")"
else
    warn "Golden dataset не найден -- тест без LLM невозможен"
fi

# Итог
echo ""
echo "============================================"
echo " Итого: ${PASS} OK, ${FAIL} FAIL, ${WARN} WARN"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "Есть ошибки. Исправьте их перед запуском бенчмарка."
    exit 1
fi

# Опциональный тест на golden
if [ "$RUN_TEST" = true ] && [ -n "${GOLDEN_DATASET:-}" ]; then
    echo ""
    echo "--- Тест на golden решении (без LLM) ---"
    echo "Запуск одного теста для проверки Docker и симуляции..."

    cd "${SCRIPT_DIR}"
    source .venv

    # Берём первый ID из golden датасета
    FIRST_ID=$(head -1 "$GOLDEN_DATASET" | python3 -c "import json,sys; print(json.loads(sys.stdin.readline())['id'])" 2>/dev/null || echo "")

    if [ -n "$FIRST_ID" ]; then
        echo "Тест: ${FIRST_ID}"
        if python3 "${BENCHMARK_DIR}/run_benchmark.py" \
            -f "$GOLDEN_DATASET" \
            -i "$FIRST_ID" \
            -p pre_check_test \
            2>&1 | tail -5; then
            pass "Тест на golden решении прошёл успешно"
        else
            fail "Тест на golden решении упал. Проверьте Docker и симуляцию."
            exit 1
        fi

        # Очистка
        rm -rf "${BENCHMARK_DIR}/pre_check_test"
    else
        warn "Не удалось получить ID из golden датасета"
    fi
fi

echo ""
echo "Всё готово к запуску бенчмарка."
exit 0

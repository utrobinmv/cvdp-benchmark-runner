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
PACKAGES="openai huggingface_hub"
for pkg in $PACKAGES; do
    if python3 -c "import ${pkg//-/_}" 2>/dev/null; then
        ver=$(python3 -c "import ${pkg//-/_}; print(${pkg//-/_}.__version__)" 2>/dev/null || echo "?")
        pass "${pkg} (${ver})"
    else
        fail "${pkg} не установлен"
    fi
done

# cocotb и pytest нужны только внутри Docker -- проверяем там (см. ниже)

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
if [ "$COCOTB_VER" = "2.0.1" ]; then
    pass "cocotb в Docker: $COCOTB_VER (верно)"
elif [ "$COCOTB_VER" = "1.9.2" ]; then
    fail "cocotb в Docker: $COCOTB_VER -- нужно cocotb==2.0.1 (cocotb_tools.runner отсутствует в 1.9.2)"
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

# 9. Проверка Docker harness (cocotb + iverilog)
echo ""
echo "--- Docker Harness ---"
HARNESS_OK=$(docker run --rm nvidia/cvdp-sim:v1.0.0 /bin/bash -c '
    iverilog -V >/dev/null 2>&1 && echo "iverilog ok" || echo "iverilog fail"
    /venv/bin/python -c "import cocotb; print(f\"cocotb {cocotb.__version__}\")" 2>/dev/null && echo "cocotb ok" || echo "cocotb fail"
' 2>/dev/null)

if echo "$HARNESS_OK" | grep -q "iverilog ok"; then
    pass "iverilog в Docker работает"
else
    fail "iverilog в Docker не работает"
fi

if echo "$HARNESS_OK" | grep -q "cocotb ok"; then
    pass "cocotb в Docker работает"
else
    fail "cocotb в Docker не работает"
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
if [ "$RUN_TEST" = true ]; then
    echo ""
    echo "--- Тест harness (без LLM) ---"
    echo "Проверка компиляции и симуляции простого модуля в Docker..."

    cd "${SCRIPT_DIR}"
    source .venv

    # Запускаем минимальный тест cocotb в Docker
    TEST_RESULT=$(docker run --rm nvidia/cvdp-sim:v1.0.0 /bin/bash -c '
        cd /tmp
        cat > test.sv << "EOF"
module test;
    initial begin
        $display("Harness test passed");
        $finish;
    end
endmodule
EOF
        iverilog -o test.vvp test.sv && vvp test.vvp
    ' 2>&1)

    if echo "$TEST_RESULT" | grep -q "Harness test passed"; then
        pass "Docker harness (iverilog + vvp) работает"
    else
        fail "Docker harness упал: $TEST_RESULT"
        exit 1
    fi
fi

echo ""
echo "Всё готово к запуску бенчмарка."
exit 0

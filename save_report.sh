#!/usr/bin/env bash
# Сохраняет отчёт бенчмарка в хранилище ~/workspace/data/cvdp-benchmark-runner/reports/
#
# ИСПОЛЬЗОВАНИЕ:
#   ./save_report.sh <work_dir> [model_name]
#
# ПРИМЕРЫ:
#   ./save_report.sh work_gemma4_12b
#   ./save_report.sh work_gemma4_12b "gemma-4-12B-it-qat-w4a16-ct"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCHMARK_DIR="${SCRIPT_DIR}/cvdp_benchmark"
REPORTS_DIR="${HOME}/workspace/data/cvdp-benchmark-runner/reports"

if [ $# -lt 1 ]; then
    echo "Использование: $0 <work_dir> [model_name]"
    exit 1
fi

WORK_DIR="$1"
MODEL_NAME="${2:-unknown}"
BENCH_WORK="${BENCHMARK_DIR}/${WORK_DIR}"

if [ ! -d "${BENCH_WORK}" ]; then
    echo "Ошибка: директория ${BENCH_WORK} не найдена"
    exit 1
fi

# Создаём директорию отчёта: YYYY-MM-DD_model_name
DATE=$(date +%Y-%m-%d)
REPORT_DIR="${REPORTS_DIR}/${DATE}_${MODEL_NAME}"
mkdir -p "${REPORT_DIR}"

echo "Сохранение отчёта в ${REPORT_DIR}/"

# Копируем файлы отчёта
for f in report.txt report.json raw_result.json prompt_response.jsonl run.log; do
    if [ -f "${BENCH_WORK}/${f}" ]; then
        cp "${BENCH_WORK}/${f}" "${REPORT_DIR}/"
        echo "  -> ${f}"
    fi
done

# Генерируем summary.json из report.json
python3 << PYEOF
import json, os

report_path = "${BENCH_WORK}/report.json"
summary_path = "${REPORT_DIR}/summary.json"

if not os.path.exists(report_path):
    print("  report.json not found, skipping summary generation")
    exit(0)

with open(report_path) as f:
    r = json.load(f)

failing = r.get("test_details", {}).get("failing_tests", [])
passing = r.get("test_details", {}).get("passing_tests", [])
total_tests = len(failing) + len(passing)

# Count unique problems
problems = {}
for t in failing + passing:
    tid = t["test_id"]
    if tid not in problems:
        problems[tid] = {"passed": 0, "failed": 0, "category": t.get("category", ""), "difficulty": t.get("difficulty", "")}
    if t in passing:
        problems[tid]["passed"] += 1
    else:
        problems[tid]["failed"] += 1

total_probs = len(problems)
passed_probs = sum(1 for p in problems.values() if p["failed"] == 0)

summary = {
    "model": "${MODEL_NAME}",
    "date": "${DATE}",
    "work_dir": "${WORK_DIR}",
    "overall": {
        "total_problems": total_probs,
        "passed_problems": passed_probs,
        "failed_problems": total_probs - passed_probs,
        "problem_pass_rate": round(passed_probs / total_probs * 100, 2) if total_probs else 0,
        "total_tests": total_tests,
        "passed_tests": len(passing),
        "failed_tests": len(failing),
        "test_pass_rate": round(len(passing) / total_tests * 100, 2) if total_tests else 0,
    },
    "by_difficulty": {},
    "by_category": {}
}

# By difficulty
diff_stats = {}
for p in problems.values():
    d = p["difficulty"]
    if d not in diff_stats:
        diff_stats[d] = {"total": 0, "passed": 0}
    diff_stats[d]["total"] += 1
    if p["failed"] == 0:
        diff_stats[d]["passed"] += 1

for diff, st in diff_stats.items():
    summary["by_difficulty"][diff] = {
        "total": st["total"],
        "passed": st["passed"],
        "failed": st["total"] - st["passed"],
        "pass_rate": round(st["passed"] / st["total"] * 100, 2) if st["total"] else 0
    }

# By category
cat_stats = {}
for p in problems.values():
    c = p["category"]
    if c not in cat_stats:
        cat_stats[c] = {"total": 0, "passed": 0, "by_difficulty": {}}
    cat_stats[c]["total"] += 1
    if p["failed"] == 0:
        cat_stats[c]["passed"] += 1
    d = p["difficulty"]
    if d not in cat_stats[c]["by_difficulty"]:
        cat_stats[c]["by_difficulty"][d] = {"total": 0, "passed": 0}
    cat_stats[c]["by_difficulty"][d]["total"] += 1
    if p["failed"] == 0:
        cat_stats[c]["by_difficulty"][d]["passed"] += 1

for cat, st in cat_stats.items():
    entry = {
        "total": st["total"],
        "passed": st["passed"],
        "failed": st["total"] - st["passed"],
        "pass_rate": round(st["passed"] / st["total"] * 100, 2) if st["total"] else 0,
    }
    for diff, ds in st["by_difficulty"].items():
        entry[diff] = {
            "total": ds["total"],
            "passed": ds["passed"],
            "failed": ds["total"] - ds["passed"],
            "pass_rate": round(ds["passed"] / ds["total"] * 100, 2) if ds["total"] else 0
        }
    summary["by_category"][cat] = entry

with open(summary_path, 'w') as f:
    json.dump(summary, f, indent=2)

print("  -> summary.json generated")
PYEOF

# Копируем лог бенчмарка
BENCH_LOG="${HOME}/workspace/tmp/cvdp-benchmark-runner/logs/benchmark.log"
if [ -f "${BENCH_LOG}" ]; then
    cp "${BENCH_LOG}" "${REPORT_DIR}/benchmark.log"
    echo "  -> benchmark.log"
fi

echo ""
echo "Отчёт сохранён: ${REPORT_DIR}/"
echo "Файлы:"
ls -lh "${REPORT_DIR}/"

# CVDP Benchmark Runner

Обёртка над [CVDP Benchmark](https://github.com/utrobinmv/cvdp_benchmark) для запуска бенчмарка с любой OpenAI-совместимой моделью.

## Что это

CVDP Benchmark -- фреймворк NVIDIA для оценки LLM на задачах верификации аппаратного обеспечения (Verilog/RTL). Этот проект упрощает подключение произвольной модели через OpenAI-compatible API.

## Быстрый старт

### 1. Клонирование

```bash
git clone https://github.com/utrobinmv/cvdp-benchmark-runner.git
cd cvdp-benchmark-runner
git submodule update --init
```

### 2. Установка зависимостей

Подробная инструкция — [INSTALL.md](INSTALL.md).

```bash
# Создание venv
source .venv

# Установка зависимостей бенчмарка
pip install -r cvdp_benchmark/requirements.txt
pip install -r cvdp_benchmark/src/llm_lib/requirements.txt
```

### 3. Исправление cocotb.sim_time_utils (обязательно!)

В датасетах используется `cocotb.sim_time_utils`, удалённый в cocotb 2.0. Без исправления часть тестов упадёт:

```bash
for f in datasets/*.jsonl; do
    sed -i 's/cocotb\.sim_time_utils/cocotb.utils/g' "$f"
done
```

> **Важно:** НЕ заменяйте `cocotb==2.0.1` на `cocotb==1.9.2` -- в 1.9.2 нет `cocotb_tools.runner`, который используют 273 из 314 тестов.

### 4. Сборка Docker-образа

```bash
cd cvdp_benchmark
docker build -f docker/Dockerfile.sim -t nvidia/cvdp-sim:v1.0.0 .
cd ..
```

### 5. Настройка модели

Скопируйте `.env.example` в `.env` и измените параметры:

```bash
cp .env.example .env
```

Файл `.env`:

```
BASE_URL=http://192.168.45.10:30000/v1
API_KEY=any_key
MODEL=/mnt/extendet_data/models/Qwen3.6-27B-FP8
# Таймаут ответа модели в секундах. По умолчанию 60 -- слишком мало для больших моделей.
# Рекомендуется минимум 600 для моделей 27B+ и 300 для моделей 12B.
MODEL_TIMEOUT=600
```

**Важно:** `MODEL_TIMEOUT` задаётся только в `.env`. Передача через переменную окружения перед запуском (например `MODEL_TIMEOUT=1200 ./run_benchmark.sh`) не работает -- скрипт перезагружает `.env` и перезаписывает значение.

### 6. Скачивание датасета

Датасет CVDP доступен на Hugging Face: [nvidia/cvdp-benchmark-dataset](https://huggingface.co/datasets/nvidia/cvdp-benchmark-dataset)

```bash
# Скачивание датасета (huggingface_hub >= 1.0)
hf download nvidia/cvdp-benchmark-dataset --repo-type dataset --local-dir ./datasets

# Для старых версий huggingface_hub (< 1.0)
huggingface-cli download nvidia/cvdp-benchmark-dataset --repo-type dataset --local-dir ./datasets
```

### 7. Pre-flight check

```bash
./pre_check.sh          # Проверка зависимостей
./pre_check.sh --test   # + тест на golden решении (без LLM)
```

### 8. Запуск

```bash
# Полный бенчмарк (1 поток)
./run_benchmark.sh -f datasets/your_dataset.jsonl

# Несколько потоков (рекомендуется для ускорения)
./run_benchmark.sh -f datasets/your_dataset.jsonl -t 4

# Один тестовый кейс
./run_benchmark.sh -f datasets/your_dataset.jsonl -i cvdp_copilot_test_issue_0001

# Несколько сэмплов (pass@k)
./run_samples.sh -f datasets/your_dataset.jsonl -n 5 -k 1

# Золотые решения (без LLM)
./run_benchmark.sh -f datasets/dataset_with_solutions.jsonl
```

**Рекомендации по потокам:**

- **4 потока** -- оптимально для моделей до 12B (быстрее в 2-3 раза)
- **2 потока** -- для моделей 27B+ (баланс скорости и стабильности)
- **1 поток** -- если сервер не справляется с параллельными запросами

Больше потоков не всегда лучше -- если сервер не справляется с параллельными запросами, будут таймауты и ретраи, что замедлит бенчмарк.

## Архитектура

```
cvdp-benchmark-runner/
├── .env                      # Параметры модели (BASE_URL, API_KEY, MODEL, MODEL_TIMEOUT)
├── .env.example              # Шаблон .env
├── .venv                     # Скрипт активации venv
├── custom_factory.py         # Кастомная ModelFactory для OpenAI-compatible API
├── run_benchmark.sh          # Скрипт запуска бенчмарка
├── run_samples.sh            # Скрипт запуска multi-sample (pass@k)
├── save_report.sh            # Сохранение отчёта в хранилище
├── pre_check.sh              # Pre-flight check (зависимости, Docker, cocotb)
├── cvdp_benchmark/           # Git submodule -- оригинальный репозиторий
├── README.md
├── INSTALL.md
└── AGENTS.md
```

### Как работает

1. `run_benchmark.sh` загружает `.env` (BASE_URL, API_KEY, MODEL)
2. Копирует `custom_factory.py` в директорию субмодуля
3. Запускает `cvdp_benchmark/run_benchmark.py` с флагом `-c custom_factory.py`
4. Фабрика создаёт `CustomOpenAI_Instance`, который коннектится к `BASE_URL` через `openai.OpenAI(base_url=...)`

## Дополнительные аргументы

Передаются напрямую в `run_benchmark.py`:

| Аргумент | Описание |
|---|---|
| `-f <file>` | Путь к JSONL датасету (обязательно) |
| `-i <id>` | Запустить один тестовый кейс по ID |
| `-t <N>` | Количество параллельных потоков |
| `-p <prefix>` | Префикс для директории результатов |
| `--queue-timeout <sec>` | Таймаут всей очереди задач |
| `--no-patch` | Не применять golden patch (только golden mode) |

## Результаты

После запуска в директории `work/` (или указанной через `-p`):

- `raw_result.json` -- сырые результаты каждого теста
- `report.json` -- структурированный отчёт
- `report.txt` -- читаемый отчёт
- `run.log` -- лог выполнения

### Хранилище отчётов

Для сравнения моделей результаты сохраняются в `~/workspace/data/cvdp-benchmark-runner/reports/`:

```bash
# Сохранение отчёта после бенчмарка
./save_report.sh work_<prefix> "<model_name>"
```

Создаёт директорию `YYYY-MM-DD_<model_name>/` со всеми файлами отчёта и `summary.json` -- сжатые метрики для сравнения.

Пример структуры:

```
reports/
├── 2026-07-21_gemma-4-12B-it-qat-w4a16-ct/
│   ├── report.txt
│   ├── report.json
│   ├── raw_result.json
│   ├── prompt_response.jsonl
│   ├── run.log
│   ├── benchmark.log
│   └── summary.json
└── 2026-07-22_another_model/
    └── ...
```

### Сравнение моделей

```bash
# Быстрый просмотр pass rate всех моделей
for d in ~/workspace/data/cvdp-benchmark-runner/reports/*/summary.json; do
    python3 -c "
import json
with open('$d') as f:
    s = json.load(f)
print(f'{s[\"model\"]:50s} easy={s[\"by_difficulty\"].get(\"easy\",{}).get(\"pass_rate\",\"N/A\")}%  medium={s[\"by_difficulty\"].get(\"medium\",{}).get(\"pass_rate\",\"N/A\")}%  total={s[\"overall\"][\"problem_pass_rate\"]}%')
"
done
```

### Таблица результатов

| Метрика | Qwen3.6-27B-FP8 | Gemma-4-31B-it-FP8 | Gemma-4-12B-it-qat-w4a16-ct |
|---------|-----------------|---------------------|------------------------------|
| Problem Pass Rate | **34.11%** (103/302) | 25.50% | 18.54% (56/302) |
| Test Pass Rate | **38.42%** (131/341) | — | 22.58% (77/341) |
| Easy Pass Rate | **47.53%** (77/162) | — | 25.93% (42/162) |
| Medium Pass Rate | **18.57%** (26/140) | — | 10.00% (14/140) |

**Вывод:** Qwen3.6-27B-FP8 значительно превосходит обе модели Gemma. Gemma-4-31B лучше Gemma-4-12B, но уступает Qwen3.6-27B.

#### Основные ошибки моделей

- **Синтаксические** -- неопределённые сигналы, дублирующиеся assign, ошибки модулей
- **Логические** -- код компилируется, но симуляция показывает неправильные результаты
- **Таймауты** -- бесконечные циклы, потеря синхронизации в асинхронных задачах

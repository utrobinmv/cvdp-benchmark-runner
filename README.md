# CVDP Benchmark Runner

Обёртка над [CVDP Benchmark](https://github.com/utrobinmv/cvdp_benchmark) для запуска бенчмарка с любой OpenAI-совместимой моделью.

## Что это

CVDP Benchmark -- фреймворк NVIDIA для оценки LLM на задачах верификации аппаратного обеспечения (Verilog/RTL). Этот проект упрощает подключение произвольной модели через OpenAI-compatible API.

## Быстрый старт

### 1. Клонирование

```bash
git clone <repo_url> cvdp-benchmark-runner
cd cvdp-benchmark-runner
git submodule update --init
```

### 2. Установка зависимостей

```bash
# Создание venv
source .venv

# Установка зависимостей бенчмарка
pip install -r cvdp_benchmark/requirements.txt
pip install -r cvdp_benchmark/src/llm_lib/requirements.txt
```

### 3. Настройка модели

Файл `.env` уже содержит параметры по умолчанию. Измените при необходимости:

```
BASE_URL=http://192.168.45.10:30070/v1
API_KEY=any_key
MODEL=gemma-4-12B-it-qat-w4a16-ct
```

### 4. Скачивание датасета

Датасет CVDP доступен на Hugging Face: [nvidia/cvdp-benchmark-dataset](https://huggingface.co/datasets/nvidia/cvdp-benchmark-dataset)

```bash
# Пример скачивания примера
huggingface-cli download nvidia/cvdp-benchmark-dataset --local-dir ./datasets
```

### 5. Запуск

```bash
# Полный бенчмарк
./run_benchmark.sh -f datasets/your_dataset.jsonl

# Один тестовый кейс
./run_benchmark.sh -f datasets/your_dataset.jsonl -i cvdp_copilot_test_issue_0001

# Несколько сэмплов (pass@k)
./run_samples.sh -f datasets/your_dataset.jsonl -n 5 -k 1

# Золотые решения (без LLM)
./run_benchmark.sh -f datasets/dataset_with_solutions.jsonl
```

## Архитектура

```
cvdp-benchmark-runner/
├── .env                      # Параметры модели (BASE_URL, API_KEY, MODEL)
├── .venv                     # Скрипт активации venv
├── custom_factory.py         # Кастомная ModelFactory для OpenAI-compatible API
├── run_benchmark.sh          # Скрипт запуска бенчмарка
├── run_samples.sh            # Скрипт запуска multi-sample (pass@k)
├── save_report.sh            # Сохранение отчёта в хранилище
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

### Результаты gemma-4-12B-it-qat-w4a16-ct

| Метрика | Значение |
|---------|----------|
| Problem Pass Rate | 18.54% (56/302) |
| Test Pass Rate | 22.58% (77/341) |
| Easy Pass Rate | 25.93% (42/162) |
| Medium Pass Rate | 10.00% (14/140) |

**Основные ошибки:**

- **Синтаксические (36 задач)** -- неопределённые сигналы, дублирующиеся assign, ошибки модулей. Иверлог не смог скомпилировать код.
- **Логические (47 задач)** -- код скомпилировался, но симуляция показала неправильные результаты (ошибки в алгоритмах, неинициализированные сигналы).
- **Таймауты (22 задачи)** -- бесконечные циклы, потеря синхронизации в асинхронных задачах.

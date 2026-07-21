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

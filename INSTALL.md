# INSTALL -- Установка CVDP Benchmark Runner

## Системные требования

- Python 3.12 (рекомендуется)
- Docker CE (для запуска тестовых харнесов)
- Git

## Пошаговая установка

### 1. Клонирование репозитория

```bash
git clone https://github.com/utrobinmv/cvdp-benchmark-runner.git
cd cvdp-benchmark-runner
```

### 2. Инициализация субмодуля

```bash
git submodule update --init --recursive
```

Проверьте, что субмодуль загружен:

```bash
ls cvdp_benchmark/src/
```

### 3. Настройка Python-окружения

```bash
# Привязка версии Python через pyenv
pyenv local 3.12.0

# Создание виртуального окружения
python -m venv ~/workspace/venvs/cvdp-benchmark-runner/default/

# Активация
source .venv

# Установка зависимостей бенчмарка
pip install -r cvdp_benchmark/requirements.txt

# Установка зависимостей LLM-модуля
pip install -r cvdp_benchmark/src/llm_lib/requirements.txt
```

### 4. Настройка Docker

```bash
# Добавление пользователя в группу docker
sudo usermod -aG docker $USER

# Выход и повторный вход (или restart session)
# Проверка:
docker --version
```

### 5. Сборка Docker-образа для симуляции

```bash
cd cvdp_benchmark
docker build -f docker/Dockerfile.sim -t nvidia/cvdp-sim:v1.0.0 .
cd ..
```

### 6. Настройка модели (файл .env)

Скопируйте `.env.example` в `.env`:

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

Измените при необходимости. Файл `.env` попадает в `.gitignore` и не коммитится.

**Важно:** `MODEL_TIMEOUT` задаётся только в `.env`. Передача через переменную окружения перед запуском (например `MODEL_TIMEOUT=1200 ./run_benchmark.sh`) не работает -- скрипт перезагружает `.env` и перезаписывает значение.

### 7. Скачивание датасета

```bash
# Установка huggingface_hub (если ещё не установлен)
pip install huggingface_hub

# Скачивание датасета (huggingface_hub >= 1.0)
hf download nvidia/cvdp-benchmark-dataset --repo-type dataset --local-dir ./datasets

# Для старых версий huggingface_hub (< 1.0)
huggingface-cli download nvidia/cvdp-benchmark-dataset --repo-type dataset --local-dir ./datasets
```

Или скачайте вручную с [Hugging Face](https://huggingface.co/datasets/nvidia/cvdp-benchmark-dataset).

### 8. Проверка

```bash
# Тестовый запуск (проверка подключения к модели)
./run_benchmark.sh -f datasets/cvdp_v1.0.1_example_nonagentic_code_generation_no_commercial_with_solutions.jsonl -i cvdp_copilot_test_issue_0001
```

## Повторное развёртывание с нуля

```bash
# 1. Удалить старое окружение
rm -rf ~/workspace/venvs/cvdp-benchmark-runner/

# 2. Обновить субмодуль
git submodule update --init --recursive

# 3. Создать venv заново
pyenv local 3.12.0
python -m venv ~/workspace/venvs/cvdp-benchmark-runner/default/
source .venv
pip install -r cvdp_benchmark/requirements.txt
pip install -r cvdp_benchmark/src/llm_lib/requirements.txt

# 4. Пересобрать Docker-образ
cd cvdp_benchmark
docker build -f docker/Dockerfile.sim -t nvidia/cvdp-sim:v1.0.0 .
cd ..
```

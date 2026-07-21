# INSTALL -- Установка CVDP Benchmark Runner

## Системные требования

- Python 3.12 (рекомендуется)
- Docker CE (для запуска тестовых харнесов)
- Git

## Пошаговая установка

### 1. Клонирование репозитория

```bash
git clone <repo_url> cvdp-benchmark-runner
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

Файл `.env` уже создан с параметрами по умолчанию:

```
BASE_URL=http://192.168.45.10:30070/v1
API_KEY=any_key
MODEL=gemma-4-12B-it-qat-w4a16-ct
```

Измените при необходимости. Файл `.env` попадает в `.gitignore` и не коммитится.

### 7. Скачивание датасета

```bash
# Установка huggingface-cli
pip install huggingface_hub

# Скачивание датасета
huggingface-cli download nvidia/cvdp-benchmark-dataset --local-dir ./datasets
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

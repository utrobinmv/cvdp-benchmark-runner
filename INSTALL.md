# INSTALL -- Установка CVDP Benchmark Runner

## Системные требования

- Python 3.12
- Docker CE
- Git

## Установка

### 1. Клонирование и субмодуль

```bash
git clone https://github.com/utrobinmv/cvdp-benchmark-runner.git
cd cvdp-benchmark-runner
git submodule update --init --recursive
```

### 2. Python-окружение

```bash
pyenv local 3.12
python -m venv ~/workspace/venvs/cvdp-benchmark-runner/default/
source .venv
pip install -r cvdp_benchmark/requirements.txt
pip install -r cvdp_benchmark/src/llm_lib/requirements.txt
```

### 3. Docker

```bash
sudo usermod -aG docker $USER
# Выйти и войти снова
docker --version
```

### 4. Исправление cocotb.sim_time_utils в датасетах

```bash
for f in datasets/*.jsonl; do
    sed -i 's/cocotb\.sim_time_utils/cocotb.utils/g' "$f"
done
```

### 5. Сборка Docker-образа

```bash
cd cvdp_benchmark
docker build -f docker/Dockerfile.sim -t nvidia/cvdp-sim:v1.0.0 .
cd ..
```

### 6. Настройка модели

```bash
cp .env.example .env
```

Отредактируйте `.env`:

```
BASE_URL=http://192.168.45.10:30000/v1
API_KEY=any_key
MODEL=/mnt/extendet_data/models/Qwen3.6-27B-FP8
MODEL_TIMEOUT=600
```

### 7. Скачивание датасета

```bash
pip install huggingface_hub
hf download nvidia/cvdp-benchmark-dataset --repo-type dataset --local-dir ./datasets
```

### 8. Проверка

```bash
./pre_check.sh
./pre_check.sh --test
```

## Повторное развёртывание

```bash
rm -rf ~/workspace/venvs/cvdp-benchmark-runner/
git submodule update --init --recursive
pyenv local 3.12
python -m venv ~/workspace/venvs/cvdp-benchmark-runner/default/
source .venv
pip install -r cvdp_benchmark/requirements.txt
pip install -r cvdp_benchmark/src/llm_lib/requirements.txt
for f in datasets/*.jsonl; do
    sed -i 's/cocotb\.sim_time_utils/cocotb.utils/g' "$f"
done
cd cvdp_benchmark
docker build -f docker/Dockerfile.sim -t nvidia/cvdp-sim:v1.0.0 .
cd ..
```

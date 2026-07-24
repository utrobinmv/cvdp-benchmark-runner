# AGENTS.md -- Контекст для AI-агента

## Структура

- `cvdp_benchmark/` -- git submodule (оригинальный репозиторий NVIDIA CVDP Benchmark)
- `custom_factory.py` -- кастомная ModelFactory для OpenAI-compatible API
- `run_benchmark.sh` -- основной скрипт запуска
- `run_samples.sh` -- скрипт для multi-sample (pass@k)
- `save_report.sh` -- сохранение отчёта в хранилище `~/workspace/data/cvdp-benchmark-runner/reports/`
- `pre_check.sh` -- pre-flight check (зависимости, Docker, cocotb, опционально тест без LLM)
- `.env` -- параметры модели (BASE_URL, API_KEY, MODEL, MODEL_TIMEOUT)
- `.env.example` -- шаблон .env

## Как работает

1. Скрипт загружает `.env`, копирует `custom_factory.py` в `cvdp_benchmark/`
2. Запускает `python3 run_benchmark.py -l -m $MODEL -c custom_factory.py [args]`
3. `CustomModelFactory` создаёт `CustomOpenAI_Instance` с `base_url=BASE_URL`
4. Модель отвечает на промпты, бенчмарк запускает Verilog-тесты в Docker

## Важные замечания

- Бенчмарк требует Docker для запуска тестовых харнесов (Verilog симуляция)
- Датасеты -- JSONL формат с Hugging Face (nvidia/cvdp-benchmark-dataset)
- Результаты пишутся в `work/` (или `-p <prefix>`)
- `custom_factory.py` импортирует `src.*` из субмодуля -- PYTHONPATH должен включать `cvdp_benchmark/`

## Pitfalls

### cocotb — НЕ менять на 1.9.2

В cocotb 1.9.2 нет `cocotb_tools.runner`, который используют 273 из 314 тестов. Бенчмарк упадёт с 87% ошибок. Использовать cocotb 2.0.1.

В cocotb 2.0.1 удалён `cocotb.sim_time_utils` — функция `get_sim_time` переехала в `cocotb.utils`. В датасетах (`.jsonl`) есть `from cocotb.sim_time_utils import get_sim_time` — перед запуском обязательно заменить на `cocotb.utils`:

```bash
for f in datasets/*.jsonl; do
    sed -i 's/cocotb\.sim_time_utils/cocotb.utils/g' "$f"
done
```

### Docker build и хеши cocotb

`docker/requirements.txt` содержит `--hash=sha256` для cocotb. Если `uv pip compile` сгенерировал хеши только для sdist, Docker build упадёт. Добавить wheel hash:

```bash
pip download cocotb==2.0.1 --no-deps -d /tmp/cocotb_dl
sha256sum /tmp/cocotb_dl/cocotb-2.0.1-*.whl
# Вставить hash в docker/requirements.txt после строки cocotb==2.0.1
```

### MODEL_TIMEOUT

`MODEL_TIMEOUT` задаётся ТОЛЬКО в `.env`. Передача через env var перед запуском (например `MODEL_TIMEOUT=1200 ./run_benchmark.sh`) не работает — скрипт перезагружает `.env` и перезаписывает значение.

Рекомендуемые значения:
- 600s для моделей 27B+
- 300s для моделей 12B
- 60s (дефолт) — недостаточно для большинства моделей

### Потоки

- 4 потока — модели до 12B
- 2 потока — модели 27B+
- 1 поток — если сервер не справляется с параллельными запросами

### LLM non-determinism

Одни и те же модели могут давать разные результаты между запусками (особенно заметно на Gemma-4-31B — разброс от 2.98% до 25.50%). Для сравнения моделей запускать несколько раз и усреднять.

# AGENTS.md -- Контекст для AI-агента

## Структура

- `cvdp_benchmark/` -- git submodule (оригинальный репозиторий NVIDIA CVDP Benchmark)
- `custom_factory.py` -- кастомная ModelFactory для OpenAI-compatible API
- `run_benchmark.sh` -- основной скрипт запуска
- `run_samples.sh` -- скрипт для multi-sample (pass@k)
- `save_report.sh` -- сохранение отчёта в хранилище `~/workspace/data/cvdp-benchmark-runner/reports/`
- `.env` -- параметры модели (BASE_URL, API_KEY, MODEL, MODEL_TIMEOUT)

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

# ClickHouse: Ads Analytics

Учебный аналитический проект для оценки эффективности рекламных кампаний на ClickHouse.

## Что реализовано

- База `ad_analytics`.
- Справочники `channels` (4 канала) и `campaigns` (4 кампании).
- Сырая таблица `raw_ads_events` с 20 000 событиями трёх типов: `impression`, `click`, `conversion`.
- Итоговая витрина `campaign_kpi` с ежедневной агрегацией по `campaign_id`, `event_date`, `channel_id`.
- Пять бизнес-запросов из задания.
- Автоматические проверки согласованности количества событий, расходов и доходов.
- Аудит `system.parts`, `system.merges`, `system.query_log` и `EXPLAIN`.
- `LowCardinality` для `device` и `country`; `Enum8` для `event_type`.

## Требования

- Docker Desktop.
- Терминал macOS или Linux.
- Официальный образ `clickhouse/clickhouse-server`.

## Запуск с нуля

Откройте Terminal в папке проекта.

### 1. Запустить ClickHouse

Если контейнер `clickhouse-server` уже существует, сначала удалите его (это удалит данные контейнера):

```bash
docker rm -f clickhouse-server
```

Затем запустите сервер:

```bash
docker run -d --name clickhouse-server \
  -p 8123:8123 -p 9000:9000 \
  clickhouse/clickhouse-server:latest
```

Дождитесь готовности:

```bash
docker exec clickhouse-server clickhouse-client --query "SELECT version()"
```

### 2. Последовательно выполнить SQL-файлы

Команды выполняются на Mac в папке, где лежат SQL-файлы:

```bash
docker exec -i clickhouse-server clickhouse-client --multiquery < 01_schema_and_dimensions.sql
docker exec -i clickhouse-server clickhouse-client --multiquery < 02_generate_events.sql
docker exec -i clickhouse-server clickhouse-client --multiquery < 03_etl_kpi.sql
docker exec -i clickhouse-server clickhouse-client --multiquery < 04_business_reports.sql
docker exec -i clickhouse-server clickhouse-client --multiquery < 05_validation.sql
docker exec -i clickhouse-server clickhouse-client --multiquery < 06_optimization_audit.sql
```

`01_schema_and_dimensions.sql` полностью пересоздаёт базу `ad_analytics`. Не запускайте его повторно, если хотите сохранить текущие данные.

## Модель данных

| Таблица | Назначение | Движок / физическая организация |
|---|---|---|
| `channels` | Справочник рекламных каналов | MergeTree, ORDER BY channel_id |
| `campaigns` | Справочник кампаний и бюджетов | MergeTree, ORDER BY campaign_id |
| `raw_ads_events` | Необработанные события | MergeTree, месячные партиции, ORDER BY campaign_id, event_date, channel_id, event_type, event_id |
| `campaign_kpi` | Ежедневная KPI-витрина | MergeTree, месячные партиции, ORDER BY campaign_id, event_date, channel_id |

Справочники небольшие и не требуют партиционирования. События и витрина имеют временной характер, поэтому разделяются по месяцу события. Это упрощает контроль объёма истории и работу с диапазонами дат без создания чрезмерно большого количества партиций.

Для аналитики по кампании и периоду первым полем сортировки выбран `campaign_id`, затем дата и канал. Это поддерживает типовой фильтр по кампании и временному диапазону. В `raw_ads_events` добавлены тип события и уникальный идентификатор для детальных выборок.

`device` и `country` имеют тип `LowCardinality(String)`, поскольку содержат небольшой повторяющийся набор значений. `event_type` использует `Enum8`.

## Определения KPI

- `impressions` — число событий `impression`.
- `clicks` — число событий `click`.
- `conversions` — число событий `conversion`.
- `spend` — сумма `cost` по всем событиям группы.
- `revenue` — сумма `revenue` по всем событиям группы.
- `CTR = clicks / impressions`.
- `CVR = conversions / clicks`.
- `CPA = spend / conversions`.
- `ROI = (revenue - spend) / spend`.

CTR, CVR и ROI хранятся как доли: например, `0.05` означает 5%. Если знаменатель равен нулю, соответствующий показатель записывается как `0`, чтобы избежать деления на ноль. В бизнес-отчётах ROI и CPA пересчитываются из суммарных числителей и знаменателей, а не усредняются по дням.

В демонстрационных данных каждый event имеет заполненные `cost` и `revenue`; доход создаётся на событиях конверсии, а расходы распределены между показами, кликами и конверсиями. Это упрощённая учебная модель, а не бухгалтерская модель рекламной платформы.

## История и TTL

- Сырые события хранятся 24 месяца.
- KPI-витрина хранится 36 месяцев.

TTL — политика хранения учебной системы. Для реальной компании сроки следует согласовать с требованиями бизнеса, аналитики и законодательства. Фактическое удаление TTL выполняется фоновыми процессами ClickHouse, поэтому не обязательно происходит мгновенно после наступления срока.

## Воспроизводимость и проверки

Для полного развёртывания достаточно последовательно выполнить шесть SQL-файлов. Все данные генерируются SQL-командами; внешние CSV и ручная корректировка строк не требуются.

`05_validation.sql` проверяет обязательные объёмы, разнообразие справочников и событий, заполненность KPI-витрины, а также точную согласованность количества показов, кликов, конверсий, расходов и доходов с исходными событиями.

`06_optimization_audit.sql` показывает активные части и партиции, текущие слияния, историю запросов и план чтения типового аналитического запроса. На небольшом наборе данных `system.merges` может быть пустой — это нормальное состояние.

## Ограничения учебной модели

- Каждая кампания связана с одним основным каналом.
- События распределяются по четырём кампаниям и соответствующим каналам.
- Данные генерируются за последние 30 календарных дней.
- Материализованное представление не используется: витрина заполняется явным повторяемым ETL-скриптом. Это делает порядок и результат загрузки прозрачными для проверки.

## Final execution results

The project was executed and validated on ClickHouse 26.10.4.207 in Docker on macOS ARM64.

- 4 channels and 4 campaigns loaded.
- 20,000 raw events generated: 16,000 impressions, 3,000 clicks and 1,000 conversions.
- 120 rows populated in `campaign_kpi`.
- Automated validation completed with `PASS`.
- Raw-event spend and KPI spend reconciled to 1,719.998.
- Raw-event revenue and KPI revenue reconciled to 49,021.
- Business reports and optimization audit scripts completed successfully.

See [FINAL_VALIDATION.md](FINAL_VALIDATION.md) for the detailed verification summary.

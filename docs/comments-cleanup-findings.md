# Что нашлось при чистке комментариев

Пилот 27.09.2026, код рассылки в kudab-api. Комментарием это не чинится, нужна правка кода или решение.

## Похоже на баги

- `EventCaptionBuilder::appendMoreAndOriginal` сравнивает сырой `canonical_url` с подписью, где ссылка уже экранирована. Если в ссылке источника есть `&`, строка «Подробнее / Открыть оригинал» допишется второй раз.
- `EventRepository::addTopScore` (SQL-копия весов скорера) проверяет статус цены `'priced'`, которого нет, и не знает про donation и price_max. Скорер рассылки уже поправлен, копия нет. Тест `WebEventsTest` подставляет тот же `'priced'`.
- `replaceDigestEvent` ставит замену в конец состава (`max position + 1`), а сборка сортирует по position: заменённое событие навсегда уезжает в хвост подборки.
- `KindEmoji`: запасной поиск значка по словам названия (`$byWord`) идёт без границы слова, «лекци» находится в «коллекция». Подавление повтора к нему не применяется, у события без тем значок всегда повторяет название. У 🛍 нет U+FE0F.
- `fixEmptyLocationLine` не срабатывает на шаблонах вида «📍 {address}»: у события без адреса в посте остаётся одинокий 📍.
- Запасная сборка поста в боте (`_build_event_caption_from_template`) отстала от шаблонов: нет ключей text, quote, kind_emoji, more_link, original_link и фильтра sentence.
- `candidatesForItem` помечает кандидата «тот же день» без учёта one_per_day: у рубрики «На выходных» почти все кандидаты уходят вниз списка.
- `listEnabledWithSchedule` не грузит `chat.owner`, хотя сервис на это рассчитывает: каждую минуту ленивые запросы по каждому каналу.
- `requestDigestText` читает `broadcast_text_grace_minutes` с `max(1, …)`, а `textGraceMinutes()` с `max(0, …)`: одна настройка, разный нижний предел.
- `enqueueForReview` сохраняет запись без транзакции, а `enqueue` оборачивает ради обсервера связи «пост → события».
- `templateCodeForDate` считает сутки по UTC: слот в 0–2 часа МСК получит форму предыдущего дня. Пока слоты 10 и 19, не проявляется.
- `BroadcastDigestBooking`: если пять недель подряд заняты, бронь молча не ставится, ни в сводке, ни в логе. `slotTaken` считает запись в статусе error занимающей слот, а `BroadcastSlotPlanner` нет.
- Формы `@return` устарели у `enqueueDueForAllChannels`, `fillFeedDays`, `enqueueDueVenuePortraits`, `nextPortraitSuggestion`, `compose`, `recompose`.

## Мёртвый код

- `TelegramChatBroadcastService`: `periodHour()`, `markRunExecutedForChatId()`, переменная `$isVenue`, ветка «старый бот без токена» в mark-sent.
- `TelegramChatBroadcastItemRepository::findNextPlannedForBroadcast` вместе со строкой в интерфейсе.
- `TelegramVenuePortraitService::POOL_PER_WEEKLY_POST` никто не читает; fallback `$photos[0] ?? venueCoverUrl(...)` ничего не даёт.
- `EventCaptionBuilder`: легаси-ветка цены (колонок `price_label`, `price`, `cost` нет), ключи `place` и `location_name` в placeShort, лишний ключ `tags`.
- `BroadcastDigestComposer`: параметр `$theme` у `landingUrl()`, всегда истинная проверка `$venue !== null` в `pickNamed`.

## Дубли, которые стоит свести

- Умолчание зазора 90 минут записано дважды: `MIN_GAP_MINUTES` в сервисе и литерал в `TelegramChatBroadcast::getMinGapMinutesAttribute`.
- `eventTakenByAnotherPost` есть и в сервисе, и в `AdminBroadcastController`.
- `dead_openings` в конфиге api и список `DEAD` в парсере разошлись, хотя должны быть одним списком.

## Недочищено

`BroadcastDigestComposer.php` и `config/broadcast_digest.php` пропущены: их в это время правила другая сессия. `AdminBroadcastController` и админка в пилот не входили, там остались копии причин, которые в сервисах уже сокращены.

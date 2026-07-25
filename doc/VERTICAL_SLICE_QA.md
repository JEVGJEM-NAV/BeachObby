# Beach Obby — QA вертикального среза

## Итог

- Stage 9: **PASS**.
- Vertical slice acceptance: **PASS**.
- Автоматические тесты: **124 passed, 0 failed**.
- Ошибок и предупреждений в финальном Output нет.

## Автоматические проверки

- Полный комплект из 124 автоматических тестов прошёл без падений.
- Тестами покрыты старт забега, непрерывный таймер, чекпоинты, универсальный hazard, сбор монеты и finish.
- Проверены server-authoritative state, изоляция session и защита от клиентской подмены состояния.

## Одиночные интеграционные сценарии

- Сценарий с монетой и двумя смертями — **PASS**.
- Сценарий без монеты и двумя смертями — **PASS**.
- Таймер переживает смерть и продолжает исходную шкалу времени.
- Finish фиксирует результат и замораживает отображаемое время.
- Повторные triggers после finish не меняют state и не создают новых обновлений состояния.
- Hazard после finish убивает персонажа, но итоговое состояние забега сохраняется после respawn.

## Desktop и mobile

- Windows viewport — **PASS**.
- iPhone 17 Pro, `LandscapeLeft` — **PASS**.
- HUD находится внутри safe area.
- TimerLabel и CoinLabel читаемы и не обрезаны.
- Touch controls присутствуют.
- HUD существует в единственном экземпляре и не дублируется после respawn.

## Acceptance matrix T1–T12

| ID | Проверка | Статус | Подтверждённый результат |
|---|---|---|---|
| T1 | Start once | **PASS** | Повторный StartLine не меняет `startedAtServerTime` или revision. |
| T2 | Timer survives death | **PASS** | Таймер продолжает исходную шкалу после смерти. |
| T3 | Initial checkpoint | **PASS** | Смерть до MidCheckpoint возвращает игрока к StartSpawn. |
| T4 | Additional checkpoint | **PASS** | Смерть после MidCheckpoint возвращает игрока к MidCheckpoint. |
| T5 | Universal hazard | **PASS** | Hazard убивает только коснувшегося игрока. |
| T6 | Coin uniqueness | **PASS** | Повторные касания и смерть не увеличивают `coinCount` повторно. |
| T7 | Per-player coin | **PASS** | Одна world coin собирается каждым игроком независимо. |
| T8 | Finish validation | **PASS** | Finish отклоняется до обязательного checkpoint и принимается после него. |
| T9 | Client trust | **PASS** | Локальная подмена state, HUD, visibility и remote payload не меняет server state. |
| T10 | HUD lifecycle | **PASS** | HUD корректно отражает NotStarted, Running и Finished, сохраняется после respawn и работает на desktop/mobile. |
| T11 | Player isolation | **PASS** | Ручной Studio Server + Clients тест подтвердил независимость двух игроков. |
| T12 | Invalid tagged object | **PASS** | Malformed tagged object безопасно игнорируется и полностью удаляется после проверки. |

### T11 — Player isolation

Ручная проверка выполнена в Roblox Studio в режиме Server + Clients с двумя клиентами.

#### Player A

- Запустил забег.
- HUD показывал `Coins 0`.
- Не активировал MidCheckpoint.
- После KillBlock возродился у StartSpawn.
- Действия Player B не изменили его состояние.
- После завершения Player B остался в состоянии Running.
- Его таймер продолжал идти.

#### Player B

- Запустил забег.
- Активировал MidCheckpoint.
- Собрал DemoCoin.
- HUD показывал `Coins 1`.
- После KillBlock возродился у MidCheckpoint.
- Его действия не изменили состояние Player A.
- Завершил забег через FinishLine.
- Его таймер остановился.
- Завершение Player B не завершило забег Player A.

#### Вывод T11

- Checkpoints независимы.
- Coins независимы.
- Deaths независимы.
- Finish и timer независимы.
- HUD каждого клиента отражает только состояние этого игрока.

## Ограничения текущего вертикального среза

В текущий вертикальный срез пока не входят:

- полноценные пляжные сцены и художественная геометрия;
- глобальный leaderboard;
- DataStore;
- финальный UI;
- будущие SUP, кокосы, funnel и quicksand механики.

## Финальное состояние

- Ветка `main` синхронизирована с `origin/main`.
- Постоянные Runtime test objects отсутствуют.
- Studio после ручного теста возвращена в Edit Mode.
- Вертикальный срез готов к следующей фазе разработки.

# Beach Obby — технический план первого вертикального среза

**Статус:** Draft — ожидает явного утверждения перед реализацией
**Дата:** 2026-07-24
**Источники:** `AGENTS.md`, `doc/MVP.md`, файлы репозитория, read-only инспекция `BeachObby.rbxl` через Roblox Studio MCP
**Изменения Studio и кода при подготовке плана:** отсутствуют

## 1. Intent Chain

- **Root Intent:** получить короткий семейный пляжный obby с серверно подтверждаемым прохождением.
- **Feature Intent:** доказать полным вертикальным срезом, что старт, непрерывный таймер, чекпоинты, смерть, монета, финиш и HUD работают как единый цикл.
- **Session Intent:** зафиксировать точную структуру Instances и Luau-файлов для первого технического прототипа без реализации полных сцен MVP.

## 2. Проверенное текущее состояние

### 2.1. Репозиторий

- Единственный игровой исходный файл: `ServerScriptService/SyncTest.server.luau`.
- Его содержимое: диагностический `print("Beach Obby: Script Sync работает")`.
- `README.md` пуст.
- Конфигурации Rojo или другого mapper-а в репозитории нет; используется Roblox Script Sync.
- `BeachObby.rbxl` существует как локальный place.
- `.rbxl.lock` исключён через `.gitignore`.
- `doc/MVP.md` задаёт серверную авторитетность старта, таймера, чекпоинтов, монет, опасностей и финиша.
- До начала этой задачи в Git уже была неотслеживаемая локальная папка `.agents/`; она не относится к реализации вертикального среза.

### 2.2. Roblox Studio

Studio проверена в **Edit mode**; play session не запускалась.

| Service | Фактическое содержимое |
|---|---|
| `Workspace` | `Camera`, `Baseplate` с `Texture`, `Terrain`, `SpawnLocation` с `Decal` |
| `ReplicatedStorage` | пуст |
| `ServerScriptService` | `SyncTest` (`Script`, server RunContext) |
| `StarterPlayer.StarterPlayerScripts` | пуст |
| `StarterPlayer.StarterCharacterScripts` | пуст |
| `StarterGui` | пуст |

Текущий `Workspace.SpawnLocation`:

- `Enabled = true`;
- `Neutral = true`;
- `Anchored = true`;
- `Size = (12, 1, 12)`;
- `Position = (0, 0.5, 0)`;
- custom attributes отсутствуют.

### 2.3. CollectionService

Игровых tags пока нет. `CollectionService:GetAllTags()` вернул только внутренние Studio-теги без tagged Instances:

- `TagEditorTagContainer`;
- `data-testid=--studio-foundation--stylesheet-wrapper`;
- `gui-object-defaults`;
- `size-full`.

Они не используются планируемыми системами и не должны удаляться или переиспользоваться.

## 3. Evidence anchors и confidence

| Решение/факт | Источник | Confidence | Статус |
|---|---|---:|---|
| Сервер владеет стартом, таймером, чекпоинтами, монетами, опасностями и финишем | `AGENTS.md`, `doc/MVP.md` | 100% | Locked |
| Таймер не останавливается и не сбрасывается после смерти | `doc/MVP.md` §§3, 4, 9, 12 | 100% | Locked |
| Начальный `SpawnLocation` одновременно является первым чекпоинтом | `doc/MVP.md` §§6.1, 13 | 100% | Locked |
| Монета уникальна в рамках забега, сохраняется после смерти и исчезает только для собравшего игрока | `doc/MVP.md` §8 | 100% | Locked |
| Опасности используют единый `Hazard` contract | `AGENTS.md`, `doc/MVP.md` §§2.3, 7 | 100% | Locked |
| HUD представляет состояние сервера, но не подтверждает его | `AGENTS.md`, `doc/MVP.md` §5 | 100% | Locked |
| В текущем place нет существующих игровых систем, remotes или gameplay tags | Studio MCP и репозиторий | 100% | Locked |
| Вложенные source-пути будут отражены Script Sync как соответствующие Instances | существующий sync подтверждает только root server script | 85% | Проверить первым малым этапом; архитектуру не менять до проверки |

## 4. Four Boxes

### 4.1. Foundation

- Luau source редактируется только в VS Code через Script Sync.
- Instances, tags, attributes и свойства UI/Parts конфигурируются в Studio.
- Script Sync-managed source не редактируется в Studio.
- Сервер является источником истины.
- Клиент отвечает только за отображение времени, монет и локальное скрытие уже собранной монеты.
- Целевые устройства полного MVP: телефон, планшет и ПК.
- Вертикальный срез строится из примитивов без декоративных assets.
- Существующие `Baseplate`, `Terrain`, `Camera` и `SyncTest` не удаляются.

### 4.2. Requirements

Игрок должен:

1. появиться на начальном `SpawnLocation`;
2. пересечь стартовую линию и запустить ровно один активный забег;
3. видеть непрерывный таймер;
4. после смерти возродиться у последнего достигнутого чекпоинта без сброса времени и монет;
5. активировать один дополнительный чекпоинт;
6. погибнуть при касании любого объекта с tag `Hazard`;
7. собрать одну монету не более одного раза за забег;
8. увидеть, что монета исчезла только для него;
9. коснуться финиша после дополнительного чекпоинта;
10. остановить таймер и зафиксировать результат ровно один раз;
11. видеть минимальный HUD: `Time 00:00.00` и `Coins 0`.

### 4.3. System Design

- Один `GameSessionService` хранит всё авторитетное состояние игрока.
- Один `WorldTriggerService` подключает все tagged touch-объекты и маршрутизирует события в `GameSessionService`.
- Один `RunStateController` получает серверные snapshots и раздаёт их клиентским presentation-контроллерам.
- Таймер не отправляет сетевые обновления каждый кадр: сервер передаёт время старта, клиент только отображает разницу, а итоговое время вычисляет сервер.
- Все переходы состояния идемпотентны: повторные `Touched` не перезапускают забег, не дублируют монету и не перезаписывают финиш.

### 4.4. Connections

- `Players` — жизненный цикл игроков и персонажей.
- `CollectionService` — единый поиск и подключение tagged world objects.
- `ReplicatedStorage` — shared config и remotes.
- `Workspace:GetServerTimeNow()` — общая временная база для плавного HUD; результат всё равно вычисляется сервером.
- `DataStoreService` — **n/a** для вертикального среза: состояние только серверной сессии.
- Внешние API, plugins, marketplace assets, monetization и analytics — **n/a**.

## 5. Acceptance criteria

- [ ] До пересечения `StartLine` HUD показывает `Time 00:00.00` и `Coins 0`.
- [ ] Первое валидное касание `StartLine` переводит состояние `NotStarted → Running`.
- [ ] Повторное касание `StartLine` не меняет время старта.
- [ ] Таймер растёт непрерывно и после смерти продолжает исходный забег.
- [ ] До активации дополнительного чекпоинта смерть возвращает к `StartSpawn`.
- [ ] После активации `MidCheckpoint` смерть возвращает к нему.
- [ ] Касание `KillBlock` убивает только коснувшегося персонажа.
- [ ] `DemoCoin` увеличивает счёт с 0 до 1 только один раз за забег.
- [ ] Смерть не возвращает монету и не уменьшает счёт.
- [ ] `DemoCoin` скрывается локально только у собравшего игрока.
- [ ] Финиш до `MidCheckpoint` отклоняется.
- [ ] Первый валидный финиш переводит `Running → Finished` и фиксирует время.
- [ ] Повторное касание финиша не меняет зафиксированное время или монеты.
- [ ] Два игрока имеют независимые таймеры, чекпоинты, монеты и финиш.
- [ ] В Output нет ошибок и новых предупреждений вертикального среза.

## 6. Точная целевая структура Roblox Instances

Пометка `(existing)` означает сохранение существующего объекта. Пометка `(new)` означает создание только после утверждения плана.

```text
Workspace
├── Camera (existing)
├── Baseplate (existing)
├── Terrain (existing)
└── BeachObby (Folder, new)
    └── VerticalSlice (Model, new)
        ├── StartSpawn (SpawnLocation, existing Workspace.SpawnLocation; move + rename)
        ├── Geometry (Folder, new)
        │   ├── StartPlatform (Part, new)
        │   ├── MidPlatform (Part, new)
        │   └── FinishPlatform (Part, new)
        ├── Triggers (Folder, new)
        │   ├── StartLine (Part, new)
        │   ├── MidCheckpoint (Part, new)
        │   └── FinishLine (Part, new)
        ├── Hazards (Folder, new)
        │   └── KillBlock (Part, new)
        └── Coins (Folder, new)
            └── DemoCoin (Part, new)

ReplicatedStorage
└── BeachObby (Folder, new)
    ├── Remotes (Folder, new)
    │   ├── RunStateUpdated (RemoteEvent, new)
    │   └── GetRunState (RemoteFunction, new)
    └── Shared (Folder, new)
        └── RunConfig (ModuleScript, new; Script Sync-managed)

ServerScriptService
├── SyncTest (Script, existing; unchanged)
├── BeachObbyServer (Script, new; Script Sync-managed)
└── Services (Folder, new)
    ├── GameSessionService (ModuleScript, new; Script Sync-managed)
    └── WorldTriggerService (ModuleScript, new; Script Sync-managed)

StarterPlayer
├── StarterPlayerScripts
│   ├── RunStateController (ModuleScript, new; Script Sync-managed)
│   ├── HUDController (LocalScript, new; Script Sync-managed)
│   └── CoinVisualController (LocalScript, new; Script Sync-managed)
└── StarterCharacterScripts (existing, remains empty)

StarterGui
└── BeachObbyHUD (ScreenGui, new)
    └── StatusFrame (Frame, new)
        ├── TimerLabel (TextLabel, new)
        └── CoinLabel (TextLabel, new)
```

### 6.1. Критические свойства Instances

| Instance | Критические свойства |
|---|---|
| `StartSpawn` | `Enabled=true`, `Neutral=true`, `Anchored=true`; остаётся физической стартовой точкой |
| `StartLine` | `Anchored=true`, `CanCollide=false`, `CanTouch=true` |
| `MidCheckpoint` | `Anchored=true`, `CanCollide=false`, `CanTouch=true`; обычный `Part`, не второй auto-spawn |
| `FinishLine` | `Anchored=true`, `CanCollide=false`, `CanTouch=true` |
| `KillBlock` | `Anchored=true`, `CanCollide=true`, `CanTouch=true` |
| `DemoCoin` | `Anchored=true`, `CanCollide=false`, `CanTouch=true` |
| `BeachObbyHUD` | `ResetOnSpawn=false`, `IgnoreGuiInset=false` |
| `TimerLabel` | начальный текст `Time 00:00.00` |
| `CoinLabel` | начальный текст `Coins 0` |

Точные CFrame, размеры и цвета greybox-объектов декоративны и настраиваются при реализации так, чтобы маршрут был коротким и однозначным. Они не являются load-bearing contract.

## 7. CollectionService tags и attributes

Все названия централизуются в `RunConfig.luau`; строковые литералы не дублируются по сервисам.

| Instance | Tag | Attributes |
|---|---|---|
| `StartSpawn` | `Checkpoint` | `CheckpointId="Start"`, `CheckpointOrder=1`, `RespawnOffset=Vector3.new(0, 4, 0)` |
| `StartLine` | `RunStart` | нет |
| `MidCheckpoint` | `Checkpoint` | `CheckpointId="Mid"`, `CheckpointOrder=2`, `RespawnOffset=Vector3.new(0, 4, 0)` |
| `KillBlock` | `Hazard` | нет |
| `DemoCoin` | `Coin` | `CoinId="VerticalSliceCoin01"` |
| `FinishLine` | `Finish` | `RequiredCheckpointOrder=2` |

Контракты:

- tagged trigger обязан быть `BasePart` с `CanTouch=true`;
- каждый `CheckpointId` и `CoinId` обязан быть непустым и уникальным;
- `CheckpointOrder` обязан быть положительным целым числом;
- первый checkpoint обязан иметь `CheckpointOrder=1`;
- invalid tagged object игнорируется с одним понятным server warning, а не ломает весь bootstrap.

## 8. Точный список файлов `.luau`

### 8.1. Новые файлы

| # | Source path | Получаемый Instance | Side | Назначение | Weight |
|---:|---|---|---|---|---|
| 1 | `ReplicatedStorage/BeachObby/Shared/RunConfig.luau` | `ReplicatedStorage.BeachObby.Shared.RunConfig` | Shared | Единственный источник tag names, attribute names, phase names, remote names и формата HUD | Load-Bearing |
| 2 | `ServerScriptService/BeachObbyServer.server.luau` | `ServerScriptService.BeachObbyServer` | Server | Проверить структуру, инициализировать services/remotes в фиксированном порядке, не содержать gameplay rules | Load-Bearing |
| 3 | `ServerScriptService/Services/GameSessionService.luau` | `ServerScriptService.Services.GameSessionService` | Server | Хранить per-player state; обрабатывать старт, checkpoint, hazard, coin, finish, respawn и snapshots | Load-Bearing |
| 4 | `ServerScriptService/Services/WorldTriggerService.luau` | `ServerScriptService.Services.WorldTriggerService` | Server | Один раз подключить `Touched` для всех пяти tags, разрешить Player/Character и вызвать соответствующий метод session service | Load-Bearing |
| 5 | `StarterPlayerScripts/RunStateController.luau` | `StarterPlayer.StarterPlayerScripts.RunStateController` | Client | Единожды получить initial snapshot, слушать `RunStateUpdated`, отвергать устаревшие revisions и раздавать state subscribers | Load-Bearing |
| 6 | `StarterPlayerScripts/HUDController.client.luau` | `StarterPlayer.StarterPlayerScripts.HUDController` | Client | Отображать время и coins; локально интерполировать running time без сетевого тика | Decorative consumer of load-bearing state |
| 7 | `StarterPlayerScripts/CoinVisualController.client.luau` | `StarterPlayer.StarterPlayerScripts.CoinVisualController` | Client | По `collectedCoinIds` скрывать tagged coin только локально через `LocalTransparencyModifier` | Decorative consumer of load-bearing state |

### 8.2. Существующий файл

`ServerScriptService/SyncTest.server.luau` остаётся без изменений и не участвует в runtime contracts вертикального среза. Его удаление не входит в план.

## 9. Серверное состояние и lifecycle

`GameSessionService` хранит таблицу по `Player`, а не по `Character`:

```text
SessionState
├── revision: number
├── phase: "NotStarted" | "Running" | "Finished"
├── startedAtServerTime: number?
├── finishedElapsedSeconds: number?
├── currentCheckpoint: BasePart
├── currentCheckpointId: string
├── currentCheckpointOrder: number
├── collectedCoinIds: {[string]: true}
└── coinCount: number
```

### 9.1. Переходы

| Событие | Preconditions | Серверное действие | Snapshot |
|---|---|---|---|
| `PlayerAdded` | игрок новый | создать `NotStarted`, checkpoint=`Start`, coins=0 | доступен через `GetRunState` |
| `StartLine.Touched` | `phase=NotStarted` | записать `startedAtServerTime=Workspace:GetServerTimeNow()`, phase=`Running` | увеличить revision и отправить |
| повторный start | phase не `NotStarted` | ничего не менять | не отправлять |
| `MidCheckpoint.Touched` | `phase=Running`, order выше текущего | заменить current checkpoint | увеличить revision и отправить |
| повторный/старый checkpoint | order не выше текущего | ничего не менять | не отправлять |
| `KillBlock.Touched` | живой Humanoid | `Humanoid.Health=0` | session не сбрасывать |
| `CharacterAdded` | session существует | переместить character к current checkpoint + `RespawnOffset` | состояние не менять |
| `DemoCoin.Touched` | `phase=Running`, CoinId ещё нет | добавить ID, coinCount+1 | увеличить revision и отправить |
| повторная монета | ID уже есть | ничего не менять | не отправлять |
| `FinishLine.Touched` | `phase=Running`, checkpoint order ≥ 2 | вычислить elapsed на сервере, phase=`Finished` | увеличить revision и отправить |
| повторный/ранний finish | preconditions не выполнены | ничего не менять | не отправлять |
| `PlayerRemoving` | session существует | удалить session и connections игрока | нет |

Смерть не меняет `phase`, `startedAtServerTime`, checkpoint или coins. Персонаж заменяется, забег — нет.

## 10. Серверная и клиентская ответственность

| Область | Server | Client |
|---|---|---|
| Старт | Проверяет touch и фиксирует единственное время старта | Только отображает snapshot |
| Таймер | Хранит start time и вычисляет final elapsed | Показывает `GetServerTimeNow() - startedAt` во время Running |
| Checkpoint | Проверяет порядок и хранит последний checkpoint | Не сообщает о достижении |
| Respawn | Перемещает новый Character к server-owned checkpoint | Не выбирает spawn |
| Hazard | Определяет Player/Humanoid и устанавливает Health=0 | Нет authoritative действий |
| Coin | Проверяет phase и уникальный CoinId; увеличивает счёт | Локально скрывает уже собранную монету |
| Finish | Проверяет phase/order и фиксирует время один раз | Останавливает отображаемый timer по snapshot |
| HUD | Отправляет только state snapshots | Форматирует время и количество монет |

Клиент не отправляет start, checkpoint, coin, hazard или finish claims.

## 11. Remote contracts

### 11.1. `RunStateUpdated` — RemoteEvent

- **Direction:** Server → конкретный Client.
- **Когда:** только после фактического перехода server state.
- **Payload:**

```text
RunStateSnapshot
├── revision: number
├── phase: string
├── startedAtServerTime: number?
├── finishedElapsedSeconds: number?
├── coinCount: number
└── collectedCoinIds: {string}
```

- Snapshot не содержит Instance references.
- Массив `collectedCoinIds` создаётся сервером из set и нужен только local presentation.
- Клиент принимает snapshot, только если `revision` не меньше уже применённого.

### 11.2. `GetRunState` — RemoteFunction

- **Direction:** Client → Server → Client.
- **Input:** отсутствует; любые переданные значения игнорируются.
- **Output:** текущий `RunStateSnapshot` вызвавшего игрока.
- **Назначение:** устранить race между загрузкой LocalScripts и первым `RunStateUpdated`.
- Не изменяет состояние и не принимает player identity из payload.

Другие RemoteEvents/RemoteFunctions для среза не нужны.

## 12. Защита от дублирования логики

1. Только `WorldTriggerService` подписывается на `Touched`.
2. Только `GameSessionService` меняет state.
3. Только `RunConfig` хранит tags, attributes, phases и remote names.
4. Только `RunStateController` слушает remotes на клиенте.
5. HUD и coin visuals подписываются на controller, а не подключаются к remotes самостоятельно.
6. Все tagged objects проходят один character→player resolver.
7. Все переходы проверяют preconditions и являются идемпотентными.
8. Hazard не содержит собственной логики respawn; он вызывает обычную смерть, а checkpoint lifecycle обрабатывает `CharacterAdded`.
9. Checkpoint, coin и finish не получают отдельных Scripts внутри world Instances.

## 13. Порядок реализации маленькими этапами

Каждый этап реализуется отдельно. После каждого этапа: запустить Studio через MCP, проверить Output, сообщить изменение и результат, затем остановиться перед следующим этапом согласно `AGENTS.md`.

### Этап 1 — проверить Script Sync boundary и создать contracts

**Изменения будущего этапа:**

- проверить, что вложенные source folders корректно создают ModuleScripts;
- создать `RunConfig.luau`;
- создать `ReplicatedStorage.BeachObby.Remotes` с двумя remotes;
- создать пустые целевые folders services/client только в необходимом объёме.

**Проверки:**

- все source paths отображаются в ожидаемых game-tree paths;
- тип каждого synced script корректен;
- Output не содержит sync/runtime errors;
- gameplay ещё не запускается.

### Этап 2 — server session bootstrap и client state controller

**Изменения будущего этапа:**

- создать `GameSessionService`, `BeachObbyServer` и `RunStateController`;
- реализовать `PlayerAdded`, `PlayerRemoving`, initial snapshot и revision.

**Проверки:**

- один игрок получает `NotStarted`, revision и coins=0;
- `GetRunState` возвращает только состояние вызывающего игрока;
- два игрока получают разные session objects;
- повторная инициализация не создаёт двойные connections;
- Output чист.

### Этап 3 — минимальный HUD

**Изменения будущего этапа:**

- создать `BeachObbyHUD`, labels и `HUDController`;
- `ResetOnSpawn=false`.

**Проверки:**

- до старта отображается `Time 00:00.00`, `Coins 0`;
- HUD не дублируется и не исчезает после respawn;
- формат сотых корректен;
- проверить Windows и один mobile viewport;
- Output чист.

### Этап 4 — старт и непрерывный timer

**Изменения будущего этапа:**

- создать `StartLine` с tag `RunStart`;
- создать `WorldTriggerService`;
- реализовать переход `NotStarted → Running`.

**Проверки:**

- первое касание запускает timer;
- повторное касание не меняет start time;
- Reset Character не сбрасывает timer;
- timer не генерирует RemoteEvent каждый frame;
- два игрока стартуют независимо;
- Output чист.

### Этап 5 — начальный и дополнительный checkpoints

**Изменения будущего этапа:**

- переместить и переименовать существующий SpawnLocation в `StartSpawn`;
- добавить оба checkpoint contracts и `MidCheckpoint`;
- реализовать server respawn placement.

**Проверки:**

- до MidCheckpoint смерть возвращает к StartSpawn;
- после MidCheckpoint смерть возвращает к MidCheckpoint;
- повторный touch не меняет timer/coins/revision;
- старый checkpoint не откатывает прогресс;
- два игрока сохраняют разные checkpoints;
- Output чист.

### Этап 6 — универсальный Hazard

**Изменения будущего этапа:**

- создать один `KillBlock`;
- подключить его только tag `Hazard`, без Script внутри Part.

**Проверки:**

- контакт любой части character убивает только этого игрока;
- множественные `Touched` не вызывают повторную обработку уже мёртвого Humanoid;
- после respawn timer и checkpoint сохранены;
- новый второй тестовый Part с тем же tag работает без нового кода, затем тестовый Part удаляется в рамках этого этапа;
- Output чист.

### Этап 7 — одна монета

**Изменения будущего этапа:**

- создать `DemoCoin`;
- реализовать server uniqueness и `CoinVisualController`.

**Проверки:**

- до старта coin claim игнорируется;
- после старта счёт становится 1;
- повторные touches оставляют 1;
- смерть оставляет 1;
- монета скрыта только у собравшего игрока;
- второй игрок видит и может собрать ту же world coin независимо;
- Output чист.

### Этап 8 — финиш

**Изменения будущего этапа:**

- создать `FinishLine`;
- реализовать проверку required checkpoint и переход `Running → Finished`.

**Проверки:**

- финиш до start и до MidCheckpoint игнорируется;
- валидный финиш останавливает отображаемое время;
- повторный touch не изменяет результат;
- смерть/respawn после finish не возобновляет timer;
- результат одного игрока не влияет на другого;
- Output чист.

### Этап 9 — полный интеграционный проход

**Проверки без добавления функций:**

- пройти `spawn → start → coin → hazard/death → start checkpoint → mid checkpoint → hazard/death → mid checkpoint → finish`;
- повторить без монеты;
- повторить двумя игроками;
- проверить Windows и mobile viewport;
- проверить Output на errors/warnings;
- подтвердить все acceptance criteria вертикального среза.

## 14. Сводный test plan

| ID | Scenario | Type | Given | When | Then | Evidence |
|---|---|---|---|---|---|---|
| T1 | Start once | Happy | NotStarted | touch StartLine дважды | один startedAt, phase Running | snapshot + HUD |
| T2 | Timer survives death | Lifecycle | Running | character dies | время продолжает исходную шкалу | before/after values |
| T3 | Initial checkpoint | Failure | Running, order 1 | die before Mid | respawn at StartSpawn | character position |
| T4 | Additional checkpoint | Happy | Running | touch Mid, then die | respawn at Mid | state + position |
| T5 | Universal hazard | Failure | living character | touch tagged KillBlock | only touching Humanoid dies | multiplayer observation |
| T6 | Coin uniqueness | Edge | Running, coinCount 0 | touch coin repeatedly and die | coinCount remains 1 | snapshot + local visibility |
| T7 | Per-player coin | Multiplayer | two players | player A collects | A hidden/count1; B visible/count0 | two clients |
| T8 | Finish validation | Trust/edge | Running, order 1 then 2 | touch Finish | reject at 1, finish at 2 | phase + final elapsed |
| T9 | Client trust | Security | client tools | attempt local state/remote misuse | server state unchanged | server snapshot |
| T10 | HUD lifecycle | UI | HUD loaded | start, die, finish | one HUD, correct states | desktop/mobile capture |
| T11 | Player isolation | Multiplayer | two active sessions | different progress | no shared checkpoint/time/coins | two snapshots |
| T12 | Invalid tagged object | Integration | malformed attributes | bootstrap/tag add | object ignored, one warning, game continues | Output |

## 15. Traceability

| Requested capability | Instances | Files | Tests |
|---|---|---|---|
| Старт забега | `StartLine` | `RunConfig`, `WorldTriggerService`, `GameSessionService` | T1 |
| Непрерывный timer | remotes, HUD | `GameSessionService`, `RunStateController`, `HUDController` | T1, T2, T10 |
| Начальный checkpoint | `StartSpawn` | `GameSessionService` | T3 |
| Дополнительный checkpoint | `MidCheckpoint` | `WorldTriggerService`, `GameSessionService` | T4 |
| Универсальный hazard | `KillBlock` | `WorldTriggerService`, `GameSessionService` | T5, T12 |
| Одна coin | `DemoCoin` | `GameSessionService`, `CoinVisualController` | T6, T7 |
| Finish | `FinishLine` | `WorldTriggerService`, `GameSessionService` | T8 |
| Минимальный HUD | `BeachObbyHUD` и labels | `RunStateController`, `HUDController` | T10 |

## 16. Load-bearing audits

| Решение | Что зависит | Три challenge-вопроса | Результат | Confidence |
|---|---|---|---|---:|
| Один server session на Player | все восемь функций | переживает ли Character death; изолированы ли players; очищается ли PlayerRemoving | Да, state не привязан к Character и удаляется при leave | 98% |
| Один tagged trigger router | все world interactions | duplicate Touched; dynamic tagged parts; malformed object | Idempotent handlers, add/remove signals, validation | 95% |
| Один snapshot contract с revision | HUD и coin visuals | initial-load race; out-of-order update; лишний network tick | RemoteFunction + revision + event only on transition | 95% |
| Server timestamp, local display | timer | смерть; client clock; forged finish | server time survives death, shared timebase, server computes final | 98% |
| Checkpoint как server state + respawn PivotTo | death lifecycle | Mid не SpawnLocation; new Character race; invalid checkpoint | BasePart contract, wait for root, fallback to Start | 94% |
| Локальное скрытие server-owned coin | multiplayer coins | A collects before B; death; repeated touch | ID set server-side, local visual subscriber, idempotency | 96% |

## 17. Риски и меры

| Риск | Последствие | Мера |
|---|---|---|
| Script Sync не поддержит ожидаемый nested mapping | game tree не совпадёт с планом | Проверить на этапе 1 до gameplay-кода; при необходимости изменить только physical source layout, сохранив logical instance contracts |
| `Touched` срабатывает для нескольких частей character | повторные transitions | Единый resolver, preconditions, per-player/object short debounce только как оптимизация; correctness обеспечивается idempotency |
| Character появляется раньше готовности root part | неверный respawn | Ждать `HumanoidRootPart`, проверять, что Character ещё актуален, применять offset |
| Client snapshot race при загрузке | HUD показывает старое состояние | `GetRunState` + монотонный `revision` |
| Timer через частые remotes | network noise и рассинхрон | Передавать start/final timestamps только на transitions |
| Глобально скрытая coin | один игрок лишает монеты остальных | Не менять server Transparency после collection; использовать local `LocalTransparencyModifier` |
| Дублирование scripts в Parts | разные правила hazard/checkpoint/coin | Не размещать Scripts в world objects; tags + central services |
| Finish можно пропустить напрямую | некорректный результат | Server проверяет phase и `RequiredCheckpointOrder` |
| Client пытается подменить progress | чит/ложный результат | Нет client gameplay claims; RemoteFunction только read-only для caller |
| Смерть сбрасывает LocalScript/UI | timer визуально перезапускается | Controllers в StarterPlayerScripts, `ScreenGui.ResetOnSpawn=false`, state повторно читается с сервера |

## 18. Сознательно не входит в вертикальный срез

- Полные геометрия и оформление стартовой зоны и сцен 1–3.
- Лежаки, горячий песок как большая поверхность, человечки, акулы, круги и вращающийся лазер.
- Финальная пальма и винтовая лестница.
- Более двух checkpoints.
- Более одного hazard object в сохранённом greybox.
- Более одной coin и полное распределение 16–25 монет.
- Название сцены, итоговый modal screen и кнопка повторного забега.
- Таблица текущего сервера, личные рекорды и глобальные `OrderedDataStore` Top-10.
- DataStore persistence, повторный вход и миграция данных.
- Художественные models, textures, sounds, animations и decorative assets.
- Магазин, monetization, cosmetics, pets, progression, achievements и будущие сцены.
- Автоматизированный test framework; для среза планируются Studio playtests и наблюдаемые server/client assertions.

Эти исключения уменьшают объём среза, но не меняют contracts, на которых позже строится полный MVP.

## 19. Validation по Four Boxes

| Area | Результат | Evidence |
|---|---|---|
| Foundation | Complete | инструкции, repo и Studio tree проверены; Script Sync boundary записан |
| Requirements | Complete | 8 requested capabilities и правила `doc/MVP.md` преобразованы в acceptance criteria |
| System Design | Complete | все Instances, 7 новых `.luau`, ownership, lifecycle, tags, attributes и remotes перечислены |
| Connections | Complete | Players, CollectionService, ReplicatedStorage и timebase определены; persistence/external отмечены n/a |
| Tests | Complete | 12 scenarios, этапные проверки и traceability определены |

Проверка scope:

- каждый design unit трассируется к requested capability или обязательному architecture constraint;
- ни одна отложенная механика из `doc/MVP.md` не добавлена;
- игровой код и Studio не изменялись;
- medium-confidence Script Sync mapping явно вынесен в первый проверочный этап;
- blocking unknowns для утверждения архитектуры отсутствуют.

## 20. Approval gate

Pre-development complete.

- Foundation, Requirements, System Design, Connections и Tests заполнены.
- Новых `.luau` файлов в плане: **7**.
- Плановых test scenarios: **12**.
- Blocking decisions: **0**.
- Реализация не начата.

Перед созданием Instances или Luau-кода требуется явное утверждение этого плана.

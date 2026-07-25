# Beach Obby — технический план Phase 2: полноценный MVP-мир

**Статус:** Approved — утверждён к реализации

**Стабильная точка возврата:** аннотированный Git-тег `v0.1.0-vertical-slice`

**Источники:** `AGENTS.md`, `doc/MVP.md`, `doc/IMPLEMENTATION_PLAN.md`, `doc/VERTICAL_SLICE_QA.md`, `doc/visuals/manifest.md`, восемь изображений `doc/visuals/image01.jpeg`–`image08.jpeg`, production-код, 124 существующих теста и read-only инспекция `Workspace.BeachObby.VerticalSlice`

**Изменения Studio и игрового кода при подготовке плана:** отсутствуют

## 1. Цель фазы

Цель Phase 2 — превратить принятый технический vertical slice в последовательный, проходимый и пригодный для настройки Beach Obby MVP-мир из четырёх сцен. Новая геометрия должна использовать уже проверенный игровой цикл, а не создавать параллельные системы.

Сохраняются без изменения базовых контрактов:

- server-authoritative run state;
- непрерывный таймер, переживающий смерть;
- последовательные checkpoints и server-side respawn placement;
- единый contract `Hazard`;
- необязательные per-player coins;
- однократный finish и замороженное итоговое время;
- существующий HUD;
- multiplayer isolation.

`v0.1.0-vertical-slice` является стабильной точкой возврата до начала Phase 2. Ни один этап нового мира не должен переписывать историю или перемещать этот тег.

### 1.1. Intent Chain

- **Root Intent:** выпустить короткий семейный пляжный obby с понятным маршрутом и серверно подтверждаемым результатом.
- **Feature Intent:** заменить техническую линию из шести объектов полноценным миром из четырёх сцен, сохранив принятый жизненный цикл забега.
- **Session Intent:** заранее зафиксировать структуру Instances, migration существующих объектов, новые runtime-компоненты, тесты и границы каждого малого этапа.

### 1.2. Player story

Игрок появляется в безопасной стартовой зоне, запускает забег, последовательно проходит горячий пляж, воду, лазерный остров и гигантскую пальму, при желании собирает монеты, после смерти возвращается к последнему последовательному checkpoint и завершает забег на вершине пальмы. Другой игрок на том же сервере проходит тот же физический мир с независимыми временем, прогрессом, монетами и финишем.

## 2. Проверенная основа и границы MVP-мира

### 2.1. Текущая основа

- QA vertical slice: `Stage 9 PASS`, `Vertical slice acceptance PASS`.
- Автоматические тесты: `124 passed, 0 failed`.
- Ручные desktop, mobile и Studio `Server + 2 Clients` проверки пройдены.
- Production state хранится по `Player`; snapshot не содержит Instances.
- `WorldTriggerService` уже маршрутизирует `RunStart`, `Checkpoint`, `Hazard`, `Coin` и `Finish`.
- `GameSessionService` уже предоставляет `StartRun`, `ReachCheckpoint`, `CollectCoin`, `FinishRun`, `PlaceCharacterAtCheckpoint` и immutable-by-copy snapshots.
- Новые gameplay remotes для построения мира не нужны.

Read-only инспекция Studio подтвердила `Edit mode` и текущее дерево:

```text
Workspace.BeachObby.VerticalSlice (Model)
├── StartSpawn (SpawnLocation; Checkpoint, order 1)
├── Triggers
│   ├── StartLine (Part; RunStart)
│   ├── MidCheckpoint (Part; Checkpoint, order 2)
│   └── FinishLine (Part; Finish, required order 2)
├── Hazards
│   └── KillBlock (Part; Hazard)
└── Coins
    └── DemoCoin (Part; Coin, CoinId="DemoCoin")
```

### 2.2. Входит в Phase 2

#### Сцена 1 — горячий пляж

- `StartSpawn` и `StartLine`;
- горячий песок как `Hazard`;
- линейный маршрут по шезлонгам;
- 2–3 циклически бегающих stick-figure NPC hazards;
- checkpoint на границе со сценой воды.

#### Сцена 2 — вода

- переход по надувным кругам, проходимый обычным Roblox-прыжком;
- вода как основной `Hazard`;
- движущиеся акулы как дополнительный контактный `Hazard`;
- необязательные coins;
- checkpoint при входе на круглый остров.

#### Сцена 3 — круглый остров

- круглый остров и центральный шар;
- одна вращающаяся перекладина, проходящая через шар и визуально образующая два противоположных laser hazards;
- coins по периметру;
- checkpoint у основания финальной пальмы.

#### Сцена 4 — гигантская пальма

- гигантская пальма;
- спиральная лестница;
- опасная область падения, возвращающая игрока к checkpoint у основания;
- `FinishLine` на вершине.

### 2.3. Не входит в Phase 2

- SUP boards и lightning;
- кокосовый пляж и его человечки;
- spiral funnel;
- quicksand, бросаемые предметы и связанный inventory;
- `DataStore`, личная persistence и global leaderboard;
- итоговый экран, повторный запуск и финальный художественный UI;
- monetization, магазин, награды, cosmetics и achievements.

Это план **MVP-мира и полного traversal**, а не всех систем релизного MVP из `doc/MVP.md`. Persistence, leaderboards и финальный UI остаются отдельной последующей фазой.

### 2.4. Использование визуальных источников

| Файл | Использование в Phase 2 | Решение |
|---|---|---|
| `image01.jpeg` | Общая яркая, простая и доброжелательная стилистика | Не определяет отдельную сцену или точную геометрию пальмы |
| `image02.jpeg` | Горячий пляж: маршрут между водой и зелёной границей, лежаки, stick figures | Композиция — ориентир; количества, цвета и пропорции не обязательны |
| `image03.jpeg` | Вода: последовательность кругов и акульи плавники | Маршрут должен быть читаемее эскиза и проходим на mobile |
| `image04.jpeg` | Круглый остров: центральный шар, одна перекладина и монеты по краю | Перекладина одна, её две стороны образуют два луча |
| `image05.jpeg` | Не используется | SUP и lightning исключены |
| `image06.jpeg` | Не используется | Кокосовый пляж исключён; пальмы на рисунке не задают финальную пальму |
| `image07.jpeg` | Не используется | Spiral funnel исключён |
| `image08.jpeg` | Не используется | Quicksand и предметы исключены |

## 3. Four Boxes

### 3.1. Foundation

- Luau source меняется только через Script Sync roots `ReplicatedStorage/`, `ServerScriptService/`, `StarterPlayerScripts/`.
- Studio используется для Instances, tags, attributes, Terrain и свойств мира.
- Текущий target: Windows и mobile; multiplayer acceptance — два клиента.
- `BeachObbyHUD` сохраняет текущий contract и `ResetOnSpawn=false`.
- Внешние assets не являются обязательными: greybox и базовый art pass должны быть возможны из primitives и проверенных локальных assets.
- Persistence и migration данных — `n/a`: DataStore в этой фазе отсутствует.

### 3.2. Requirements

- Маршрут строго линейный и показывает следующую цель.
- Все четыре сцены проходимы без специальных ускорений.
- Движущиеся hazards предсказуемы и цикличны.
- Hot sand, water, sharks, stick figures, laser и fall catch используют единый server-side hazard contract.
- Checkpoints нельзя активировать с пропуском порядка.
- Coins необязательны и независимы для игроков.
- Смерть не меняет timer, coins или phase.
- Finish требует checkpoint у основания пальмы и фиксируется один раз.

### 3.3. System Design

- `GameSessionService` остаётся единственным владельцем run state.
- `WorldTriggerService` остаётся единственным router tagged contacts.
- Движение hazards отделено от последствий контакта: movement services двигают geometry, `WorldTriggerService` продолжает применять `Hazard`.
- Все стабильные IDs, names и movement entries централизуются в `WorldConfig`.
- Новые world Parts не получают вложенных Scripts.

### 3.4. Connections

- `CollectionService`: существующие пять tags; новые gameplay tags не нужны.
- `RunService`: server-side обновление предсказуемого движения.
- `Workspace`: authoritative positions, overlap/touch integration и `GetServerTimeNow()`.
- `Players`: существующий lifecycle без новых `PlayerAdded`/`CharacterAdded` chains.
- Remotes: существующие `RunStateUpdated` и `GetRunState`; новых нет.
- Analytics, marketplace, monetization, localization и external APIs — `n/a` для этой фазы.

## 4. Целевая архитектура Workspace

Ниже фиксируется точное дерево функциональных units. Повторяющиеся декоративные детали именуются последовательностями (`Lounge01…N`, `Step01…N`); их окончательное количество определяется только traversal-тестом и не является новым gameplay contract.

```text
Workspace
└── BeachObby (Folder)
    ├── World (Model, new)
    │   ├── SharedEnvironment (Model)
    │   │   ├── OceanSurface (Part; visual, no gameplay tag)
    │   │   ├── GlobalFallCatch (Part; Hazard)
    │   │   ├── DistantBeach (Model)
    │   │   └── ForestBackdrop (Model)
    │   ├── Scene01_HotBeach (Model)
    │   │   ├── Start (Folder)
    │   │   │   ├── StartSpawn (SpawnLocation; Checkpoint)
    │   │   │   ├── StartLine (Part; RunStart)
    │   │   │   └── DemoCoin (Part; Coin)
    │   │   ├── Geometry (Folder)
    │   │   │   ├── HotSandVisual (Part)
    │   │   │   ├── Loungers (Folder: Lounge01…N)
    │   │   │   └── EndPlatform (Part)
    │   │   ├── Hazards (Folder)
    │   │   │   ├── HotSandHazard (Part; Hazard)
    │   │   │   └── StickFigures (Folder: Runner01…Runner03)
    │   │   │       └── each Runner (Model)
    │   │   │           ├── Visual (Model)
    │   │   │           └── Hitbox (Part; Hazard)
    │   │   ├── MovementPaths (Folder: RunnerNN_Start/RunnerNN_End marker Parts)
    │   │   ├── Coins (Folder: HotBeachCoin01…HotBeachCoin03)
    │   │   └── Triggers (Folder)
    │   │       └── WaterStartCheckpoint (Part; Checkpoint order 2)
    │   ├── Scene02_Water (Model)
    │   │   ├── Geometry (Folder)
    │   │   │   ├── WaterSurface (Part; visual)
    │   │   │   ├── EntryPlatform (Part)
    │   │   │   └── Rings (Folder: Ring01…N)
    │   │   ├── Hazards (Folder)
    │   │   │   ├── WaterKillPlane (Part; Hazard)
    │   │   │   └── Sharks (Folder: Shark01…N)
    │   │   │       └── each Shark (Model)
    │   │   │           ├── Visual (Model)
    │   │   │           └── Hitbox (Part; Hazard)
    │   │   ├── MovementPaths (Folder: SharkNN_Start/SharkNN_End marker Parts)
    │   │   ├── Coins (Folder: WaterCoin01…WaterCoin04)
    │   │   └── Triggers (Folder)
    │   │       └── LaserIslandStartCheckpoint (Part; Checkpoint order 3)
    │   ├── Scene03_LaserIsland (Model)
    │   │   ├── Geometry (Folder)
    │   │   │   ├── IslandBase (Part)
    │   │   │   ├── CenterSphere (Part)
    │   │   │   ├── EntryPlatform (Part)
    │   │   │   └── ExitPlatform (Part)
    │   │   ├── Hazards (Folder)
    │   │   │   └── LaserAssembly (Model)
    │   │   │       └── LaserBar (Part; one bar; Hazard)
    │   │   ├── Coins (Folder: LaserIslandCoin01…LaserIslandCoin05)
    │   │   └── Triggers (Folder)
    │   │       └── PalmBaseCheckpoint (Part; Checkpoint order 4)
    │   └── Scene04_PalmFinish (Model)
    │       ├── Geometry (Folder)
    │       │   ├── PalmTree (Model)
    │       │   │   ├── Trunk (Model)
    │       │   │   └── Fronds (Model)
    │       │   ├── SpiralSteps (Folder: Step01…N)
    │       │   └── SummitPlatform (Part)
    │       ├── Hazards (Folder)
    │       │   └── PalmFallCatch (Part; Hazard)
    │       ├── Coins (Folder: PalmCoin01…PalmCoin03)
    │       └── Triggers (Folder)
    │           └── FinishLine (Part; Finish, required order 4)
    └── VerticalSlice (Model; temporary legacy shell after Phase 2.8)
        ├── Triggers (Folder; empty after migration)
        ├── Hazards (Folder)
        │   └── KillBlock (Part; isolated regression Hazard)
        └── Coins (Folder; empty after migration)
```

### 4.1. Collision conventions

- Видимая поверхность и gameplay hitbox разделяются только там, где это действительно нужно: water, sand, moving NPCs и laser.
- Visual-only Parts: `CanTouch=false`; `CanQuery=false`, если raycast/overlap им не нужен; collision задаётся по traversal-задаче.
- Hazard hitboxes: `CanTouch=true`, `CanQuery=true`; видимость может быть отключена после gameplay validation.
- Movement path markers: `Anchored=true`, `CanCollide=false`, `CanTouch=false`, `CanQuery=false`, `Transparency=1` после настройки.
- Ни один world Part не содержит `Script`, `LocalScript` или `ModuleScript`.

### 4.2. Жизненный цикл `VerticalSlice`

1. В Phase 2.1–2.7 новый `World` строится рядом; `VerticalSlice` не удаляется и остаётся стабильным regression fixture.
2. До migration новые tagged objects размещаются так, чтобы обычный spawn не мог случайно активировать их. Проверки новых сцен выполняются контролируемым Play-телепортом.
3. В Phase 2.8 принятые `StartSpawn`, triggers и `DemoCoin` переносятся в итоговые пути по таблице ниже; bootstrap переключается на перенесённый `StartSpawn`.
4. После migration оставшийся shell `VerticalSlice` с техническим `KillBlock` физически изолируется от игрового маршрута, но сохраняется до полного regression Phase 2.10–2.12. Вторых активных `StartSpawn`, `StartLine`, checkpoint ID, coin ID или `FinishLine` в нём не остаётся.
5. Удаление `VerticalSlice` разрешается только **после** Phase 2.12, полного regression, сохранённого place и нового acceptance tag. Само удаление выполняется отдельной явно утверждённой cleanup-задачей и отдельным коммитом.

Такой порядок не лишает проект принятой точки сравнения до доказанной работоспособности нового мира.

## 5. Mapping существующих объектов

| Объект | Будущая роль | Действие | Сохранение contract |
|---|---|---|---|
| `StartSpawn` | Первый spawn и checkpoint сцены 1 | Перенести в `World.Scene01_HotBeach.Start`, сохранить имя | `CheckpointId="Start"`, order `1`, `RespawnOffset=(0,4,0)`, tag `Checkpoint` |
| `StartLine` | Единственный запуск забега | Перенести в `Scene01_HotBeach.Start`, визуально заменить под пляжную линию | Tag `RunStart`, без gameplay attributes |
| `MidCheckpoint` | Checkpoint на границе сцены 1 и воды | Перенести, переименовать в `WaterStartCheckpoint`, обновить ID; не клонировать как второй активный checkpoint | `CheckpointId="WaterStart"`, order `2`, offset `(0,4,0)` |
| `KillBlock` | Технический regression hazard | Оставить в `VerticalSlice` до acceptance; его свойства использовать как шаблон hitbox, но не ставить в финальный маршрут | Tag `Hazard`; финальные hazards используют тот же tag |
| `DemoCoin` | Демонстрационная монета стартовой зоны, входит в счёт | Перенести в `Scene01_HotBeach.Start`; визуально заменить, но сохранить ID | Tag `Coin`, `CoinId="DemoCoin"` |
| `FinishLine` | Finish на вершине пальмы | Перенести в `Scene04_PalmFinish.Triggers`, визуально заменить; required order изменить с `2` на `4` | Tag `Finish`, единственный gameplay attribute `RequiredCheckpointOrder=4` |
| `BeachObbyHUD` | Технический timer/coin HUD всего MVP-мира | Оставить в `StarterGui` без clone и без новой панели | Существующий client snapshot contract; финальный художественный UI вне Phase 2 |

В Phase 2.8 должны быть автоматические проверки ровно одного активного `StartSpawn`, `StartLine` и `FinishLine` в игровом `World`. Старые активные копии не оставляются рядом с маршрутом.

## 6. Greybox-first стратегия

Каждая сцена проходит четыре последовательных gate. Переход к следующему gate допустим только после чистого Output и принятого результата предыдущего.

### 6.1. Greybox

- простые Parts, Models и при необходимости Terrain;
- реальный масштаб аватара;
- прыжковые расстояния и посадочные зоны;
- однозначный маршрут и видимость следующей цели;
- checkpoint boundary;
- hazard hitboxes;
- все запланированные coins;
- отсутствие декоративных assets и тяжёлых VFX.

### 6.2. Gameplay validation

- desktop traversal обычным управлением;
- mobile traversal с touch controls;
- death/respawn до и после checkpoint;
- repeated touch/idempotency;
- два независимых игрока;
- сквозной маршрут без developer assistance;
- контроль целевой длительности 3–6 минут для первого успешного прохождения.

### 6.3. Art pass

- яркие материалы и простые формы по `image01`–`image04`;
- шезлонги, круги, остров, шар, пальма и читаемая граница моря/леса;
- декоративные модели без изменения gameplay hitboxes;
- освещение, локальные VFX и звук только после сохранения gameplay scale;
- `image05`–`image08` не используются.

### 6.4. Optimization

- объединение повторяющейся декоративной geometry там, где это не ухудшает collision;
- аудит количества Parts/MeshParts;
- отключение ненужных `CanCollide`, `CanTouch`, `CanQuery` и shadows;
- server motion только для gameplay hitboxes, decorative motion преимущественно client-side;
- проверка streaming compatibility;
- повторная mobile performance и safe-area проверка.

## 7. Новые runtime-компоненты

### 7.1. Обязательные компоненты

| Source path | Side | Ответственность | Почему существующего router недостаточно | Тестирование |
|---|---|---|---|---|
| `ServerScriptService/Config/WorldConfig.luau` | Server config | Стабильные world paths, checkpoint/coin IDs, список moving assemblies, их path markers и циклы | `RunConfig` описывает общий protocol, но не composition конкретного мира | frozen tables, уникальные IDs, корректные paths, допустимые durations |
| `ServerScriptService/Services/MovingHazardService.luau` | Server | Предсказуемо и циклично перемещать stick figures и sharks между marker points; idempotent `Start/Destroy` | `WorldTriggerService` реагирует на контакт, но не создаёт движение | unit interpolation/config tests, duplicate-start/cleanup tests, Studio path and death integration |
| `ServerScriptService/Services/RotatingHazardService.luau` | Server | Вращать одну `LaserAssembly` вокруг фиксированного pivot с серверно известной фазой | Router не управляет CFrame/Pivot и скоростью препятствия | deterministic angle tests, one-bar contract, idempotent lifecycle, Studio touch reliability |

`MovingHazardService` является общим для stick figures и sharks. Отдельный `SharkMovementController` не нужен: различия задаются конфигурацией и visual model, а не вторым алгоритмом.

`RotatingHazardService` отделён от линейного движения, потому что его invariant — вращение assembly вокруг фиксированного центра, а не интерполяция между двумя точками. Объединение этих разных lifecycle в универсальный «двигатель всего» усложнило бы тесты.

### 7.2. Что не создаётся

- Новые RemoteEvents/RemoteFunctions — не нужны.
- Отдельные scripts внутри hazards — запрещены.
- Отдельный `SharkMovementController` — дублировал бы линейное movement.
- Декоративный client controller — не нужен для greybox. В Phase 2.9 он допустим только при конкретном VFX, который нельзя выполнить статически; до появления такой потребности файл не создаётся.
- Отдельный `CheckpointService`, `CoinService` или `FinishService` — уже покрыто `GameSessionService`.

### 7.3. Server authority и движение

- Gameplay hitboxes двигаются сервером и остаются tagged `Hazard`.
- Клиент не передаёт позицию hazards, время цикла или факт попадания.
- Visual model следует server-owned hitbox или получает только декоративную локальную интерполяцию без изменения collision.
- Свободная физика и client network ownership не используются как источник движения.
- Для laser сначала проверяется `Touched` на целевой скорости 5–7 секунд за оборот. Если Studio integration докажет пропуски контакта, один общий server overlap path добавляется в существующий hazard routing; kill logic не копируется в rotating service.

## 8. Checkpoint plan

Граница между сценами одновременно является концом предыдущей сцены и безопасным началом следующей. Рекомендуется следующий locked порядок:

| CheckpointId | CheckpointOrder | Сцена | Расположение | RespawnOffset | Критерий активации |
|---|---:|---|---|---|---|
| `Start` | 1 | Сцена 1 | Безопасная стартовая площадка перед `StartLine` и первым шезлонгом | `Vector3.new(0, 4, 0)` | Начальная session; повторный touch ничего не меняет |
| `WaterStart` | 2 | Граница 1 → 2 | Безопасная площадка после горячего пляжа, перед первым кругом | `Vector3.new(0, 4, 0)` | Только Running и текущий order ровно `1` |
| `LaserIslandStart` | 3 | Граница 2 → 3 | Входная безопасная зона круглого острова после последнего круга | `Vector3.new(0, 4, 0)` | Только Running и текущий order ровно `2` |
| `PalmBase` | 4 | Граница 3 → 4 | У основания пальмы до первой ступени | `Vector3.new(0, 4, 0)` | Только Running и текущий order ровно `3` |

`FinishLine.RequiredCheckpointOrder = 4`.

Текущий `ReachCheckpoint` принимает любой order больше текущего и напрямую не проверяет tag `Checkpoint`. Для полного мира этого недостаточно: в Phase 2.8 preconditions меняются на наличие tag `Checkpoint` и **ровно `currentCheckpointOrder + 1`**. Это server-side закрывает пропуск сцен; геометрическая недоступность не считается защитой. DataStore migration не требуется, потому что сохранённых run/checkpoint данных нет.

## 9. Coin plan

Используется нижняя граница утверждённого диапазона — **16 необязательных coins**: демонстрационная монета плюс 15 монет сцен. Все IDs уникальны, стабильны и не меняются при art replacement.

| CoinId | Сцена | Приблизительное место | Сложность | Видна с основного маршрута |
|---|---|---|---|---|
| `DemoCoin` | Старт | Между spawn и первым препятствием, без блокировки StartLine | Низкая | Да |
| `HotBeachCoin01` | Горячий пляж | Над ранним широким шезлонгом | Низкая | Да |
| `HotBeachCoin02` | Горячий пляж | Над средней безопасной линией | Низкая | Да |
| `HotBeachCoin03` | Горячий пляж | Над боковым шезлонгом с более точным прыжком | Средняя | Да |
| `WaterCoin01` | Вода | Над первым крупным кругом | Низкая | Да |
| `WaterCoin02` | Вода | Над центральным кругом основного пути | Низкая | Да |
| `WaterCoin03` | Вода | Между двумя близкими кругами | Средняя | Да |
| `WaterCoin04` | Вода | На боковом, но предсказуемом ответвлении | Средняя | Да |
| `LaserIslandCoin01` | Лазерный остров | Периметр у входа | Низкая | Да |
| `LaserIslandCoin02` | Лазерный остров | Периметр, первая четверть | Средняя | Да |
| `LaserIslandCoin03` | Лазерный остров | Периметр напротив входа | Средняя | Да |
| `LaserIslandCoin04` | Лазерный остров | Периметр, третья четверть | Средняя | Да |
| `LaserIslandCoin05` | Лазерный остров | Периметр у выхода | Низкая | Да |
| `PalmCoin01` | Пальма | Нижняя часть лестницы | Низкая | Да |
| `PalmCoin02` | Пальма | Средняя часть лестницы | Средняя | Да |
| `PalmCoin03` | Пальма | Верхняя часть перед summit | Средняя | Да |

Монеты не дают награду, не блокируют finish и не сохраняются между sessions. Server-owned coin Instances не уничтожаются и не скрываются глобально; существующий `CoinVisualController` продолжает per-player local hiding.

## 10. Этапы реализации

Общее правило каждого этапа: маленькое изменение → Script Sync/Studio inspection → автоматические тесты → targeted Play → Output audit → ручной `Save to File`, если менялся place → отдельный коммит. Начало следующего этапа требует принятия предыдущего.

### Phase 2.1 — структура `World` и общий маршрут

- **Цель:** создать контейнеры четырёх сцен и непрерывный spatial layout без gameplay migration.
- **Instances:** `World`, четыре scene Models, `SharedEnvironment`, пустые функциональные folders, greybox entry/exit platforms и общая fall boundary без активного tag до проверки.
- **Luau:** создать `ServerScriptService/Config/WorldConfig.luau` только с frozen names/paths; production bootstrap пока не переключать.
- **Переиспользование:** текущие services/remotes/HUD без изменения.
- **Новая механика:** отсутствует.
- **Автотесты:** `WorldConfigSpec` на frozen config, уникальные scene names и ожидаемые root paths.
- **Интеграция:** Studio tree, отсутствие случайных tags, видимость следующей сцены, отсутствие пересечений с `VerticalSlice`.
- **Приёмка:** путь от сцены 1 до сцены 4 физически однозначен; production vertical slice проходит 124 старых теста.
- **Save to File:** да, вручную после проверки.
- **Коммит:** `Add MVP world hierarchy and route layout`.

### Phase 2.2 — greybox горячего пляжа

- **Цель:** получить mobile-проходимый маршрут по шезлонгам над hot sand.
- **Instances:** `HotSandVisual`, `HotSandHazard`, `Loungers`, `EndPlatform`, placeholders `Runner01…Runner03`, path markers, позиции четырёх scene-1 coins включая будущую позицию `DemoCoin`; финальные tags добавляются только проверенным hitboxes.
- **Luau:** дополнить `WorldConfig`; movement ещё не запускать.
- **Переиспользование:** `Hazard`, `Coin`, `Checkpoint` contracts и `WorldTriggerService`.
- **Новая механика:** отсутствует; placeholders неподвижны.
- **Автотесты:** world contract для hot sand/hitbox type, отсутствие scripts в Parts, уникальность подготовленных CoinId.
- **Интеграция:** прыжки desktop/mobile, смерть от sand, безопасный landing, отсутствие случайного WaterStart touch.
- **Приёмка:** маршрут можно пройти обычными прыжками; песок надёжно убивает; боковой coin остаётся необязательным.
- **Save to File:** да.
- **Коммит:** `Build hot beach greybox`.

### Phase 2.3 — stick-figure moving hazards

- **Цель:** добавить 2–3 предсказуемых циклических hazards сцены 1.
- **Instances:** `Runner01…Runner03`, `Visual`, `Hitbox`, пары path markers.
- **Luau:** создать `MovingHazardService.luau`, его spec и bootstrap initialization; дополнить `WorldConfig` entries.
- **Переиспользование:** `WorldTriggerService` убивает по tag `Hazard`; `GameSessionService` не меняется.
- **Новая механика:** server-owned linear ping-pong movement.
- **Автотесты:** interpolation endpoints, cycle repeat, invalid config, idempotent `Start`, `Destroy` cleanup, отсутствие state transition от hazard.
- **Интеграция:** contact любой частью character, повторные touches, death/respawn, движение двух hazards без drift.
- **Приёмка:** безопасный интервал читаем; движение не зависит от client; timer/checkpoint переживают смерть.
- **Save to File:** да — меняются Models/path markers и service Instance через sync.
- **Коммит:** `Add deterministic beach moving hazards`.

### Phase 2.4 — greybox воды и кругов

- **Цель:** построить основной путь по кругам до острова.
- **Instances:** `WaterSurface`, `WaterKillPlane`, `EntryPlatform`, `Rings`, позиции `WaterCoin01…04`, `LaserIslandStartCheckpoint`.
- **Luau:** дополнить `WorldConfig`; новых services нет.
- **Переиспользование:** hazard, checkpoint и coin transitions.
- **Новая механика:** отсутствует.
- **Автотесты:** world contract для ring path, checkpoint order/ID, CoinId uniqueness, no scripts in world Parts.
- **Интеграция:** desktop/mobile traversal, water death, respawn at `WaterStart`, reach order 3 only after order 2.
- **Приёмка:** основной путь всегда проходим обычным прыжком; вода не создаёт безопасных дыр.
- **Save to File:** да.
- **Коммит:** `Build inflatable ring crossing greybox`.

### Phase 2.5 — sharks и water hazards

- **Цель:** добавить акул как читаемую движущуюся контактную угрозу без отдельной death logic.
- **Instances:** `Shark01…N`, visual/hitbox и path markers; количество фиксируется минимальным, достаточным для читаемой угрозы.
- **Luau:** только конфигурация `MovingHazardService`; отдельный shark controller не создавать.
- **Переиспользование:** `MovingHazardService`, `WorldTriggerService`, `Hazard`.
- **Новая механика:** отсутствует — новый consumer общего movement.
- **Автотесты:** shark entries используют общий schema; invalid/missing path ignored safely; no duplicate connections.
- **Интеграция:** shark kills only touching player, water remains functional, respawn and timer stable, two clients see authoritative motion.
- **Приёмка:** акулы не блокируют единственный путь постоянно и не толкают игрока непредсказуемой физикой.
- **Save to File:** да.
- **Коммит:** `Add shared shark movement hazards`.

### Phase 2.6 — круглый остров и вращающийся laser

- **Цель:** построить сцену 3 и одну серверно управляемую laser bar.
- **Instances:** `IslandBase`, `CenterSphere`, entry/exit, `LaserAssembly/LaserBar`, пять coins, позиция `PalmBaseCheckpoint`.
- **Luau:** создать `RotatingHazardService.luau`, spec и bootstrap initialization; laser config в `WorldConfig`.
- **Переиспользование:** `WorldTriggerService` для `Hazard`, существующие coin/checkpoint contracts.
- **Новая механика:** server-side rotation around fixed pivot; один оборот настраивается внутри утверждённого диапазона 5–7 секунд.
- **Автотесты:** deterministic angle, fixed pivot, one assembly/one bar, opposite ends, idempotent lifecycle, invalid instance safety.
- **Интеграция:** repeated contact, missed-touch stress at target speed, desktop/mobile timing, death/respawn, two-client consistency.
- **Приёмка:** одна bar визуально образует два противоположных луча; безопасные окна понятны; все coins необязательны.
- **Save to File:** да.
- **Коммит:** `Add rotating laser island greybox`.

### Phase 2.7 — пальма и спиральная лестница

- **Цель:** создать mobile-проходимый финальный подъём без migration finish.
- **Instances:** `PalmTree`, `SpiralSteps`, `SummitPlatform`, `PalmFallCatch`, три coin positions, placeholder finish position.
- **Luau:** дополнить `WorldConfig`; новый movement code не нужен.
- **Переиспользование:** `Hazard` и current checkpoint placement.
- **Новая механика:** отсутствует.
- **Автотесты:** steps and fall catch contract, no scripts in world Parts, PalmBase path declared.
- **Интеграция:** полный подъём desktop/mobile, намеренное падение на разных высотах, отсутствие случайного finish.
- **Приёмка:** подъём занимает целевые 20–40 секунд после настройки; падение всегда возвращает к основанию после migration.
- **Save to File:** да.
- **Коммит:** `Build giant palm finish climb greybox`.

### Phase 2.8 — migration checkpoints, coins и finish

- **Цель:** переключить production run с `VerticalSlice` на `World`.
- **Instances:** перенести `StartSpawn`, `StartLine`, `DemoCoin`, `MidCheckpoint` и `FinishLine`; создать orders 3–4 и остальные 15 coins; добавить финальные tags/attributes; изолировать остаток `VerticalSlice`.
- **Luau:** обновить bootstrap initial checkpoint path; изменить `ReachCheckpoint` на tagged exact-next order; расширить `WorldConfig`; добавить `WorldContractSpec` и checkpoint sequence tests.
- **Переиспользование:** все текущие run transitions, remotes, controllers и HUD.
- **Новая механика:** только строгая последовательность checkpoint `current + 1`; остальные изменения — composition/migration.
- **Автотесты:** сохранить 124; reject order skip, orders 1–4, unique CheckpointId/CoinId, finish required order 4, exactly one active start/finish, snapshots unchanged.
- **Интеграция:** полный route с/без coins, deaths in every scene, repeated triggers, finish freeze, old vertical slice inaccessible.
- **Приёмка:** bootstrap не ссылается на `VerticalSlice`; full route заканчивается только после `PalmBase`; 16 coins доступны per player.
- **Save to File:** обязательно, вручную, с проверкой размера/time/hash.
- **Коммит:** `Migrate run progression to the MVP world`.

### Phase 2.9 — визуальный проход

- **Цель:** заменить greybox visuals, не меняя validated hitboxes и route scale.
- **Instances:** материалы/цвета/visual Models сцен, освещение, ограниченные VFX/SFX; gameplay hitboxes остаются отдельными.
- **Luau:** новые файлы не планируются. Client-only visual controller добавляется только при конкретной подтверждённой VFX-задаче.
- **Переиспользование:** все gameplay services без изменения.
- **Новая механика:** отсутствует.
- **Автотесты:** world contracts и 124+ regression; no scripts in world Parts; gameplay CFrames/hitbox sizes audit against approved greybox.
- **Интеграция:** visual readability, route visibility, no collision changes, desktop/mobile screenshots, Output.
- **Приёмка:** визуальный тон соответствует `image01`–`image04`; excluded sketches не попали в мир; gameplay unchanged.
- **Save to File:** да.
- **Коммит:** `Apply Beach Obby MVP world art pass`.

### Phase 2.10 — desktop/mobile/multiplayer regression

- **Цель:** доказать полный игровой цикл после migration и art pass без добавления функций.
- **Instances/Luau:** не создавать и не менять; временные runtime probes уничтожать до Stop.
- **Переиспользование:** весь production stack.
- **Новая механика:** отсутствует.
- **Автотесты:** полный suite с 124 прежними и всеми Phase 2 specs, 0 failed.
- **Интеграция:** Windows; выбранный современный phone preset; `Server + 2 Clients`; route with/without coins; death at every checkpoint; client trust; clean Output.
- **Приёмка:** каждый run независим; HUD не обрезан; route доступен touch controls; временные objects отсутствуют.
- **Save to File:** нет, если проверка ничего не меняла.
- **Коммит:** документационный QA-коммит `Document MVP world regression results`.

### Phase 2.11 — performance pass

- **Цель:** устранить измеренные bottlenecks, не менять gameplay difficulty.
- **Instances:** только подтверждённые оптимизации geometry, collision, queries, shadows и decorative effects.
- **Luau:** оптимизация movement update только по profiler evidence; никаких новых systems по предположению.
- **Переиспользование:** movement services и world config.
- **Новая механика:** отсутствует.
- **Автотесты:** весь suite; lifecycle/cleanup tests movement services.
- **Интеграция:** одинаковый mobile preset до/после, FPS/memory comparison, two-client server load, streaming compatibility audit.
- **Приёмка:** нет regression traversal/touch; улучшение или отсутствие ухудшения подтверждено измерением.
- **Save to File:** да, если менялись Instances/Lighting/Workspace properties; иначе не требуется.
- **Коммит:** `Optimize MVP world runtime performance`.

### Phase 2.12 — финальный MVP-world acceptance

- **Цель:** финально принять world phase и зафиксировать новую стабильную точку.
- **Instances/Luau:** никаких feature changes; только необходимые исправления отдельными предшествующими коммитами.
- **Переиспользование:** весь production stack и QA matrix.
- **Новая механика:** отсутствует.
- **Автотесты:** все 124 старых плюс новые Phase 2 tests, 0 failed.
- **Интеграция:** полный route, deaths, 16 coins optional, finish, desktop/mobile, `Server + 2 Clients`, Output clean.
- **Приёмка:** выполнен Definition of Done из раздела 15; place сохранён; Git clean.
- **Save to File:** финальное ручное сохранение и проверка hash, если с последнего сохранения были правки Studio.
- **Коммит:** `Document Beach Obby MVP world acceptance`; затем отдельный annotated acceptance tag по явной команде владельца.

`VerticalSlice` становится кандидатом на удаление только после успешного Phase 2.12 и acceptance tag. Cleanup не смешивается с acceptance-коммитом.

## 11. Тестовая стратегия

### 11.1. Существующая база

- Все существующие 124 теста сохраняются без ослабления.
- Их число может только расти; acceptance требует `0 failed`.
- Автотесты продолжают запускаться только в Studio при `RunAutomatedTests=true`.

### 11.2. Unit tests

- `WorldConfig` frozen, names/paths корректны.
- Уникальность всех `CoinId` и `CheckpointId`.
- Checkpoint orders равны `1, 2, 3, 4` без gaps/duplicates.
- `ReachCheckpoint` отклоняет untagged checkpoint и skip `1 → 3`/`1 → 4`.
- `FinishLine.RequiredCheckpointOrder` равен последнему checkpoint order.
- `MovingHazardService`: endpoints, ping-pong cycle, phase, invalid config, idempotent `Start`, cleanup.
- Shark и stick figure используют общий movement schema.
- `RotatingHazardService`: fixed pivot, direction, period, exact one-bar assembly, idempotent lifecycle.
- Движение hazards не меняет session phase/revision/timer/checkpoint/coins.

### 11.3. Automated Studio integration

- Все declared instance paths существуют и имеют точный ClassName.
- Все required tags/attributes присутствуют; лишние gameplay attributes отсутствуют.
- Нет world Parts с вложенными scripts.
- Нет одного Instance с несовместимыми gameplay tags.
- Нет duplicate stable IDs.
- Ровно один active `StartSpawn`, `StartLine` и `FinishLine` в финальном world.
- Tagged hazards kill; moving/rotating hazards сохраняют contact reliability.
- Bootstrap использует world `StartSpawn`, а не regression fixture.
- Полный checkpoint order и finish gate проходят server-side.

### 11.4. Ручной desktop

- Полный route с монетами и без них.
- Death/respawn в каждой сцене.
- Повторные touches и post-finish triggers.
- Читаемость movement timing и следующей цели.
- HUD, camera и controls.
- Output без errors/warnings.

### 11.5. Ручной mobile

- Один стабильный современный phone preset, зафиксированный в QA-отчёте.
- Все прыжки и спиральная лестница проходят touch controls.
- Safe area, читаемость HUD и отсутствие duplicate UI.
- Moving hazards оставляют понятное безопасное окно.
- FPS/memory фиксируются одинаковым способом после каждой сцены.

### 11.6. Ручной `Server + Clients`, два игрока

- Разные checkpoint orders и respawn positions.
- Одинаковую world coin каждый игрок собирает независимо.
- Hazard убивает только коснувшегося.
- Finish одного игрока не завершает второго.
- Moving hazards имеют согласованную server-owned позицию.
- HUD каждого клиента отражает только его snapshot.

### 11.7. Traceability

| Requirement | Design | Основное evidence |
|---|---|---|
| Горячий пляж | Scene01, hot sand, loungers, runners | Phase 2.2–2.3 mobile/desktop traversal |
| Вода | Scene02, rings, water, sharks | Phase 2.4–2.5 traversal/death |
| Laser island | Scene03, one LaserBar | Rotation unit + contact integration |
| Palm finish | Scene04, spiral, PalmBase, FinishLine | Fall/respawn + finish freeze |
| Последовательность | orders 1–4, exact-next rule | unit skip rejection + full route |
| Coins | 16 stable IDs | uniqueness scan + two clients |
| Player isolation | существующий per-Player state | Server + 2 Clients acceptance |

## 12. Performance budget

Абсолютные FPS/part/memory лимиты без baseline не фиксируются. Используется измеримый консервативный процесс:

1. В Phase 2.1 выбрать один современный phone Device Emulator preset и применять его неизменно до acceptance.
2. До добавления первой сцены снять baseline FPS и memory в Edit/Play одинаковым маршрутом.
3. После каждой сцены записывать изменение FPS, client memory и server activity; сравнивать с предыдущим этапом, а не с выдуманной цифрой.
4. Минимизировать физически moving Parts: один server hitbox на moving hazard assembly, visual children следуют ему.
5. Использовать anchored deterministic motion; не строить gameplay на свободной физике.
6. Отключать `CanTouch` и `CanQuery` у decorative Parts, которым они не нужны.
7. Отключать `CastShadow` у мелких повторяющихся decorations, если shadow не помогает читаемости.
8. Выполнять decorative VFX преимущественно на клиенте; collision и hit detection остаются серверными.
9. Переиспользовать lounge/ring/palm assets и материалы вместо уникальной тяжёлой копии каждого элемента.
10. После полного greybox оценить фактическую пользу `Workspace.StreamingEnabled`: проверить spawn, remote scene visibility, checkpoint respawn и moving hazards при streaming. В рамках документа `StreamingEnabled` не меняется.

## 13. Риски и снижение

| Риск | Последствие | Снижение |
|---|---|---|
| Moving hazards и network ownership | Разная позиция или нечестное попадание на клиентах | Anchored server motion, client не сообщает hit, two-client observation |
| Вращающийся laser и нестабильный `Touched` | Игрок проходит сквозь bar или умирает без контакта | Широкий единый hitbox, target speed 5–7 s, stress integration; общий overlap path только по доказанной необходимости |
| Shark collision | Толчки, застревание, случайная блокировка колец | Non-colliding visual/hitbox, server motion, пути вне landing centers, water route всегда имеет окно |
| Сложная spiral staircase на mobile | Невозможный подъём/падения камеры | Greybox mobile gate до art, широкие steps/landing zones, 20–40 s target |
| Падение между сценами | Character зависает вместо смерти | `GlobalFallCatch` и scene-specific kill planes без gaps |
| Случайный следующий checkpoint | Пропуск сцены | Exact-next server rule, spatial separation, checkpoint contract tests |
| Слишком много Parts | Mobile FPS/memory regression | Reuse, grouped visuals, measurement after each scene, scene-analysis/perf pass |
| Regression vertical slice | Потеря принятого behavior | Stable tag, 124 tests, сохранить fixture до Phase 2.12, migration отдельным этапом |
| Desktop/mobile differences | Разная сложность прыжков и UI | Одинаковый mobile preset на каждом greybox gate, отдельная desktop/mobile acceptance |
| Multiplayer timing | State/HUD одного игрока влияет на другого | Server-owned per-Player state, targeted `FireClient`, `Server + 2 Clients` tests |
| Bootstrap hardcoded на `VerticalSlice` | Новый spawn не становится default checkpoint | Явная migration правка и automated path assertion в Phase 2.8 |
| Duplicate IDs/tags после migration | Coin/checkpoint засчитывается неверно | World contract scan, один active start/finish, unique stable IDs |
| Art pass меняет collision | Ранее проходимый route ломается | Visual/hitbox separation, CFrame/size audit, повторный traversal после каждой scene replacement |

## 14. Решения и блокирующие вопросы

### 14.1. Принятые решения

1. Новый `World` строится параллельно принятому `VerticalSlice`; раннего удаления нет.
2. Финальный маршрут содержит четыре checkpoint orders: `Start=1`, `WaterStart=2`, `LaserIslandStart=3`, `PalmBase=4`.
3. Finish требует order `4`.
4. `ReachCheckpoint` становится exact-next, потому что текущая проверка «любой больший order» не защищает от пропуска сцены.
5. Используется 16 coins — нижняя граница утверждённого MVP-диапазона; `DemoCoin` сохраняет ID.
6. Stick figures и sharks используют один `MovingHazardService`.
7. Laser использует отдельный `RotatingHazardService` и одну длинную bar.
8. Все последствия hazard остаются в общем server routing; movement services не меняют session state.
9. Новые remotes не создаются.
10. Финальный художественный UI, DataStore и leaderboards не входят в world phase.
11. `image05`–`image08` не используются.
12. Внешние marketplace assets не нужны для прохождения: greybox и базовый art pass должны оставаться воспроизводимыми из контролируемых assets/primitives.

### 14.2. Действительно блокирующие вопросы

**Нет.** Требования, composition, checkpoint order, coin count, migration boundary и runtime ownership выводятся из утверждённых документов и текущей архитектуры. Любые tuning-значения расстояний, скорости stick figures/sharks и количество повторяющихся декоративных Parts определяются измерением на greybox gate и не блокируют начало Phase 2.1.

## 15. Definition of Done

Beach Obby MVP-world готов только когда:

- все четыре сцены последовательно проходимы;
- полный успешный маршрут укладывается в целевые 3–6 минут для нового игрока после tuning;
- timer переживает все смерти;
- checkpoints активируются строго по порядку;
- падение с пальмы возвращает к `PalmBase`;
- 16 optional coins работают независимо для игроков;
- все hazards server-authoritative;
- finish требует последний checkpoint и замораживает время;
- два игрока имеют независимые забеги;
- desktop и mobile проверки пройдены;
- все 124 прежних и все новые автоматические тесты проходят с `0 failed`;
- Output не содержит errors или новых warnings;
- временные Runtime/malformed objects отсутствуют;
- place сохранён и его hash зафиксирован;
- Git working tree чист, кроме заранее ожидаемых локальных файлов;
- QA-результат документирован;
- по отдельной явной команде создан новый annotated acceptance tag.

## 16. Validation gate

| Область | Статус | Evidence |
|---|---|---|
| Foundation | Complete | Repo, Script Sync roots, QA baseline, Studio Edit tree и target devices проверены |
| Requirements | Complete | Четыре сцены, in/out scope, lifecycle и measurable acceptance определены |
| System Design | Complete | Workspace tree, migration, files, ownership, tags, IDs и movement lifecycle перечислены |
| Connections | Complete | Existing services/remotes, CollectionService, RunService, Workspace и Players определены; persistence `n/a` |
| Tests | Complete | Unit, Studio integration, desktop, mobile и two-client strategy связаны с requirements |

Load-bearing решения — server state, exact checkpoint order, server motion, единый hazard routing и delayed removal `VerticalSlice` — проверяются минимум unit contract, одиночным Play и multiplayer regression.

**Pre-development complete.** Реализация Phase 2.1 не начинается без явного утверждения этого плана.

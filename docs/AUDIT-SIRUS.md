# Технический аудит Gladdy для Sirus — 2.40

## A. Краткое резюме

Исследован именно `AmonRay/Gladdy-sirus`, не ElvUI и не FrameXML патча. Подтверждены горячие выделения памяти при рассылке сообщений и обновлении аур, неограниченные повторы чтения здоровья, лишний опрос питомцев, работа таймеров отключённых модулей, скрытие ошибок обработчика событий и простаивающие кастбары.

Исправления выполнены небольшими логическими этапами: диспетчер; ауры/combat log; жизненный цикл/питомцы; таймеры UI; библиотеки. Формат GladdyXZ, имена настроек и публичные сообщения модулей сохранены. Отдельным коммитом удалены нарративные комментарии собственного Lua-кода. Не выполнялись полная перепись, перенос кода ElvUI/WeakAuras в модули Gladdy или замена DR/CD на предполагаемые серверные значения.

Проверки вне клиента подтверждают логику и Lua 5.1, но не визуальную корректность, фактический FPS, защищённые действия в бою или баланс реалма. Открытые вопросы перечислены ниже; они не выдаются за исправленные.

## B. Изученная реализация

- Репозиторий: https://github.com/AmonRay/Gladdy-sirus.
- База аудита: `master`, `bf981e2a7cec57de5ffc32459728f2335a06bb37`, Gladdy 2.39, Interface 30300. Перед аудитом успешно слит PR #1; его изменения не пересчитаны как новые исправления аудита.
- До предыдущей адаптации доступный исходный commit: `0020d1dc08337eb78013dcb0b317dbadc596c35c`, «fix spec detect», 2025-12-25. Это уже адаптация Sirus с таблицами созвездий, не чистый upstream. Полная история upstream не восстанавливалась: целевой исходник предоставлен пользователем и однозначно установлен.
- Чистая рабочая ветка создана от обновлённого master в отдельном worktree; прежняя рабочая копия и её незакоммиченные файлы сохранены. Изменения не смешивались с чужими и не отправлялись через force-push.
- 31 собственный Lua-файл. TOC загружает 29 Lua-файлов: 9 основных и 20 модулей. `EventListener` также регистрируется как модуль. `Announcements.lua` и `ArenaCountDown.lua` присутствуют, но закомментированы в TOC; их обработчики не являются текущей нагрузкой выполнения.
- `embeds.xml` загружает LibStub, CallbackHandler, AceDB/DBOptions/GUI/Config/Comm/Timer/Hook/Serializer, LibDeflate, SharedMedia/Widgets, DRList, LibClassAuras, SpellRange и LibCustomGlow. Точные решения по обновлению: [LIBRARIES.md](LIBRARIES.md).
- ElvUI использован для проверки формата combat log, API созвездий и совместимой AceTimer. FrameXML патча — для контрактов C_Unit, CombatLogFix и CompactArenaFrame. WeakAuras-Sirus — для сравнения библиотек и двух выбранных замен. Проблемы их собственных модулей не приписываются Gladdy.

## C. Карта архитектуры

### Загрузка и жизненный цикл

`Gladdy.toc → embeds.xml → Gladdy.lua → Lang → Util/Frame/Options → Constants_shared/Constants_Wrath → ImportStrings → модули → EventListener`.

`PLAYER_LOGIN → OnInitialize → AceDB(GladdyXZ) → локализация/настройки → Initialize модулей → OnEnable`.

`UPDATE_BATTLEFIELD_STATUS → curBracket → JoinedArena → CreateButton/UpdateFrame → JOINED_ARENA`.

`ARENA_OPPONENT_UPDATE/UNIT_* → SpotEnemy/guids → ENEMY_SPOTTED, UNIT_SPEC, AURA_*, TRINKET_USED, RACIAL_USED → обработчики модулей → UI`.

`Reset → Reset модулей → ResetUnit/ResetButton → очистка GUID/аур/состояния, отмена pollers, восстановление штатных фреймов`. В бою показ откладывается через `PLAYER_REGEN_ENABLED`; вопрос создания secure-фреймов до проверки lockdown оставлен в реестре.

| Подсистема | Входы и связи | Стоимость/жизненный цикл |
| --- | --- | --- |
| Gladdy.lua | Реестр модулей, приоритеты, SendMessage, arena lifecycle | Раньше сортировка при каждой рассылке; теперь порядок кэширован, подписки читаются актуальные |
| Frame.lua / Clicks | Создание кнопок, secure attributes, layout, movers | До 5 кнопок, переиспользуются; UpdateFrame пересчитывает весь layout в основном по настройкам/входу, не каждому combat log |
| EventListener | CLEU, UNIT_AURA, касты, ARENA_OPPONENT_UPDATE | Центральные GUID, spec, aura scans; главные горячие пути |
| Healthbar / Powerbar | UNIT_HEALTH/MAXHEALTH/NAME, события ресурсов, сообщения смерти/spec | Событийное обновление, теперь ограниченный retry только недоступного max health |
| Pets | UNIT_PET, PET_SPOTTED/DESTROYED/STEALTH, polling | Пулы фреймов по arena pet; общий callback 10 Гц с изменением UI только при новых health/max |
| Auras / BuffsDebuffs | AURA_FADE, GAIN, LIMIT; interrupt messages | Приоритетная аура + прерывание; списки иконок переиспользуются; active countdowns всё ещё вызываются покадрово |
| Cooldowns | cast/aura/spec messages, таблицы классов/CD | Иконки из iconCache; создание/позиционирование при изменении состава, OnUpdate активных CD |
| Racial / Trinket | Созвездия, события использования и shared CD | Отдельные иконки/состояние, общая CreateIconFrame |
| Diminishings | CLEU aura applied/refresh/removed → DRList | 16 скрываемых иконок на unit; таймеры активных категорий; таблицы wotlk |
| Castbar | Unit cast/channel events, CAST_START | Плавное покадровое движение сохранено; idle OnUpdate теперь снят |
| Range Check / Combat Indicator | Repeat timer 0.05 с / OnUpdate с интервалом 0.05 с | Polling сохранён для legacy API; отключение модуля теперь прекращает работу |
| Highlight / Classicon | Смена target/focus; ENEMY_SPOTTED/UNIT_SPEC | Target/focus обход максимум 5 unit; не заменялся сложным кэшем ради микроэкономии |
| TotemPlates | WorldFrame scan каждые 0.5 с и per-totem OnUpdate | Работает вне арены намеренно; legacy nameplate assumptions требуют проверки на DF UI |
| Shadowsight Timer | Системное сообщение/аура, 1–2 timer frame | OnUpdate с порогом 0.01 с; повторы записи целых секунд оставлены для отдельной настройки |
| ExportImport / XiconProfiles / VersionCheck | Команды/UI; AceSerializer/Deflate/AceDB; AceComm | Сжатие и deep copy на редких пользовательских операциях допустимы; малые version messages не основание менять весь транспорт |
| Announcements / ArenaCountDown | Нейтральные chat events, сообщения, repeating 1 с | Не загружаются текущим TOC; runtime-оптимизации этих файлов не заявляются |

### Сохранение состояния

AceDB хранит профиль в GladdyXZ. Дефолты модулей объединяются в defaults.profile; options меняют профиль и вызывают UpdateFrame. Import/export сериализует и сжимает профиль. Схема сохранения не мигрировала; старый zlib-профиль включён в тестовую фикстуру. OnProfileChanged/Reset переприменяют локализацию и тестовые фреймы; языковые снимки таблиц требуют отдельной проверки.

## D. Реестр проблем

«Подтверждено» означает вывод из конкретного пути кода/автономного теста, не измеренный FPS. P0 в пределах выполненных проверок не установлен.

| ID / приоритет | Место / тип | Сценарий и причина | Влияние / частота | Уверенность | Решение / статус | Риск изменения / проверка |
| --- | --- | --- | --- | --- | --- | --- |
| G01 P1 | Gladdy.lua: IterModules, SendMessage; CPU/память | Для каждого сообщения создавались список модулей, N пар и closure, выполнялась сортировка | Внутри каждого AURA_GAIN и других сообщений; частота равна потоку сообщений | Подтверждено, измерено на стенде | Кэш порядка, инвалидируется NewModule; подписки не кэшируются. Исправлено | Смена подписок внутри dispatch; проверена live-unregister и регистрация нового модуля |
| G02 P1 | Healthbar.lua: ENEMY_SPOTTED/UNIT_DEATH; логика/таймеры | Нулевое здоровье считалось отсутствием данных и запускало новый C_Timer:After без лимита; смерть ещё планировала повторное чтение | Повтор каждые 0.1 с при health=0, несколько цепочек при повторных событиях | Подтверждено по коду | До 3 deduplicated AceTimer retry только при недоступном max, проверка GUID, отмена на reset/death; delayed death refresh удалён. Исправлено | Данные могут появиться позднее 0.3 с; основное восстановление через UNIT_HEALTH/MAXHEALTH. Проверены нули, лимит, отмена, другой GUID; клиентный сценарий M03 |
| G03 P1 | Pets.lua: PET_SPOTTED/CheckUnitPet; CPU/UI | На каждом кадре 2 чтения UnitHealth + UnitHealthMax, безусловный текст, повторные замыкания | По каждому видимому питомцу; зависит от FPS | Подтверждено, счётчики стенда | Общий callback до 10 Гц, один health/max и render только изменений. Исправлено | Задержка до 100 мс, проверка в бою M04; polling fallback сохранён |
| G04 P2 | EventListener.lua: UNIT_AURA; память/GC | Новые tuple-таблицы и рекурсивный DeepCopy всего снимка на каждое событие | По aura event × до 80 сканируемых аур на unit | Подтверждено по коду | Две переиспользуемые карты, tuple живой ауры переиспользуется; scalar messages сохранены. Исправлено | Aliasing/потеря fade; проверены публичный current map, removal, повторные события |
| G05 P2 | EventListener.lua: CLEU; CPU/память | Debug whitelist создавался на каждое событие, проходила нерелевантная обработка | Каждый combat log в арене | Подтверждено по коду | Постоянный whitelist и ранний выход; известные specSpells пропускаются даже из damage/heal. Исправлено | Нельзя терять spec по урону; специальная регрессия это проверяет |
| G06 P1 | EventListener.lua: OnEvent; диагностика | pcall подавлял ошибку; вывод зависел от выключенного по умолчанию debug | Любая ошибка обработчика | Подтверждено | Обычный вызов под стандартным error handler WoW. Исправлено | Ошибки станут видимыми, а не исчезнут; проверен ошибочный callback при debug=false |
| G07 P1 | RangeCheck/CombatIndicator/Pets: UpdateFrameOnce; lifecycle | UnregisterAllMessages не отменял уже работающий timer/OnUpdate/event | После выключения модуля до reset/выхода | Подтверждено | Cancel/detach при отключении, безопасный restart при включении. Исправлено | Повторное включение и тестовый режим; проверены оба перехода и отсутствие второго range timer |
| G08 P2 | EventListener: SpotEnemy; Pets: PET_DESTROYED; состояние | Старая GUID→unit ссылка не убиралась при смене GUID/уничтожении pet | При смене питомца, исчезновении, повторном slot | Подтверждено | Удаляется только принадлежащая unit старая ссылка, nil GUID не записывается. Исправлено | Не стереть чужой mapping; проверены замена GUID и cleanup pet |
| G09 P2 | Castbar.lua: JOINED_ARENA/CAST_START/STOP/OnUpdate; CPU | Alpha=0 не останавливал callback idle/fade-completed кастбара | До 5 callback каждый кадр даже без каста | Подтверждено | Подписка только на cast/fade, снятие при idle, восстановление при start/delay. Исправлено | Потеря следующего каста; проверены cast/channel/stop/fade/restart, M05 |
| G10 P2 | Options.lua: FormatTimer; UI | SetText/SetFormattedText каждый кадр, когда отображаемая секунда та же | Каждый активный DR/CD/aura timer | Подтверждено по числу UI-записей | Сравнение с GetText перед SetText. Исправлено | GetText/форматирование тоже имеют стоимость; чистый выигрыш CPU в игре не измерен. Проверены все форматы и внешний reset текста |
| G11 P2 | Util.lua: CreateIconFrame OnUpdate; логика | После StopCooldown выполнялись лишняя отрисовка истёкшего состояния и повторная работа | На истечении каждой иконки | Подтверждено | Вычитание elapsed до проверки, немедленный return на expiry/nil state. Исправлено | READY должен быть один; тест проверяет единственный READY |
| G12 P2 | AceTimer-3.0; CPU/lifecycle | Встроенный 1018 работал без скрытия idle и проверки nextFire; изменение activeTimers внутри callback осложняло iteration | Каждый кадр timer driver | Подтверждено по реализации | 1020 из ElvUI-Sirus; snapshot pending и sleep. Исправлено | Upgrade/отмена/embedded methods; 9 библиотечных регрессий в отдельном рантайме |
| G13 P1 | TotemPlates.lua: NameplateScanValid/WorldFrame; совместимость | Предположения о legacy WorldFrame regions/children могут не соответствовать DF UI | Scan каждые 0.5 с и активные plate callbacks | Обоснованный риск; клиент не проверен | Не переписывался под неподтверждённый контракт. Открыто | Проверить legacy и DF UI plate schemas и ElvUI coexistence; M08 |
| G14 P1 | Constants_Wrath.lua: file-scope GetSpellInfo keys; совместимость | Если любой используемый spell отсутствует, nil как ключ таблицы может остановить загрузку | Один раз при загрузке; фактический список доступных ID неизвестен | Обоснованный риск, не утверждение о сбое Sirus | Нужен список отсутствующих ID текущего клиента; не подменять их произвольными строками. Открыто | Контролируемый spell probe и запуск без других аддонов; M01 |
| G15 P2 | Lang/Constants/Options: ApplyLanguage; локализация | Таблицы spec/CD/default labels создаются до изменения пользовательского языка и содержат строки выбранного при загрузке языка | При locale override/profile switch | Подтверждённая структурная несогласованность; UI-эффект требует клиента | Требуется canonical spec IDs + совместимая миграция ключей, не локальный массовый replace. Открыто | Старые профили/иконки/спеки обоих языков; M07 |
| G16 P2 | Util/Cooldowns/DR/Shadowsight: OnUpdate; UI | SetFont/SetTextColor/alpha либо целые секунды повторяются чаще изменения вида | Только активные таймеры, кроме постоянно созданных aura containers | Подтверждены повторные вызовы; стоимость — гипотеза до профиля | Общий FormatTimer уже сокращает текст; font/color throttling отдельно не вводился. Частично | Пороговые цвета, масштаб, переключение настроек; M09 |
| G17 P1 | Gladdy.lua: JoinedArena/CreateButton; secure UI | Создание отсутствующих кнопок выполняется до проверки InCombatLockdown | Редкий вход/перезагрузка на арене в combat | Обоснованный риск | Не перестраивался state machine без клиента. Открыто | Taint, bindings, показ после PLAYER_REGEN_ENABLED; M06 |
| G18 P2 | ExportImport.lua: CheckDeserializedOptions; валидация | Неподходящий тип deserialized root/version может вызвать ошибку до понятного отказа | Только ручной импорт повреждённой строки | Обоснованный риск по отсутствию boundary validation | Сжатие проверено; строгая schema/size validation отдельной задачей. Открыто | Нужен corpus старых профилей; M07 |

Статусы «исправлено» относятся к изменениям кода и автономным тестам; приёмка в игровом клиенте остаётся отдельной.

## E. Подробный анализ производительности

### События

До аудита каждый AURA_GAIN инициировал новый sort всех модулей даже для сообщения без подписчиков. Выбран кэш только порядка, а не списка подписчиков: RegisterMessage/UnregisterMessage во время вызова сохраняют прежнюю семантику. Публичный IterModules остаётся итератором. NewModule сбрасывает кэш; поиск показал, что код не меняет module.priority после регистрации.

CLEU больше не создаёт debug-таблицу каждый вызов и не проходит обработку для SWING_DAMAGE/неизвестных periodic events. Фильтрация не ограничивается одним списком типов: известное заклинание специализации сохраняет обработку независимо от damage/heal типа. Death, interrupt, aura applied/refresh/removed, cast success/missed, shadowsight сохранены.

Health/Power остаются событийными. Полный UpdateFrame не переносился в часто вызываемые события. Target/focus обход до пяти unit достаточно мал; новый индекс для этой операции не оправдан без измерения.

### Ауры и память

UNIT_AURA пока сохраняет полное сканирование до 40 helpful + 40 harmful аур и протокол FADE→GAIN→LIMIT, от которого зависят Auras/BuffsDebuffs. Замена на delta-only сообщения потребовала бы менять несколько публичных контрактов, приоритеты и поведение stealth.

DeepCopy убран из горячего пути, но оставлен в import/profile операциях, где независимая копия действительно нужна. Две карты ограничены состоянием одного arena unit; tuple сохраняющейся ауры не создаётся заново. Удаление определяется по предыдущей карте до её очистки. Snapshot по spellID всё ещё не различает несколько экземпляров одной ауры от разных caster — существующее ограничение, не новая оптимизация.

### OnUpdate и UI

Покадровое движение castbar оставлено плавным. Изменены только подключение и отключение idle callback. Опрос питомца сохранён из-за legacy arena API, но ограничен 0.1 с; SetMinMaxValues обновляется при изменении max health.

Range/Combat Indicator сохраняют 0.05 с для отзывчивости; при отключении их работа прекращается. CombatIndicator сравнивает видимость, а config update инвалидирует это сравнение.

FormatTimer сокращает одинаковые SetText, но вычисление строки и GetText остаются. Это не основание обещать общий прирост FPS. Пулы cooldown icons, DR иконки и списки buff/debuff уже переиспользуют UI-объекты; удалять эти механизмы не требовалось. Массовый layout остаётся редким, а не покадровым.

TotemPlates намеренно работает и вне арены. Его WorldFrame scan и mouseover/target highlight не отключались только ради уменьшения счётчика: это изменило бы функциональность вне арены. Глубокая адаптация под DF UI оставлена до проверки фактических nameplate объектов.

## F. Выполненные исправления

| Этап | Поведение до | Что сохранено/изменено | Проверка и остаточный риск |
| --- | --- | --- | --- |
| 1. Dispatch | Новые таблицы/сортировка на каждое сообщение | Приоритет и живые подписки сохранены; порядок переиспользуется | Live-unregister, новая регистрация, synthetic 50 000 handlers |
| 2. Aura/CLEU | DeepCopy, debug allocation, лишний проход событий | Scalar messages, aura fade и spec detection сохранены | Повторная аура, удаление, current map, damage spec, видимые runtime errors |
| 3. Lifecycle | Бесконечные health retries, death refresh, pet polling, выключенные pollers | Retry dedup/limit/GUID; reset отменяет; pet polling остаётся с 100 мс | 0 HP/max, старый GUID, отмена, переключение модулей, 600 pet ticks |
| 4. UI timers | Idle cast callbacks и одинаковые text writes | Анимация активных кастов не throttled, форматы таймера прежние | Restart/fade/channel, minutes/tenths/seconds/negative, внешний SetText |
| 5. Libraries | AceTimer1018/Callback7/Deflate1.0.1 | Выборочные Sirus-compatible замены, старый wire-format не менялся | Отдельные library tests, legacy fixture и перекрёстный zlib тест |
| 6. Code style | Нарративные комментарии в собственном коде | Удалены комментарии, не публичные функции/настройки; vendor notices оставлены | Повторены синтаксис и все регрессии |

## G. Результаты профилирования

Реальный клиент/профилировщик WoW отсутствует. Данные ниже — **один синтетический запуск Lua 5.1 через lupa на Linux**, не игровые измерения и не прогноз FPS. Диспетчер загружался из baseline commit и рабочей версии в независимых runtime, с 25 искусственными модулями и 2 000 сообщений. GC остановлен на измеряемом участке; allocated_KiB — рост Lua heap до сборки, не retained memory/утечка и не общая память аддона.

| Измерение | До | После |
| --- | ---: | ---: |
| Сообщения | 2 000 | 2 000 |
| Вызовы handlers | 50 000 | 50 000 |
| table.sort | 2 000 | 1 |
| os.clock, секунд | 0.038982 | 0.009592 |
| Рост heap при остановленном GC, KiB | 6250.312 | 0.914 |

Pet benchmark: 600 callbacks по 1/60 с с неизменным здоровьем, реальный Pets.lua baseline/рабочий, WoW API и UI — заглушки.

| Операция | До | После |
| --- | ---: | ---: |
| UnitHealth | 1 200 | 99 |
| UnitHealthMax | 600 | 99 |
| Записи текста | 600 | 0 |

Отдельная регрессия FormatTimer: 600 тиков для десятисекундного отрезка в seconds-режиме дали 10 записей текста. Это измерение числа операций, не CPU всей отрисовки.

Выводы ограничены этим стендом. Повторные запуски дадут другое время. Воспроизведение:

```sh
git show bf981e2a7cec57de5ffc32459728f2335a06bb37:Gladdy/Gladdy.lua > /tmp/gladdy-core-before.lua
git show bf981e2a7cec57de5ffc32459728f2335a06bb37:Gladdy/Modules/Pets.lua > /tmp/gladdy-pets-before.lua
lua5.1 tests/bench_dispatch.lua /tmp/gladdy-core-before.lua
lua5.1 tests/bench_dispatch.lua
lua5.1 tests/bench_pets.lua /tmp/gladdy-pets-before.lua
lua5.1 tests/bench_pets.lua
```

Исходный вывод: [benchmark-results.txt](benchmark-results.txt). CPU UI/FPS, частота CLEU на реалме и GC-паузы в клиенте не измерялись.

## H. Результаты тестирования

### Успешно вне клиента

- Синтаксис 86 Lua-файлов: Lua 5.1, включая библиотеки и тесты.
- 37 регрессионных сценариев `tests/sirus_spec.lua`.
- 9 проверок реальных обновлённых библиотек `tests/libraries_spec.lua` в отдельном runtime с настоящим LibStub.
- 101 зависимость TOC/XML: файлы существуют, Script/Include применены к правильным типам файлов.
- Два synthetic operation-count benchmark.
- Локальная перекрёстная декомпрессия 1.0.1 ↔ 1.0.2 и Python zlib; фиксированный старый профиль хранится в tests/fixtures.
- Проверка diff и whitespace, изменения разбиты по логическим коммитам. CI повторяет проверки на native lua5.1.

### Найденные при разработке неуспешные прогоны

Тестовый стенд уточнялся: заглушка SendMessage мешала тесту настоящего dispatcher; UnitAura был перехвачен локально до смены заглушки; ожидаемое число seconds-текстов было 11 вместо 10; mock fadeOut возвращал функцию вместо nil; Python-обёртка приняла два результата CompressZlib за один. Эти прогоны исправлены и не выдаются за найденные баги игрового Gladdy. Итоговый набор не содержит известных падающих тестов.

### Недоступно

Не запускались реальный Sirus, GUI-проверки, arena matches, protected/taint actions, реальные сетевые AceComm messages, человеческий ввод/клики, проверка всех server spell IDs/CD/DR, полная end-to-end загрузка настоящего WoW UI. Заглушки не доказывают эти свойства.

### Ручная приёмка в клиенте

Перед тестами — резервная копия WTF. Сравнивать одинаковый реалм/профиль/UI scale и похожие матчи, а не случайные FPS разных сцен.

| Сценарий | Условия/действия | Ожидаемый результат |
| --- | --- | --- |
| M01 Загрузка | Только Gladdy; затем Gladdy+ElvUI; затем Gladdy+WeakAuras; включить `/console scriptErrors 1`, `/reload` | Нет Lua-ошибок, доступны `/gladdy`, media и иконки; записать реальные выбранные LibStub minor |
| M02 Lifecycle | Два последовательных матча 2v2, затем 3v3/5v5; visibility seen/unseen/destroyed | Нет старой расы/spec/созвездия/GUID, иконки и таймеры не переходят к следующему сопернику |
| M03 Health | Споттинг при недоступном max HP; смерть, Feign Death, реальное воскрешение; быстро выйти/зайти | Не более 3 pending retries на один бар, DEAD не затирается callback; HP/Power восстанавливаются событиями; FD не считается смертью |
| M04 Pets | Призыв/смена/уничтожение/невидимость питомца; смена max HP; отключение/включение Pets | Нет Lua-ошибок/GUID старого pet, max обновлён, реакция до 100 мс, отключённый poller не работает |
| M05 Cast/Target | Серии cast, channel, stop, fail, interrupt, delayed; смена target/focus в stealth/death | Кастбар после паузы снова обновляется, fade завершается, target/focus borders следуют текущему unit |
| M06 Combat lockdown | Войти/перезагрузить на арене в combat с отсутствующими кнопками; выйти из боя | Зафиксировать taint/blocked actions; UI должен показываться после regen; проблема G17 считается открытой до проверки |
| M07 Profiles | Старые export strings, copy/reset/import; auto/ruRU/enUS и их смена | Настройки не потеряны; сравнить spec/CD labels; зафиксировать G15/G18 отдельно, не считать решёнными |
| M08 DF UI | Totem plates с новым DF UI, с ElvUI и без, оба порядка загрузки; target/mouseover | Проверить распознавание реальных plate objects; не обещать работоспособность legacy региона до этого теста |
| M09 Timers | DR refresh/fade, shared racial/trinket CD, font/scale и dynamic colors во время CD | Цифры и цвет корректны на границах 60/30/11/10/5/3/0; READY один раз; баланс сверить с сервером |
| M10 Toggle/load order | Выключить/включить Range, CI, Pets в матче; оба порядка загрузки ElvUI/WeakAuras | Нет orphan callbacks, вторых timers и ошибок при upgrades библиотек |

### План игрового профилирования

1. Проверить наличие `debugprofilestop`, `UpdateAddOnCPUUsage`, `GetAddOnCPUUsage`, `GetFunctionCPUUsage`, `GetScriptCPUUsage`, `GetAddOnMemoryUsage` до использования. Отсутствующая функция не заменяется современным Retail API.
2. При поддержке включить scriptProfile и перезагрузиться; одинаково включить его для baseline/2.40. В отдельном непостоянном диагностическом стенде сэмплировать counters/timing CLEU, UNIT_AURA, SendMessage, pet polls и активных timer scripts.
3. Собрать одинаковые интервалы idle вне арены, подготовка, интенсивный бой с pets/многими аурами, смерть/выход. Записать count, aggregate CPU, peak samples, память после GC; не печатать каждое событие в чат.
4. Сравнить активные UI writes, число активных timer handles после disable/reset и наличие callbacks вне арены. Не объявлять рост памяти утечкой до проверки retained references после reset/GC.
5. После измерения выключить scriptProfile/диагностику и перезагрузиться. В релизе не добавлены постоянно работающие профилировщики или счётчики.

## I. Незакрытые проблемы и следующий шаг

Первый следующий шаг — M01/M02/M03/M05/M06 на актуальном клиенте Sirus. Затем G13 (nameplates), G15 (языковые canonical keys), G14 (полный spell probe), G18 (валидация и corpus import) и G16 (font/color/alpha по результатам профиля). Для серверных CD/DR нужны достоверные боевые логи/документация реалма, а не вывод по UI чужого аддона.

Не обновлялись автоматически все библиотеки и не добавлялись крупные glow-ресурсы ради номера версии. Решения и оставшиеся upgrade-тесты приведены в LIBRARIES.md.

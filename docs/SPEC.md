# usb_notifier — техническое задание

Menu-bar приложение для macOS 14+: при подключении/отключении USB-устройства показывает
системное уведомление и играет звук, а по клику на иконку в строке меню — живой список
подключённых устройств со скоростью линка и выделенным питанием. Бесплатный аналог PlugTalk,
сознательно без правил на устройство и без мониторинга внешних дисплеев. Основа —
[ohaiibuzzle/USBNotifier](https://github.com/ohaiibuzzle/USBNotifier) (GPL-3.0), из него
взяты схема подписки на IOKit, дебаунс и группировка уведомлений.

## 1. Пользовательский сценарий

1. Пользователь запускает приложение (`make install`). Иконки в Dock нет, в строке меню
   появляется `cable.connector`. При первом запуске macOS спрашивает разрешение на
   уведомления. Отказ не закрывает приложение — звуки и список продолжают работать.
2. Устройства, подключённые до запуска, попадают в список молча, без уведомлений.
3. Пользователь втыкает устройство. Через ~1 с приходит уведомление «Connected» с именем
   устройства и второй строкой «скорость · питание», играет звук подключения.
   Если за секунду воткнули несколько устройств — одно уведомление «N devices connected»
   со списком имён.
4. Пользователь выдёргивает устройство — то же самое с «Disconnected» и звуком отключения.
5. Клик по иконке открывает окно в стиле дропдауна PlugTalk (§7). В нём:
   - список устройств: иконка категории, имя, производитель, скорость, питание;
   - выбор звука подключения и отключения из системных;
   - кнопки пробы звуков;
   - под шестерёнкой — уведомления вкл/выкл, звуки вкл/выкл, «заменять предыдущее
     уведомление», запуск при входе, Quit.

## 2. Источники данных / внешние интерфейсы (проверено эмпирически)

### IOKit: класс устройства

- Класс — `IOUSBHostDevice`. Константа `kIOUSBHostDeviceClassName "IOUSBHostDevice"` —
  проверено по заголовку `IOUSBHostFamilyDefinitions.h` из Xcode SDK. Upstream использует
  `kIOUSBDeviceClassName`, в этих заголовках её нет.
- Подписка: `IONotificationPortCreate` → `IOServiceAddMatchingNotification` с
  `kIOFirstMatchNotification` и `kIOTerminatedNotification` на `IOServiceMatching("IOUSBHostDevice")`.
  Именно first-match, а не `kIOMatchedNotification`: по `IOKitLib.h` first-match приходит
  один раз на экземпляр сервиса, а matched может прийти повторно при перерегистрации уже
  подключённого устройства — это ложное «Connected». Новое подключение — всегда новый
  экземпляр, поэтому first-match ничего не теряет.
  Оба итератора нужно сразу выбрать до конца — иначе нотификации не взводятся; upstream
  делает это при старте и тем самым молча пропускает уже подключённые устройства.
- Свойства — `IORegistryEntryCreateCFProperties`, идентификатор — `IORegistryEntryGetRegistryEntryID`.
- Полный список — `IOServiceGetMatchingServices` с тем же matching-словарём.

### Ключи свойств (по `IOUSBHostFamilyDefinitions.h` + реальный дамп)

| Ключ | Смысл |
| --- | --- |
| `idVendor`, `idProduct` | VID / PID |
| `kUSBProductString`, `kUSBVendorString`, `kUSBSerialNumberString` | строки дескриптора (современные ключи) |
| `USB Product Name`, `USB Vendor Name`, `USB Serial Number` | те же строки, старые ключи |
| `USBSpeed` (`kUSBHostMatchingPropertySpeed`) | enum `tIOUSBHostConnectionSpeed`, см. ниже |
| `UsbLinkSpeed` (`kUSBHostPropertyForceLinkSpeed`) | скорость линка в бит/с |
| `UsbPowerSinkAllocation` (`kUSBHostDevicePropertyPowerSinkAllocation`) | «OSNumber mA of current the device is expected to sink from Vbus (5V)» |
| `UsbPowerSinkCapability` | максимум mA, который устройство может взять |
| `bcdUSB` | версия USB, которую объявляет устройство, в BCD: 0x0110 = 1.1, 0x0200 = 2.0, 0x0320 = 3.2 |

Enum `tIOUSBHostConnectionSpeed` (значения `USBSpeed`):
None=0, Full=1 (12 Mb/s), Low=2 (1.5 Mb/s), High=3 (480 Mb/s), Super=4 (5 Gb/s),
SuperPlus=5 (10 Gb/s), SuperPlusBy2=6 (20 Gb/s).

Реальный дамп `ioreg` устройства на Apple Silicon (форум Apple Developer):

```text
"USBSpeed" = 3
"UsbLinkSpeed" = 480000000
"UsbPowerSinkAllocation" = 500
"USB Product Name" = "TETRA PEI interface"
"kUSBCurrentConfiguration" = 1
"bcdUSB" = 512
"locationID" = 34734080
```

На этой машине проверить на живом устройстве не удалось: в момент разведки к ней ничего
не было подключено, `ioreg` показал только контроллеры `AppleT8132USBXHCI`. Финальная
проверка — руками с реальной флешкой/хабом.

### Звуки

Системные звуки лежат в `/System/Library/Sounds` (проверено `ls`): Basso, Blow, Bottle,
Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink. Играются через
`NSSound(named:)` по имени без расширения.

## 3. Решения и отвергнутые варианты

| Решение | Почему так | Что отвергли и почему |
| --- | --- | --- |
| Идентификатор устройства — registry entry ID | уникален для каждого экземпляра | upstream `"VID-PID"`: два одинаковых устройства сливаются в одно |
| Скорость: `UsbLinkSpeed` (бит/с) → «USB 2.0 · 480 Mb/s», запасной вариант — enum `USBSpeed`. Поколение — из `bcdUSB` (2.x → «USB 2.0», ≥4 → «USB4»), без ключа — по скорости (≤12 Mb/s — 1.1, ≤480 Mb/s — 2.0, <40 Gb/s — 3.2, дальше USB4) | реальная скорость линка в готовых единицах; клавиатура на 12 Mb/s обычно объявляет 2.0, и PlugTalk показывает «USB 2.0 · 12 Mb/s» | upstream-ключ `Device Speed` — другой enum (см. §4); поколение только по скорости — Full Speed-устройства USB 2.0 выглядят как «USB 1.1» |
| Устройство Apple с PTP-интерфейсом (класс 0x06) — категория «Phone», а не «Camera» | так iPhone/iPad выглядит первым интерфейсом | — |
| В пачке с подключениями и отключениями играет только звук подключения | два звука одновременно сливаются | — |
| Питание: `UsbPowerSinkAllocation` → бейдж «2.5 W» (mA × 5 В), mA — во всплывающей подсказке; нет ключа или 0 — не показываем | единственное, что отдаёт IOKit без привилегий | — |
| Уведомление без собственного звука, звук отдельно через `NSSound` | раздельные звуки на подключение/отключение и отдельный выключатель | звук самого уведомления: один на всё и зависит от настроек Focus |
| Дебаунс 1 с, пачка → одно уведомление «N devices connected» | хаб с пятью устройствами не должен сыпать пять баннеров | — |
| При отказе в уведомлениях приложение работает дальше | звуки и список полезны и без уведомлений | upstream показывает диалог и завершается |
| Список перечитывается после каждого события и при открытии окна | `UsbPowerSinkAllocation` может появиться позже момента подключения | постоянный поллинг — лишний |
| UI на английском, строки прямо в коде | одна локаль | xcstrings-локализация upstream |
| Внешний вид окна повторяет дропдаун PlugTalk (см. §7) | так попросил пользователь | нативное меню upstream с подменю |
| Категория устройства (иконка + «Vendor · Category») по классу USB: `bDeviceClass`, а при 0/0xEF — первый `bInterfaceClass` дочерних `IOUSBHostInterface` | так в дизайне PlugTalk | — |
| Нет правил на устройство, нет мониторинга дисплеев | так попросил пользователь | — |
| Выкинуто из upstream: пауза мониторинга, «извлечь все диски» | не просили | — |

## 4. Подводные камни

- **`Device Speed` ≠ `USBSpeed`.** Upstream читает старый ключ `Device Speed` с отображением
  0=Low, 1=Full, 2=High, 3=Super, 4=Super+. У `USBSpeed` другой порядок (1=Full, 2=Low).
  Смешаешь — Full Speed станет Low и наоборот, а High Speed превратится в SuperSpeed.
- **Питание — это выделение, а не измерение.** `UsbPowerSinkAllocation` — сколько mA
  устройству разрешено/запрошено с VBUS 5 В, а не сколько оно реально потребляет. Ватты
  = mA × 5 В / 1000. Самопитаемые устройства и часть хабов ключа не имеют.
- **На отключении свойств уже может не быть.** Устройство для уведомления «Disconnected»
  берётся из кэша по registry ID, а не читается с умирающего сервиса.
- **Уведомления и автозапуск требуют бандла.** `UNUserNotificationCenter` и `SMAppService`
  падают/молчат у голого бинарника из `swift build`. Только `make run`/`make install`.
- **Окно `MenuBarExtra(.window)` и `onAppear`.** Проверено на запущенном приложении
  (`NSLog` + шесть кликов по иконке через System Events): `onAppear` срабатывает при
  каждом открытии окна, вместе с `NSWindow.didBecomeKeyNotification`. Приложение при этом
  активным не становится — `NSApplication.didBecomeActiveNotification` не приходит ни разу,
  так что завязываться на активацию нельзя. Делегат `UNUserNotificationCenter`
  (`willPresent` → `[.banner, .list]`) оставлен на случай, если приложение всё же
  окажется активным.

## 5. Структура проекта

```text
macos/
  Package.swift
  Resources/Info.plist        bundle id xyz.vvzvlad.usb-notifier, LSUIElement
  scripts/build.sh            swift build → USBNotifier.app, ad-hoc codesign
  Sources/USBNotifier/
    USBNotifierApp.swift      @main, MenuBarExtra (.window)
    USBDevice.swift           model, parsing of IOKit properties, speed/power formatting
    USBMonitor.swift          IOKit notifications, debounce, device list
    Notifier.swift            UNUserNotificationCenter
    SoundPlayer.swift         NSSound playback of system sounds
    Settings.swift            @AppStorage keys and defaults
    LaunchAtLogin.swift       SMAppService.mainApp
    MenuView.swift            device list and settings UI
  Tests/USBNotifierTests/
    USBDeviceTests.swift      parsing and formatting tests
```

## 6. Ограничения

- Только USB-устройства класса `IOUSBHostDevice`; Thunderbolt-устройства без USB-функции и
  дисплеи не отслеживаются.
- Питание — выделенное, а не реально потребляемое.
- Хабы показываются в списке как обычные устройства, без дерева. Хаб USB 3.x — это два
  `IOUSBHostDevice` (половины USB 2 и USB 3), поэтому один физический хаб даёт две строки
  и «2 hubs» в шапке.
- Свои звуковые файлы, история подключений, объём накопителей — не делаются.
- Подпись ad-hoc: при первом запуске Gatekeeper может потребовать открыть через ПКМ → Open
  (для сборки на этой же машине не требует).
- Не проверено на живом устройстве, что `IOUSBHostInterface` — прямые дети
  `IOUSBHostDevice` в плоскости `IOService`. Если это не так, категория не определится:
  будет общая иконка `cable.connector` без подписи категории, без падения.

## 7. Дизайн (образец — PlugTalk)

Образец — макет дропдауна на лендинге <https://plugtalk.thenightwatcher.online> (секция
«From your menu bar»). Скриншот всей страницы:
<https://shot.huntscreens.com/e2221046-5de9-4021-bbe1-2989d8e7f134.webp>, дропдаун на
нём — область x 1520–2440, y 3050–4050.

Цвета сняты пипеткой с этого скриншота:

- акцент — `#FF5C8F`;
- фон — `#13151B`, тёмная тема принудительно;
- бейдж скорости — синий, бейдж мощности — оранжевый: капсула с цветным текстом, заливка
  15 %, обводка 40 %.

Сверху вниз:

- **Шапка:** иконка в розовом квадрате, «USB Notifier», «N devices · M hubs» моноширинным,
  справа капсула с суммарной мощностью.
- Секция **«USB DEVICES»**, в каждой строке:
  - иконка категории;
  - имя;
  - бейдж «USB 2.0 · 480 Mb/s»;
  - бейдж «2.5 W»;
  - под именем «Vendor · Category».
- **Строки выбора звука** подключения и отключения.
- **Футер:** ▷ Plug / ▶ Unplug — проба звуков, справа шестерёнка с переключателями и Quit.

Из макета не взяты:

- внешние дисплеи;
- кнопки info/mute/settings у устройств — это правила;
- полоска заполнения накопителя;
- наборы звуков.

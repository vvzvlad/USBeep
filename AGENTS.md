# Agent Instructions — usb_notifier (USBeep)

Menu-bar приложение для macOS: уведомление и звук при подключении/отключении USB-устройства,
живой список устройств со скоростью линка и выделенным питанием. Бесплатный аналог PlugTalk
без правил и мониторинга дисплеев, сделан на основе
[ohaiibuzzle/USBNotifier](https://github.com/ohaiibuzzle/USBNotifier) (GPL-3.0).

Требования, проверенные факты об IOKit и отвергнутые варианты — в `docs/SPEC.md`.
Прочитай его, прежде чем менять логику опроса устройств.

## Структура проекта

- `macos/Package.swift` — SwiftPM: executable `USBeep` + тесты `USBeepTests`
- `macos/Sources/USBeep/` — код приложения
- `macos/Tests/USBeepTests/` — тесты чистой логики (разбор свойств, форматирование)
- `macos/Resources/Info.plist` — Info.plist бандла (`LSUIElement`, bundle id)
- `macos/scripts/build.sh` — собирает `macos/USBeep.app` и подписывает ad-hoc
- `docs/SPEC.md` — требования и проверенные факты

## Команды

```bash
make test       # swift test
make app        # macos/USBeep.app
make run        # собрать бандл и запустить
make install    # в /Applications и запустить
make uninstall
make clean
```

Голый бинарник из `swift build` не запускать: `UNUserNotificationCenter` и `SMAppService`
работают только из бандла с bundle id. Запуск — только через `make run` / `make install`.

## Репозитории и релизы

- `origin` — Gitea `projects/usb_notifier`, там ишью.
- `github` — `vvzvlad/USBeep`, ветка `main`. Это бывший форк `ohaiibuzzle/USBNotifier`,
  отвязанный от сети форков: форки не показываются в поиске GitHub. История upstream
  влита слиянием `-s ours`, авторство его коммитов сохранено.
- Имя приложения — USBeep, bundle id `xyz.vvzvlad.usbeep`. Каталог и репозиторий в Gitea
  по-прежнему называются `usb_notifier`.
- `.github/workflows/build.yml`: на каждый пуш в `main` и PR — `make test` и `make app`,
  zip бандла выкладывается артефактом.
- Релиз: поставить тег `vX.Y.Z` и запушить его в `github`. Workflow соберёт приложение
  с версией из тега (`APP_VERSION` в `build.sh`) и создаст GitHub Release с
  `USBeep.zip`.

## Соглашения

- Комментарии в коде — на английском. На английском же всё остальное, что остаётся в
  репозитории и адресовано не тебе одному: пользовательский интерфейс, строки логов и
  **сообщения коммитов** — и subject, и тело. Отчёты агента пользователю в чате — на
  русском, но в файл и в историю git они не попадают.
- Повторяющиеся действия — через `make`-таргеты, а не разрозненные команды в шелле.
- Тесты обязательны для новой чистой логики (разбор свойств IOKit, форматирование).
  Код, который ходит в IOKit / NotificationCenter, проверяется руками на живом устройстве.
- Лицензия GPL-3.0 (наследуется от upstream) — не менять.
- Ветка по умолчанию — `main`.

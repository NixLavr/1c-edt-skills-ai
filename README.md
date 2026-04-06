# 1C EDT Skills AI

Набор skills для Codex, связанных с разработкой на 1С и 1C:EDT.

Сейчас в репозитории есть skills:

- `cfe-build-edt` - сборка файла расширения `.cfe` из пары EDT-проектов основной конфигурации и расширения.
- `v8std-bsl-review` - проверка и безопасное исправление BSL-кода по стандартам разработки 1С (v8std) с упором на качество кода, отсутствие запросов в цикле и переиспользование БСП.

## Структура

```text
skills/
  cfe-build-edt/
    SKILL.md
    scripts/
      cfe-build-edt.ps1
  v8std-bsl-review/
    SKILL.md
    agents/
      openai.yaml
    references/
      v8std-bsl-checklist.md
```

## Установка

Скопируйте нужную папку skill в каталог skills Codex.

Пример для `cfe-build-edt`:

```powershell
Copy-Item -Recurse -Force `
  "C:\Users\Nix Lavr\1c-edt-skills-ai\skills\cfe-build-edt" `
  "C:\Users\Nix Lavr\.codex\skills\cfe-build-edt"
```

Пример для `v8std-bsl-review`:

```powershell
Copy-Item -Recurse -Force `
  "C:\Users\Nix Lavr\1c-edt-skills-ai\skills\v8std-bsl-review" `
  "C:\Users\Nix Lavr\.codex\skills\v8std-bsl-review"
```

Если skill уже установлен, можно обновить его содержимое:

```powershell
Copy-Item -Recurse -Force `
  "C:\Users\Nix Lavr\1c-edt-skills-ai\skills\v8std-bsl-review\*" `
  "C:\Users\Nix Lavr\.codex\skills\v8std-bsl-review"
```

## Что делает `cfe-build-edt`

Skill автоматизирует сборку `.cfe` из EDT-исходников:

1. Экспортирует EDT-проект основной конфигурации в XML конфигуратора через `1cedtcli`.
2. Экспортирует EDT-проект расширения в XML конфигуратора через `1cedtcli`.
3. Создает временную файловую информационную базу.
4. Загружает в нее основную конфигурацию.
5. Загружает в нее расширение.
6. Выгружает бинарный файл `.cfe`.

### Требования

- установлен `1C:EDT`;
- установлен `1C:Enterprise` с `1cv8.exe`;
- рядом есть два EDT-проекта:
- проект основной конфигурации;
- проект расширения.

По умолчанию скрипт ожидает такие имена каталогов:

- `Информационная_база`
- `Информационная_база.Расширение`

### Пример запуска

Если вы находитесь в корне проекта:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  "C:\Users\Nix Lavr\.codex\skills\cfe-build-edt\scripts\cfe-build-edt.ps1"
```

Явное указание путей:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  "C:\Users\Nix Lavr\.codex\skills\cfe-build-edt\scripts\cfe-build-edt.ps1" `
  -BaseProjectPath "C:\Path\To\Информационная_база" `
  -ExtensionProjectPath "C:\Path\To\Информационная_база.Расширение" `
  -OutputFile "C:\Path\To\build\Расширение.cfe"
```

### Результат и логи

По умолчанию результат сохраняется в:

```text
build\Расширение.cfe
```

Если при сборке возникает ошибка, смотрите логи в каталоге временной сборки:

```text
build\cfe-build\logs
```

## Что делает `v8std-bsl-review`

Skill предназначен для code review и безопасного исправления BSL-кода по стандартам ИТС:

- проверяет структуру модуля, именование, комментарии, параметры и экспортный интерфейс;
- ищет проблемы в обработке исключений;
- проверяет запросы и доступ к данным;
- строго считает запросы в цикле нарушением высокого приоритета;
- если в проекте уже есть БСП, предпочитает ее штатный функционал самописным дублям.

### Ключевые правила

- сначала перечислить нарушения, потом вносить минимальные безопасные правки;
- не ломать публичные контракты и сигнатуры обработчиков событий;
- не оставлять запросы в цикле без явного решения или замечания;
- использовать функционал БСП, если он уже есть в конфигурации;
- не подключать новую зависимость на БСП в проект, где ее нет.

### На что опирается

Skill использует краткую выжимку правил и ссылки на ИТС в файле:

- [skills/v8std-bsl-review/references/v8std-bsl-checklist.md](C:\Users\Nix Lavr\1c-edt-skills-ai\skills\v8std-bsl-review\references\v8std-bsl-checklist.md)

Основные источники:

- [Система стандартов и методик разработки 1С](https://its.1c.ru/db/v8std)
- [Оформление модулей](https://its.1c.ru/db/v8std/browse/13/-1/31/32)
- [Использование прикладных объектов и универсальных коллекций значений](https://its.1c.ru/db/v8std/browse/13/-1/31/34)
- [Оптимизация запросов](https://its.1c.ru/db/v8std/browse/13/-1/26/28)

### Примеры запросов к Codex

- `Проверь общий модуль по стандартам 1С и исправь замечания.`
- `Приведи этот обработчик формы к v8std.`
- `Найди нарушения ИТС в запросе и поправь безопасно.`
- `Проверь код, убери запросы в цикле и используй БСП, если в проекте уже есть готовый механизм.`

## Для чего репозиторий

Репозиторий нужен как публичное или приватное хранилище skills, которые можно:

- версионировать в Git;
- переносить между машинами;
- ставить в `$CODEX_HOME/skills`;
- дорабатывать под конкретный процесс 1С/EDT.

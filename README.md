# 1C EDT Skills AI

Набор skills для Codex, связанных с разработкой на 1С и 1C:EDT.

Сейчас в репозитории есть skill:

- `cfe-build-edt` — сборка файла расширения `.cfe` из пары EDT-проектов:
  основной конфигурации и расширения.

## Структура

```text
skills/
  cfe-build-edt/
    SKILL.md
    scripts/
      cfe-build-edt.ps1
```

## Установка

Скопируйте папку skill в каталог skills Codex:

```powershell
Copy-Item -Recurse -Force `
  "C:\Users\Nix Lavr\1c-edt-skills-ai\skills\cfe-build-edt" `
  "C:\Users\Nix Lavr\.codex\skills\cfe-build-edt"
```

Если skill уже установлен, можно просто обновить файлы:

```powershell
Copy-Item -Recurse -Force `
  "C:\Users\Nix Lavr\1c-edt-skills-ai\skills\cfe-build-edt\*" `
  "C:\Users\Nix Lavr\.codex\skills\cfe-build-edt"
```

## Что делает `cfe-build-edt`

Skill автоматизирует сборку `.cfe` из EDT-исходников:

1. Экспортирует EDT-проект основной конфигурации в XML конфигуратора через `1cedtcli`
2. Экспортирует EDT-проект расширения в XML конфигуратора через `1cedtcli`
3. Создаёт временную файловую информационную базу
4. Загружает в неё основную конфигурацию
5. Загружает в неё расширение
6. Выгружает бинарный файл `.cfe`

## Требования

- установлен `1C:EDT`
- установлен `1C:Enterprise` с `1cv8.exe`
- рядом есть два EDT-проекта:
  - проект основной конфигурации
  - проект расширения

По умолчанию скрипт ожидает такие имена каталогов:

- `Информационная_база`
- `Информационная_база.Расширение`

## Пример запуска

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

## Результат

По умолчанию результат сохраняется в:

```text
build\Расширение.cfe
```

## Логи

Если при сборке возникает ошибка, смотрите логи в каталоге временной сборки:

```text
build\cfe-build\logs
```

Скрипт также умеет повторять шаги конфигуратора, если база временно занята блокировкой конфигурирования.

## Для чего репозиторий

Репозиторий нужен как публичное или приватное хранилище skills, которые можно:

- версионировать в Git
- переносить между машинами
- ставить в `$CODEX_HOME/skills`
- дорабатывать под конкретный процесс 1С/EDT

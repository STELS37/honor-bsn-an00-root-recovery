# После перезагрузки — схема восстановления

На HONOR BSN-AN00 исходный KernelSU-модуль загружается временно в оперативную память. Перезагрузка выгружает его, даже если менеджер и пользовательский компонент ksud остаются установленными.

## Два независимых этапа

1. **Запуск Shizuku после старта Android.** Официальная Shizuku требует запуск через Wireless Debugging после каждой загрузки. [Shizuku+](https://github.com/thejaustin/ShizukuPlus) содержит BootCompleteReceiver и AdbStartWorker и может автоматически подключиться к Wireless ADB при доступных системных разрешениях. На конкретной прошивке HONOR это не подтверждено; если OEM отключит беспроводную отладку, может понадобиться вручную включить её.
2. **Восстановление KernelSU по требованию.** Существующая Root App запускает upstream `run.sh`; aShell You может сохранить локальную команду Shizuku в плитке быстрых настроек. Файл [scripts/restore-root.sh](../scripts/restore-root.sh) проверяет состояние до вызова исходного скрипта и защищает от повторного запуска при `PARKED`.

## Источники компонентов

- [apps/manifest.json](../apps/manifest.json) — официальные закреплённые APK, версии и контрольные суммы;
- [scripts/fetch-apps.py](../scripts/fetch-apps.py) — получение и проверка файлов;
- [docs/ROOT-CHAIN.md](ROOT-CHAIN.md) — подтверждённая на устройстве цепочка получения root;
- [Shizuku+ boot documentation](https://github.com/thejaustin/ShizukuPlus/wiki/Service-Connection) — upstream механизм запуска по BOOT_COMPLETED;
- [aShell You](https://ashellyou.github.io/) — Quick Settings tiles для команд Shell/Shizuku.

## Что подтверждено

- Root в активной сессии: ранее наблюдались `GRANT_ROOT rc=0 uid=0`, `ROOT_STAGE_OK`, `KSU_CHAIN_OK`.
- После перезагрузки временный модуль отсутствует до повторной загрузки.
- Автозапуск Shizuku+ на HONOR BSN-AN00: ещё не проверен.
- Полное автоматическое восстановление root без участия пользователя: ещё не подтверждено.

Не путайте менеджер KernelSU в списке приложений с фактически загруженным `kernelsu.ko`: для результата нужно проверить состояние ядра и доступ root. Работающие `PARKED`-процессы нельзя принудительно завершать.

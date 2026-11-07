# USB MinerShortcut Cleanup Toolkit 🛡️

PowerShell toolkit that scrubs an aggressive USB crypto miner which hijacks the Windows service layer and propagates through removable media. It targets shortcut-based malware families that replace real files with `.lnk` launchers pointing back to malicious payloads. Below you’ll find threat behaviour, remediation steps, and usage details.

## Threat Overview

- Persists as a service under `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\U######` (letter `U` + six digits).
- Creates and refreshes a scheduled task named `svctrl64`.
- Drops payload files inside `C:\Windows\System32`:
  - `svctrl64.exe` — primary loader/miner.
  - `U######.dll` — paired DLL with matching identifier.
  - `wsvcz` — helper directory containing config/runtime data.
- On removable media, hides original content, spawns shortcuts like `USB Disk.lnk` / `USB Drive.lnk`, `USB Drive.lnk`, `documents.lnk`, and plants a `sysvolume` folder to reinfect other hosts. Victims often double-click a familiar “USB disk” shortcut, unknowingly launching the miner loader.

## What the Script Does

- `1` — removes the `U######` service and the `svctrl64` scheduled task, then forces a reboot.
- `2` — cleans `%SystemRoot%\System32`: resets attributes, deletes the exe/DLL/folder bundle.
- `3` — lists removable drives, resets their attributes, removes `sysvolume` and every `.lnk` shortcut.
- `4` — performs bulk shortcut cleanup inside a user-specified folder or across any removable drive (excluding C:), wiping shortcut-virus droppers in one pass.
- Writes a detailed log to `usb_miner_cleanup.log` and prints a live summary in the console.
- For evidence preservation there is an alternate build (`usb_miner_cleanup_archive.ps1`) that copies artifacts into a ZIP before deletion.

## Sample Cleanup Log

```2025-11-12 12:55:40:usb_miner_cleanup.log
=== File cleanup in System32 started ===
Process svctrl64.exe not running.
Removed item: C:\WINDOWS\System32\svctrl64.exe
Removed item: C:\WINDOWS\System32\wsvcz
Removed DLL file: C:\WINDOWS\System32\u502431.dll
=== USB drive cleanup started ===
Selected drive: E:\ (Type: Removable; Label: )
Removed folder: E:\sysvolume
Removed shortcut: E:\USB Drive.lnk
Removed shortcut: E:\USB Drive\.lnk
```

## Usage

1. Download `usb_miner_cleanup.ps1` and optionally `run_usb_cleanup.bat` into the same directory.
2. Launch the BAT file or run PowerShell **as Administrator**:  
   `powershell -ExecutionPolicy Bypass -File .\usb_miner_cleanup.ps1`
3. Choose from the menu:
   - `1` → wait for the automatic reboot.
   - `2` → rerun after reboot to purge system files.
   - `3` → select the infected USB drive and clean it.
   - `4` → purge all `.lnk` shortcuts from a chosen folder or removable drive.
4. Review `usb_miner_cleanup.log` for a step-by-step record.
5. Need forensics? Use `usb_miner_cleanup_archive.ps1` to quarantine artifacts into ZIP files beside the script.

## Author

ikngmkrs — system administrator who faced a fleet-wide infection and built this toolkit to eliminate the `svctrl64` miner quickly and repeatably. Follow updates and discussions in the Telegram group: [t.me/ikingmakers](https://t.me/ikingmakers). Need a private tunnel? Check out the community VPN service: [t.me/shadofyBot](https://t.me/shadofyBot?start=utm_github).

## Why This Repo Exists

- Automates painful manual cleanup tasks across dozens of endpoints.
- Documents the telltale indicators of the `svctrl64` miner for faster detection.
- Restores USB media by removing malicious shortcuts without wiping legitimate data and by reversing attribute hijacking used by “shortcut virus” variants.

🔧 Future ideas: hash and signature validation, IOC export, integration with centralized logging.

Made with love ❤️

---

# USB MinerShortcut Cleanup Toolkit (RU)

Скрипт удаляет навязчивый USB-майнер, который маскируется под системный сервис и распространяется через флешки. Угроза относится к семейству «shortcut вирусов», заменяющих настоящие файлы на `.lnk`-ярлыки, запускающие вредоносный загрузчик.

## Как ведёт себя вирус

- Прописывается как служба в `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\U######` (буква `U` + 6 цифр).
- Создаёт и поддерживает задачу планировщика `svctrl64`.
- Раскладывает полезную нагрузку в `C:\Windows\System32`:
  - `svctrl64.exe` — основной загрузчик/майнер;
  - `U######.dll` — библиотека с тем же идентификатором;
  - `wsvcz` — вспомогательная папка с конфигурацией.
- При подключении флешки скрывает оригинальные файлы, создаёт ярлыки `USB Disk.lnk` / `USB Drive.lnk`, `documents.lnk` и папку `sysvolume`, чтобы повторно заразить систему: пользователь кликает по знакомому ярлыку, а запускается загрузчик майнера.

## Что делает скрипт

- `1` — удаляет сервис `U######` и задачу `svctrl64`, затем перезагружает ПК.
- `2` — чистит `System32`, снимает защитные атрибуты, удаляет exe/dll/каталог.
- `3` — показывает все съёмные диски, сбрасывает атрибуты, удаляет `sysvolume` и все `.lnk`-ярлыки на флешке.
- `4` — массово удаляет ярлыки (`.lnk`) либо в указанной папке, либо на выбранном съёмном накопителе (кроме диска C:), избавляясь от «shortcut вирусов».
- Ведёт подробный лог (`usb_miner_cleanup.log`), умеет выводить сводку прямо в консоль.
- Для форензики доступна архивная версия (`usb_miner_cleanup_archive.ps1`), которая складывает удалённые артефакты в ZIP рядом со скриптом.

## Пример успешной очистки

```2025-11-12 12:55:40:usb_miner_cleanup.log
=== File cleanup in System32 started ===
Process svctrl64.exe not running.
Removed item: C:\WINDOWS\System32\svctrl64.exe
Removed item: C:\WINDOWS\System32\wsvcz
Removed DLL file: C:\WINDOWS\System32\u502431.dll
=== USB drive cleanup started ===
Selected drive: E:\ (Type: Removable; Label: )
Removed folder: E:\sysvolume
Removed shortcut: E:\USB Drive.lnk
Removed shortcut: E:\USB Drive\.lnk
```

## Как пользоваться

1. Скачайте `usb_miner_cleanup.ps1` и (по желанию) `run_usb_cleanup.bat` в одну папку.
2. Запустите BAT-файл или PowerShell **от имени администратора** (`powershell -ExecutionPolicy Bypass -File .\usb_miner_cleanup.ps1`).
3. Выберите в меню:
   - `1` → дождитесь перезагрузки;
   - `2` → повторный запуск, чистка системных файлов;
   - `3` → очистка флешки (выберите нужную букву).
   - `4` → массовое удаление `.lnk`-ярлыков в выбранной папке или на накопителе.
4. Проверьте `usb_miner_cleanup.log` — там фиксируется каждая операция.
5. Для сохранения улиц — используйте архивную версию (`usb_miner_cleanup_archive.ps1`), которая складывает найденные файлы в ZIP.

## Автор

ikngmkrs — системный администратор/айтишник, который столкнулся с массовым заражением корпоративных ноутбуков и написал утилиту, чтобы быстро вычищать последствия. За обновлениями и новостями следите в Telegram: [t.me/ikingmakers](https://t.me/ikingmakers). Для безопасного доступа используйте VPN-сервис сообщества: [t.me/shadofyBot](https://t.me/shadofyBot?start=utm_github).

## Зачем нужен этот репозиторий

- Автоматизирует ручную работу по чистке вируса с десятков машин.
- Помогает коллегам быстро найти информацию о характерных признаках `svctrl64`-минёра.
- Даёт готовый инструмент для удаления заражённых ярлыков, восстановления прав доступа и атрибутов на флешках без переустановки системы.

🔧 Возможный роадмап: добавить опцию проверки хэшей, автопоиск новых сигнатур и экспорт отчётов.

Сделано с любовью ❤️

Привет Кате Корень

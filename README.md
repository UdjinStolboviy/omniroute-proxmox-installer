# OmniRoute Proxmox VE Helper Installer

Цей проєкт містить професійний інтерактивний інсталятор для розгортання **OmniRoute** на базі **Proxmox VE (PVE) 8.x+** у стилі відомих скриптів *Proxmox VE Helper Scripts* (рівня tteck).

Інсталятор повністю автоматизує процес створення LXC-контейнера на Debian 12, налаштування систем віртуалізації (nesting, keyctl), встановлення Docker CE та запуску OmniRoute разом із Redis для кешування та лімітування запитів.

---

## ⚡ Особливості
- **Стиль Proxmox VE Helper Scripts:** Зручне інтерактивне меню з вибором режимів встановлення.
- **Два профілі встановлення:**
  - *Default Settings:* Автоматичне визначення наступного вільного ID контейнера, конфігурації CPU/RAM, автоматичний вибір сховища та DHCP.
  - *Advanced Settings:* Ручне налаштування CTID, імені хоста, об'ємів RAM/CPU/диска, вибір сховища (ZFS, LVM-Thin, Directory, Ceph тощо) та налаштування статичної IP-адреси.
- **Підтримка Docker CE:** Автоматичне налаштування офіційного репозиторію Docker, встановлення Docker Engine, CLI, Buildx та Compose всередині LXC.
- **Автоматична генерація секретів:** Безпечна генерація унікальних значень для `JWT_SECRET`, `API_KEY_SECRET`, `STORAGE_ENCRYPTION_KEY` та первинного пароля адміністратора (`INITIAL_PASSWORD`).
- **Модульна структура:** Скрипт розділений на окремі файли в директорії `lib/` для зручності підтримки та розвитку.
- **Логування та перевірки:** Детальний лог встановлення зберігається у `/var/log/omniroute_install.log` на PVE хості.

---

## 📂 Структура проєкту

```
omniroute-proxmox-installer/
├── install.sh              ← Головний інсталятор (запуск на хості Proxmox)
├── update.sh               ← Оновлення OmniRoute (запуск всередині LXC)
├── uninstall.sh            ← Видалення (на хості — видаляє LXC, в контейнері — видаляє сервіси)
├── lib/
│   ├── ui.sh               ← Функції інтерфейсу, кольори та запити
│   ├── validate.sh         ← Перевірка сумісності хоста PVE
│   ├── storage.sh          ← Автовизначення та вибір сховищ
│   ├── network.sh          ← Налаштування мережевих мостів, DHCP та Static IP
│   ├── lxc.sh              ← Створення та запуск LXC-контейнерів
│   ├── docker.sh           ← Встановлення Docker всередині контейнера
│   ├── github.sh           ← Отримання останніх релізів OmniRoute
│   └── functions.sh        ← Допоміжні утиліти (генератори секретів, логи)
└── configs/
    ├── docker-compose.yml  ← Конфігурація сервісів OmniRoute та Redis
    └── omniroute.env       ← Шаблон конфігураційного середовища
```

---

## 🚀 Використання на віддаленому сервері Proxmox VE

Ви можете запустити встановлення на віддаленому сервері Proxmox двома основними способами: віддалено в один рядок або шляхом завантаження репозиторію.

### Варіант 1: Запуск однією командою через curl (Рекомендовано)
Найпростіший спосіб. Підключіться до вашого сервера Proxmox VE через SSH та виконайте:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/UdjinStolboviy/omniroute-proxmox-installer/main/install.sh)"
```

#### 🛡️ Безпечне віддалене підключення (Рекомендації):
Якщо ваше інтернет-з'єднання нестабільне, або ви боїтеся переривання встановлення при втраті SSH-сесії, використовуйте термінальний мультиплексор `screen` або `tmux`:

1. **Підключіться до PVE хоста:**
   ```bash
   ssh root@your-proxmox-ip
   ```
2. **Встановіть та запустіть tmux (якщо не встановлено):**
   ```bash
   apt-get update && apt-get install -y tmux
   tmux
   ```
3. **Запустіть скрипт встановлення:**
   ```bash
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/UdjinStolboviy/omniroute-proxmox-installer/main/install.sh)"
   ```
   *Тепер, навіть якщо ви відключитеся від SSH, процес продовжиться у фоні. Ви зможете повернутися до нього командою `tmux attach`.*

---

### Варіант 2: Локальний запуск (Клонування репозиторію)
Якщо ви бажаєте перевірити код перед запуском або змінити дефолтні файли конфігурації:

1. **Підключіться до PVE хоста через SSH:**
   ```bash
   ssh root@your-proxmox-ip
   ```
2. **Клонуйте репозиторій та перейдіть у нього:**
   ```bash
   git clone https://github.com/UdjinStolboviy/omniroute-proxmox-installer.git
   cd omniroute-proxmox-installer
   ```
3. **Зробіть скрипт виконуваним та запустіть:**
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

---

## ⚙️ Керування після встановлення

### Оновлення OmniRoute
Скрипт автоматично додає інструмент оновлення всередину LXC-контейнера. Для оновлення до останньої стабільної версії виконайте на PVE хості:
```bash
pct exec <CTID> -- /opt/omniroute/update.sh
```
*(де `<CTID>` — це ID вашого контейнера, наприклад `100`)*

Або увійдіть у консоль контейнера та виконайте:
```bash
/opt/omniroute/update.sh
```

### Видалення OmniRoute
Ви можете видалити застосунок двома способами:

1. **Повне видалення контейнера LXC (запуск на хості PVE):**
   ```bash
   /path/to/omniroute-proxmox-installer/uninstall.sh
   # або якщо репозиторій не клоновано:
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/UdjinStolboviy/omniroute-proxmox-installer/main/uninstall.sh)"
   ```
   Скрипт запитає ID контейнера та повністю знищить його разом з усіма даними.

2. **Видалення тільки сервісів Docker (запуск всередині LXC):**
   ```bash
   /opt/omniroute/uninstall.sh
   ```
   Це зупинить контейнери Docker, видалить їх та очистить папку `/opt/omniroute`, залишивши сам LXC-контейнер робочим.

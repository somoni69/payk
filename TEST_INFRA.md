# Test Infrastructure & Verification Matrix (TEST_INFRA)
**Project**: Payk Mobile Application — UDC Design System & Ecosystem 1C Audit  
**Author**: Senior QA / Test Architect (`teamwork_test_writer`)  
**Methodologies**: Category-Partition Method (TSL), Boundary Value Analysis (BVA), Pairwise Testing (Orthogonal Arrays), Workload & Stress Simulation.

---

## 1. Обзор архитектуры тестирования

Тестовая инфраструктура мобильного приложения Payk построена на базе `flutter_test`, `flutter_riverpod` (с изоляцией через `ProviderContainer` и `ProviderScope.overrides`), и `go_router` для симуляции сквозных маршрутов и состояний.

```
                    ┌──────────────────────────────────────────────┐
                    │               TEST HARNESS                   │
                    └──────────────────────┬───────────────────────┘
                                           │
         ┌─────────────────────────────────┼─────────────────────────────────┐
         ▼                                 ▼                                 ▼
┌───────────────────┐             ┌───────────────────┐             ┌───────────────────┐
│ Unit / Theme      │             │ Navigation & Shell│             │ Lifecycle / State │
│  - Color Tokens   │             │  - 3 Shell Tabs   │             │  - Logout & Splash│
│  - Typography     │             │  - Active Capsule │             │  - SplashGate.res │
│  - Radii / Spacing│             │  - Tab Switching  │             │  - /auth/phone    │
└───────────────────┘             └───────────────────┘             └───────────────────┘
         │                                 │                                 │
         └─────────────────────────────────┼─────────────────────────────────┘
                                           ▼
                                ┌─────────────────────┐
                                │ Screen Structure &  │
                                │ Component Fidelity  │
                                │  - Home (Header+QR) │
                                │  - Categories (3col)│
                                │  - Profile (7 cards)│
                                └─────────────────────┘
```

---

## 2. Матрица тестового анализа по 10 фичам Feature Inventory

### Feature 1: `udc_theme_tokens` (Milestone M1)
- **Category-Partition**:
  - *Цветовые токены*: Первичный фиолетовый (`primary = #6248EE`, `primaryDark = #4E32E6`), Градиент шапки (`headerGradientStart = #9F72E7`, `headerGradientEnd = #8574E6`), Поверхности (`canvas = #FFFFFF`, `tile = #F8F9FD`, `activePill = #EDEAFB`), Границы (`border = #EFF0F2`).
  - *Типографика*: Семейство `Manrope`, начертания `FontWeight.w400`, `w500`, `w600`, `w700`.
  - *Радиусы скругления*: Карточки (`16 dp`), нижний край хедера (`24 dp`), капсула навигации (`18 dp`), кнопки (`14–16 dp`).
- **BVA (Boundary Value Analysis)**:
  - Прозрачность: альфа-канал токена `headerButtonBg` (`0x38FFFFFF` = 22%), подзаголовка хедера (`0xD9FFFFFF` = 85%).
  - Толщина границы: ровно `1.0–1.2 dp` для контурных элементов, `1.5 dp` при фокусе.
- **Pairwise**:
  - Сочетание светлой темы + высокой контрастности (High Contrast Mode).
- **Workload**:
  - Быстрый доступ к токенам через статические геттеры `PaykColors` без аллокаций в горячем цикле отрисовки (120 FPS).

### Feature 2: `cleanup_legacy_design` (Milestone M1)
- **Category-Partition**:
  - *Компоненты на удаление/замену*: устаревший `_GlassBar` с `BackdropFilter`, старые цвета (`0xFF6C4DFF`), плавающие многокнопочные бары.
  - *Ожидаемое состояние*: отсутствие вызовов старых сущностей, `flutter analyze` с 0 предупреждений о deprecated/unused элементах.
- **BVA**:
  - Отсутствие `BackdropFilter` в дереве виджетов нижней навигации (0 инстансов).
- **Pairwise**:
  - Проверка отсутствия старых ссылок во всех 3 целевых экранах.
- **Workload**:
  - Устранение лагов GPU при скролле за счет ликвидации блюра подложки.

### Feature 3: `udc_bottom_nav_bar` (Milestone M1)
- **Category-Partition**:
  - *Вкладки навигации*: ровно 3 слота (0: Home, 1: Categories, 2: Profile).
  - *Индикация активной вкладки*: лавандовая капсула `#EDEAFB` со скруглением `18 dp`, активная иконка `#6248EE`.
  - *Неактивные вкладки*: прозрачный фон, иконка `#9FA1AE`.
- **BVA**:
  - Индексы вкладок: 0 (мин/дефолт), 1 (центр), 2 (макс). Индексы <0 или >2 не должны приводить к падению shell.
  - Количество элементов: строго 3 элемента.
- **Pairwise**:
  - Переход: 0 -> 1, 1 -> 2, 2 -> 0, 0 -> 2, повторный тап по текущей вкладке (re-selection).
- **Workload**:
  - Стресс-тест быстрых переключений: 50 последовательных тапов по разным вкладкам за 1 секунду без рассинхронизации индекса.

### Feature 4: `router_adaptation_3tabs` (Milestone M1)
- **Category-Partition**:
  - *Ветви ShellRoute*:
    - Ветка 0: `/home`
    - Ветка 1: `/categories`
    - Ветка 2: `/profile`
  - *Push-маршруты*: `/code`, `/history`, `/friends`, `/rules`.
- **BVA**:
  - Начальная локация после аутентификации: строго `/home`.
  - Маршрутизация при отсутствии авторизации: редирект на `/auth/phone`.
- **Pairwise**:
  - (Авторизован=true/false) x (SplashFinished=true/false) x (OnboardingSeen=true/false).
- **Workload**:
  - Глубокие переходы по стеку: `/home` -> push `/code` -> pop -> switch to `/profile` -> push `/rules` -> pop.

### Feature 5: `home_screen_udc` (Milestone M2)
- **Category-Partition**:
  - *Фиолетовая шапка*: градиент `#9F72E7` -> `#8574E6`, радиус снизу 24 dp, аватар, приветствие «Привет, {Name}!», подзаголовок «С возвращением!».
  - *Кнопки в хедере*: колокольчик (уведомления), сканер QR-кода.
  - *Карточки быстрых действий*: «QR-код» (интерактивный), «Мои компании», «Мои сертификаты».
  - *Секция «Новые компании»*: заголовок, кнопка «Все», горизонтальный скролл карточек с логотипом.
- **BVA**:
  - Имя пользователя: короткое (3 символа), длинное (35 символов с эллипсисом), null/пустое (фолбэк).
  - Список компаний: 0 компаний (empty state), 1 компания (граничное), 20+ компаний (горизонтальный список).
- **Pairwise**:
  - Наличие/отсутствие непрочитанных уведомлений x Наличие компаний в избранном.
- **Workload**:
  - Плавная прокрутка экрана Home с горизонтальным списком компаний без просадок кадров.

### Feature 6: `categories_search_screen_udc` (Milestone M3)
- **Category-Partition**:
  - *Поле поиска*: плейсхолдер «Поиск по компаниям», иконка лупы, кнопка «Карта» сбоку (52x52 dp).
  - *Сетка категорий*: ровно 3 колонки (`crossAxisCount: 3`), пастельный фон плиток `#F8F9FD`, скругление 16 dp.
  - *Набор категорий*: 18 категорий («Все компании», «Еда и напитки», «Продукты», «Одежда и обувь» и др.).
- **BVA**:
  - Текст поиска: пустая строка (показываются все категории), 1 символ, 50 символов, спецсимволы (`<>&"'\`).
  - Число категорий: ровно 18 эталонных плиток.
- **Pairwise**:
  - Ввод поискового запроса x тап по кнопке «Карта» x тап по категории.
- **Workload**:
  - Фильтрация сетки на каждый ввод символа без задержек ввода.

### Feature 7: `profile_screen_udc` (Milestone M4)
- **Category-Partition**:
  - *AppBar*: кнопка «Назад», заголовок «Профиль», иконка логаута (Logout).
  - *7 структурных карточек*:
    1. Изображение профиля (аватар + «Добавить изображение»)
    2. Пользователь (ФИО + «Изменить»)
    3. Контакты (Email с плашкой + «Сменить пароль»)
    4. Детский клуб (аккордеон)
    5. Пушистый клуб (аккордеон)
    6. Способы входа (Google, Email с зелеными бейджами)
    7. Удаление аккаунта («Удалить» цвета `#E04875` + «Все бонусы будут удалены»)
- **BVA**:
  - Длина email: стандартный, длинный (40+ символов с переносом).
  - Статус способов входа: 1 привязанный способ, 2 способа.
- **Pairwise**:
  - Тап по раскрывающимся блокам (Детский/Пушистый клуб) в свернутом и развернутом состоянии.
- **Workload**:
  - Быстрое переключение аккордеонов без перестроения всего дерева экрана.

### Feature 8: `logout_splash_flow` (Milestone M4)
- **Category-Partition**:
  - *Инициатор*: нажатие на кнопку выхода на экране профиля или программный `session.logout()`.
  - *Поведение SplashGate*:
    - Метод `SplashGate.reset()` переводит `state` в `false`.
    - Реактивный провайдер `splashFinishedProvider` оповещает роутер.
    - Очищаются токены сессии (`SessionController.logout()`).
  - *Маршрутизация*:
    - Немедленный переход на `/splash`.
    - Показ анимации сплэша.
    - По завершении (`SplashGate.complete()`) — автоматический редирект на `/auth/phone`.
- **BVA**:
  - Время показа сплэша: сокращенное при `disableAnimations` (1 ms) и стандартное.
  - Повторный вызов `reset()` при уже сброшенном флаге: идемпотентность.
- **Pairwise**:
  - Logout из вкладки Profile vs Logout из глубокого вложенного роута (`/rules`).
- **Workload**:
  - Серия входов и выходов: Login -> Home -> Profile -> Logout -> Splash -> Phone -> Repeat. Отсутствие утечек памяти и задваивания слушателей.

### Feature 9: `backend_1c_integration_report` (Milestone M5)
- **Category-Partition**:
  - Наличие файла `AUDIT_INTEGRATION_1C_BACKEND.md` в корне репозитория.
  - Полнота разделов: аудит FastAPI backend, аудит 1C HTTP REST-сервиса, матрица эндпоинтов, рекомендации по архитектуре.
- **BVA**:
  - Объем документа (> 500 строк детального анализа), наличие таблиц маппинга полей моделей Payk <-> 1С.
- **Verification**:
  - Автоматическая валидация наличия файла и ключевых разделов.

### Feature 10: `e2e_verification_analyze` (Milestone M6)
- **Category-Partition**:
  - `flutter analyze` завершается с кодом 0 (No issues found).
  - `flutter test` завершается со всеми успешно пройденными тестами (100% pass rate).
- **BVA**:
  - Число ошибок/предупреждений: строго 0.
- **Workload**:
  - Полный параллельный прогон всего тестового набора.

---

## 3. Таблица Pairwise-комбинаций для Навигации и Сессии

| Тест-кейс ID | Авторизация (`loggedIn`) | Onboarding Seen | Splash Intro Done | Текущий URL | Ожидаемый редирект URL |
|---|---|---|---|---|---|
| `TC-NAV-01` | False | False | False | `/` | `/splash` |
| `TC-NAV-02` | False | False | True | `/splash` | `/onboarding` |
| `TC-NAV-03` | False | True | True | `/onboarding` | `/auth/phone` |
| `TC-NAV-04` | False | True | True | `/home` (несанкц.) | `/auth/phone` |
| `TC-NAV-05` | True | True | True | `/auth/phone` | `/home` |
| `TC-NAV-06` | True | True | True | `/splash` | `/home` |
| `TC-NAV-07` | True -> False (Logout) | True | True -> False (`reset`) | `/profile` | `/splash` -> `/auth/phone` |
| `TC-NAV-08` | True | True | True | `/categories` | `/categories` (ветка 1) |
| `TC-NAV-09` | True | True | True | `/profile` | `/profile` (ветка 2) |

---

## 4. Спецификация тестовых файлов

| Файл теста | Проверяемые фичи | Назначение и проверяемые свойства |
|---|---|---|
| `test/udc_theme_test.dart` | F1, F2 | Токены `PaykColors` (primary `#6248EE`, header gradient, canvas, tile, activePill, border), типографика Manrope, стили кнопок и полей ввода. |
| `test/udc_navigation_test.dart` | F3, F4 | Ровно 3 вкладки бара, правильные иконки (`home_rounded`, `search_rounded`/`grid_view_rounded`, `person_rounded`), активная капсула `#EDEAFB`, переключение роутов `/home`, `/categories`, `/profile`. |
| `test/splash_logout_test.dart` | F8, F4 | Логика `SplashGate.reset()`, реактивность `splashFinishedProvider`, перенаправление со страницы профиля на сплэш и затем на `/auth/phone`. |
| `test/udc_screens_structure_test.dart` | F5, F6, F7 | Структура и компоненты экранов Home (хедер, QR, Новые компании), Categories (строка поиска, карта, 3-колоночная сетка 18 категорий), Profile (карточки пользователя, контактов, способов входа, удаление аккаунта). |

---

## 5. Команды запуска и валидации

```bash
# 1. Запуск статического анализатора кода
flutter analyze

# 2. Запуск полного набора unit и widget тестов
flutter test

# 3. Таргетированный запуск тестов UDC
flutter test test/udc_theme_test.dart
flutter test test/udc_navigation_test.dart
flutter test test/splash_logout_test.dart
flutter test test/udc_screens_structure_test.dart
```

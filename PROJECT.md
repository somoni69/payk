# Project: Payk Mobile App — UDC Redesign & Ecosystem 1C Audit

## Architecture
- **Framework**: Flutter 3.x (Dart ^3.13.2)
- **State Management**: Flutter Riverpod ^3.4.3
- **Routing**: GoRouter ^18.1.2 (StatefulShellRoute с 3 ветками: `/home`, `/categories`, `/profile`)
- **Typography**: Manrope (Regular 400, Medium 500, SemiBold 600, Bold 700)
- **Design System Style**: UDC Design System (чистый, плоский enterprise-дизайн, без глассморфизма/неона):
  - Primary Purple: `#6248EE`
  - Header Gradient: `#9F72E7` -> `#8574E6`
  - Canvas & Cards: `#FFFFFF`
  - Category Tile Background: `#F8F9FD`
  - Active Tab Pill: `#EDEAFB`
  - Border: `#EFF0F2` (1 dp)
  - Screen Padding: 20 dp, Card Radius: 16 dp, Header Bottom Radius: 24 dp, Active Nav Capsule: 18 dp
- **Network / API**: `ApiClient` (`http: ^1.5.0`) с JWT Bearer auth и авторефрешем через `/refresh`
- **Backend Ecosystem**: FastAPI + PostgreSQL (`C:\Users\Farzod\Payk-Ecosystem`), 1C HTTP REST сервис

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | `udc_theme_tokens` | Цветовая палитра UDC, типографика Manrope, стили карточек и радиусы | M1 | survey_udc_specs |
| 2 | `cleanup_legacy_design` | Удаление устаревших компонентов (`_StatusCard`, глассморфизм `_GlassBar`, старые цвета) | M1 | survey_mobile_app |
| 3 | `udc_bottom_nav_bar` | 3-кнопочный Bottom App Bar (Главный, Категории, Профиль) с лавандовой капсулой `#EDEAFB` | M1 | survey_udc_specs, R2 |
| 4 | `router_adaptation_3tabs` | GoRouter на 3 StatefulShellBranch (`/home`, `/categories`, `/profile`) с push-маршрутами | M1 | survey_mobile_app, R2 |
| 5 | `home_screen_udc` | Главный экран: фиолетовый хедер, аватар, сканер, колокольчик, карточки QR/Компании/Сертификаты, Новые компании | M2 | survey_udc_specs, R1 |
| 6 | `categories_search_screen_udc` | Экран категорий и поиска: строка поиска с картой, 3-колоночная сетка 18 категорий, фильтры | M3 | survey_udc_specs, R1 |
| 7 | `profile_screen_udc` | Экран профиля: хедер с логаутом, аватар с фото, карточка «Пользователь» с ФИО, Контакты, Вход, Удаление аккаунта | M4 | survey_udc_specs, R1 |
| 8 | `logout_splash_flow` | Splash Screen при выходе: сброс `SplashGate.reset()`, очистка сессии, показ сплэша перед `/auth/phone` | M4 | survey_mobile_app, R4 |
| 9 | `backend_1c_integration_report` | Официальный markdown-отчет об интеграции мобильного приложения с Payk-Ecosystem и 1С | M5 | survey_backend_1c, R3 |
| 10 | `e2e_verification_analyze` | Комплексная проверка: `flutter analyze` (0 issues), unit/widget тесты, приемочные сценарии | M6 | ORIGINAL_REQUEST |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | UDC Design System, Theme Tokens & 3-Tab Shell Router | `lib/core/theme/`, `lib/core/widgets/payk_shell.dart`, `lib/app/router.dart` | none | DONE |
| M2 | Home Screen (UDC Style) | `lib/features/home/home_screen.dart`, карточки действий, блок «Новые компании» | M1 | DONE |
| M3 | Categories & Search Screen (UDC Style) | `lib/features/categories/categories_screen.dart`, поиск, сетка категорий | M1 | DONE |
| M4 | Profile Screen (UDC Style) & Splash on Logout | `lib/features/profile/profile_screen.dart`, `SplashGate.reset()`, логаут | M1 | DONE |
| M5 | Backend Payk-Ecosystem & 1C Integration Audit Report | `AUDIT_INTEGRATION_1C_BACKEND.md` в корне репозитория | none | DONE |
| M6 | Final Integration & E2E Acceptance Testing | Полный прогон `flutter analyze`, тестов и проверка приемочных критериев | M1, M2, M3, M4, M5 | DONE |

## Interface Contracts
### Shell Navigation ↔ Screens
- Route `/home`: `HomeScreen` (ветка 0, иконка `Icons.home_rounded`)
- Route `/categories`: `CategoriesScreen` (ветка 1, иконка `Icons.grid_view_rounded`)
- Route `/profile`: `ProfileScreen` (ветка 2, иконка `Icons.person_rounded`)
- Push routes: `/code` (QR код кассира), `/history` (история начислений), `/friends` (рефералы), `/rules` (правила программы)

### SessionController & SplashGate ↔ Logout Navigation
- `SplashGate`:
  - `bool get introDone`
  - `void reset()`: сбрасывает `introDone = false`
  - `void complete()`: выставляет `introDone = true`
- `SessionController.logout()`:
  - очищает токены
  - вызывает `SplashGate.reset()`
  - перенаправляет на `/splash`
  - `SplashScreen` по таймеру (1.2с) вызывает `SplashGate.complete()`, после чего роутер перенаправляет на `/auth/phone`

## Code Layout
- `lib/core/theme/`:
  - `payk_colors.dart`: палитра UDC (primary `#6248EE`, header `#9F72E7`->`#8574E6`, canvas `#FFFFFF`, tile `#F8F9FD`, pill `#EDEAFB`, border `#EFF0F2`)
  - `payk_theme.dart`: ThemeData с Manrope, без устаревших компонентов
- `lib/core/widgets/`:
  - `payk_shell.dart`: 3-кнопочный `_UdcBottomBar`
- `lib/app/`:
  - `router.dart`: StatefulShellRoute на 3 ветки (`/home`, `/categories`, `/profile`)
- `lib/features/home/`:
  - `home_screen.dart`: UDC стиль, шапка, аватар, сканер, колокольчик, карточки QR/Компании/Сертификаты, Новые компании
- `lib/features/categories/`:
  - `categories_screen.dart`: строка поиска, сетка 3 колонок, 18 категорий
- `lib/features/profile/`:
  - `profile_screen.dart`: AppBar с выходом, аватар с фото, карточка «Пользователь», Контакты, Способы входа, Удаление аккаунта
- `lib/features/auth/`:
  - `splash_screen.dart`: поддержка сброса и показа при логауте
- `AUDIT_INTEGRATION_1C_BACKEND.md`:
  - Полный markdown-отчет об интеграциях мобильного приложения с бэкендом Payk-Ecosystem и 1С

## 1.Architecture design
```mermaid
graph TD
  A["User Device"] --> B["Flutter App (Material)"]
  B --> C["UI Component Layer"]
  B --> D["State Management (Provider)"]
  B --> E["HTTP Client (package:http)"]
  E --> F["External API Endpoint"]

  subgraph "Frontend Layer"
    B
    C
    D
    E
  end

  subgraph "External Services"
    F
  end
```

## 2.Technology Description
- Frontend: Flutter (Dart SDK >=3.3) + Material 3 + go_router + provider
- Backend: None (direct HTTP calls from app)

## 3.Route definitions
| Route | Purpose |
|-------|---------|
| /login | Login screen (form + submission feedback) |
| /api-test | API testing screen (request builder + response viewer) |

## 6.Data model(if applicable)
Not required for this UI/UX improvement scope (no new data entities).

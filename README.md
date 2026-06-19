# ARS Mobile — Cliente Flutter del Sistema de Auxilio Mecánico y Gestión de Talleres

**Sistemas de Información II — Universidad Autónoma Gabriel René Moreno (UAGRM)**

## Entregables

| Recurso | Enlace |
|---|---|
| Repositorio público | https://github.com/InformationSystem2/auto-repair-shop-flutter |
| Aplicacion apk | https://github.com/InformationSystem2/auto-repair-shop-flutter/blob/main/auxilio-mecanico.apk |

---

## Información del Proyecto

Este directorio contiene la aplicación móvil de **ARS (Auto Repair Shop — Sistema de Auxilio Mecánico y Gestión de Talleres)**, desarrollada utilizando **Flutter (Dart)** y estructurada bajo el patrón de arquitectura limpia por capas y gestor de estado reactivo **Provider**.

La aplicación móvil está orientada a la asistencia en carretera y la operación de técnicos mecánicos, proporcionando capacidades críticas en movilidad:
* **Seguimiento Geográfico en Tiempo Real**: Visualización interactiva sobre mapas mediante **flutter_map** y transmisión constante de coordenadas por GPS con **geolocator**.
* **Gestión de Incidentes de Auxilio**: Permite a los clientes reportar incidentes con fotos/ubicación, y a los técnicos postular ofertas y ver la ruta de asistencia en el mapa.
* **Mensajería Push**: Integración nativa con **Firebase Cloud Messaging (FCM)** para recibir alertas inmediatas de nuevas ofertas, incidentes asignados o estados de pago.

---

## Arquitectura de Flujo de Datos

```
   Arranca la App (main.dart) 
          │  
          ▼
   Splash / NavigationGate ──► Verifica JWT y sesión activa en Storage
          ├── Autenticado: Redirige al Dashboard/Home
          └── No Autenticado: Redirige a LoginScreen
          
   Localización en Carretera (Segundo Plano) 
          │  
          ▼
   Geolocator API ──► Obtiene coordenadas GPS del dispositivo móvil
          │
          ▼
   Dio Client ──► Envía actualizaciones por HTTP/WebSockets al Backend
```

---

## Estructura del Proyecto

```
auto-repair-shop-flutter/
├── lib/
│   ├── core/                       # Núcleo del sistema móvil
│   │   ├── config/                 # Configuración de API y variables globales
│   │   ├── models/                 # Modelos de datos del dominio
│   │   ├── providers/              # Gestión de estado (AuthProvider, IncidentProvider, etc.)
│   │   ├── services/               # Clientes HTTP (Dio) y geolocalización
│   │   ├── storage/                # Almacenamiento local (SharedPreferences)
│   │   └── theme/                  # Estilos visuales globales de la App (Inter Font)
│   │
│   ├── features/                   # Módulos y Casos de Uso (CU)
│   │   ├── auth/                   # Pantalla de login e inicio de sesión
│   │   ├── dashboard/              # Métricas rápidas para mecánicos o clientes
│   │   ├── home/                   # Panel principal y navegación
│   │   ├── incidents/              # Creación de reportes de auxilio, ofertas y mapa activo
│   │   ├── notifications/          # Historial y gestión de alertas push
│   │   ├── profile/                # Perfil de usuario, configuración e información del taller
│   │   ├── register/               # Formularios de onboarding de clientes y talleres
│   │   ├── splash/                 # Pantalla de carga inicial
│   │   ├── technician/             # Administración de mecánicos y servicios asignados
│   │   └── vehicles/               # Registro y control de automóviles del cliente
│   │
│   ├── shared/                     # Componentes y widgets reutilizables de UI
│   ├── app.dart                    # Configuración de MaterialApp y enrutamiento global
│   └── main.dart                   # Inicialización de servicios y Providers de la App
│
├── assets/                         # Logotipos y recursos de imagen estáticos
├── .env                            # Archivo de configuración de variables de entorno
├── pubspec.yaml                    # Gestión de dependencias y assets de Flutter
└── README.md
```

---

## Tecnologías

### Core & Framework
| Tecnología | Versión | Uso |
|---|---|---|
| Flutter SDK | ^3.5.x | Framework multiplataforma principal para iOS y Android |
| Dart | ^3.x | Lenguaje de programación nativo optimizado para UI |
| Provider | ^6.1.x | Gestor de estado estructurado y reactivo |

### Geolocalización, Integración y Media
| Tecnología | Versión | Uso |
|---|---|---|
| Dio | ^5.4.x | Cliente HTTP avanzado para peticiones REST seguras |
| Flutter Map | ^8.1.x | Componente para el renderizado interactivo de mapas OpenStreetMap |
| Geolocator | ^14.0.x | Integración con el GPS nativo del dispositivo para el auxilio mecánico |
| Firebase Messaging | ^15.0.x | Recepción y procesamiento de notificaciones push |
| Image Picker | ^1.0.x | Captura fotográfica con la cámara móvil para reportar incidentes |

---

## Instalación y Ejecución

### 1. Requisitos Previos
* Flutter SDK (v3.5.x o superior) configurado.
* Dispositivo móvil físico o emulador (Android SDK / iOS Xcode) configurado.

### 2. Configurar Variables de Entorno
Cree un archivo `.env` en el directorio raíz del proyecto:

```env
API_BASE_URL=http://localhost:8000/api
```

### 3. Compilar e Iniciar la Aplicación

Obtener las dependencias del proyecto:
```bash
flutter pub get
```

Iniciar la aplicación en su emulador o dispositivo físico conectado:
```bash
flutter run
```

---

## Pantallas Principales / Casos de Uso

| Pantalla | Caso de Uso / Flujo | Descripción |
|---|---|---|
| `LoginScreen` | CU01 - Autenticación | Inicio de sesión, control de token y redirección según rol |
| `IncidentMap` | CU02 - Asistencia | Visualización interactiva de vehículos de asistencia en el mapa |
| `IncidentRequest` | CU03 - Registro | Permite al usuario crear una solicitud de auxilio adjuntando geolocalización y foto |
| `OfferSubmission` | CU06 - Cotizaciones | Pantalla para que los mecánicos envíen ofertas de solución con tarifas |
| `ProfileScreen` | Cuenta | Gestión de perfil, vehículos del cliente y especialidades del técnico |

---

## Módulo de Seguridad y Persistencia

### Token Bearer y Persistencia
Al autenticarse, la app almacena localmente el token JWT de forma encriptada en la persistencia nativa con `shared_preferences`. Todas las llamadas posteriores inyectan automáticamente el token en los encabezados HTTP a través de interceptores personalizados en el cliente `Dio`.

### Geolocalización Segura y Background
El rastreo de ubicación del técnico requiere permisos explícitos del sistema operativo. La geolocalización de incidentes se realiza de manera controlada y solo transmite información de posicionamiento cuando existe un incidente de auxilio activo asignado al técnico mecánico.

---

## Por qué control de accesos a nivel de atributos y no de endpoints simple

| Tipo de Control | Permite ocultar campos sensibles | Flexibilidad por Rol | Complejidad de UI |
|---|---|---|---|
| **Control por Endpoint (`/taller/{id}`)** | No (Muestra la pantalla completa o no) | Baja | Baja |
| **Control a nivel de Atributo (ARS)** | **Sí** (Oculta precios, calificaciones o ingresos) | **Alta** (Granularidad según permisos) | Media (Widgets condicionales) |

---

## Equipo

| Integrante |
|---|
| **Evert Rodríguez Araúz** | 
| **Rojas Rivero Douglas Ismael** |

---

*Proyecto desarrollado para la materia de Sistemas de Información II — UAGRM*

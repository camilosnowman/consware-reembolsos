# Consware Reembolsos

## 1. Descripción y alcance del MVP

MVP para registrar y gestionar solicitudes de reembolso en pesos colombianos (COP). Permite crear solicitudes, consultarlas por estado o nombre de empleado, ver su detalle y decidir las que requieren revisión manual.

El proyecto se organiza en tres clientes/servicios: API en `backend/`, aplicación móvil Flutter en `mobile/` y aplicación web Angular en `web/`.

## 2. Tecnologías

- **Backend:** ASP.NET Core 8 y Entity Framework Core 8.
- **Base de datos:** SQL Server.
- **Móvil:** Flutter.
- **Web:** Angular (el proyecto actual usa Angular 22).

## 3. Requisitos previos

- .NET SDK 8.
- SQL Server disponible localmente o en red, con permisos para crear/actualizar la base de datos.
- Herramienta de EF Core: `dotnet tool install --global dotnet-ef` (si aún no está instalada).
- Flutter SDK y un emulador Android o dispositivo físico, para el cliente móvil.
- Node.js y npm, para el cliente web.

## 4. Configuración de SQL Server

Actualice la cadena de conexión `DefaultConnection` en `backend/Consware.Reimbursements.Api/appsettings.json` según su instancia de SQL Server. La configuración incluida usa esta instancia de ejemplo:

```json
"DefaultConnection": "Server=JEREMY\\MSSQLSERVER2026;Database=ConswareReembolsosDB;Trusted_Connection=True;TrustServerCertificate=True;"
```

Use el nombre de servidor, credenciales y opciones de seguridad apropiados para su entorno.

## 5. Ejecutar el backend

Desde `backend/Consware.Reimbursements.Api` ejecute:

```bash
dotnet restore
dotnet ef database update
dotnet run --urls http://0.0.0.0:5000
```

La API quedará disponible en `http://localhost:5000`; en ambiente de desarrollo también expone Swagger. La política CORS actual autoriza el frontend en `http://localhost:4200`.

## 6. Ejecutar Flutter

Cuando el cliente móvil esté disponible, desde `mobile/` ejecute:

```bash
flutter pub get
```

Antes de iniciar, configure la URL de la API en `lib/config/api_config.dart`:

- Use `10.0.2.2` si ejecuta la aplicación en el emulador Android.
- Use la dirección IP LAN de la máquina que ejecuta la API si utiliza un dispositivo físico.

Después ejecute:

```bash
flutter run
```

## 7. Ejecutar Angular

Desde `web/` ejecute:

```bash
npm install
npm start
```

La aplicación se sirve en `http://localhost:4200`.

## 8. API y reglas de negocio

Base de las rutas: `/api/reimbursements`.

| Método | Ruta | Descripción |
| --- | --- | --- |
| `POST` | `/api/reimbursements` | Crea una solicitud de reembolso. |
| `GET` | `/api/reimbursements?status={status}&employeeName={employeeName}` | Lista solicitudes, con filtros opcionales `status` y `employeeName`. |
| `GET` | `/api/reimbursements/{id}` | Obtiene el detalle de una solicitud. |
| `PATCH` | `/api/reimbursements/{id}/approve` | Aprueba una solicitud pendiente. |
| `PATCH` | `/api/reimbursements/{id}/reject` | Rechaza una solicitud pendiente; recibe `{ "reason": "..." }`. |

Reglas implementadas:

- Un monto menor o igual a **500.000 COP** se aprueba automáticamente al crearse.
- Un monto superior a **500.000 COP** queda en estado `Pending` hasta una decisión manual.
- El rechazo requiere un motivo no vacío.
- `Approved` y `Rejected` son estados finales: no pueden aprobarse ni rechazarse nuevamente.
- Se valida que nombre del empleado, categoría y descripción sean obligatorios, y que el monto sea mayor que cero.
- La API utiliza `400` para datos inválidos, `404` para solicitudes inexistentes y `409` para intentos de modificar una solicitud que ya tiene decisión final.

## 9. Decisiones técnicas

- La API usa controladores ASP.NET Core y DTOs para separar el contrato HTTP de las entidades de persistencia.
- La lógica de negocio está encapsulada en `ReimbursementService`; el controlador se limita a traducir resultados a respuestas HTTP.
- EF Core con el proveedor de SQL Server persiste las solicitudes y cuenta con una migración inicial.
- Las fechas se almacenan en UTC (`CreatedAtUtc` y `DecidedAtUtc`).
- El listado se ordena por fecha de creación descendente y admite filtrado por estado y coincidencia en el nombre de empleado.
- CORS se restringe al origen local del cliente Angular durante desarrollo.

## 10. Fuera de alcance por tiempo

El MVP no incluye autenticación ni autorización por roles, adjuntos/soportes de gasto, notificaciones, auditoría detallada, paginación, pruebas automatizadas completas, ni despliegue productivo.

En una siguiente iteración se resolvería con autenticación basada en JWT y roles, almacenamiento de archivos en un servicio de objetos, eventos o colas para notificaciones, trazabilidad de cambios, paginación y pruebas unitarias/de integración, además de configuración por ambientes y CI/CD.

## 11. Uso de IA

Se usaron asistentes de IA —Codex CLI y agentes de código opencode— para estructurar el proyecto, generar código base y revisar escenarios de prueba. El candidato verificó el funcionamiento y puede explicar y modificar cada archivo.

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
- Herramienta de EF Core: `dotnet tool install --global dotnet-ef --version 8.0.11` (si aún no está instalada; alinee la versión con los paquetes EF 8.x del proyecto).
- Flutter SDK y un emulador Android o dispositivo físico, para el cliente móvil.
- Node.js `^22.22.3`, `^24.15.0` o `>=26.0.0` y npm, para el cliente web (requisitos de Angular 22).

## 4. Configuración de SQL Server

Actualice la cadena de conexión `DefaultConnection` en `backend/Consware.Reimbursements.Api/appsettings.json` según su instancia de SQL Server. La configuración incluida usa esta instancia de ejemplo:

```json
"DefaultConnection": "Server=JEREMY\\MSSQLSERVER2026;Database=ConswareReembolsosDB;Trusted_Connection=True;TrustServerCertificate=True;"
```

Use el nombre de servidor, credenciales y opciones de seguridad apropiados para su entorno.

Si su SQL Server usa usuario/contraseña (por ejemplo SQL Server en Docker), hay una plantilla en `backend/Consware.Reimbursements.Api/appsettings.Development.example.json`: copie ese archivo como `appsettings.Development.json` y escriba ahí su contraseña (ese archivo no se versiona, está en .gitignore).

## 5. Ejecutar el backend

Desde `backend/Consware.Reimbursements.Api` ejecute:

```bash
dotnet restore
dotnet ef database update
dotnet run --urls http://0.0.0.0:5000
```

La API quedará disponible en `http://localhost:5000`; en ambiente de desarrollo también expone Swagger. CORS autoriza los orígenes locales de los frontends: Angular `http://localhost:4200` y, para pruebas de Flutter web, `4201`/`4202`.

## 6. Ejecutar Flutter

Desde `mobile/` (cliente móvil del empleado) ejecute:

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
npm ci
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
- El monto admite hasta dos decimales y un máximo de `9999999999999999.99` COP. Se rechaza la precisión adicional con `400`, en lugar de redondear antes de guardarlo.
- Después de quitar espacios al inicio y al final, el nombre admite 100 caracteres; la categoría 60; la descripción y el motivo de rechazo 500 cada uno.
- La API utiliza `400` para datos inválidos, `404` para solicitudes inexistentes y `409` para intentos de modificar una solicitud que ya tiene decisión final.

## 9. Decisiones técnicas

- La API usa controladores ASP.NET Core y DTOs para separar el contrato HTTP de las entidades de persistencia.
- La lógica de negocio está encapsulada en `ReimbursementService`; el controlador se limita a traducir resultados a respuestas HTTP.
- EF Core con el proveedor de SQL Server persiste las solicitudes y cuenta con una migración inicial.
- Las fechas se almacenan en UTC (`CreatedAtUtc` y `DecidedAtUtc`) y las respuestas JSON indican UTC con el sufijo `Z`, también al consultar registros ya guardados.
- El listado se ordena por fecha de creación descendente y admite filtrado por estado y coincidencia en el nombre de empleado.
- CORS permite los orígenes locales documentados de Angular y Flutter web durante desarrollo.

## 10. Fuera de alcance por tiempo

El MVP no incluye autenticación ni autorización por roles, adjuntos/soportes de gasto, notificaciones, auditoría detallada, paginación, pruebas automatizadas completas, ni despliegue productivo.

En una siguiente iteración se resolvería con autenticación basada en JWT y roles, almacenamiento de archivos en un servicio de objetos, eventos o colas para notificaciones, trazabilidad de cambios, paginación y mayor cobertura de pruebas, además de configuración por ambientes y CI/CD.

## 11. Pruebas y compilación

Con SQL Server y la API en ejecución, desde la raíz del repositorio:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_api_tests.ps1
```

Se puede usar otra instancia de la API con `-BaseUrl http://localhost:5098`. La suite crea solicitudes de prueba en la base configurada; imprime los casos y termina con código distinto de cero si alguno falla. Los detalles y casos de borde están en `tests/README.md`.

Comprobaciones independientes de los clientes y del backend, desde sus respectivas carpetas:

```powershell
# backend/Consware.Reimbursements.Api
dotnet build -c Release

# mobile
flutter pub get
flutter analyze
flutter test
flutter build web

# web
npm ci
npm test -- --watch=false
npm run build
```

Los resultados ejecutados y los límites de verificación de la entrega se registran en `CHECKLIST_ENTREGA.md`. Una compilación o una prueba con servicio simulado no sustituye una ejecución en un dispositivo Android.

En la revisión del 6 de noviembre de 2026 se aprobaron **28/28 casos HTTP contra SQL Server**, **18/18 pruebas Flutter** y **16/16 pruebas Angular**. También se compilaron los tres proyectos y el APK Android, y se comprobó con Playwright el recorrido de crear en Flutter web, decidir desde Angular y consultar el resultado y el motivo en Flutter. Los detalles del entorno y la persistencia tras reiniciar la API están en el checklist.

## 12. Paquete de entrega

Desde la raíz, ejecute `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\empaquetar.ps1`. El ZIP conserva la carpeta raíz `consware-reembolsos/` e incluye los archivos versionados permitidos. Excluye configuraciones privadas, archivos de IDE, resultados de compilación y material personal de estudio.

## 13. Uso de IA

Se usaron asistentes de IA —Codex y agentes de código OpenCode— para estructurar el proyecto, generar código base, revisar escenarios y corregir errores. Las comprobaciones ejecutadas y sus límites están documentados en `CHECKLIST_ENTREGA.md`.

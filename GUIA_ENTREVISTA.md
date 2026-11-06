# Guía de entrevista — Consware Reembolsos

Esta guía ayuda a explicar el MVP con precisión. Las referencias corresponden al código que existe en este repositorio.

## 1. Arquitectura en cuatro capas

El recorrido de una solicitud es:

`Flutter / Angular -> Controller -> Service -> EF Core -> SQL Server`

1. **Clientes (Flutter y Angular).** Son dos interfaces para roles y dispositivos distintos: Flutter registra y consulta solicitudes del empleado; Angular permite revisar pendientes y decidirlas. Ambos consumen el mismo contrato HTTP `/api/reimbursements`. Referencias: `mobile/lib/services/reimbursement_api_service.dart` y `web/src/app/services/reimbursement.service.ts`.
2. **Controller.** `Controllers/ReimbursementsController.cs` recibe HTTP, enlaza DTOs, valida el formato del filtro `status` y traduce el resultado del servicio a códigos HTTP (`201`, `200`, `400`, `404`, `409`). Su responsabilidad es el protocolo, no la política del negocio.
3. **Service.** `Services/ReimbursementService.cs` concentra las reglas: validaciones, límite de autoaprobación, transiciones de estado y motivo de rechazo. Separarlo hace que esas reglas se reutilicen y se prueben sin depender de HTTP. La interfaz `Services/IReimbursementService.cs` expresa ese contrato y `Services/ServiceResult.cs` permite devolver éxito o error de dominio al controller.
4. **Persistencia (EF Core sobre SQL Server).** `Data/AppDbContext.cs` mapea la entidad `Models/ReimbursementRequest.cs` a la tabla `ReimbursementRequests`; EF Core transforma consultas y cambios en SQL para SQL Server. `Program.cs` registra el contexto con `UseSqlServer`. Así el modelo de negocio no contiene SQL manual y los detalles de almacenamiento quedan aislados.

En términos prácticos, EF Core es el adaptador de persistencia y SQL Server es el motor final: por eso aparecen como dos pasos en el diagrama, aunque pertenecen a la misma capa de datos.

## 2. Diez preguntas típicas y respuestas cortas

1. **¿Por qué SQL Server y no otro motor?** Para un MVP .NET es una elección natural por la integración oficial con EF Core (`UseSqlServer`), tipos monetarios y migraciones. No es un requisito universal: PostgreSQL sería una alternativa válida si el contexto operativo o de costos lo favoreciera.

2. **¿Por qué separar el service del controller?** El controller debe manejar HTTP; el service debe proteger las reglas de negocio. `ReimbursementService.cs` evita duplicar o saltarse la política si en el futuro se agrega otro consumidor, un job o un endpoint.

3. **¿Por qué una sola tabla sin FK a Users?** El alcance es un MVP sin autenticación ni catálogo de usuarios. Por eso se guarda `EmployeeName` como dato de la solicitud y se evita introducir usuarios, roles y ciclos de vida que aún no existen. Con identidad real, se agregaría `UserId` con FK y se conservaría el nombre como dato histórico si hiciera falta.

4. **¿Por qué no microservicios?** Hay un único dominio pequeño, una base de datos y un equipo/flujo sencillo. Un monolito modular reduce despliegues, observabilidad, latencia y consistencia distribuida. Se dividiría cuando aparezcan límites de dominio y necesidades de escalado independientes demostrables.

5. **¿Cómo se implementa la regla de 500.000 COP?** En `CreateAsync` de `Services/ReimbursementService.cs`, `AutoApprovalLimit` vale `500000m`: si `Amount <= 500000m`, crea `Approved` y registra `DecidedAtUtc`; si es mayor, crea `Pending` sin fecha de decisión.

6. **¿Por qué el rechazo exige motivo?** Porque una decisión negativa debe ser explicable para el empleado y útil para seguimiento. `RejectAsync` rechaza un motivo nulo, vacío o con solo espacios con `400`, y guarda el texto normalizado en `RejectionReason`.

7. **¿Cómo se evita cambiar un estado final?** Antes de aprobar o rechazar, el service exige `Status == Pending`. Si ya está `Approved` o `Rejected`, devuelve `Conflict`; `ReimbursementsController.cs` lo convierte en HTTP `409`.

8. **¿Por qué `DECIMAL(18,2)`?** El dinero no debe representarse con punto flotante binario. `AppDbContext.cs` configura `decimal(18,2)` y precisión `18,2`, suficiente para COP con dos decimales de almacenamiento y sin errores de redondeo típicos de `float` o `double`.

9. **¿Cómo comparten Flutter y Angular la misma API?** Comparten rutas, JSON y códigos HTTP, no código de interfaz. Flutter configura la base en `mobile/lib/config/api_config.dart`; Angular usa la misma ruta en `web/src/app/services/reimbursement.service.ts`. Cada cliente adapta la URL a su entorno (por ejemplo, `10.0.2.2` en emulador Android) y consume los mismos DTOs expuestos por `Dtos/Dtos.cs`.

10. **¿Qué mejoraría en producción?** JWT y roles; `rowversion` para concurrencia optimista; carga de recibos en almacenamiento de objetos; auditoría de cambios; pruebas unitarias, de integración y end-to-end; CI/CD; y caché donde las lecturas lo justifiquen. También agregaría paginación, configuración por ambientes y observabilidad. Son mejoras posteriores al alcance actual, no funcionalidades que el MVP ya prometa.

## 3. Matriz de pruebas T01–T16

La matriz ejecutable está en `tests/run_api_tests.ps1`. Es una prueba de aceptación de la API: crea datos propios por ejecución, valida HTTP y, cuando aplica, el estado devuelto.

- **T01:** crea un reembolso de `100000`; espera `201` y `Approved`.
- **T02:** prueba el límite exacto: `500000`; espera `201` y `Approved`. El caso confirma que la comparación es inclusiva (`<=`).
- **T03:** prueba el primer peso por encima del límite: `500001`; espera `201` y `Pending`.
- **T04:** monto `0`; espera `400`.
- **T05:** monto negativo; espera `400`.
- **T06:** descripción en blanco; espera `400`.
- **T07:** categoría vacía; espera `400`.
- **T08:** consulta el id inexistente `999999`; espera `404`.
- **T09:** lista con `status=Pending`; espera `200` y solo elementos pendientes.
- **T10:** filtra por `employeeName`; espera `200` y solo el empleado solicitado.
- **T11:** combina `status=Pending` y nombre; espera `200` y elementos que satisfacen ambos filtros.
- **T12:** aprueba la solicitud pendiente creada en T03; espera `200` y `Approved`.
- **T13:** crea otra pendiente y la rechaza con `Soporte insuficiente`; espera `200` y `Rejected`.
- **T14:** intenta rechazar una pendiente con motivo en blanco; espera `400`.
- **T15:** intenta aprobar por segunda vez una solicitud ya aprobada; espera `409`.
- **T16:** intenta rechazar por segunda vez una solicitud ya rechazada; espera `409`.

Los casos límite más importantes para decir en entrevista son **500.000 COP = aprobada** y **500.001 COP = pendiente**. Juntos demuestran que la frontera de la regla está intencionalmente cubierta, no solo el caso promedio.

Para ejecutarla, se inicia la API y luego se ejecuta `./tests/run_api_tests.ps1`, como documenta `tests/README.md`. El estado de partida informado para esta entrega es 16/16 pruebas aprobadas.

## 4. Flujo demostrable end-to-end

1. Iniciar SQL Server y configurar `DefaultConnection` en `backend/Consware.Reimbursements.Api/appsettings.json`. Ejecutar la API según `README.md`; en desarrollo Swagger queda disponible y el backend escucha en el puerto `5000`.
2. Levantar Angular con `npm start` en `web/`. Su servicio consulta pendientes y usa `PATCH /{id}/approve` o `PATCH /{id}/reject`; la vista está en `web/src/app/features/approvals/approvals.component.ts`.
3. Levantar Flutter o usar su emulador con la URL indicada en `mobile/lib/config/api_config.dart`. En la pantalla de creación, registrar dos solicitudes para el mismo empleado: una de `500000` y otra de `500001` COP.
4. Mostrar en Flutter que la primera aparece aprobada automáticamente y que la segunda queda pendiente; el cliente obtiene el listado con el filtro `employeeName`.
5. Cambiar a Angular, filtrar por pendientes y localizar la solicitud de `500001`. Aprobarla para mostrar la transición a `Approved` y la actualización del listado.
6. Crear otra solicitud mayor de `500000` y rechazarla desde Angular, escribiendo un motivo. Volver a Flutter y mostrar el estado `Rejected` y `rejectionReason` en el historial.
7. Como cierre técnico, intentar repetir una decisión sobre una solicitud final: la API responde `409`, demostrando que el servidor —no solo la interfaz— protege la transición de estados.

La trazabilidad del recorrido es clara: el cliente envía el DTO, `ReimbursementsController.cs` delega, `ReimbursementService.cs` aplica la regla, `AppDbContext.cs` persiste y el mismo recurso JSON vuelve a cualquiera de los dos clientes.

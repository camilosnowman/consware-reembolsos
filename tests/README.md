# Pruebas de aceptación de la API

Suite HTTP de caja negra contra la API real y SQL Server real. No usa EF InMemory
ni simula la base de datos: valida el contrato JSON, los códigos HTTP y lo que
quedó persistido.

## Requisitos

- .NET 8 SDK.
- Una instancia de SQL Server accesible con el esquema de
  `backend/Consware.Reimbursements.Api/Migrations` aplicado.
- Cadena de conexión configurada fuera del repositorio (por ejemplo en
  `appsettings.Development.json`, variables de entorno o user-secrets). No se
  incluyen credenciales en este documento.
- PowerShell 5.1 o superior.

Si aún no existe el esquema, aplícalo con la migración ya versionada (requiere
`dotnet-ef`):

```powershell
dotnet ef database update --project backend/Consware.Reimbursements.Api
```

No hay migraciones nuevas para este cambio: las fechas se re-etiquetan como UTC
al construir el DTO, sin tocar columnas.

## Ejecutar

1. Inicia la API desde la raíz del repositorio:

   ```powershell
   dotnet run --project backend/Consware.Reimbursements.Api --urls http://localhost:5000
   ```

2. En otra terminal, desde la raíz del repositorio:

   ```powershell
   .\tests\run_api_tests.ps1
   ```

   Para apuntar a otra URL:

   ```powershell
   .\tests\run_api_tests.ps1 -BaseUrl http://localhost:5001
   ```

La suite hace un único prechequeo `GET /api/reimbursements` y solo continúa si
responde `200`. Imprime `PASS`/`FAIL` con el HTTP recibido y esperado, muestra un
resumen y devuelve código `0` solo si todos los casos pasan.

## Cobertura

Casos base `T01`-`T16`:

- Creación aprobada automáticamente (`<= 500000`) y pendiente (`> 500000`).
- Montos `0` y negativos, descripción y categoría vacías: `400`.
- `GET` inexistente: `404`.
- Filtros por `status`, por `employeeName` y combinados.
- Aprobar y rechazar una solicitud pendiente.
- Rechazo sin motivo: `400` y la solicitud permanece `Pending`.
- Inmutabilidad: segundo `approve`/`reject` responde `409` y el estado, el motivo
  y `decidedAtUtc` no cambian.

Casos de regresión `R01`-`R12`:

- `R01`/`R02`: montos con tres decimales (`0.001`, `500000.001`) se rechazan con
  `400`; no se redondean.
- `R03`: `500000.01` queda `Pending` (justo por encima del tope).
- `R04`: `9999999999999999.99` (máximo de `decimal(18,2)`) se acepta como
  `Pending`.
- `R05`: `10000000000000000.00` supera el rango y responde `400`.
- `R06`-`R09`: nombre de 101, categoría de 61, descripción de 501 y motivo de
  rechazo de 501 caracteres responden `400`; el rechazo inválido deja la
  solicitud `Pending`.
- `R10`/`R11`: `status=999` y `status=NoExiste` responden `400` (solo se aceptan
  valores definidos del enumerador).
- `R12`: `createdAtUtc` y `decidedAtUtc` se serializan en UTC con sufijo `Z`.

Los montos extremos de `R01`-`R05` se envían como literal JSON (no se convierten
a `double` en PowerShell), para que la precisión llegue intacta al `decimal` de
C#.

## Datos que crea

Cada ejecución genera un identificador aleatorio (`runId`) y lo usa en los
nombres de empleado, de modo que los filtros no dependan de ejecuciones previas.
La suite inserta solicitudes reales: aprobadas, pendientes y rechazadas, incluida
una con el monto máximo. La API no expone `DELETE`, así que esos registros
permanecen en la base; se pueden eliminar manualmente por el prefijo del nombre
(`Demo API <runId>`, `Pendiente API <runId>`, `Rechazo API <runId>`,
`Motivo API <runId>`, `Longitud API <runId>`, `Rango API <runId>`,
`Precision API <runId>`). No se modifican ni eliminan datos de otras
ejecuciones.

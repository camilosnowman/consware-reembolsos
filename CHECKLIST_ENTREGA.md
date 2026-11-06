# Verificación de la entrega corregida

Comprobaciones ejecutadas el **6 de noviembre de 2026** en Windows, con .NET SDK 8.0.427, Node 24.18.0, Angular 22 y Flutter 3.47.9. Los resultados corresponden a esta revisión y distinguen pruebas simuladas de integración real.

## Backend y SQL Server

- [x] `dotnet build -c Release`: **0 errores y 0 advertencias**.
- [x] `dotnet ef database update`: la instancia SQL Server existente estaba actualizada. No se necesitó una migración nueva para corregir la salida UTC.
- [x] `powershell -NoProfile -File .\tests\run_api_tests.ps1 -BaseUrl http://127.0.0.1:5098`: **28/28** casos aprobados, con un directorio `TEMP` limpio y sin depender de una carpeta de OpenCode.
- [x] T01–T16: creación, límite inclusivo de 500.000 COP, datos obligatorios, 404, filtros, aprobación, rechazo con motivo e inmutabilidad con 409.
- [x] R01–R12: precisión monetaria, máximo de `decimal(18,2)`, longitudes, estados inexistentes y fechas JSON con sufijo `Z`.
- [x] Persistencia real: después de detener y reiniciar el proceso de API de prueba, se consultaron una solicitud rechazada y otra aprobada creadas durante el recorrido de navegador; conservaron estado, motivo y fechas.

Se usó SQL Server real, sin EF InMemory. La API de verificación escuchó en el puerto 5098 para mantener separada la instancia local preexistente. Las pruebas crean solicitudes identificables; no eliminan registros anteriores. Consulte `tests/README.md` para repetir la suite.

## Clientes

- [x] `flutter analyze`: **sin observaciones**.
- [x] `flutter test`: **18/18** pruebas aprobadas, incluidos estados, motivo, recarga tras POST, lista vacía/corta, reintento y propiedad del servicio inyectado. Estas pruebas usan HTTP simulado.
- [x] `flutter build web`: compilación correcta.
- [x] `flutter build apk --release --no-pub`: compilación correcta. Se inspeccionó el APK con `aapt2 dump permissions` y contiene `android.permission.INTERNET`.
- [x] `npm test -- --watch=false`: **16/16** pruebas aprobadas, con HTTP simulado.
- [x] `npm run build`: compilación Angular correcta.
- [x] Angular conserva hasta dos decimales al mostrar un importe, de modo que `500000.01` no se presenta como `500000`.

La compilación web conserva un aviso de Flutter sobre la fuente opcional `CupertinoIcons`; no impidió el build. Esta revisión no repitió una ejecución del APK en un dispositivo ni en un emulador.

## Recorrido real con Playwright

Se controló Chrome mediante el MCP oficial de Playwright, con un perfil aislado. Los clientes se sirvieron en `localhost:4201` (Angular) y `localhost:4202` (Flutter web). El navegador redirigió las llamadas de prueba de `localhost:5000` a la API verificada en `127.0.0.1:5098`; las respuestas y la persistencia fueron reales, sin simular los datos de negocio.

- [x] Flutter creó una solicitud de 650.000 COP y la mostró automáticamente en el listado como Pendiente.
- [x] Angular la encontró con el filtro inicial Pendientes; bloqueó un motivo de espacios y permitió rechazar con un motivo válido recortado.
- [x] Flutter mostró Rechazada y el motivo guardado desde Angular.
- [x] Una segunda solicitud creada en Flutter se aprobó desde Angular, con confirmación, y Flutter mostró Aprobada.
- [x] Angular mostró `500.000,01` sin redondear el caso pendiente situado justo por encima del límite.
- [x] Ambos clientes mostraron error y reintento al interrumpir la conexión de forma controlada. Flutter recuperó datos reales al restaurar la conexión y reintentar.

## Paquete y publicación

Para regenerar y verificar el ZIP desde la raíz:

```powershell
powershell -NoProfile -File .\scripts\probar_empaquetado.ps1
```

El script realiza **7 comprobaciones**: estructura raíz, separadores portables `/`, exclusiones, completitud, ausencia de archivos adicionales, inclusión de la plantilla de configuración y ausencia de `.git`. Debe finalizar con `PRUEBAS DE EMPAQUETADO: OK` antes de publicar.

El paquete se construye desde los archivos versionados permitidos. No incluye credenciales de desarrollo, material personal de estudio, archivos de IDE, índices locales ni resultados de compilación. El SHA-256 del ZIP final se publica en las notas de la release, para no crear una referencia circular dentro del propio paquete.

## Referencias verificables del historial

- Validación y contrato API: `2482f19`, `b490eba`.
- Correcciones y pruebas Flutter: `c630955`, `629921d`.
- Panel y pruebas Angular: `8e2e6e4`, `9ed69df`, `de41fb5`.
- Empaquetado portable: `6189877`, `9ed69df`.

Se preserva el tag original `entrega-final`. La revisión corregida se identifica con una nueva release; no se reescribe el historial publicado.

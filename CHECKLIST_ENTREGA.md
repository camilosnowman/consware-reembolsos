# Checklist operativo de entrega

Referencia de verificación de API: `powershell tests/run_api_tests.ps1` — 16/16 pruebas aprobadas. El script requiere que la API ya esté escuchando en `http://localhost:5000`.

- [x] La API compila y escucha en el puerto 5000. Verificado por el prechequeo y la ejecución satisfactoria de `powershell tests/run_api_tests.ps1`.
- [x] `dotnet ef database update` crea y aplica el esquema. La migración inicial de EF Core está versionada (`02cc6ad`) y la API probada persiste contra SQL Server.
- [ ] La tabla `ReimbursementRequests` se inspeccionó visualmente en SSMS. Pendiente de comprobación manual en la instancia SQL Server de entrega.
- [x] `POST` valida los datos y aplica el límite de 500.000 COP. Cubierto por T01–T07 de `powershell tests/run_api_tests.ps1`.
- [x] `GET` lista, filtra y consulta por id con 404. Cubierto por T08–T11 de `powershell tests/run_api_tests.ps1`.
- [x] `PATCH approve/reject` opera solo sobre `Pending`: 400 para motivo inválido y 409 para estados finales. Cubierto por T12–T16 de `powershell tests/run_api_tests.ps1`.
- [ ] Flutter ejecuta el flujo completo. El flujo está implementado en el commit `bc1fb83`, pero falta una ejecución funcional registrada.
- [x] Flutter muestra el motivo de rechazo. Implementado y versionado en `bc1fb83` (`my_reimbursements_screen.dart`).
- [x] Angular filtra pendientes y permite aprobar/rechazar. Implementado en `f5d4065`; la compilación de Angular fue verificada en el estado actual del repositorio.
- [ ] Los datos persisten después de reiniciar la API. La persistencia SQL está implementada, pero falta una verificación explícita de reinicio.
- [x] El README describe la ejecución en otro equipo y el uso de IA. Verificado en el commit `6c8e23a`.
- [x] Existen commits incrementales reales. El historial contiene cambios separados de API, migración, documentación, pruebas, web y móvil.

## Pendientes manuales

1. Ejecutar `dotnet ef database update` contra la instancia de entrega y confirmar `ReimbursementRequests` en SSMS.
2. Ejecutar el flujo Flutter en emulador o dispositivo, incluida la visualización de un rechazo.
3. Reiniciar la API y confirmar que las solicitudes creadas siguen disponibles.

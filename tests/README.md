# Pruebas de aceptación de la API

Inicia primero la API desde `backend/`:

```powershell
dotnet run --urls http://0.0.0.0:5000
```

Después, desde la raíz del repositorio, ejecuta:

```powershell
.\tests\run_api_tests.ps1
```

La suite valida los casos T01 a T16, imprime `PASS` o `FAIL` con el HTTP recibido y esperado, muestra un resumen y devuelve código `0` solo si todos los casos pasan. Si la API no está disponible, termina antes de correr la matriz.

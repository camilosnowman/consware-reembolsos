NOTAS ANDROID — permisos y tráfico en texto claro (cleartext)
============================================================

El scaffold `android/` NO está incluido aún. Cuando se ejecute
`flutter create .` dentro de `mobile/` (o `flutter create mobile` desde
la raíz del repo) se generará. Entonces hay que editar:

    android/app/src/main/AndroidManifest.xml

1) Agregar el permiso de INTERNET justo antes de <application>:

    <uses-permission android:name="android.permission.INTERNET" />

2) Dentro de la etiqueta <application>, permitir tráfico HTTP en claro
   (necesario porque la API corre en http:// y no en https://):

    <application
        android:name="${applicationName}"
        android:label="consware_reimbursements"
        android:usesCleartextTraffic="true"
        ... >

Qué  y por qué
--------------
- INTERNET: sin él `http` falla con SocketException en release.
- usesCleartextTraffic: en Android 9+ el http en claro viene bloqueado
  por defecto; la API local (http://10.0.2.2:5000 o la IP LAN del PC)
  no usa TLS, así que lo habilitamos.
- Solo para desarrollo. En producción habría que usar HTTPS o una
  network security config más restrictiva.

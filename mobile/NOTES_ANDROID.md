NOTAS ANDROID — permisos y tráfico HTTP
=======================================

Estado del scaffold `android/`
------------------------------
El scaffold Android YA está incluido y versionado en el repo
(`mobile/android/`, generado con `flutter create .` desde `mobile/`).
No hay que volver a generarlo.

Permisos
--------
`android/app/src/main/AndroidManifest.xml` declara, justo antes de
`<application>`:

    <uses-permission android:name="android.permission.INTERNET" />

Los manifest de `debug/` y `profile/` también lo incluyen (la plantilla
de Flutter lo agrega para hot reload). Con esto el permiso queda
cubierto en todos los tipos de build, incluido release.

Tráfico HTTP en claro (cleartext)
---------------------------------
La API local corre en `http://` (`http://10.0.2.2:5000` desde el
emulador; la IP LAN del PC desde un dispositivo físico).

NO se agregó `android:usesCleartextTraffic="true"` ni ninguna otra
configuración global insegura: no hay que asumir que el HTTP a la API
falla solo porque esa bandera no esté presente.

Si en algún build concreto se llegara a observar bloqueo del tráfico en
claro (en Android 9+ con targetSdk 28+ viene deshabilitado por defecto),
la corrección puntual es una *network security config* restringida a los
hosts de desarrollo (`10.0.2.2` y la IP LAN del PC), definida en
`android/app/src/main/res/xml/network_security_config.xml` y referenciada
desde el `<application>` del manifest. En producción lo correcto es
servir la API por HTTPS.

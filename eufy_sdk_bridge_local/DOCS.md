# eufy-sdk bridge (lokal)

Die [ha-eufy-sdk-bridge](https://github.com/mega-yfue/ha-eufy-sdk-bridge) als Home-Assistant-App,
gebaut aus dem Fork [benji2k2/ha-eufy-sdk-bridge](https://github.com/benji2k2/ha-eufy-sdk-bridge),
Zweig `deploy/local`. Der Supervisor baut das Abbild beim Installieren und bei jedem Update selbst
auf dem HA-Host. Welcher Commit gebaut wird, steht in `build.yaml`.

Grundlage ist das Dev-Add-on aus
[mega-yfue/ha-eufy-sdk-addon](https://github.com/mega-yfue/ha-eufy-sdk-addon) (MIT).

## Verbindung zur Integration

Die Ports sind ab Werk **nicht** auf dem Host veröffentlicht. Die Bridge ist dann nur im internen
Docker-Netz von HA erreichbar, nicht im LAN. Die Integration `eufy_sdk` von Hand einrichten mit:

- Host: der Hostname dieser App (steht unter *Info*, Form `xxxxxxxx-eufy-sdk-bridge-local`)
- Port: `3000`

Die Stream-Adressen (`rtsp://<host>:8554/<seriennummer>`) baut die Integration aus demselben Host,
sie laufen also ebenfalls intern.

## Daten

Sitzung (`.eufy-session.json`), Push-Registrierung (`.eufy-fcm.json`) und die letzten
Ereignisbilder liegen im App-Konfigurationsordner, auf dem Host `/app_configs/<slug>/`. Beim Umzug
von einer anderen Bridge diese Dateien vor dem ersten Start dorthin kopieren und dieselbe
`openudid` eintragen. Dann meldet sich die App mit der bestehenden Sitzung an, ohne 2FA.

## Nur eine Bridge pro Konto

Zwei Bridges am selben eufy-Konto verdrängen sich gegenseitig. Die alte Bridge vorher stoppen.

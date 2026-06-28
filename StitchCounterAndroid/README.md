# StitchCounter Android

Version Android simple de StitchCounter hecha con Expo, React Native y TypeScript.

## Requisitos

- Node.js 22 o superior.
- Expo Go instalado en el telefono Android para probar durante desarrollo.
- Una cuenta de Expo/EAS si queres generar builds cloud.

En esta Mac no habia Node global disponible, asi que se uso un Node local descargado en `../.tools/node-v22.23.1-darwin-arm64`. Para usarlo desde esta carpeta:

```sh
export PATH="$(pwd)/../.tools/node-v22.23.1-darwin-arm64/bin:$PATH"
```

## Desarrollo con Expo Go

```sh
cd StitchCounterAndroid
export PATH="$(pwd)/../.tools/node-v22.23.1-darwin-arm64/bin:$PATH"
npm start -- --host lan
```

Despues abri Expo Go en Android y escanea el QR. Si necesitás ingresar la URL manualmente, usa la URL `exp://...` que muestre Expo en la terminal.

## APK de prueba

El perfil `preview` en `eas.json` genera un APK instalable:

```sh
cd StitchCounterAndroid
export PATH="$(pwd)/../.tools/node-v22.23.1-darwin-arm64/bin:$PATH"
npx eas-cli@latest login
npx eas-cli@latest build -p android --profile preview
```

Cuando EAS termine, descarga el APK desde el enlace que muestra la terminal.

## Build de produccion Android

El perfil `production` genera un Android App Bundle (`.aab`):

```sh
npx eas-cli@latest build -p android --profile production
```

## Datos locales

Los proyectos se guardan localmente con AsyncStorage bajo la clave `@stitchcounter/projects`.

### Deploy de app Laravel

# 🔐 Secretos de GitHub necesarios para tu CI/CD

Este repositorio necesita algunos secretos configurados en tu repositorio de GitHub para que los flujos de CI/CD funcionen correctamente. A continuación, se detalla qué secretos son necesarios, cómo se llaman y cómo puedes obtenerlos.

| Nombre del secreto       | Origen / Cómo obtenerlo |
|--------------------------|--------------------------|
| `GH_PAT`                 | Token personal de GitHub. Ve a [https://github.com/settings/tokens](https://github.com/settings/tokens), genera un token clásico con los scopes `repo`, `workflow`. |
| `GITHUB_TOKEN`           | Token automático que GitHub inyecta en cada workflow. No necesitas crearlo ni configurarlo. Solo úsalo como variable en tus Actions. |
| `DOCKER_USERNAME`        | Tu nombre de usuario de Docker Hub (el mismo con el que inicias sesión). |
| `DOCKER_TOKEN`        | Access Token de Docker generado desde [https://hub.docker.com/settings/security](https://hub.docker.com/settings/security). |
| `SOPS_AGE_KEY`           | Tu clave privada de Age. Si la generaste con `age-keygen -o age.key`, entonces ejecuta `cat age.key` y copia todo el contenido como secreto. ⚠️ **Nunca subas este archivo a tu repositorio.** |
| `KUBECONFIG`             | Archivo de configuración de tu clúster Kubernetes. Puedes generarlo con: |
|| ```bash kubectl config view --minify --flatten --raw > kubeconfig.yaml``` |
||Luego copia su contenido como secreto. |
| `TELEGRAM_BOT_TOKEN`     | Token de tu bot de Telegram. Crea uno con [@BotFather](https://t.me/BotFather), usa `/newbot`, sigue las instrucciones, y recibirás un token como `123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`. |
| `TELEGRAM_CHAT_ID`       | ID del chat o canal donde enviar mensajes: |
||1. Manda un mensaje al bot. |
||2. Abre en tu navegador: `https://api.telegram.org/bot<tu_bot_token>/getUpdates`|
|| 3. Busca `"chat":{"id":...}` en la respuesta JSON. Ese es el ID. |

---

✅ **Tip:** Puedes configurar estos secretos en tu repositorio yendo a `Settings > Secrets and variables > Actions`.

---

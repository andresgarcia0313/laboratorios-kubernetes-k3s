<!-- lang: es-CO -->
# Muestra gratis - Kit de laboratorios Kubernetes en español con k3s

Estos son **2 de los 12 laboratorios** del kit completo, tal como están en el producto, sin
recortes ni versiones reducidas. Pruébalos en tu clúster y decide con la práctica en la
mano, no con una lista de temas.

Esta carpeta **sí se puede compartir** con quien quieras. Si le sirve a alguien de tu equipo, pásale
este enlace para que reciba su propia copia y las correcciones que vaya publicando:
[labs.ingeniumcodex.com](https://labs.ingeniumcodex.com/?origen=compartido#gratis)

## Qué traes aquí

| Laboratorio | Qué aprendes | Tiempo |
|---|---|---|
| [`lab-01-namespace-y-deployment/`](lab-01-namespace-y-deployment/) | La cadena Deployment, ReplicaSet y Pod, y por qué entenderla te ahorra la mitad de los problemas | 20 min |
| [`lab-08-resourcequota/`](lab-08-resourcequota/) | Qué pasa de verdad cuando un Deployment pide más de lo que la cuota del namespace permite | 35 min |

Los dos retos finales vienen resueltos y explicados en
[`soluciones/`](soluciones/).

Empieza por el 01 si estás arrancando con Kubernetes. Ve directo al 08 si ya trabajas con
clústeres y quieres ver el nivel del material: ese laboratorio responde con salidas de
consola reales la pregunta de por qué un Deployment se queda en `READY 3/5` sin que nadie
sepa decir por qué, y es el caso que más tiempo hace perder en el trabajo.

## Cómo se usa

```bash
cd lab-01-namespace-y-deployment
cat README.md            # Objetivo, requisitos y pasos
./aplicar.sh             # Crea todo y espera a que el clúster termine
# ... sigue los pasos y compara con la sección "Qué debes ver"
./eliminar.sh            # Borra todo sin dejar basura
```

Requisitos: un clúster Kubernetes **de pruebas** (k3s, Kubernetes estándar, minikube o
kind, con un solo nodo alcanza), `kubectl` apuntando a él y una terminal Linux o macOS. En
Windows, WSL (Windows Subsystem for Linux, subsistema de Windows para Linux).

## Qué vas a notar en estos dos laboratorios

Es lo mismo que encuentras en los otros diez:

- **Cada línea de YAML tiene su comentario al final**, sin excepciones, incluidas `spec:` y
  `metadata:`. Son archivos para copiar y adaptar a tu trabajo, no para mirar.
- **La sección "Qué debes ver"** te dice si te funcionó. Las salidas de consola que
  aparecen entre bloques de texto son reales, de corridas medidas sobre k3s v1.34.3, con
  fecha. Donde no hay una salida medida, se describe en palabras qué debe aparecer. En este
  kit nunca se inventa texto de consola, y notarás la diferencia frente a otro material.
- **Una tabla de errores comunes**, con el síntoma exacto, la causa y la solución. En el
  laboratorio 08 esa tabla sola ya justifica el rato que inviertas.
- **Un reto final con solución explicada.** La solución no es solo el comando: dice por qué
  funciona y qué decidirías en producción, que es la pregunta que te van a hacer en el
  trabajo.
- **`aplicar.sh` y `eliminar.sh`** en cada laboratorio, que validan, aplican en orden de
  dependencia, esperan al clúster y después limpian. Nada de dejar objetos sueltos.

## Los otros 10 laboratorios del kit completo

| # | Laboratorio | Qué aprendes |
|---|---|---|
| 02 | Service ClusterIP | Cómo se alcanza un Pod, selectores, Endpoints y DNS interno |
| 03 | Sondas y rollout | `readinessProbe`, `livenessProbe`, actualizar y revertir sin tumbar el servicio |
| 04 | Ingress por HTTP | Rutas, `pathType`, `ingressClassName` y qué pasa con la clase equivocada |
| 05 | TLS con certificado autofirmado | cert-manager de punta a punta, sin necesitar dominio ni salida a Internet |
| 06 | TLS con Let's Encrypt | ACME, reto HTTP-01, `ingress-shim` y cuatro trampas reales de Traefik |
| 07 | LimitRange | Valores por defecto, mínimos y máximos por contenedor |
| 09 | Rollout atascado por la cuota | `maxSurge`, `maxUnavailable` y el atasco que te cuesta una madrugada |
| 10 | securityContext | Contenedor sin root, de solo lectura, sin capacidades de más |
| 11 | Pod Security Admission | Perfiles `baseline` y `restricted`, y cómo avisar antes de bloquear |
| 12 | NetworkPolicy de egreso | Cerrar la salida de un Pod sin romper la resolución de nombres |

Más de 7 horas de práctica, en orden de dificultad creciente, pensadas para que cada
laboratorio te deje algo que puedas usar al día siguiente en el trabajo.

## El kit completo

**COP 49.000**, pago único. Son los 12 laboratorios, los 12 retos resueltos y los
manifiestos para copiar a tus proyectos, con licencia de uso personal: puedes usarlos en tu
trabajo, incluso comercial.

### [labs.ingeniumcodex.com](https://labs.ingeniumcodex.com/?origen=github)

Todo funciona igual en **k3s** y en **Kubernetes estándar**. Lo que es específico de un
controlador de Ingress va marcado con un comentario que dice cómo se hace en el otro, así
que lo que practiques aquí te sirve en el clúster que te toque.

Si tu equipo necesita varias licencias, o quieres usar el material para dictar formación,
escribe por ese mismo enlace.

## Guías gratis de diagnóstico

Cuando algo falla en tu clúster, estas guías van del mensaje de error exacto a la corrección, con los comandos
para confirmar la causa:

- [Tu Service no responde y los endpoints salen vacíos](https://labs.ingeniumcodex.com/service-kubernetes-no-responde.html?origen=github)
- [El certificado de cert-manager se queda en pending](https://labs.ingeniumcodex.com/certificado-cert-manager-pendiente.html?origen=github)
- [Liveness probe failed: por qué se reinicia tu Pod que funciona](https://labs.ingeniumcodex.com/liveness-probe-failed-pod-reinicia.html?origen=github)
- [404 page not found en un Ingress de k3s con Traefik](https://labs.ingeniumcodex.com/ingress-k3s-404-page-not-found-traefik.html?origen=github)

## Sobre el autor

Andrés García. Ingeniero de sistemas, con maestría en dirección de proyectos. Instructor de
Docker y Kubernetes. Estos laboratorios salieron de su propio clúster k3s de varios nodos y
de los problemas que le tocó resolver ahí: por eso las salidas de consola tienen fecha y los
errores comunes son los que de verdad salen.

## Licencia de la muestra

Esta carpeta se puede copiar y compartir libremente, completa y sin cambios, incluido este
archivo. El kit completo se entrega con licencia de uso personal y no se puede
redistribuir.

El material se entrega tal como está, sin garantía. **Ejecútalo en un clúster de pruebas,
nunca en producción.**

## Control de cambios

| Versión | Fecha | Autor | Cambio |
|---|---|---|---|
| 1.0 | 2026-10-10 | Andrés García | Versión inicial de la muestra |
| 1.1 | 2026-10-12 | Andrés García | Enlaces a las cuatro guías gratis de diagnóstico |

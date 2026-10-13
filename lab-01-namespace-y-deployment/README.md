<!-- lang: es-CO -->
# Laboratorio 01 - Namespace y Deployment: tu primer despliegue

## Objetivo

Crear un espacio propio dentro del clúster y poner a correr una aplicación con dos
copias idénticas. Al terminar vas a saber leer la diferencia entre lo que pediste y
lo que el clúster logró darte, que es la pregunta que se repite en todos los
laboratorios siguientes.

Conceptos que quedan cubiertos:

- Namespace: una habitación separada dentro del clúster.
- Deployment: la orden "quiero N copias de esta imagen corriendo siempre".
- ReplicaSet: el intermediario que de verdad crea los Pods.
- Pod: la unidad más pequeña que Kubernetes sabe ejecutar.

## Requisitos

- Un clúster Kubernetes con permiso para crear namespaces. Sirve k3s, Kubernetes
  estándar, minikube o kind.
- `kubectl` configurado y apuntando a ese clúster. Compruébalo con `kubectl get ns`.
- Salida a Internet desde los nodos para descargar la imagen del contenedor.

Tiempo estimado: 20 minutos.

## Archivos

| Archivo | Objeto | Qué hace |
|---|---|---|
| `00-namespace.yaml` | Namespace `lab-01` | Aísla el laboratorio del resto del clúster |
| `01-deployment.yaml` | Deployment `tienda` | Pide 2 réplicas de la aplicación de demostración |
| `aplicar.sh` | - | Crea los dos objetos en orden y espera a que estén listos |
| `eliminar.sh` | - | Borra el namespace y, en cascada, todo lo que contiene |

La imagen es `andresgarcia0313/nodehostname:1.0.0`: una aplicación mínima que responde
por HTTP (Hypertext Transfer Protocol, protocolo de transferencia de hipertexto) con el
nombre del Pod que atendió la petición. Es ideal para ver el balanceo de carga en los
laboratorios siguientes.

## Pasos

### 1. Revisa los manifiestos antes de aplicarlos

Cada línea de los archivos YAML (YAML Ain't Markup Language, un formato de texto para
configuración) lleva un comentario al final que explica para qué sirve. Léelos primero:

```bash
cat 00-namespace.yaml
cat 01-deployment.yaml
```

### 2. Valida sin tocar el clúster

Antes de crear nada, pídele a `kubectl` que revise la sintaxis y el esquema:

```bash
kubectl apply --dry-run=client -f 00-namespace.yaml -f 01-deployment.yaml
```

`--dry-run=client` no crea nada: solo confirma que los manifiestos están bien formados.

### 3. Crea el namespace

```bash
kubectl apply -f 00-namespace.yaml
kubectl get namespace lab-01
```

### 4. Crea el Deployment

```bash
kubectl apply -f 01-deployment.yaml
```

Kubernetes acepta el Deployment de inmediato. Crear los Pods es un trabajo aparte, que
hace el ReplicaSet unos segundos después.

### 5. Observa la cadena completa

```bash
kubectl -n lab-01 get deployment tienda
kubectl -n lab-01 get replicaset
kubectl -n lab-01 get pods
```

### 6. Espera a que el despliegue termine

```bash
kubectl -n lab-01 rollout status deployment tienda
```

Este comando se queda esperando hasta que todas las réplicas pedidas estén disponibles,
o hasta que se agote su tiempo. Es la forma correcta de esperar en un script: mucho mejor
que un `sleep` a ciegas.

### 7. Mira la aplicación por dentro

```bash
kubectl -n lab-01 logs -l app.kubernetes.io/name=tienda --tail=5
kubectl -n lab-01 describe deployment tienda | head -30
```

### 8. Prueba que el Deployment repone lo que se cae

Borra un Pod a mano y mira lo que pasa:

```bash
kubectl -n lab-01 delete pod -l app.kubernetes.io/name=tienda --field-selector status.phase=Running --wait=false
kubectl -n lab-01 get pods -w
```

Corta la vista con `Ctrl+C` cuando hayas visto suficiente.

### 9. Limpia

```bash
./eliminar.sh
```

También puedes ejecutar todo el laboratorio de una sola vez con `./aplicar.sh`.

## Qué debes ver

- `kubectl get namespace lab-01` muestra una fila con el namespace en estado `Active`.
- `kubectl get deployment tienda` muestra las columnas `READY`, `UP-TO-DATE` y
  `AVAILABLE`. Cuando todo funciona, `READY` queda en `2/2`: dos réplicas pedidas y dos
  listas. En los primeros segundos puedes ver `0/2` o `1/2` mientras se descarga la imagen.
- `kubectl get replicaset` muestra un solo ReplicaSet, con un nombre que es el del
  Deployment más un sufijo aleatorio, y las columnas `DESIRED`, `CURRENT` y `READY` en 2.
- `kubectl get pods` muestra dos Pods, cada uno con el nombre del ReplicaSet más otro
  sufijo aleatorio, en estado `Running` y con `READY 1/1` (un contenedor listo de uno).
- `rollout status` termina con un mensaje que dice que el despliegue se completó.
- Al borrar un Pod a mano, en la vista con `-w` aparece el Pod viejo pasando a
  `Terminating` y, casi al instante, un Pod nuevo con otro sufijo pasando por `Pending`,
  `ContainerCreating` y `Running`. El Deployment nunca se queda con menos de las réplicas
  que pediste si el clúster tiene espacio.

## Errores comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `Error from server (NotFound): namespaces "lab-01" not found` al aplicar el Deployment | Aplicaste el Deployment antes del namespace | Aplica siempre en orden numérico; `aplicar.sh` ya lo hace |
| Pods en `ImagePullBackOff` o `ErrImagePull` | Los nodos no alcanzan el registro de imágenes, o el nombre de la imagen tiene un error de tipeo | Revisa la salida a Internet del nodo y el nombre exacto de la imagen con `kubectl -n lab-01 describe pod <nombre>` |
| Pods en `Pending` y nunca arrancan | No hay nodo con recursos libres, o hay un `taint` que lo impide | `kubectl -n lab-01 describe pod <nombre>` y lee la sección `Events` al final |
| `READY 0/2` pero los Pods dicen `Running` | El contenedor arrancó pero su sonda de disponibilidad aún no pasa | Esto se trabaja a fondo en el laboratorio 03 |
| `kubectl get pods` no muestra nada | Olvidaste el `-n lab-01` y estás mirando el namespace `default` | Agrega siempre `-n lab-01`, o fija el namespace con `kubectl config set-context --current --namespace=lab-01` |
| `the server doesn't have a resource type "deployment"` | `kubectl` no está apuntando a ningún clúster | Revisa tu archivo de configuración con `kubectl config current-context` |

## Reto final

Sin editar `01-deployment.yaml`, consigue lo siguiente y explica cada resultado:

1. Lleva el Deployment a 4 réplicas y confirma que aparecen 4 Pods.
2. Devuélvelo a 2 réplicas y averigua, mirando las edades de los Pods (`AGE`), cuáles
   sobrevivieron.
3. Agrega la etiqueta `entorno=pruebas` a los Pods existentes y comprueba si el
   Deployment los sigue considerando suyos.
4. Explica por qué, si borras el ReplicaSet en lugar del Pod, el Deployment crea uno
   nuevo completo.

La solución está en [`../soluciones/lab-01.md`](../soluciones/lab-01.md).

## Control de cambios

| Versión | Fecha | Autor | Cambio |
|---|---|---|---|
| 1.0 | 2026-10-10 | Andrés García | Versión inicial |

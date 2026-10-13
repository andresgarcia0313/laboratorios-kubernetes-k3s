<!-- lang: es-CO -->
# Laboratorio 08 - ResourceQuota: el presupuesto del namespace

## Objetivo

Responder con evidencia la pregunta que más confunde en producción: ¿qué pasa cuando un
Deployment pide, en total, más recursos de los que el namespace permite?

La respuesta corta es que no falla el Deployment. Corre degradado, con las réplicas que
caben, y el motivo solo aparece si sabes dónde mirar. Al terminar vas a saber leer ese
diagnóstico en treinta segundos.

Conceptos que quedan cubiertos:

- ResourceQuota: el tope agregado del namespace, la suma de todos sus Pods.
- La diferencia entre lo declarado y lo consumido: la cuota cobra lo declarado.
- Dónde ocurre el rechazo: al crear cada Pod, no al crear el Deployment.
- Los eventos `FailedCreate` y las condiciones del Deployment.

## Requisitos

- Un clúster Kubernetes con permiso para crear namespaces y ResourceQuota. Sirve k3s,
  Kubernetes estándar, minikube o kind.
- `kubectl` configurado y apuntando a ese clúster.
- Nada más. Este laboratorio es autosuficiente: trae su propio LimitRange en
  `01-limitrange.yaml`, que en el kit completo se estudia aparte en el laboratorio 07.
- En el kit completo este laboratorio comparte el namespace `lab-resource-quota` con el
  laboratorio 09, el del rollout atascado; aquí lo tienes para ti solo.

Tiempo estimado: 35 minutos.

## Archivos

| Archivo | Objeto | Qué hace |
|---|---|---|
| `00-namespace.yaml` | Namespace `lab-resource-quota` | Aísla el laboratorio |
| `01-limitrange.yaml` | LimitRange `container-limits` | Reglas por contenedor: valores por defecto, mínimo y máximo |
| `02-resourcequota.yaml` | ResourceQuota `namespace-quota` | Tope agregado del namespace |
| `03-deployment-over-quota.yaml` | Deployment `web-over-quota` | 5 réplicas válidas una a una, pero la suma supera la cuota |
| `aplicar.sh` | - | Crea todo en orden y muestra el diagnóstico completo |
| `eliminar.sh` | - | Borra el namespace y, en cascada, todo lo que contiene |

La imagen es `registry.k8s.io/pause:3.10`, un contenedor inerte que no consume casi nada.
Es a propósito: la cuota cuenta lo que el Pod declara, no lo que gasta. Vas a ver la cuota
llena con Pods que no hacen nada.

## Pasos

### 1. Entiende las cuentas antes de aplicar

| Concepto | Valor |
|---|---|
| CPU reservada por Pod, inyectada por el LimitRange | 100m |
| Réplicas pedidas | 5 |
| CPU reservada total que haría falta | 500m |
| Tope de `requests.cpu` en la cuota | 300m |
| Réplicas que caben | 3 |

### 2. Crea el namespace, el LimitRange y la ResourceQuota

```bash
kubectl apply -f 00-namespace.yaml -f 01-limitrange.yaml -f 02-resourcequota.yaml
kubectl -n lab-resource-quota describe resourcequota namespace-quota
```

### 3. Crea el Deployment que no cabe

```bash
kubectl apply -f 03-deployment-over-quota.yaml
```

Fíjate bien en que `kubectl` dice `created` sin protestar. La cuota no revisa el
Deployment: revisa cada Pod cuando el ReplicaSet intenta crearlo.

### 4. Mira lo que de verdad pasó

```bash
kubectl -n lab-resource-quota get deployment web-over-quota
kubectl -n lab-resource-quota get replicaset
kubectl -n lab-resource-quota get pods
```

### 5. Comprueba que el LimitRange completó los recursos

El manifiesto del Deployment no tiene bloque `resources`. Averigua con qué valores quedó
cada Pod:

```bash
kubectl -n lab-resource-quota get pods -l app.kubernetes.io/name=web-over-quota \
  -o jsonpath='{.items[0].spec.containers[0].resources}{"\n"}'
```

### 6. Mira cómo quedó el presupuesto

```bash
kubectl -n lab-resource-quota describe resourcequota namespace-quota
```

### 7. Busca el motivo del rechazo en los eventos

Esta es la parte que casi nadie encuentra sola:

```bash
kubectl -n lab-resource-quota get events --field-selector reason=FailedCreate \
  -o custom-columns=OBJETO:.involvedObject.name,MENSAJE:.message | head -3
```

### 8. Lee las condiciones del Deployment

```bash
kubectl -n lab-resource-quota get deployment web-over-quota \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status} ({.reason}){"\n"}{end}'
```

### 9. Libera cuota y vuelve a llenarla

```bash
kubectl -n lab-resource-quota scale deployment web-over-quota --replicas=2
sleep 8
kubectl -n lab-resource-quota get deployment web-over-quota
kubectl -n lab-resource-quota scale deployment web-over-quota --replicas=5
sleep 8
kubectl -n lab-resource-quota get deployment web-over-quota
```

### 10. Limpia

```bash
./eliminar.sh
```

Si vas a seguir con el laboratorio 09, no borres todavía: ese laboratorio parte de este
mismo estado.

## Qué debes ver

Las salidas de esta sección son reales: salen de una corrida del autor del 2026-09-23
sobre k3s v1.34.3. Si repites el laboratorio cambian los sufijos aleatorios de los nombres
(`...-7k84t`) y la columna `AGE`; el comportamiento y los mensajes son los mismos.

### El presupuesto, antes de que exista un solo Pod

Salida real de `kubectl -n lab-resource-quota describe resourcequota namespace-quota`:

```text
Name:            namespace-quota
Namespace:       lab-resource-quota
Resource         Used  Hard
--------         ----  ----
limits.cpu       0     600m
limits.memory    0     512Mi
pods             0     10
requests.cpu     0     300m
requests.memory  0     256Mi
```

`Used` en cero y `Hard` con los topes del manifiesto.

### El Deployment se acepta sin protestar

Salida real de `kubectl apply -f 03-deployment-over-quota.yaml`:

```text
deployment.apps/web-over-quota created
```

### Solo caben 3 de las 5 réplicas

Salida real de `kubectl -n lab-resource-quota get deployment web-over-quota`:

```text
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
web-over-quota   3/5     3            3           15s
```

Salida real de `kubectl -n lab-resource-quota get replicaset`:

```text
NAME                        DESIRED   CURRENT   READY   AGE
web-over-quota-5d99769886   5         3         3       15s
```

El ReplicaSet quiere 5 (`DESIRED`) y tiene 3 (`CURRENT`).

En `kubectl get pods` vas a ver **tres** Pods en `Running`, no cinco. Los dos que faltan no
aparecen en estado `Pending`: nunca llegaron a crearse, porque el API los rechazó antes de
guardarlos. Este es el punto que más se malinterpreta del laboratorio.

### El LimitRange completó los recursos del Pod

Salida real del `jsonpath` del paso 5:

```text
{"limits":{"cpu":"200m","memory":"128Mi"},"requests":{"cpu":"100m","memory":"64Mi"}}
```

Son exactamente los valores por defecto del LimitRange. Esa inyección ocurre antes de
revisar la cuota, y con esos números la cuota cobra cada Pod.

### La cuota quedó llena

Salida real de `describe resourcequota` después de crear el Deployment:

```text
Name:            namespace-quota
Namespace:       lab-resource-quota
Resource         Used   Hard
--------         ----   ----
limits.cpu       600m   600m
limits.memory    384Mi  512Mi
pods             3      10
requests.cpu     300m   300m
requests.memory  192Mi  256Mi
```

`requests.cpu 300m/300m` y `limits.cpu 600m/600m`: la CPU está al tope. La memoria
(192Mi de 256Mi) y el número de Pods (3 de 10) todavía tienen espacio, pero basta con que
un solo recurso esté lleno para bloquear un Pod nuevo.

### El motivo, en los eventos

Salida real del paso 7:

```text
OBJETO                      MENSAJE
web-over-quota-5d99769886   Error creating: pods "web-over-quota-5d99769886-rhx75" is forbidden: exceeded quota: namespace-quota, requested: limits.cpu=200m,requests.cpu=100m, used: limits.cpu=600m,requests.cpu=300m, limited: limits.cpu=600m,requests.cpu=300m
```

Así se lee ese mensaje, que es el que vas a encontrar en producción:

| Parte | Significado |
|---|---|
| `exceeded quota: namespace-quota` | Qué cuota lo bloqueó |
| `requested: requests.cpu=100m` | Lo que pedía el Pod nuevo |
| `used: requests.cpu=300m` | Lo que ya estaba usado en el namespace |
| `limited: requests.cpu=300m` | El tope; 300m más 100m lo superaría |

### Las condiciones del Deployment

Salida real del paso 8:

```text
Available=False (MinimumReplicasUnavailable)
ReplicaFailure=True (FailedCreate)
Progressing=True (ReplicaSetUpdated)
```

- `Available=False`: no tiene el mínimo de réplicas disponibles que pide su estrategia.
- `ReplicaFailure=True (FailedCreate)`: su ReplicaSet no puede crear Pods.
- El Deployment no se borra ni falla del todo: sigue atendiendo con 3 Pods.

### Liberar cuota y volver a llenarla

Salidas reales del paso 9, con la cuota consultada en la misma línea:

```text
deployment.apps/web-over-quota scaled
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
web-over-quota   2/2     2            2           25s
requests.cpu usado=200m tope=300m
```

```text
deployment.apps/web-over-quota scaled
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
web-over-quota   3/5     3            3           33s
requests.cpu usado=300m tope=300m
```

Con 2 réplicas el Deployment queda completo (`2/2`). Al volver a 5, el ReplicaSet crea
solo el Pod que cabe y vuelve a `3/5`. No hace falta intervenir: en cuanto hay cuota libre,
el ReplicaSet completa las réplicas por sí solo.

## Errores comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `pods "x" is forbidden: failed quota: namespace-quota: must specify limits.cpu for: ...` | La cuota controla CPU y memoria, y el Pod no las declara porque no hay LimitRange que ponga valores por defecto | Crea el LimitRange, o declara `resources` en el Pod. Es la salida real que da un namespace con cuota y sin LimitRange |
| Buscas los Pods que faltan en `Pending` y no los encuentras | Los Pods rechazados por cuota no existen: el API los rechazó antes de guardarlos | Mira los eventos `FailedCreate`, nunca `get pods` |
| El Deployment dice `3/5` y nadie sabe por qué | El mensaje de cuota solo vive en los eventos del ReplicaSet | `kubectl get events --field-selector reason=FailedCreate` en ese namespace |
| Subes la cuota y los Pods no aparecen de inmediato | El ReplicaSet reintenta con espera creciente tras cada rechazo | Espera, o fuerza con `kubectl rollout restart`. En el laboratorio 09 se mide cuánto tarda |
| La cuota está llena pero `kubectl top pods` muestra consumo casi nulo | La cuota cobra lo declarado, no lo consumido | Ajusta `requests` y `limits` a la realidad; es la causa número uno de clústeres con cuota llena y nodos vacíos |
| `error validating data: unknown field "hard"` al cambiar la cuota | `hard` va dentro de `spec`, y los valores de `pods` deben ir entre comillas porque son texto | Copia la estructura de `02-resourcequota.yaml` |
| Los eventos ya no aparecen | Kubernetes borra los eventos al cabo de una hora por defecto | Vuelve a provocar el fallo con `kubectl rollout restart deployment web-over-quota` |

## Reto final

1. Sin tocar la ResourceQuota, consigue que las 5 réplicas de `web-over-quota` corran al
   mismo tiempo. Hay más de un camino: encuentra dos y di cuál usarías en producción.
2. Agrega a la cuota un tope de `services` igual a 1 y demuestra que el segundo Service
   del namespace se rechaza. Explica en qué se diferencia ese rechazo del de los Pods.
3. Crea un namespace con la misma ResourceQuota pero **sin** LimitRange y demuestra cuál
   es el mensaje exacto que da un Pod sin `resources`.
4. Explica por qué un Pod con `requests` muy bajos y `limits` muy altos es un problema para
   la cuota y para el nodo, aunque el Pod parezca eficiente.

La solución está en [`../soluciones/lab-08.md`](../soluciones/lab-08.md).

## Control de cambios

| Versión | Fecha | Autor | Cambio |
|---|---|---|---|
| 1.0 | 2026-10-10 | Andrés García | Versión inicial |

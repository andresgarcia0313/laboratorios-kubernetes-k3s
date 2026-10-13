<!-- lang: es-CO -->
# Solución del reto - Laboratorio 08

## 1. Lograr que las 5 réplicas corran sin tocar la ResourceQuota

Hay tres caminos, y cada uno enseña algo distinto.

### Camino A: bajar lo que cada Pod pide, declarándolo en el Deployment

Si cada Pod reserva 60m en lugar de 100m, cinco réplicas suman 300m y caben justo:

```yaml
      containers:
        - name: pausa
          image: registry.k8s.io/pause:3.10
          resources:
            requests:
              cpu: 60m
              memory: 32Mi
            limits:
              cpu: 120m
              memory: 64Mi
```

Las cuentas tienen que cuadrar con los cuatro topes a la vez:

| Recurso | Por Pod | Por 5 Pods | Tope de la cuota | ¿Cabe? |
|---|---|---|---|---|
| `requests.cpu` | 60m | 300m | 300m | Sí, justo |
| `limits.cpu` | 120m | 600m | 600m | Sí, justo |
| `requests.memory` | 32Mi | 160Mi | 256Mi | Sí, con holgura |
| `limits.memory` | 64Mi | 320Mi | 512Mi | Sí, con holgura |

Ojo con el LimitRange del laboratorio 07, que exige un mínimo de 50m de CPU y 32Mi de
memoria: 60m y 32Mi lo respetan por poco. Con 40m el Pod sería rechazado por el LimitRange,
no por la cuota, y el mensaje de error sería otro.

### Camino B: bajar los valores por defecto del LimitRange

Si el Deployment no declara `resources`, lo que decide es el LimitRange. Cambiar su
`defaultRequest` a 60m de CPU y su `default` a 120m consigue el mismo efecto sin tocar el
Deployment:

```bash
kubectl -n lab-resource-quota patch limitrange container-limits --type merge \
  -p '{"spec":{"limits":[{"type":"Container","min":{"cpu":"50m","memory":"32Mi"},"max":{"cpu":"500m","memory":"256Mi"},"defaultRequest":{"cpu":"60m","memory":"32Mi"},"default":{"cpu":"120m","memory":"64Mi"}}]}}'
kubectl -n lab-resource-quota rollout restart deployment web-over-quota
```

Un LimitRange solo actúa sobre Pods **nuevos**. Los que ya existen conservan los valores
que recibieron al nacer, por eso hace falta el `rollout restart`.

### Camino C: bajar las réplicas

```bash
kubectl -n lab-resource-quota scale deployment web-over-quota --replicas=3
```

No cumple el reto, porque no corren las 5, pero es la respuesta correcta en la mitad de los
casos reales: a menudo el número de réplicas se escogió sin mirar el presupuesto.

### Cuál usar en producción

El camino A. Los recursos de una carga de trabajo son parte de su definición y deben vivir
en el manifiesto del Deployment, versionado junto al código, no en un LimitRange compartido
que alguien puede cambiar sin saber a quién afecta.

El LimitRange es una red de seguridad para lo que llegue sin declarar nada, no el lugar
donde se dimensiona una aplicación. Y hay un motivo más: con valores explícitos puedes
calcular el costo de tu servicio y detectar cuándo quedaron desfasados; con valores
heredados, no.

## 2. Un tope de Services en la cuota

```bash
kubectl -n lab-resource-quota patch resourcequota namespace-quota --type merge \
  -p '{"spec":{"hard":{"services":"1"}}}'
kubectl -n lab-resource-quota create service clusterip primero --tcp=80:3000
kubectl -n lab-resource-quota create service clusterip segundo --tcp=80:3000
```

El primer Service se crea. El segundo es rechazado en el momento, con un mensaje de la
forma `services "segundo" is forbidden: exceeded quota: namespace-quota, requested:
services=1, used: services=1, limited: services=1`.

La diferencia con los Pods es **quién recibe el error y cuándo**:

| | Pods de un Deployment | Services |
|---|---|---|
| Quién pide crearlo | El ReplicaSet, un controlador dentro del clúster | Tú, desde `kubectl` |
| Quién ve el error | Nadie, hasta que alguien lea los eventos | Tu terminal, de inmediato |
| Qué pasa después | El controlador reintenta solo, con espera creciente | Nada: tu comando falló y punto |
| Cómo se diagnostica | `kubectl get events --field-selector reason=FailedCreate` | Leyendo la salida del comando |

Esta es la lección de fondo del laboratorio: los objetos que creas a mano te avisan; los
que crea un controlador por ti, no. Todo lo que un controlador cree en tu nombre (Pods de
un Deployment, de un DaemonSet, de un Job, PersistentVolumeClaim de un StatefulSet) falla
en silencio y solo deja rastro en los eventos.

Para dejarlo como estaba:

```bash
kubectl -n lab-resource-quota delete service primero --ignore-not-found
kubectl -n lab-resource-quota patch resourcequota namespace-quota --type json \
  -p '[{"op":"remove","path":"/spec/hard/services"}]'
```

## 3. Una cuota sin LimitRange

```bash
kubectl create namespace lab-quota-sin-limitrange
sed 's/namespace: lab-resource-quota/namespace: lab-quota-sin-limitrange/' \
  ../lab-08-resourcequota/02-resourcequota.yaml | kubectl apply -f -
kubectl -n lab-quota-sin-limitrange run probe --image=registry.k8s.io/pause:3.10 --dry-run=server
```

Esta es la salida real que obtuvo el autor en la corrida del 2026-09-23:

```text
Error from server (Forbidden): pods "probe" is forbidden: failed quota: namespace-quota: must specify limits.cpu for: probe; limits.memory for: probe; requests.cpu for: probe; requests.memory for: probe
```

La regla es simple y no tiene excepciones: si una ResourceQuota controla un recurso de
cómputo, **todo** Pod del namespace debe declararlo. Sin un LimitRange que ponga valores
por defecto, cualquier Pod que llegue sin `resources` se rechaza. Y como casi todos los
Pods que la gente escribe llegan sin `resources`, poner una cuota sin su LimitRange es la
forma más rápida de romper un namespace entero.

Fíjate en el detalle de `--dry-run=server`: a diferencia de `--dry-run=client`, este sí
manda el objeto al API para que lo valide de verdad, con sus controles de admisión, pero
sin guardarlo. Es la forma correcta de probar si algo sería aceptado.

Limpia el namespace de prueba:

```bash
kubectl delete namespace lab-quota-sin-limitrange
```

## 4. Por qué `requests` bajos y `limits` altos son un problema

Los dos valores sirven para cosas distintas, y confundirlos es el error de dimensionado más
común:

- `requests` es lo que el planificador reserva. Decide en qué nodo cabe el Pod y cuenta
  para `requests.cpu` y `requests.memory` de la cuota.
- `limits` es el techo. Si el Pod pasa su límite de memoria, el kernel lo mata
  (`OOMKilled`); si pasa el de CPU, se le frena (throttling). Cuenta para `limits.cpu` y
  `limits.memory` de la cuota.

Con `requests` muy bajos y `limits` muy altos pasan tres cosas malas a la vez:

1. **El nodo se sobrevende.** El planificador cree que el nodo está casi vacío, porque solo
   suma `requests`, y mete más Pods de los que el nodo puede sostener si todos usan de
   verdad lo que tienen permitido. El día de carga alta, todos frenan al mismo tiempo.
2. **La cuota se llena antes de lo que esperas, por el lado equivocado.** En este
   laboratorio la cuota no se llenó por `requests.cpu` sola: `limits.cpu` llegó a 600m de
   600m exactamente al mismo tiempo. Un `limits` generoso consume presupuesto del namespace
   igual que un `requests` generoso.
3. **El Pod pierde su garantía.** En la clasificación interna de Kubernetes, un Pod con
   `requests` iguales a `limits` es `Guaranteed`; uno con `requests` menores que `limits` es
   `Burstable`; uno sin nada es `BestEffort`. Cuando al nodo le falta memoria, mata primero
   a los `BestEffort`, luego a los `Burstable` que más se pasaron de su `requests`, y de
   últimos a los `Guaranteed`. Pedir poco y permitirse mucho te pone al principio de la
   fila de los sacrificables.

La regla práctica: `requests` igual al consumo normal medido, y `limits` entre una y dos
veces ese valor. Para cargas sensibles, `requests` igual a `limits`. Y mide antes de
decidir, con `kubectl top pods` o con las métricas de tu sistema de monitoreo: cualquier
número escogido a ojo va a estar mal en los dos sentidos al mismo tiempo.

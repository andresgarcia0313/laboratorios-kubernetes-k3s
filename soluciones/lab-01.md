<!-- lang: es-CO -->
# Solución del reto - Laboratorio 01

## 1. Llevar el Deployment a 4 réplicas

```bash
kubectl -n lab-01 scale deployment tienda --replicas=4
kubectl -n lab-01 rollout status deployment tienda
kubectl -n lab-01 get pods
```

`kubectl scale` cambia solo el campo `spec.replicas` del objeto que ya existe en el
clúster. No toca tu archivo YAML, y ahí está la trampa: si después vuelves a hacer
`kubectl apply -f 01-deployment.yaml`, el valor del archivo (2) gana y el Deployment
regresa a 2 réplicas. En un flujo de trabajo serio, el número de réplicas vive en el
archivo, no en un comando suelto.

El Deployment no crea los Pods: actualiza su ReplicaSet, y el ReplicaSet crea los dos Pods
que faltan. Por eso no aparece un ReplicaSet nuevo, sino el mismo con `DESIRED 4`.

## 2. Volver a 2 réplicas y averiguar quién sobrevive

```bash
kubectl -n lab-01 scale deployment tienda --replicas=2
kubectl -n lab-01 get pods --sort-by=.metadata.creationTimestamp
```

Sobreviven, en general, los Pods más antiguos. El ReplicaSet ordena sus Pods por una
escala de costo de eliminación antes de borrar, y en ese orden los Pods que todavía no
están listos, los que llevan menos tiempo o los que están en nodos con más Pods del mismo
ReplicaSet se van primero. En este laboratorio, con dos Pods iguales y sanos, lo que
decide es la antigüedad.

Mira la columna `AGE`: los dos que quedan son los que ya existían antes de escalar a 4. Si
quieres forzar a quién borrar primero, existe la anotación
`controller.kubernetes.io/pod-deletion-cost`, pero es un detalle avanzado y poco común.

## 3. Agregar una etiqueta a los Pods existentes

```bash
kubectl -n lab-01 label pods -l app.kubernetes.io/name=tienda entorno=pruebas
kubectl -n lab-01 get pods --show-labels
kubectl -n lab-01 get deployment tienda
```

El Deployment los sigue considerando suyos. La razón es que su `selector.matchLabels` solo
exige `app.kubernetes.io/name: tienda`: un selector pide que las etiquetas que lista
coincidan, no que sean las únicas. Agregar etiquetas de más nunca saca a un Pod de su
ReplicaSet.

Lo contrario sí rompe la relación. Quítale la etiqueta que el selector exige:

```bash
kubectl -n lab-01 label pod <nombre-del-pod> app.kubernetes.io/name-
kubectl -n lab-01 get pods
```

Ese Pod queda huérfano, deja de contar para el Deployment, y el ReplicaSet crea uno nuevo
para reponerlo. Terminas con un Pod de más que ya nadie administra, y que no se borra si
borras el Deployment. Es una técnica real para sacar un Pod enfermo de la rotación y
examinarlo con calma, y también una forma clásica de dejar basura en un clúster sin darse
cuenta.

Los Pods nuevos que cree el ReplicaSet no llevan `entorno=pruebas`, porque esa etiqueta la
pusiste a mano sobre los Pods, no en el `template` del Deployment. Para que la lleven
todos, va en `spec.template.metadata.labels`.

## 4. Por qué borrar el ReplicaSet crea uno nuevo completo

```bash
kubectl -n lab-01 get replicaset
kubectl -n lab-01 delete replicaset <nombre-del-replicaset>
kubectl -n lab-01 get replicaset,pods
```

Hay una cadena de responsabilidades, y cada eslabón solo vigila al siguiente:

| Quién | Qué vigila | Qué hace si falta algo |
|---|---|---|
| Deployment | Que exista un ReplicaSet que corresponda a su `template` actual | Crea un ReplicaSet nuevo |
| ReplicaSet | Que existan tantos Pods como dice su `replicas` | Crea los Pods que falten |
| kubelet del nodo | Que los contenedores del Pod que le asignaron estén corriendo | Reinicia el contenedor |

Si borras un Pod, el ReplicaSet lo repone: un Pod nuevo, mismo ReplicaSet. Si borras el
ReplicaSet, se van con él sus Pods (son sus dependientes, con `ownerReferences` apuntando
a él), y el Deployment, que no se enteró de nada más que de la ausencia, crea un ReplicaSet
nuevo con otro sufijo, que a su vez crea los Pods desde cero. Por eso el `AGE` de todo
queda en segundos.

Y si borras el Deployment, se va toda la cadena. Compruébalo:

```bash
kubectl -n lab-01 delete deployment tienda
kubectl -n lab-01 get replicaset,pods
```

Esta es, además, la razón de que `eliminar.sh` borre el namespace en lugar de ir objeto por
objeto: el namespace es el dueño último de todo lo que contiene.

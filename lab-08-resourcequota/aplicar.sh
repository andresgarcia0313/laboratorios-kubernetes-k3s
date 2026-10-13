#!/usr/bin/env bash
# Crea el laboratorio 08: namespace, LimitRange, ResourceQuota y el Deployment que no cabe en la cuota.
# Comparte el namespace lab-resource-quota con el laboratorio 09; no los ejecutes a la vez.
# No revierte nada: para deshacerlo usa ./eliminar.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "== Validando los manifiestos sin tocar el clúster =="
kubectl apply --dry-run=client -f 00-namespace.yaml -f 01-limitrange.yaml \
  -f 02-resourcequota.yaml -f 03-deployment-over-quota.yaml

echo "== Creando el namespace, el LimitRange y la ResourceQuota =="
kubectl apply -f 00-namespace.yaml -f 01-limitrange.yaml -f 02-resourcequota.yaml

echo "== Presupuesto del namespace antes de crear Pods =="
kubectl -n lab-resource-quota describe resourcequota namespace-quota

echo "== Creando el Deployment que pide 5 réplicas =="
kubectl apply -f 03-deployment-over-quota.yaml

echo "== Esperando 15 s a que el ReplicaSet intente crear los Pods =="
sleep 15

echo "== Lo que de verdad pasó =="
kubectl -n lab-resource-quota get deployment,replicaset,pods
kubectl -n lab-resource-quota describe resourcequota namespace-quota
echo "-- Eventos de rechazo (FailedCreate) --"
kubectl -n lab-resource-quota get events --field-selector reason=FailedCreate \
  -o custom-columns=OBJETO:.involvedObject.name,MENSAJE:.message | head -3

echo "Listo. Lee la sección \"Qué debes ver\" del README.md y compara."

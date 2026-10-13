#!/usr/bin/env bash
# Borra el laboratorio 08. Al borrar el namespace, Kubernetes borra en cascada el LimitRange,
# la ResourceQuota, el Deployment y sus Pods. No revierte ningún cambio del clúster.
set -euo pipefail
cd "$(dirname "$0")"

echo "== Esto es lo que hay ahora en lab-resource-quota =="
kubectl -n lab-resource-quota get deployment,pods,limitrange,resourcequota 2>/dev/null \
  || echo "El namespace lab-resource-quota ya no existe."

echo "== Borrando el namespace lab-resource-quota (espera a que termine) =="
kubectl delete -f 00-namespace.yaml --ignore-not-found

echo "Listo. Para volver a crearlo: ./aplicar.sh"

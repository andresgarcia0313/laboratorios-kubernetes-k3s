#!/usr/bin/env bash
# Borra el laboratorio 01. Al borrar el namespace, Kubernetes borra en cascada todo lo que contiene.
# No revierte cambios de configuración del clúster: este laboratorio no hace ninguno.
set -euo pipefail
cd "$(dirname "$0")"

echo "== Esto es lo que hay ahora en lab-01 =="
kubectl -n lab-01 get deployment,replicaset,pods 2>/dev/null || echo "El namespace lab-01 ya no existe."

echo "== Borrando el namespace lab-01 (puede tardar unos segundos) =="
kubectl delete -f 00-namespace.yaml --ignore-not-found

echo "Listo. Para volver a crearlo: ./aplicar.sh"

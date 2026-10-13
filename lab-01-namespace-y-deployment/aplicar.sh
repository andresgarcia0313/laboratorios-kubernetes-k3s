#!/usr/bin/env bash
# Crea el laboratorio 01 completo: namespace y Deployment, en orden de dependencia.
# No revierte nada: para deshacerlo usa ./eliminar.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "== Validando los manifiestos sin tocar el clúster =="
kubectl apply --dry-run=client -f 00-namespace.yaml -f 01-deployment.yaml

echo "== Creando el namespace =="
kubectl apply -f 00-namespace.yaml

echo "== Creando el Deployment =="
kubectl apply -f 01-deployment.yaml

echo "== Esperando a que las 2 réplicas estén disponibles =="
kubectl -n lab-01 rollout status deployment tienda --timeout=180s

echo "== Estado final =="
kubectl -n lab-01 get deployment,replicaset,pods

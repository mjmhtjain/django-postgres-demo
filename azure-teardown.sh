#!/bin/bash
set -e

for rgname in `az group list --query "[? contains(location,'east')][].{name:name}" -o tsv`;
do
echo Deleting ${rgname}
az group delete -n ${rgname} --yes --no-wait
done

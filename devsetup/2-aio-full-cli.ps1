# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License in the repo root for license information.
# ------------------------------------------------------------
Param(
    
  [string]
  [Parameter(mandatory = $True)]
  $ResourceGroupName,

  [string]
  [Parameter(mandatory = $True)]
  $ClusterName,

  [string]
  [Parameter(mandatory = $True)]
  $KeyVaultName

)

Write-Host "Pre-requisite - Key Vault"

az keyvault create -n $KeyVaultName -g $ResourceGroupName -o tsv --query id

$keyVaultResourceId = $(az keyvault show -n $KeyVaultName -g $ResourceGroupName -o tsv --query id)

Write-Host "Deploying AIO components"

az iot ops init --cluster $ClusterName -g $ResourceGroupName --kv-id $keyVaultResourceId `
  --mq-mode auto --simulate-plc

# Setup a NON TLS anonymous listener for MQTT broker - do not use in production, for dev purposes only
kubectl apply -f $PSScriptRoot/yaml/mq-listener-non-tls.yaml

# Currently using the azure-iot-operations namespace as the default selection - simplifies some config
kubectl config set-context --current --namespace=azure-iot-operations

Write-Host "AIO components deployed in Azure and on the K3D cluster in the dev container"  -ForegroundColor DarkGreen
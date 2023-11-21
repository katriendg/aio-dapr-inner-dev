# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License in the repo root for license information.
# ------------------------------------------------------------
Param(
    
  [string]
  [Parameter(mandatory = $True)]
  $ResourceGroupName,

  [string]
  [Parameter(mandatory = $False)]
  $ClusterName = "arck-aio-dev",

  [string]
  [Parameter(mandatory = $True)]
  $KeyVaultName,

  [string]
  [Parameter(mandatory = $False)]
  $TemplateFile = "minimal-mq.json",

  [string]
  [Parameter(mandatory = $False)]
  $ParametersFile = "minimal-mq-opc.parameters.json"

)

Write-Host "Pre-requisite - Key Vault"

az keyvault create -n $KeyVaultName -g $ResourceGroupName

$keyVaultResourceId = $(az keyvault show -n $KeyVaultName -g $ResourceGroupName -o tsv --query id)

Write-Host "Preparing AIO with CLI --no-deploy"
# Configure the Key Vault Extension on the Arc enabled cluster, configure App Registration and permissions

az iot ops init --cluster $ClusterName -g $ResourceGroupName --kv-id $keyVaultResourceId --no-deploy

Write-Host "Deploying AIO components with ARM template"

$random = Get-Random -Minimum 1000 -Maximum 9999
$deploymentName = "aio-deployment-$random"

az deployment group create `
--resource-group $ResourceGroupName `
--name aio-deployment-$deploymentName `
--template-file "$PSScriptRoot/templates/$TemplateFile" `
--parameters "$PSScriptRoot/environments/$ParametersFile" `
--parameters clusterName=$ClusterName `
--verbose --no-prompt

# TODO observability base chart via Helm

# Currently using the azure-iot-operations namespace as the default selection - simplifies some config
kubectl config set-context --current --namespace=azure-iot-operations

# Deploy MQ Broker, Listener and Diagnostics
Write-Host "Deploying MQTT Broker and TLS enabled Listener, and non-TLS Listener for dev purposes"
kubectl apply -f $PSScriptRoot/yaml/mq-cert-issuer.yaml
kubectl apply -f $PSScriptRoot/yaml/minimal-mq-broker.yaml
kubectl apply -f $PSScriptRoot/yaml/mq-listener-non-tls.yaml

# Deploy OPC UA Broker with Helm 
Write-Host "Deploying OPC UA components"

helm upgrade -i opcuabroker oci://mcr.microsoft.com/azureiotoperations/opcuabroker/helmchart/microsoft.iotoperations.opcuabroker `
    --set image.registry=mcr.microsoft.com     `
    --version 0.1.0-preview    `
    --namespace azure-iot-operations    `
    --create-namespace     `
    --set secrets.kind=k8s     `
    --set secrets.csiServicePrincipalSecretRef=aio-akv-sp `
    --set secrets.csiDriver:=secrets-store.csi.k8s.io `
    --set mqttBroker.address=mqtts://aio-mq-dmqtt-frontend.azure-iot-operations:8883     `
    --set mqttBroker.authenticationMethod=serviceAccountToken `
    --set mqttBroker.serviceAccountTokenAudience=aio-mq     `
    --set mqttBroker.caCertConfigMapRef='aio-ca-trust-bundle-test-only'     `
    --set mqttBroker.caCertKey=ca.crt `
    --set connectUserProperties.metriccategory=aio-opc     `
    --set opcPlcSimulation.deploy=true     `
    --wait

# TODO upgrade Helm chart to Preview or change to usage of CR create via Yaml (AssetEndpointProfile)
helm upgrade -i aio-opcplc-connector oci://mcr.microsoft.com/opcuabroker/helmchart/aio-opc-opcua-connector `
    --version 0.1.0-preview.6 `
    --namespace azure-iot-operations `
    --set opcUaConnector.settings.discoveryUrl="opc.tcp://opcplc-000000:50000" `
    --set opcUaConnector.settings.autoAcceptUntrustedCertificates=true `
    --wait

# Deploy AssetType and Asset instance - WIP this does not seem to work yet - no OPCUA messages in the broker
kubectl apply -f $PSScriptRoot/yaml/assettypes.yaml
kubectl apply -f $PSScriptRoot/yaml/asset.yaml

Write-Host "Key Vault, AIO MQ and OPC Broker deployed in Azure and connected K3D cluster"
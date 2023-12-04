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
  $KeyVaultName,

  [string]
  [Parameter(mandatory = $False)]
  $TemplateFile = "minimal-mq.json",

  [string]
  [Parameter(mandatory = $False)]
  $Location = "northeurope"

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
--parameters clusterName=$ClusterName `
--parameters location=$Location `
--parameters clusterLocation=$Location `
--verbose --no-prompt

# Currently using the azure-iot-operations namespace as the default selection - simplifies some config
kubectl config set-context --current --namespace=azure-iot-operations

# Deploy reflector to sync configmaps across namespaces
# https://github.com/emberstack/kubernetes-reflector
helm repo add emberstack https://emberstack.github.io/helm-charts
helm repo update
helm upgrade --install reflector emberstack/reflector

# Create mqtt-client service account in azure-iot-ooerations and default namespaces
kubectl create sa mqtt-client -n azure-iot-operations
kubectl create sa mqtt-client -n "default"

# az iot ops INIT done via CLI, configmap with the CA cert is created in azure-iot-operation namespace
# Annotate the configmap to allow emberstack/reflector to sync across namespaces, and auto-create in `default` namespace
kubectl annotate configmap aio-ca-trust-bundle-test-only -n azure-iot-operations reflector.v1.k8s.emberstack.com/reflection-allowed='true'
kubectl annotate configmap aio-ca-trust-bundle-test-only -n azure-iot-operations reflector.v1.k8s.emberstack.com/reflection-auto-enabled='true'
kubectl annotate configmap aio-ca-trust-bundle-test-only -n azure-iot-operations reflector.v1.k8s.emberstack.com/reflection-auto-namespaces='default'

# Deploy MQ Broker, Listener and Diagnostics
Write-Host "Deploying MQTT Broker and TLS enabled Listener, and non-TLS Listener for dev purposes"
kubectl apply -f $PSScriptRoot/yaml/ns/mq-cert-issuer.yaml
kubectl apply -f $PSScriptRoot/yaml/ns/mq-broker-default.yaml # this TLS listener has SAN DNS and IP settings for cross namespace hostname

# Deploy OPC UA Broker with Helm 
Write-Host "Deploying OPC UA components"

helm upgrade -i opcuabroker oci://mcr.microsoft.com/azureiotoperations/opcuabroker/helmchart/microsoft.iotoperations.opcuabroker `
    --set image.registry=mcr.microsoft.com     `
    --version 0.1.0-preview    `
    --namespace azure-iot-operations    `
    --create-namespace     `
    --set secrets.kind=k8s     `
    --set secrets.csiServicePrincipalSecretRef=aio-akv-sp `
    --set secrets.csiDriver=secrets-store.csi.k8s.io `
    --set mqttBroker.address=mqtts://aio-mq-dmqtt-frontend.azure-iot-operations.svc.cluster.local:8883     `
    --set mqttBroker.authenticationMethod=serviceAccountToken `
    --set mqttBroker.serviceAccountTokenAudience=aio-mq     `
    --set mqttBroker.caCertConfigMapRef='aio-ca-trust-bundle-test-only'     `
    --set mqttBroker.caCertKey=ca.crt `
    --set connectUserProperties.metriccategory=aio-opc     `
    --set opcPlcSimulation.deploy=true     `
    --wait

helm upgrade -i aio-opcplc-connector oci://mcr.microsoft.com/opcuabroker/helmchart/aio-opc-opcua-connector `
    --version 0.1.0-preview.6 `
    --namespace azure-iot-operations `
    --set opcUaConnector.settings.discoveryUrl="opc.tcp://opcplc-000000.azure-iot-operations.svc.cluster.local:50000" `
    --set opcUaConnector.settings.autoAcceptUntrustedCertificates=true `
    --wait

# Deploy AssetType and Asset instance
kubectl apply -f $PSScriptRoot/yaml/assettypes.yaml
kubectl apply -f $PSScriptRoot/yaml/asset.yaml
# Deploy an example of unmodelled asset (no AssetType)
kubectl apply -f $PSScriptRoot/yaml/asset-unmodelled.yaml

Write-Host "Finished - Key Vault, AIO MQ and OPC Broker deployed in Azure and connected K3D cluster"
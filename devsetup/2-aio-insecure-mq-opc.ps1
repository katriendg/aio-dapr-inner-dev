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
  [Parameter(mandatory = $False)]
  $TemplateFile = "insecure-mq.json",

  [string]
  [Parameter(mandatory = $False)]
  $Location = "northeurope"

)

Write-Host "Deploying AIO components with ARM template - $TemplateFile"

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

# TODO observability base chart via Helm

# Currently using the azure-iot-operations namespace as the default context - simplifies some config
Write-Host "Setting default namespace to azure-iot-operations"  -ForegroundColor DarkGreen
kubectl config set-context --current --namespace=azure-iot-operations

# Deploy MQ Broker, Listener and Diagnostics
Write-Host "Deploying broker and non-TLS Listener for dev purposes"
kubectl apply -f $PSScriptRoot/yaml/insecure-mq-broker-listener.yaml

# Deploy OPC UA Broker with Helm 
Write-Host "Deploying OPC UA components without TLS to MQ"

helm upgrade -i opcuabroker oci://mcr.microsoft.com/azureiotoperations/opcuabroker/helmchart/microsoft.iotoperations.opcuabroker `
    --set image.registry=mcr.microsoft.com     `
    --version 0.1.0-preview    `
    --namespace azure-iot-operations    `
    --create-namespace     `
    --set secrets.kind=k8s     `
    --set mqttBroker.address=mqtt://aio-mq-dmqtt-frontend.azure-iot-operations:1883     `
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

Write-Host "Finished - AIO, MQ and OPC Broker deployed in Azure and connected K3D cluster" -ForegroundColor DarkGreen
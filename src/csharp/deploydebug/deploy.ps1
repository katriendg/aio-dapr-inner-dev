# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License in the repo root for license information.
# ------------------------------------------------------------
param (    
    [Parameter(Mandatory=$False)]
    [string]$ContainerRegistry = "k3d-devregistry.localhost:5500",

    [Parameter(Mandatory=$True)]
    [string]$Version,

    [Parameter(Mandatory=$False)]
    [string]$Namespace = "azure-iot-operations"
)

$contents = (Get-Content $PSScriptRoot/yaml/samplepubsub.yaml) -Replace '__{container_registry}__', $ContainerRegistry

$contents = $contents -replace '__{image_version}__', $Version
$contents = $contents -replace '__{aio_namespace}__', $Namespace

$contents | kubectl apply -n $Namespace -f -
# Azure IoT Operations Inner Developer Loop - Sample with Dapr

> Note: [Azure IoT Operations](https://learn.microsoft.com/en-us/azure/iot-operations/) is currently in PREVIEW and subject to change. This sample might stop working at any time due to changes in the PREVIEW.

Inner dev loop with Visual Studio Code, dev container and Bridge to Kubernetes to allow local developer environment configuration and debugging of workloads.
The sample workload is using .NET, though the same debugging experience can be achieved with other languages.

## Prerequisites

- Visual Studio Code
- Docker
- Dev container support
- Azure subscription

## Initial Setup

Open this project in Visual Studio Code dev container:

- Open the Command palette
- Choose the option `Dev Containers: Reopen in container`
- Once the image has been initialized, the dev container will have initialized K3D Kubernetes cluster with a local container registry for development purposes. This is now ready for initializing Azure IoT Operations and Azure Arc. The container registry is available inside the devcontainer and inside the K3D cluster under the name `k3d-devregistry.localhost:5500`.

### Connect to Azure Arc

Run all these scripts from your PowerShell terminal.

Ensure you are logged into your Azure tenant and set a default subscription.

```powershell
 
az login # optionally add --tenant "tenantid"
az account set --subscription "mysubscription_name_or_id"
az account show

```

Run the following script remembering to take note of the parameters passed. Ensure that for the parameter `Location` you use one of the [supported regions](https://learn.microsoft.com/en-us/azure/iot-operations/get-started/quickstart-deploy?tabs=linux).

```powershell
 
 ./devsetup/1-arc.ps1 -ClusterName arck-MY-CLUSTER -ResourceGroupName rg-MY-RG -Location northeurope

```

### Deploy Azure IoT Operations

Run the following script to provision an Azure Key Vault and deploy AIO with the default settings,  including an MQ non-TLS listener and a Simulated PLC.

Please be patient as this deployment will take more than **15 minutes**.

```powershell
 
 ./devsetup/2-aio.ps1 -ClusterName arck-MY-CLUSTER -ResourceGroupName rg-MY-RG -KeyVaultName kv-MY-KEYVAULTNAME

```

This is a one-time setup and you are now ready to develop your custom modules and debug them on the cluster using Bridge for Kubernetes.

Work in Progress.

## Option to Leverage this Sample without Dev Container

It is also possible to run a local debug loop without the Visual Studio Dev Container, however this is not yet documented. The pre-requisites and setup will be explained at a later stage.

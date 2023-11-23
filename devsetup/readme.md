# AIO - Deployment Options in Developer Environment

The normal developer setup for this sample with AIO deployment follows a full AIO deployment as documented on the root [Readme](../README.md). Start there if you have not yet reviewed the document. For development purposes we also share a few different options to deploy AIO components in a more controlled and separated way.

## Sample 1: Deploying AIO Components: MQ, OPC Broker and Sample Asset

### Sample 1: Pre-requisites

- Dev Container setup with the K3D cluster, without any Azure Arc or Azure IoT Operations components installed
- `az login` has been executed and subscription set as default

If required, simply reset your environment using the `[0-cleanup.ps1 script](./devsetup/0-cleanup.ps1)`. See the [Readme - Clean up environment](../README.md#clean-up-environment-and-reset-dev-container)

### Sample 1: What will be deployed

On Azure:

- Azure Resource Group
- Azure Arc Connected Kubernetes cluster
- Azure Key Vault account
- Azure IoT Operations Arc extension
- AIO MQ Arc extension
- Azure Arc Custom Location
- Azure Arc custom location sync rules

On the K3D cluster:

- Azure Arc
- Azure (Arc) Provider for Secrets Store CSI Driver
- AIO base components (cert-manager, orchestrator, metrics)
- AIO MQ component with a Broker, a TLS Listener without auth, a non-TLS Listener for development, Diagnostics service
- OPC UA Broker, OPC UA Connector (AssetEndpointProfile), AssetType and Asset

### Sample 1: Deployment

- In a PowerShell terminal run the following script to connect the cluster to Azure Arc.

```powershell
 
 ./devsetup/1-arc.ps1 -ClusterName arck-MY-CLUSTER -ResourceGroupName rg-MY-RG -Location northeurope

```

- In a PowerShell terminal run the following script, passing in the same Resource Group and ClusterName as used above, ensuring the Azure Key Vault named passed in will be unique enough:

```powershell
./devsetup/2-aio-minimal-mq-opc.ps1 -ClusterName arck-MY-CLUSTER -ResourceGroupName rg-MY-RG -KeyVaultName kv-MY-KEYVAULTNAME  -Location northeurope
```

- Validate components are deployed by reviewing the pods. This can take a few minutes.

```powershell
kubectl get pods -n azure-iot-operations

NAME                                            READY   STATUS    RESTARTS      AGE
aio-cert-manager-cainjector-6c7c546578-9f5bv    1/1     Running   0             42m
aio-cert-manager-64f9548744-7jvqm               1/1     Running   0             42m
aio-cert-manager-webhook-7f676965dd-z58wg       1/1     Running   0             42m
aio-orc-controller-manager-6c4d9f6f98-qz74d     2/2     Running   0             42m
aio-orc-api-854b9967fc-d5fst                    2/2     Running   0             42m
aio-mq-operator-7656b665d8-b8bxj                3/3     Running   0             40m
aio-mq-diagnostics-service-6ccb67d785-77wfw     1/1     Running   0             35m
aio-mq-dmqtt-health-manager-0                   1/1     Running   0             35m
opcplc-000000-68c58f486-br8qh                   1/1     Running   0             35m
aio-opc-admission-controller-84f674cd69-zr2pg   1/1     Running   0             35m
aio-opc-supervisor-6d5c9b5964-vmm87             1/1     Running   1 (35m ago)   35m
aio-mq-dmqtt-backend-2-0                        1/1     Running   0             35m
aio-mq-dmqtt-backend-1-1                        1/1     Running   0             35m
aio-mq-dmqtt-backend-1-0                        1/1     Running   0             35m
aio-mq-dmqtt-backend-2-1                        1/1     Running   0             35m
aio-mq-dmqtt-frontend-1                         1/1     Running   0             29m
aio-mq-dmqtt-frontend-0                         1/1     Running   0             29m
aio-mq-diagnostics-probe-0                      1/1     Running   1 (28m ago)   35m
aio-mq-dmqtt-authentication-0                   1/1     Running   1 (28m ago)   35m
aio-opc-opc.tcp-1-6676cfc49f-5dg6n              2/2     Running   0             27m

```

- Once deployment is complete, open a new Terminal and run `mqttui` to watch messages from the OPC UA broker flow through to the MQTT broker. You should see messages under the topic `azure-iot-operations/data/opc.tcp/opc.tcp-1/thermostat-sample`.
- This concludes the setup of Sample 1.

## Sample 2: Deploying AIO Components MQ, OPC Broker and Sample Asset without TLS and Secrets (for dev only!) - Work in Progress...

This sample aims to deploy and configure AIO in the simplest form possible for trying out in a developer environment.

### Sample 2: Pre-requisites

- Dev Container setup with the K3D cluster, without any Azure Arc or Azure IoT Operations components installed
- `az login` has been executed and subscription set as default

If required, simply reset your environment using the `[0-cleanup.ps1 script](./devsetup/0-cleanup.ps1)`. See the [Readme - Clean up environment](../README.md#clean-up-environment-and-reset-dev-container)

### Sample 2: What will be deployed

On Azure:

- Azure Resource Group
- Azure Arc Connected Kubernetes cluster
- Azure IoT Operations Arc extension
- AIO MQ Arc extension
- Azure Arc Custom Location
- Azure Arc custom location sync rules

On the K3D cluster:

- Azure Arc
- AIO base components (cert-manager, orchestrator, metrics)
- AIO MQ component with a Broker, a non-TLS Listener for development, Diagnostics service
- OPC UA Broker, OPC UA Connector (AssetEndpointProfile), AssetType and Asset
- All local traffic between MQ and OPC Broker will be non-TLS

### Sample 2: Deployment

- In a PowerShell terminal run the following script to connect the cluster to Azure Arc.

```powershell
 
 ./devsetup/1-arc.ps1 -ClusterName arck-MY-CLUSTER -ResourceGroupName rg-MY-RG -Location northeurope

```

- In a PowerShell terminal run the following script to provision AIO:

```powershell
# Pass an exta argument -Location if you want something else than northeurope
./devsetup/2-aio-nontls-mq-opc.ps1 -ClusterName arck-MY-CLUSTER -ResourceGroupName rg-MY-RG

```

- Validate components are deployed by reviewing the pods. This can take a few minutes.

```powershell
kubectl get pods -n azure-iot-operations

NAME                                            READY   STATUS    RESTARTS      AGE
aio-cert-manager-cainjector-6c7c546578-l7fgh    1/1     Running   0          21m
aio-cert-manager-64f9548744-n9jvr               1/1     Running   0          21m
aio-cert-manager-webhook-7f676965dd-n54sf       1/1     Running   0          21m
aio-orc-controller-manager-6c4d9f6f98-j555s     2/2     Running   0          21m
aio-orc-api-6d88b76b99-gq9jp                    2/2     Running   0          21m
aio-mq-operator-889658cfb-dmfvs                 3/3     Running   0          19m
aio-mq-diagnostics-service-6ccb67d785-xgf7s     1/1     Running   0          10m
aio-mq-dmqtt-health-manager-0                   1/1     Running   0          10m
aio-mq-dmqtt-backend-1-0                        1/1     Running   0          10m
aio-mq-diagnostics-probe-0                      1/1     Running   0          10m
aio-mq-dmqtt-backend-2-0                        1/1     Running   0          10m
aio-mq-dmqtt-backend-2-1                        1/1     Running   0          10m
aio-mq-dmqtt-backend-1-1                        1/1     Running   0          10m
aio-mq-dmqtt-authentication-0                   1/1     Running   0          10m
aio-mq-dmqtt-frontend-0                         1/1     Running   0          10m
aio-mq-dmqtt-frontend-1                         1/1     Running   0          10m
opcplc-000000-68c58f486-wvvzc                   1/1     Running   0          3m5s
aio-opc-admission-controller-84f674cd69-mgst2   1/1     Running   0          3m5s
aio-opc-supervisor-5c464b7dd9-rflm9             1/1     Running   0          3m5s
aio-opc-opc.tcp-1-cb6944bdf-27vx9               2/2     Running   0          2m16s

```

- Once deployment is complete, open a new Terminal and run `mqttui` to watch messages from the OPC UA broker flow through to the MQTT broker. You should see messages under the topic `azure-iot-operations/data/opc.tcp/opc.tcp-1/thermostat-sample`.
- This concludes the setup of Sample 2.

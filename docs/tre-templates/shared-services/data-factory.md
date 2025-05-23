# Azure Data Factory Shared Service

Azure Data Factory provides managed ETL/ELT services that can be used to automate data import into the TRE (especially in the case of data sets that are too large for the airlock process, or that need to be loaded into blob or data lake storage for use with Databricks). In particular it is useful for data imports that need to run repeatedly (especially on a schedule), e.g. to import newly available or updated data.

Documentation on Data Factory can be found here: [https://learn.microsoft.com/en-us/azure/data-factory/](https://learn.microsoft.com/en-us/azure/data-factory/).

The ADF Shared Service includes:
-	An Azure Data Factory instance
-	A user-defined managed identity used by ADF to authenticate to Azure resources; this identity is granted Storage Blob Data Contributor and Storage File Privileged Contributor at the TRE subscription level to allow access to all workspace storage accounts by default, as well as Secrets Reader for the dedicated Key Vault. (The user-defined managed identity can also be created externally and passed into the create dialog instead of letting the TRE create it.)
-	An "intermediate" storage account used for temporary storage for data that needs to be transformed before landing in the workspace storage account(s)
-	A dedicated Key Vault used to hold connection information/secrets used in ADF pipelines
-	An Auto-resolve Integration Runtime for use with public data sources
-	An Azure-hosted Managed Virtual Network Integration Runtime for use with the Intermediate and Workspace storage accounts and other data sinks

Information about the created resources is displayed on the Shared Service’s Details tab within the TRE Portal.
For access to on-premise or other private data sources you may need to create a Self-Hosted or other Integration Runtime and configure it within ADF; these steps are not documented here.

## Deploy

If you will be using an externally created user-defined managed identity, you will need to know the name of the identity and the name of the resource group it was created in. At this time the MI must be created in the same subscription as the TRE Core is deployed to.

To deploy the Data Factory Shared Service:

1. Run the below command in your terminal to build, publish and register the Data Factory shared service bundle:

  ```cmd
  make shared_service_bundle BUNDLE=data-factory
  ```

1. Navigate back to the TRE UI, and click *Create new* again within the Shared Services page.

2. Select the Data Factory template, then fill in the required details. 

This will deploy the infrastructure required for Data Factory into the TRE Core resource group.

## Setup and usage

Users granted the Azure RBAC role `Data Factory Contributor` or any role that is a superset of that one at either the TRE Core Resource Group or Subscription level (or above) can access Data Factory Studio though the Azure Portal or via the Connect button on the Shared Service page. Accessing Data Factory from within the TRE is not necessary as the Data Factory is intended to be externally available in order to facilitate data movement. 

The intermediate storage account is intended for **ephemeral storage** only. Data should only be stored there long enough to apply any necessary transformations, copied into the destination, and then deleted from the intermediate storage account. Data that does not need to be transformed should be copied directly from source to the target workspace and should not touch the intermediate storage account at all.

In order to access a given workspace's storage account an administrator will need to create one or more Managed Private Endpoints from within the Data Factory Studio targeting the correct storage account's blob, file, or datalake subtypes (depending on how the data will be stored).

The Details page on the Data Factory Shared Service page also provides a number of useful pieces of information, such as the name of the deployed ADF resource, the name and URI of the ADF-dedicated Key Vault used to store connection secrets, and the name and hostnames of the Intermediate Storage account used when data requires transformation before it is landed in the target workspace storage account.

Be aware that changing any of the values in the Shared Service Update screen will likely cause the Data Factory to be deleted and recreated.

### Initial setup

#### Managed Private Endpoints

The deployment will automatically create 3 Managed Private Endpoints to the Intermediate storage account and one to the ADF-dedicated Key Vault; these require manual approval.

1. Connect to the Data Factory (by clicking the Connect button in the TRE Shared Service page), then navigate to the Managed Private Endpoints page. 
2. Click any of the -storage endpoints, then click the “Manage approvals in Azure portal” link at the bottom of the pane that opens. On the resulting Azure page, click the Private endpoint connections tab, check the boxes next to all of the Pending endpoints that say “Requested by DataFactory”, then click Approve and confirm the action.
3. Repeat for the Key Vault managed private endpoint.
4. Refresh the list of managed private endpoints periodically until all 4 endpoints show Approved/Approved.
 
#### Creating the ADF Credential

1. Navigate to the Manage > Security > Credentials page in the Data Factory Studio and click +New.
2. Under Type, select User-assigned managed identity. Select the correct Azure subscription (the one the TRE Core is deployed to) and the User-assigned managed identity listed in the Shared Service Details. Then click Create.

#### Linking the Data Factory to GitHub
1. From within the Data Factory Studio, click the Manage icon  in the left hand nav bar, then select Git configuration under Source control.
2. Provide the following settings:
* Repository type: GitHub (do not check Use GitHub Enterprise Server)
* GitHub repository owner: <Your GitHub organization>
* Repository name: <The repository intended to hold ADF code>
* Collaboration branch: main (or any other branch as desired)
* Publish branch: adf_publish (or any other branch as desired)
* Root folder: /
* Import existing resources: Unchecked

It is strongly recommended to apply branch protection policies to the Collaboration branch in order to ensure that changes being published follow policy etc.; in particular, if Data Factory is intended to be used to **import** data but not to **export** data, pipelines should be carefully reviewed for compliance.

#### Adding a new TRE workspace as a target
When you create a new workspace, if ADF will be used to import data into that workspace the following actions must be performed. 

Note that the ADF identity will automatically have access to the workspace storage account, so no permissions changes are needed.

Add one or more Managed Private Endpoint(s)

You will need to discuss with the Researcher(s) and Data Factory user(s) who will be using and importing data into the workspace to determine which private endpoints are necessary.

If the Researcher(s) plan to use the data in file form, e.g. opening it in Excel or processing it locally on the TRE VM, then you will need to add a File endpoint. If they are planning to use the data in blob or data lake form, e.g. accessing it from Databricks, Azure ML, etc., then you will need to add a Blob or Data Lake endpoint. You can add multiple, however this will increase the cost of the workspace vs. adding one.

Adding a Managed private endpoint

1. From within the Data Factory Studio, click the Manage icon in the left hand nav bar, then select Managed private endpoints under Security. 
2. To add a new private endpoint, click the + New button. Select the type of resource you want to link to. For File endpoints, locate or search for the “Azure File Storage” type; for Blob, locate or search for “Azure Blob Storage”, then select Continue. Give the MPE a name of the format WS-<workspace_id>-<type>-storage where <workspace_id> is the last 4 characters of the target Workspace ID, and <type> is either “file” or “blob” depending.
3. Select the Azure Subscription containing the target workspace, then search for a storage account named stgws<workspace_id>, where the <workspace_id> is the same as above (last 4 characters of the Workspace ID). Select the Create button.
4. The UI will refresh to show the new endpoint in a Provisioning state. Click the endpoint’s name, then at the bottom click the Manage approvals in Azure portal link.
5. In the new widow that opens, click the Private endpoint connections tab, find the new private endpoint (it will be in the Pending state and the Description field will say “Requested by DataFactory”), check the checkbox next to it, then click Approve.
6. Select Yes on the approval dialog (you can update the Description field if you like).
7. Return to the Data Factory window. After a few minutes, if you refresh, the new Managed Private Endpoint should change to show a Provisioning State of “Approved” and an Approval State of “Approved”. At this point the MPE is ready to be used to copy data via ADF.

Removing Managed Private Endpoints

For workspaces where the data only needs to be imported one time, the Managed Private Endpoint(s) created for that workspace can safely be deleted after the import is completed. Make sure you have removed any Data Factory Linked Services referencing the MPE first (you can see them by clicking the link under Possible Linked Services; if the number is 0 the MPE is safe to delete).
In the Manage > Security > Managed private endpoints page, hover over the MPE to be deleted and then click the trash can to delete the MPE, then confirm the deletion.

## Network requirements

While Data Factory requires access to resources outside of the Azure TRE VNET, it is expected that one or more integration runtimes will be provisioned that have access to those resources. Additional `datafactory` private endpoints can be created that those integration runtimes have network connectivity to in order to communicate with the Data Factory in the TRE. Thus no additional firewall rules are created or necessary. However, if you prefer to provide the automatically deployed VNet-integrated integration runtime with external access, those rules can be manually applied.

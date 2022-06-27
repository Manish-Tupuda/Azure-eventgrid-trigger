
data "azurerm_resource_group" "sample" {
  name     = "Manish"
  
  /*tags = {
    sample = "azure-functions-event-grid-terraform"
  }*/
}

resource "azurerm_eventgrid_topic" "sample_topic" {
  name                = "${var.prefix}-azsam-egt"
  location            = var.location
  resource_group_name = "Manish"
  tags = {
    sample = "azure-functions-event-grid-terraform"
  }
}

resource "azurerm_application_insights" "logging" {
  name                = "${var.prefix}-ai"
  location            = var.location
  resource_group_name = "Manish"
  application_type    = "web"
  retention_in_days   = 90
  tags = {
    sample = "azure-functions-event-grid-terraform"
  }
}

resource "azurerm_storage_account" "inbox" {
  name                      = "${var.prefix}inboxsa"
  resource_group_name       = "Manish"
  location                  = var.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  account_kind              = "StorageV2"
  enable_https_traffic_only = true
  tags = {
    sample = "azure-functions-event-grid-terraform"
  }
}

resource "azurerm_storage_container" "storagecontainer" {
  name                  = "contzss"
  storage_account_name  = azurerm_storage_account.inbox.name
  container_access_type = "private"
}

data "archive_file" "file_function_app" {
  type        = "zip"
  source_dir  = "C:/Users/Quadrant/OneDrive - Quadrant Resource LLC/Documents/sample/Project1/Function/bin/Debug/netcoreapp3.1/publish"
  output_path = "C:/Users/Quadrant/OneDrive - Quadrant Resource LLC/Documents/sample/Project1/Function/bin/Debug/netcoreapp3.1/publish/now.zip"
}
resource "azurerm_storage_blob" "appcode" {
  name = "httptrigger.zip"
  storage_account_name = azurerm_storage_account.inbox.name
  storage_container_name = azurerm_storage_container.storagecontainer.name
  type = "Block"
  source = "C:/Users/Quadrant/OneDrive - Quadrant Resource LLC/Documents/sample/Project1/Function/bin/Debug/netcoreapp3.1/publish/now.zip"
}

data "azurerm_storage_account_blob_container_sas" "storage_account_blob_container_sas" {
  connection_string = azurerm_storage_account.inbox.primary_connection_string
  container_name    = azurerm_storage_container.storagecontainer.name

  start = "2021-01-01T00:00:00Z"
  expiry = "2022-01-01T00:00:00Z"

  permissions {
    read   = true
    add    = false
    create = false
    write  = false
    delete = false
    list   = false
  }
}
resource "azurerm_app_service_plan" "fxnapp" {
  name                = "${var.prefix}-fxn-plan"
  location            = var.location
  resource_group_name = "Manish"
  kind                = "functionapp"
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
  tags = {
    sample = "azure-functions-event-grid-terraform"
  }
}


resource "azurerm_function_app" "fsn" {
  name                       = "${var.prefix}-fxn"
  location                   = var.location
  resource_group_name        = "Manish"
  app_service_plan_id        = azurerm_app_service_plan.fxnapp.id
  //storage_account_name       = azurerm_storage_account.fxnstor.name
  //storage_account_access_key = azurerm_storage_account.fxnstor.primary_access_key
  //version                    = "~3"
  tags = {
    sample = "azure-functions-event-grid-terraform"
  }
  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE"    = "https://${azurerm_storage_account.inbox.name}.blob.core.windows.net/${azurerm_storage_container.storagecontainer.name}/${azurerm_storage_blob.appcode.name}${data.azurerm_storage_account_blob_container_sas.storage_account_blob_container_sas.sas}",
    "FUNCTIONS_WORKER_RUNTIME" = "dotnet",
    "AzureWebJobsDisableHomepage" = "true",
    AppInsights_InstrumentationKey = azurerm_application_insights.logging.instrumentation_key
  sample_topic_endpoint                    = azurerm_eventgrid_topic.sample_topic.endpoint
  sample_topic_key                         = azurerm_eventgrid_topic.sample_topic.primary_access_key
  }
  
os_type = "linux"
  site_config {
    use_32_bit_worker_process = false
  }
  storage_account_name       = azurerm_storage_account.inbox.name
  storage_account_access_key = azurerm_storage_account.inbox.primary_access_key
  version                    = "~3"



  # We ignore these because they're set/changed by Function deployment
  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"]
    ]
  }
}

/*
module "functions" {
  source                                   = "./functions"
  prefix                                   = var.prefix
  resource_group_name                      = azurerm_resource_group.sample.name
  location                                 = azurerm_resource_group.sample.location
  application_insights_instrumentation_key = azurerm_application_insights.logging.instrumentation_key
  sample_topic_endpoint                    = azurerm_eventgrid_topic.sample_topic.endpoint
  sample_topic_key                         = azurerm_eventgrid_topic.sample_topic.primary_access_key
}
*/


resource "azurerm_eventgrid_event_subscription" "eventgrid_subscription" {
  name   = "${var.prefix}-handlerfxn-egsub"
  scope  = azurerm_storage_account.inbox.id
  labels = ["azure-functions-event-grid-terraform"]
  azure_function_endpoint {
    //function_id = "azurerm_function_app.fsn.id/functions/EventGridTrigger1.eventGridFunctionName"
    //function_id = "/subscriptions/28576802-f8de-468d-97c1-db184a0f64e9/resourceGroups/Manish/providers/Microsoft.Web/sites/newfsz-fxn/functions/EventGridTrigger1.eventGridFunctionName"
    function_id = "${azurerm_function_app.fsn.id}/functions/${var.eventGridFunctionName}"

    # defaults, specified to avoid "no-op" changes when 'apply' is re-ran
    max_events_per_batch              = 1
    preferred_batch_size_in_kilobytes = 64
  }
}


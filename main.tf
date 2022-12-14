terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.34.0"
    }
  }

  backend "local" {}
}

provider "azurerm" {
  features {}
}

data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

data "azurerm_subnet" "test_pep_sub3" {
  name                 = var.snet_name
  resource_group_name  = var.vnet_resource_group_name
  virtual_network_name = var.vnet_name
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags = {
    akosid = "iot_sbx"
  }
}

resource "azurerm_storage_account" "asa" {
  name                          = var.storage_account_name
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  account_kind                  = "StorageV2"
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  public_network_access_enabled = false
  is_hns_enabled                = true
  tags = {
    akosid = "iot_sbx"
  }
}

resource "azurerm_storage_container" "backend" {
  name                  = join("-", [var.project, "terraform", "states"])
  storage_account_name  = azurerm_storage_account.asa.name
  container_access_type = "private"
  depends_on = [
    azurerm_private_endpoint.pep
  ]
}

data "azurerm_private_dns_zone" "dns01" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = "rg_aiplatform_poc"
}

resource "azurerm_private_dns_a_record" "arecord" {
  name                = join("-", [var.project, "terraform", "states"])
  zone_name           = "privatelink.blob.core.windows.net"
  resource_group_name = "rg_aiplatform_poc"
  ttl                 = 10
  records             = [azurerm_private_endpoint.pep.private_service_connection.0.private_ip_address]
}

resource "azurerm_private_endpoint" "pep" {
  name                = join("-", [var.project, "terraform", "states"])
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = data.azurerm_subnet.test_pep_sub3.id
  private_service_connection {
    name                           = join("-", [var.project, "terraform", "states"])
    private_connection_resource_id = azurerm_storage_account.asa.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }
  private_dns_zone_group {
    name                 = data.azurerm_private_dns_zone.dns01.name
    private_dns_zone_ids = [data.azurerm_private_dns_zone.dns01.id]
  }
  tags = {
    akosid = "iot_sbx"
  }
}

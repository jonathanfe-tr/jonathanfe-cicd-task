
#################################################################
# Commands #####################################################
#
# terraform apply -var "environment=dev"
#
# terraform apply -var "environment=production"
#
#
#
#
#
#############################################################################
# TERRAFORM CONFIG
#############################################################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.0"
    }
  }
      backend "azurerm" {
        resource_group_name  = "jonathanfeTF"
        storage_account_name = "jonathanfe"
        container_name       = "tfstate"
        key                  = "terraform.tfstate"
    }
}









#############################################################################
# VARIABLES
#############################################################################

variable "resource_group_name" {
  type = string
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "environment" {
  type = string

}

variable "vnet" {
  type = string 
}

variable "sub" {
  type = string 
  
}

# #variable "counter" {
# #  type = string  
# #}


# #############################################################################
# # PROVIDERS
# #############################################################################

 provider "azurerm" {
   features {}
 }

# #############################################################################
# # RESOURCES
# #############################################################################


 resource "azurerm_resource_group" "jonathanfeTF" {
#   name     = "${var.resource_group_name}-${terraform.workspace}"
   name     = "${var.resource_group_name}"
   location = var.location

 }




 resource "azurerm_virtual_network" "jonathanfeTF" {
   name                = "jonathanfe-terraform-network-${terraform.workspace}"
 #  address_space       = ["30.0.0.0/16"]
   address_space       = [var.vnet] 
   location            = azurerm_resource_group.jonathanfeTF.location
   resource_group_name = azurerm_resource_group.jonathanfeTF.name
 }

 resource "azurerm_subnet" "jonathanfeTF" {
   name                 = "database"
   resource_group_name  = azurerm_resource_group.jonathanfeTF.name
   virtual_network_name = azurerm_virtual_network.jonathanfeTF.name
  # address_prefixes     = ["30.0.1.0/24"]
  address_prefixes     = [var.sub]
 }

 resource "azurerm_network_interface" "jonathanfeTF" {
   count = "${terraform.workspace == "production" ? 2 : 1}"
#   #  count = var.environment == "production" ? 3 : 1 

#   count               = 3
   name                = "jonathanfe-terraform-nic${count.index}-${terraform.workspace}"
   location            = azurerm_resource_group.jonathanfeTF.location
   resource_group_name = azurerm_resource_group.jonathanfeTF.name

   ip_configuration {
     name                          = "database"
     subnet_id                     = azurerm_subnet.jonathanfeTF.id
     private_ip_address_allocation = "Dynamic"
   }
 }

 resource "azurerm_virtual_machine" "jonathanfeTF" {
   count = "${terraform.workspace == "production" ? 2 : 1}"
#   #  count               =  var.environment == "production" ? 3 : 1 
#   count               = 3
   name                = "jonathanfe-terraform-machine${count.index}-${terraform.workspace}"
   resource_group_name = azurerm_resource_group.jonathanfeTF.name
   location            = azurerm_resource_group.jonathanfeTF.location
   vm_size             = "Standard_DS1_v2"
   #  size                = "Standard_F2"
   availability_set_id = azurerm_availability_set.vm-availability-set.id 
   network_interface_ids = [
     azurerm_network_interface.jonathanfeTF[count.index].id,
   ]


   os_profile {
     computer_name  = "hostname"
     admin_username = "testadmin"
   }
   os_profile_linux_config {
     disable_password_authentication = true
     ssh_keys {
       key_data = data.azurerm_key_vault_secret.main.value


     #  key_data = file("~/.ssh/id_rsa.pub")
       path     = "/home/testadmin/.ssh/authorized_keys"
     }
     
     
     
   }



   storage_os_disk {
     name              = "myosdisk${count.index}-${terraform.workspace}"
     caching           = "ReadWrite"
     create_option     = "FromImage"
     managed_disk_type = "Standard_LRS"
   }

   storage_image_reference {
     publisher = "Canonical"
     offer     = "UbuntuServer"
     sku       = "16.04-LTS"
     version   = "latest"
   }

 }
 



   data "azurerm_virtual_network" "jonathanfe-bastionTF" {
     name                = "bastion1"
     resource_group_name = "bastion1"
   }

   data "azurerm_resource_group" "bastion-rg" {
     name = "bastion1"
   }

   resource "azurerm_virtual_network_peering" "jonathanfe-bastionTF" {
     name                         = "${var.resource_group_name}"
     resource_group_name          = azurerm_resource_group.jonathanfeTF.name
     virtual_network_name         = azurerm_virtual_network.jonathanfeTF.name
     remote_virtual_network_id    = data.azurerm_virtual_network.jonathanfe-bastionTF.id
    allow_virtual_network_access = true
     allow_forwarded_traffic      = true
     allow_gateway_transit        = false
   }
   resource "azurerm_virtual_network_peering" "jonathanfe-peering" {
     name                         = "peering-${terraform.workspace}"
     resource_group_name          = data.azurerm_resource_group.bastion-rg.name
     virtual_network_name         = data.azurerm_virtual_network.jonathanfe-bastionTF.name
     remote_virtual_network_id    = azurerm_virtual_network.jonathanfeTF.id
     allow_virtual_network_access = true
     allow_forwarded_traffic      = true
     allow_gateway_transit        = false
   }


    resource "azurerm_public_ip" "LBRG" {
      name                = "PublicIPForLB"
      location            = var.location
      resource_group_name = azurerm_resource_group.jonathanfeTF.name
      allocation_method   = "Static"
    }
    resource "azurerm_lb" "LBRG" {
      name                = "TestLoadBalancer"
      location            = var.location
      resource_group_name = azurerm_resource_group.jonathanfeTF.name
      frontend_ip_configuration {
        name                 = "PublicIPAddress"
        public_ip_address_id = azurerm_public_ip.LBRG.id
      }
    }
     resource "azurerm_lb_backend_address_pool" "backend-pool" {
     loadbalancer_id = azurerm_lb.LBRG.id
     name            = "BackEndAddressPool"
   }
   resource "azurerm_network_interface_backend_address_pool_association" "example" {
   count = "${terraform.workspace == "production" ? 2 : 1}"
  # count                   = 3
   network_interface_id    = azurerm_network_interface.jonathanfeTF[count.index].id
   ip_configuration_name   = "database"
   backend_address_pool_id = azurerm_lb_backend_address_pool.backend-pool.id 
   }
     resource "azurerm_lb_probe" "LBRG" {
     resource_group_name = azurerm_resource_group.jonathanfeTF.name
     loadbalancer_id     = azurerm_lb.LBRG.id 
     name                = "lb-health-probe"
     port                = 8080
   }
     resource "azurerm_lb_rule" "LBRG" {
     resource_group_name            = azurerm_resource_group.jonathanfeTF.name
     loadbalancer_id                = azurerm_lb.LBRG.id
     name                           = "LBRule"
     protocol                       = "Tcp"
     frontend_port                  = 80
     backend_port                   = 8080
     backend_address_pool_id        = azurerm_lb_backend_address_pool.backend-pool.id 
     frontend_ip_configuration_name = "PublicIPAddress"
     probe_id                       = azurerm_lb_probe.LBRG.id
   }
    resource "azurerm_availability_set" "vm-availability-set" {
      name                = "example-aset"
      location            = azurerm_resource_group.jonathanfeTF.location
      resource_group_name = azurerm_resource_group.jonathanfeTF.name
    }
 
#    resource "azurerm_virtual_machine_extension" "vm-extension" {
#      count = "${terraform.workspace == "production" ? 5 : 1}"
#   #   count                = 3
#      name                 = "jonathanfe"
#      virtual_machine_id   = azurerm_virtual_machine.jonathanfeTF[count.index].id
#      publisher            = "Microsoft.Azure.Extensions"
#      type                 = "CustomScript"
#      type_handler_version = "2.1"
#      settings = <<SETTINGS
#      {
# "commandToExecute": "bash script.sh"
#      }
#    SETTINGS
#    }
 resource "azurerm_network_security_group" "nsg" {
   name                = "firewall"
   location            = azurerm_resource_group.jonathanfeTF.location
   resource_group_name = azurerm_resource_group.jonathanfeTF.name
    security_rule {
     name                       = "port80"
     priority                   = 100
     direction                  = "Inbound"
     access                     = "Allow"
     protocol                   = "Tcp"
     source_port_range          = "*"
     destination_port_range     = "80"
     source_address_prefix      = "34.99.159.243/32"
     destination_address_prefix = "*"
   }
 }
 resource "azurerm_network_interface_security_group_association" "nsg" {
   count = "${terraform.workspace == "production" ? 2 : 1}"
   # count = 3 
   network_interface_id      = azurerm_network_interface.jonathanfeTF[count.index].id 
   network_security_group_id = azurerm_network_security_group.nsg.id 
 }





data "azurerm_key_vault" "kv" {
  name                = "jonathanfekeyvault"
  resource_group_name = "jonathanfe-azuretask-rg"
}
data "azurerm_key_vault_secret" "main" {
  name         = "jonathanfe-public-key"
  key_vault_id = data.azurerm_key_vault.kv.id
}


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
        resource_group_name  = "jonathanfeTF2"
        storage_account_name = "jonathanfe2"
        container_name       = "tfstate2"
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

# variable "script" {
#   type = string 
  
# }



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

data "azurerm_resource_group" "storage-account" {
  name = "jonathanfeTF2"
}



 resource "azurerm_virtual_network" "jonathanfeTF" {
   name                = "jonathanfe-terraform-network-${terraform.workspace}"
   address_space       = [var.vnet] 
   location            = azurerm_resource_group.jonathanfeTF.location
   resource_group_name = azurerm_resource_group.jonathanfeTF.name
 }

 resource "azurerm_subnet" "jonathanfeTF" {
   name                 = "database"
   resource_group_name  = azurerm_resource_group.jonathanfeTF.name
   virtual_network_name = azurerm_virtual_network.jonathanfeTF.name
  address_prefixes     = [var.sub]
 }

 resource "azurerm_network_interface" "jonathanfeTF" {
   count = "${terraform.workspace == "production" ? 2 : 3}"
   name                = "jonathanfe-terraform-nic${count.index}-${terraform.workspace}"
   location            = azurerm_resource_group.jonathanfeTF.location
   resource_group_name = azurerm_resource_group.jonathanfeTF.name

   ip_configuration {
     name                          = "database"
     subnet_id                     = azurerm_subnet.jonathanfeTF.id
     private_ip_address_allocation = "Dynamic"
     public_ip_address_id = azurerm_public_ip.publicip[count.index].id 
   }
 }

 resource "azurerm_virtual_machine" "jonathanfeTF" {
   count = "${terraform.workspace == "production" ? 2 : 3}"
   name                = "jonathanfe-terraform-machine${count.index}-${terraform.workspace}"
   resource_group_name = azurerm_resource_group.jonathanfeTF.name
   location            = azurerm_resource_group.jonathanfeTF.location
   vm_size             = "Standard_DS1_v2"
   availability_set_id = azurerm_availability_set.vm-availability-set.id 
   network_interface_ids = [
     azurerm_network_interface.jonathanfeTF[count.index].id,
   ]


   os_profile {
     computer_name  = "hostname"
     admin_username = "testadmin"
     admin_password = "Password1234!"
   }
   os_profile_linux_config {
     disable_password_authentication = false
     ssh_keys {
       key_data = data.azurerm_key_vault_secret.publickey.value


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
     name                         = "peering-jf-${terraform.workspace}"
     resource_group_name          = data.azurerm_resource_group.bastion-rg.name
     virtual_network_name         = data.azurerm_virtual_network.jonathanfe-bastionTF.name
     remote_virtual_network_id    = azurerm_virtual_network.jonathanfeTF.id
     allow_virtual_network_access = true
     allow_forwarded_traffic      = true
     allow_gateway_transit        = false
   }


    resource "azurerm_public_ip" "publicip" {
      name                = "PublicIP"
      location            = var.location
      resource_group_name = azurerm_resource_group.jonathanfeTF.name
      allocation_method   = "Dynamic"
    }

    resource "azurerm_availability_set" "vm-availability-set" {
      name                = "example-aset"
      location            = azurerm_resource_group.jonathanfeTF.location
      resource_group_name = azurerm_resource_group.jonathanfeTF.name
    }
 
   resource "azurerm_virtual_machine_extension" "vm-extension" {
     count = "${terraform.workspace == "production" ? 2 : 3}"
  #   count                = 3
      name                 = "jonathanfe"
      virtual_machine_id   = azurerm_virtual_machine.jonathanfeTF[count.index].id
      publisher            = "Microsoft.Azure.Extensions"
      type                 = "CustomScript"
      type_handler_version = "2.1"
      settings = <<SETTINGS
      {
 "commandToExecute": "sudo apt-get install openjdk-8-jre-headless -y && wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add - && sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list' && sudo apt update -y && sudo apt install jenkins -y"

                     
      }
    SETTINGS
    }


 resource "azurerm_network_security_group" "nsg" {
   name                = "firewall"
   location            = azurerm_resource_group.jonathanfeTF.location
   resource_group_name = azurerm_resource_group.jonathanfeTF.name
    security_rule {
     name                       = "jenkins"
     priority                   = 100
     direction                  = "Inbound"
     access                     = "Allow"
     protocol                   = "Tcp"
     source_port_range          = "*"
     destination_port_range     = "8080"
     source_address_prefix      = "34.99.159.243/32"
     destination_address_prefix = "*"
   }
      security_rule {
     name                       = "port80"
     priority                   = 110
     direction                  = "Inbound"
     access                     = "Allow"
     protocol                   = "Tcp"
     source_port_range          = "*"
     destination_port_range     = "80"
     source_address_prefix      = "34.99.159.243/32"
     destination_address_prefix = "*"
   }
    security_rule {
     name                       = "ssh"
     priority                   = 10
     direction                  = "Inbound"
     access                     = "Allow"
     protocol                   = "Tcp"
     source_port_range          = "*"
     destination_port_range     = "22"
     source_address_prefix      = "*"
     destination_address_prefix = "*"
   }
 }
 resource "azurerm_network_interface_security_group_association" "nsg" {
   count = "${terraform.workspace == "production" ? 2 : 3}"
   # count = 3 
   network_interface_id      = azurerm_network_interface.jonathanfeTF[count.index].id 
   network_security_group_id = azurerm_network_security_group.nsg.id 
 }



 


##Managed Identity

resource "azurerm_user_assigned_identity" "managed_identity" {
  count = "${terraform.workspace == "production" ? 2 : 3}"
  location            = var.location
  name                  = "jonathanfe-cicd"
}

# keyvault-data

data "azurerm_key_vault" "kv" {
  name                = "jonathanfekeyvault"
  resource_group_name = "jonathanfe-azuretask-rg"
}
data "azurerm_key_vault_secret" "publickey" {
  name         = "jonathanfe-public-key"
  key_vault_id = data.azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "privatekey" {
  name         = "jonathanfe-key"
  key_vault_id = data.azurerm_key_vault.kv.id
}
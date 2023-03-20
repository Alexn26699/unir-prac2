#---------------------------------------------------------------------------------------------------
# Primero levantamos los grupos de recursos para cada servicio.

#resource "azurerm_resource_group" "RG-TERRAFORM-STATES" {
#  name     = "RG-TERRAFORM-STATES"
#  location = "West Europe"
#}

resource "azurerm_resource_group" "RG-REGISTRY" {
  name     = "RG-REGISTRY"
  location = "West Europe"
}

resource "azurerm_resource_group" "RG-VM" {
  name     = "RG-VM"
  location = "West Europe"
}

resource "azurerm_resource_group" "RG-AKS" {
  name     = "RG-AKS"
  location = "West Europe"
}

#---------------------------------------------------------------------------------------------------
# Levantamos un storageaccount con un contenedor para que los States de Terraform se guarden.

#resource "azurerm_storage_account" "unirterraformstates" {
#  name                     = "unirterraformstates"
#  resource_group_name      = "RG-TERRAFORM-STATES"
#  location                 = "West Europe"
#  account_tier             = "Standard"
#  account_replication_type = "LRS"

#  tags = {
#    environment = "registry"
#  }
#}

#resource "azurerm_storage_container" "stcontainer" {
#  name                  = "tfcluster"
#  storage_account_name  = "unirterraformstates"
#  container_access_type = "private"
#}

#---------------------------------------------------------------------------------------------------
# Levantamos el servicio ACR.

resource "azurerm_container_registry" "unirregistry" {
  name                = "unirregistry"
  resource_group_name = "RG-REGISTRY"
  location            = "West Europe"
  sku                 = "Basic"
}

#---------------------------------------------------------------------------------------------------
# Levantamos la VM y los servicios de red.

resource "azurerm_virtual_network" "vnet" {
  name                = "Vnet-unir"
  address_space       = ["10.1.0.0/24"]
  location            = "West Europe"
  resource_group_name = "RG-VM"
}

resource "azurerm_subnet" "subnet" {
  name                 = "sub-vm"
  resource_group_name  = "RG-VM"
  virtual_network_name = "Vnet-unir"
  address_prefixes     = ["10.1.0.0/24"]
}

resource "azurerm_public_ip" "public_ip" {
  name                = "az-unir-vm-ip"
  resource_group_name = "RG-VM"
  location            = "West Europe"
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nic" {
  name                = "unir-nic"
  location            = "West Europe"
  resource_group_name = "RG-VM"

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "az-unir-vm-nsg"
  location            = "West Europe"
  resource_group_name = "RG-VM"

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    description                = "Allow SSH"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

}

resource "azurerm_subnet_network_security_group_association" "linux-vm-nsg-association" {
  depends_on=[azurerm_resource_group.RG-VM]
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                            = "az-unir-vm"
  location                        = "West Europe"
  resource_group_name             = "RG-VM"
  network_interface_ids           = [azurerm_network_interface.nic.id]
  size                            = "Standard_B1s"
  admin_username                  = "alex"
  disable_password_authentication = true
 # admin_password                  = "Pass1234!"  

  admin_ssh_key {
    username   = "alex"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}


#---------------------------------------------------------------------------------------------------
# Levantamos Vnet-aks y Cluster AKS

resource "azurerm_virtual_network" "aksvnet" {
  name                = "Vnet-aks"
  location            = "West Europe"
  resource_group_name = "RG-AKS"
  address_space       = ["10.2.0.0/20"]
}

resource "azurerm_subnet" "sub-aks" {
  name                 = "sub-aks"
  resource_group_name  = "RG-AKS"
  virtual_network_name = "Vnet-aks"
  address_prefixes     = ["10.2.0.0/22"]
}

resource "azurerm_kubernetes_cluster" "aks-unir" {
  name                = "AKS-UNIR"
  location            = "West Europe"
  resource_group_name = "RG-AKS"
  dns_prefix          = "AKS-UNIR"

  network_profile {
    network_plugin     = "azure"
    service_cidr       = "10.0.0.0/24"
    dns_service_ip     = "10.0.0.254"
    docker_bridge_cidr = "172.17.0.1/16"
  }

  default_node_pool {
    name               = "default"
    node_count         = 1
    vm_size            = "Standard_B2s"
    vnet_subnet_id     = azurerm_subnet.sub-aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "AKS-CLUSTER"
  }
}



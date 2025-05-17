packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
}

source "googlecompute" "ops_agent_test" {
  project_id           = "simplifymycloud-dev"
  source_image         = "debian-12-bookworm-v20240516"  # Latest Debian 12 image
  source_image_family  = "debian-12"
  source_image_project_id = ["debian-cloud"]  # Debian project
  ssh_username         = "admin"  # Debian uses "admin" by default
  zone                 = "us-central1-a"
  image_name           = "ops-agent-test-{{timestamp}}"
  image_description    = "Test image for ops-agent log collection with Go log generator on Debian"
}

build {
  sources = ["source.googlecompute.ops_agent_test"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y curl",
      
      # Install ops-agent for Debian
      "curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh",
      "sudo bash add-google-cloud-ops-agent-repo.sh --also-install",
      
      # Create log directory
      "sudo mkdir -p /var/log/custom"
    ]
  }

  provisioner "shell" {
    inline = [
      # Create a service user for the log generator
      "sudo useradd -r -s /bin/false loggen",
      "sudo mkdir -p /opt/log-generator",
      "sudo chown loggen:loggen /opt/log-generator",
      "sudo chown loggen:loggen /var/log/custom"
    ]
  }

  provisioner "file" {
    source      = "../ops-agent-logs/bin/log-generator"
    destination = "/tmp/log-generator"
  }

  provisioner "file" {
    source      = "../config/ops_agent_config.yaml"
    destination = "/tmp/ops_agent_config.yaml"
  }

  provisioner "shell" {
    inline = [
      # Move files to their proper locations
      "sudo mv /tmp/log-generator /opt/log-generator/",
      "sudo chmod +x /opt/log-generator/log-generator",
      "sudo chown loggen:loggen /opt/log-generator/log-generator",
      
      "sudo mv /tmp/ops_agent_config.yaml /etc/google-cloud-ops-agent/config.yaml",
      
      # Create a systemd service for the log generator
      "cat <<EOF | sudo tee /etc/systemd/system/log-generator.service",
      "[Unit]",
      "Description=Log Generator Service",
      "After=network.target",
      "",
      "[Service]",
      "Type=simple",
      "User=loggen",
      "Group=loggen",
      "ExecStart=/opt/log-generator/log-generator",
      "Restart=always",
      "RestartSec=5",
      "StandardOutput=journal",
      "StandardError=journal",
      "SyslogIdentifier=log-generator",
      "",
      "[Install]",
      "WantedBy=multi-user.target",
      "EOF",
      
      # Enable and start services
      "sudo systemctl daemon-reload",
      "sudo systemctl enable log-generator.service",
      "sudo systemctl start log-generator.service",
      "sudo systemctl restart google-cloud-ops-agent",
      
      # Verify the services are running
      "sudo systemctl status log-generator.service",
      "sudo systemctl status google-cloud-ops-agent"
    ]
  }
}
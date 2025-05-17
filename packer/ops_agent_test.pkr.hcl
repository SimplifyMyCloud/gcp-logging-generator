packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
}

source "googlecompute" "ops_agent_test" {
  project_id          = "simplifymycloud-dev" # Your project ID
  source_image_family = "debian-11"
  zone                = "us-west1-a"
  image_name          = "ops-agent-test-{{timestamp}}"
  image_description   = "Test image for ops-agent log collection"
  machine_type        = "e2-medium"

  # Service account configuration
  service_account_email = "smc-packer-sa@simplifymycloud-dev.iam.gserviceaccount.com"

  # OS Login configuration
  use_os_login = true

  # Use the impersonated service account for ssh_username
  # This should be the OS Login format of your service account
  ssh_username = "sa_packer_sa_simplifymycloud_dev_iam_gserviceaccount_com"

  # Extended timeouts
  ssh_timeout            = "10m"
  startup_script_timeout = "5m"

  # Authentication scopes
  scopes = [
    "https://www.googleapis.com/auth/cloud-platform"
  ]
}

build {
  sources = ["source.googlecompute.ops_agent_test"]

  provisioner "shell" {
    pause_before = "30s"
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y curl",

      # Install ops-agent
      "curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh",
      "sudo bash add-google-cloud-ops-agent-repo.sh --also-install",

      # Create directories
      "sudo mkdir -p /var/log/custom"
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
      # Install log generator
      "sudo mkdir -p /opt/log-generator",
      "sudo mv /tmp/log-generator /opt/log-generator/",
      "sudo chmod +x /opt/log-generator/log-generator",

      # Configure ops-agent
      "sudo mv /tmp/ops_agent_config.yaml /etc/google-cloud-ops-agent/config.yaml",

      # Create service file
      "sudo bash -c 'cat > /etc/systemd/system/log-generator.service << EOL",
      "[Unit]",
      "Description=Log Generator Service",
      "After=network.target",
      "",
      "[Service]",
      "ExecStart=/opt/log-generator/log-generator",
      "Restart=always",
      "",
      "[Install]",
      "WantedBy=multi-user.target",
      "EOL'",

      # Enable services
      "sudo systemctl daemon-reload",
      "sudo systemctl enable log-generator.service",
      "sudo systemctl restart google-cloud-ops-agent"
    ]
  }
}
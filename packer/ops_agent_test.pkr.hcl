source "googlecompute" "ops_agent_test" {
  project_id        = "simplifymycloud-dev"
  source_image      = "debian-11-bullseye-v20220303"
  ssh_username      = "packer"
  zone              = "us-west1-a"
  image_name        = "ops-agent-test-{{timestamp}}"
  image_description = "Test image for ops-agent log collection"
}

build {
  sources = ["source.googlecompute.ops_agent_test"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y curl gnupg",

      # Install ops-agent
      "curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh",
      "sudo bash add-google-cloud-ops-agent-repo.sh --also-install",

      # Install Go if using Go script
      "sudo apt-get install -y golang-go",

      # Create directories
      "sudo mkdir -p /var/log/custom",
      "sudo mkdir -p /opt/log-generator"
    ]
  }

  # Copy your log generator script
  provisioner "file" {
    source      = "log_generator.go"
    destination = "/opt/log-generator/"
  }

  # Copy ops-agent configuration
  provisioner "file" {
    source      = "ops_agent_config.yaml"
    destination = "/tmp/config.yaml"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/config.yaml /etc/google-cloud-ops-agent/config.yaml",
      "sudo chmod +x /opt/log-generator/log_generator.go",

      # Set up as systemd service
      "echo '[Unit]\\nDescription=Log Generator Service\\nAfter=network.target\\n\\n[Service]\\nExecStart=/opt/log-generator/log_generator.sh\\nRestart=always\\n\\n[Install]\\nWantedBy=multi-user.target' | sudo tee /etc/systemd/system/log-generator.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable log-generator.service",
      "sudo systemctl restart google-cloud-ops-agent"
    ]
  }
}
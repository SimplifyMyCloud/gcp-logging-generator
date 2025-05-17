packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
}

source "googlecompute" "ops_agent_test" {
  project_id          = "simplifymycloud-dev"
  source_image_family = "debian-11"
  zone                = "us-west1-a"
  image_name          = "ops-agent-test-{{timestamp}}"
  image_description   = "Test image for ops-agent log collection"
  machine_type        = "e2-medium"
  
  service_account_email = "smc-packer-sa@simplifymycloud-dev.iam.gserviceaccount.com"
  use_os_login        = true
  ssh_username        = "sa_packer_sa_simplifymycloud_dev_iam_gserviceaccount_com"
  
  ssh_timeout         = "10m"
  startup_script_timeout = "5m"
  
  scopes              = [
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
      
      # Install ops-agent with extra diagnostics
      "curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh",
      "sudo bash add-google-cloud-ops-agent-repo.sh --also-install",
      "echo 'Checking ops-agent installation status...'",
      "sudo systemctl status google-cloud-ops-agent || true",
      
      # Create log directory
      "sudo mkdir -p /var/log/custom",
      "sudo chmod 777 /var/log/custom"  # Make sure permissions are open for testing
    ]
  }

  # Copy binary FIRST, before configurating ops-agent
  provisioner "file" {
    source      = "../ops-agent-logs/bin/log-generator"
    destination = "/tmp/log-generator"
  }

  # Set up log generator before configuring ops-agent
  provisioner "shell" {
    inline = [
      "sudo mkdir -p /opt/log-generator",
      "sudo mv /tmp/log-generator /opt/log-generator/",
      "sudo chmod +x /opt/log-generator/log-generator",
      
      # Start generating logs before configuring ops-agent
      "echo 'Testing log generator...'",
      "sudo /opt/log-generator/log-generator &",
      "sleep 5",  # Give it a moment to start creating logs
      "ls -la /var/log/custom/",
      "head -n 5 /var/log/custom/structured.log || echo 'No structured logs yet'",
      "head -n 5 /var/log/custom/plain.log || echo 'No plain logs yet'",
      "head -n 5 /var/log/custom/error.log || echo 'No error logs yet'",
      "sudo pkill log-generator"  # Kill the temporary instance
    ]
  }

  # Now copy the ops-agent configuration
  provisioner "file" {
    source      = "../config/ops_agent_config.yaml"
    destination = "/tmp/ops_agent_config.yaml"
  }

  provisioner "shell" {
    inline = [
      # Check ops-agent config file before replacing
      "echo 'Default ops-agent config:'", 
      "sudo cat /etc/google-cloud-ops-agent/config.yaml || echo 'No default config found'",
      
      # Examine uploaded config
      "echo 'Uploaded config:'", 
      "cat /tmp/ops_agent_config.yaml",
      
      # Copy with backup
      "sudo cp /etc/google-cloud-ops-agent/config.yaml /etc/google-cloud-ops-agent/config.yaml.bak || true",
      "sudo cp /tmp/ops_agent_config.yaml /etc/google-cloud-ops-agent/config.yaml",
      "sudo chmod 640 /etc/google-cloud-ops-agent/config.yaml",
      "sudo chown root:root /etc/google-cloud-ops-agent/config.yaml",
      
      # Validate config
      "echo 'Validating ops-agent config...'",
      "sudo google-cloud-ops-agent validate-config || echo 'Config validation failed'",
      
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
      
      # Try to restart ops-agent with detailed error logging
      "sudo systemctl daemon-reload",
      "echo 'Starting log-generator service...'",
      "sudo systemctl enable log-generator.service",
      "sudo systemctl start log-generator.service",
      "sudo systemctl status log-generator.service || true",
      
      "echo 'Restarting ops-agent with detailed diagnostics...'",
      "sudo systemctl restart google-cloud-ops-agent || true",
      "sudo systemctl status google-cloud-ops-agent --no-pager || true",
      "sudo journalctl -u google-cloud-ops-agent --no-pager -n 50 || true",
      
      # Check if logs are being generated
      "sleep 10",  # Give it time to generate logs
      "echo 'Checking for logs...'",
      "ls -la /var/log/custom/",
      "head -n 5 /var/log/custom/structured.log || echo 'No structured logs found'",
      
      # Check if ops-agent found the logs
      "echo 'Checking ops-agent status...'",
      "sudo google-cloud-ops-agent tail || echo 'Tail command not available'",
      "echo 'Build completed with diagnostics'"
    ]
  }
}
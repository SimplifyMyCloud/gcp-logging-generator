# GCP Ops-Agent Log Generator

This project provides a streamlined way to test the Google Cloud Operations Agent (ops-agent) by automatically generating various log types on Google Compute Engine (GCE) VMs. The image is built using Packer and includes a Go application that continuously generates structured, plain text, and error logs that are captured and processed by the ops-agent.

## Overview

The Google Cloud Operations Agent collects system metrics and application logs from your VMs, making them available for analysis in Google Cloud Logging and Monitoring. This project helps you test and validate your ops-agent configuration by generating predictable log patterns that can be monitored in your GCP environment.

## Features

- **Automated Log Generation**: Continuously generates three types of logs:
  - JSON-structured logs with timestamps, request IDs, latency, and status codes
  - Plain text logs for general activity tracking
  - Error logs with various error types and reference codes

- **Packer Integration**: Fully automated VM image creation with all necessary components
  - Installs and configures the Google Cloud Operations Agent
  - Deploys the Go log generator application
  - Sets up systemd service for automatic startup

- **Ops-Agent Configuration**: Includes a pre-configured ops-agent setup that collects all generated logs

## Project Structure

```
gcp-logging-generator/
├── bin/
│   └── log-generator             # Pre-built Go binary
├── cmd/
│   └── log-generator/
│       └── main.go               # Go source code
├── config/
│   └── ops_agent_config.yaml     # Ops-agent configuration
├── go.mod                        # Go module definition
├── go.sum                        # Go module dependencies
├── packer/
│   └── ops_agent_test.pkr.hcl    # Packer configuration
└── README.md
```

## Getting Started

### Prerequisites

- Google Cloud Platform account with appropriate permissions
- Go 1.16 or later installed locally
- Packer 1.8 or later installed locally
- Google Cloud SDK configured with your project

### Building the Go Binary

1. Clone this repository:
   ```bash
   git clone https://github.com:SimplifyMyCloud/gcp-logging-generator.git
   cd gcp-logging-generator
   ```

2. Initialize Go modules:
   ```bash
   go mod init gcp-logging-generator
   go get github.com/google/uuid
   ```

3. Build the Go binary:
   ```bash
   GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o bin/log-generator ./cmd/log-generator
   ```

### Creating the Ops-Agent Configuration

Create the ops-agent configuration file:

```bash
mkdir -p config
```

Add the following content to `config/ops_agent_config.yaml`:

```yaml
logging:
  receivers:
    structured_logs:
      type: files
      include_paths:
        - /var/log/custom/structured.log
      parser: json
    
    plain_logs:
      type: files
      include_paths:
        - /var/log/custom/plain.log
      
    error_logs:
      type: files
      include_paths:
        - /var/log/custom/error.log
      
  service:
    pipelines:
      structured_pipeline:
        receivers:
          - structured_logs
      
      plain_pipeline:
        receivers:
          - plain_logs
      
      error_pipeline:
        receivers:
          - error_logs

metrics:
  receivers:
    hostmetrics:
      type: hostmetrics
      collection_interval: 60s
  
  processors:
    metrics_filter:
      type: exclude_metrics
      metrics_pattern: []
  
  service:
    pipelines:
      default_pipeline:
        receivers:
          - hostmetrics
        processors:
          - metrics_filter
```

### Building the VM Image with Packer

Run Packer:
   ```bash
   cd packer
   packer init .
   packer build ops_agent_test.pkr.hcl
   ```

## Deploying VMs Using the Image

After Packer successfully builds the image, you can deploy VMs using it:

```bash
gcloud compute instances create ops-agent-test-1 \
  --image=ops-agent-test-[timestamp] \
  --zone=us-west1-a
```

## Log Types Generated

### Structured JSON Logs
```json
{
  "timestamp": "2025-05-16T12:34:56.789Z",
  "level": "INFO",
  "message": "Request processed",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "latency_ms": 234,
  "status_code": 200
}
```

### Plain Text Logs
```
[2025-05-16 12:34:56] [INFO] User activity recorded. Session: 550e8400-e29b-41d4-a716-446655440000
```

### Error Logs
```
[2025-05-16 12:34:56] [ERROR] Connection timeout. Reference: ERR-a1b2c3d4
```

## Troubleshooting

### Common Issues and Solutions

#### SSH Authentication Issues with OS Login
If you're using OS Login (required by organizational policy constraints), ensure:

1. Your service account has the proper roles:
   ```bash
   gcloud projects add-iam-policy-binding your-project-id \
     --member="serviceAccount:your-service-account@project-id.iam.gserviceaccount.com" \
     --role="roles/compute.osLogin"
   ```

2. Find your OS Login username for the service account:
   ```bash
   gcloud compute os-login describe-profile --impersonate-service-account=your-service-account@project-id.iam.gserviceaccount.com
   ```

3. Update the `ssh_username` in your Packer config with this value

#### Ops-Agent Service Failures

If the ops-agent service fails to start, check:

1. Validate the ops-agent configuration:
   ```bash
   sudo google-cloud-ops-agent validate-config
   ```

2. Check the service logs:
   ```bash
   sudo journalctl -u google-cloud-ops-agent --no-pager
   ```

3. Verify file permissions:
   ```bash
   ls -la /var/log/custom/
   sudo chmod 755 /var/log/custom
   ```

### Verifying Log Collection

To verify that logs are being collected:

1. SSH into the VM:
   ```bash
   gcloud compute ssh ops-agent-test-1 --zone=us-west1-a
   ```

2. Check that logs are being generated:
   ```bash
   ls -la /var/log/custom/
   tail /var/log/custom/structured.log
   ```

3. Verify the ops-agent is running:
   ```bash
   sudo systemctl status google-cloud-ops-agent
   ```

4. In the Google Cloud Console, navigate to "Logging" > "Logs Explorer" and filter for your VM instance

## Customization

### Modifying Log Content and Frequency

Edit the Go code in `cmd/log-generator/main.go` to customize:
- Log content and format
- Frequency of log generation (adjust the `time.Sleep()` values)
- Types of errors and status codes generated

### Changing Ops-Agent Configuration

Modify `config/ops_agent_config.yaml` to:
- Adjust parsing rules
- Change pipeline configuration
- Add other log sources or metrics collectors

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Google Cloud Operations Agent team
- HashiCorp Packer
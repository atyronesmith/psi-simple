# OpenShift Compact Cluster Ansible Playbook

This repository provides comprehensive Ansible playbooks to automate the preparation, deployment, and management of a compact OpenShift cluster (with 0 compute nodes, only control plane nodes) on Red Hat OpenStack Platform (RHOSP). The playbooks follow the official OpenShift installation process using the Installer-Provisioned Infrastructure (IPI) method.

## 🚀 Features

### Core Functionality
- **Official OpenShift Installation**: Uses the official `openshift-install` tool for cluster deployment
- **Compact Cluster Architecture**: Deploys 3 control plane nodes with 0 worker nodes
- **Installer-Provisioned Infrastructure (IPI)**: Full automation of OpenStack infrastructure
- **OpenStack Integration**: Native integration with Red Hat OpenStack Platform (RHOSP)

### Enhanced Installation Features
- **🔍 Prerequisite Validation**: Comprehensive validation of environment, tools, files, and OpenStack connectivity
- **🌐 CIDR Overlap Detection**: Automatically detects and resolves overlapping network CIDRs with existing OpenStack subnets
- **🔄 Floating IP Management**: Intelligent reuse of existing floating IPs and automatic creation when needed
- **📱 DNS Setup Automation**: Automatically configures DNS resolution on macOS for seamless cluster access
- **🛠️ Enhanced Error Handling**: Improved error handling with retries, timeouts, and detailed debugging information
- **🔒 Status Checking**: Comprehensive cluster status validation before destruction operations
- **🧹 Cleanup Handlers**: Automatic cleanup of resources on installation failure
- **🎯 Signature Auto-Detection**: Cleanup script can auto-detect cluster signature from metadata.json
- **🔄 Enhanced Router Cleanup**: Intelligent router deletion with interface removal and retry logic
- **⌨️ Tab Completion**: Bash and Zsh completion support for all Makefile targets

### User Experience Enhancements
- **Interactive Sudo Prompting**: Seamless password prompting for DNS configuration
- **Colored Output**: Clear visual feedback with colored status messages
- **Comprehensive Logging**: Detailed logging and troubleshooting guidance
- **Makefile Integration**: Easy-to-use make targets for all operations
- **Code Quality**: All code passes ansible-lint validation (production profile)

## 📋 Prerequisites

### System Requirements
- **Operating System**: macOS or Linux
- **Python**: 3.8+ with virtual environment support
- **Ansible**: 2.9+ (installed in virtual environment)
- **OpenStack Client**: Configured with cloud credentials
- **Internet Access**: Required for downloading OpenShift installer and client tools

### Required Tools
- `jq`: Command-line JSON processor (for CIDR validation and JSON processing)
- `openstack`: OpenStack CLI client (for infrastructure operations)
- `ansible-lint`: For code quality validation
- `nslookup`: For DNS resolution testing (usually pre-installed)

### OpenShift Requirements
- **OpenShift Pull Secret**: [Get one here](https://cloud.redhat.com/openshift/install/pull-secret)
- **SSH Key Pair**: For cluster access and debugging
- **OpenStack Resources**: Sufficient quotas for compute, networking, and storage

## 🏗️ Architecture Overview

### Cluster Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    OpenShift Compact Cluster                │
├─────────────────────────────────────────────────────────────┤
│  Control Plane Nodes (3x)                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Master 1  │  │   Master 2  │  │   Master 3  │        │
│  │ (Schedulable│  │ (Schedulable│  │ (Schedulable│        │
│  │  = false)   │  │  = false)   │  │  = false)   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                             │
│  Worker Nodes: 0 (Compact Cluster)                         │
│                                                             │
│  Networking:                                                │
│  • API Floating IP: External cluster access                │
│  • Ingress Floating IP: Application access                 │
│  • Machine Network: OpenStack subnet                       │
│  • Cluster Network: Pod-to-pod communication              │
│  • Service Network: Service discovery                      │
└─────────────────────────────────────────────────────────────┘
```

### Installation Process Flow
```
Prerequisites → CIDR Validation → Floating IP Management →
DNS Setup → Manifest Generation → Ignition Configs →
OpenStack Infrastructure → Bootstrap → Control Plane →
Cluster Completion
```

## 📁 Directory Structure

```
psi-simple/
├── ansible.cfg                     # Ansible configuration
├── deploy.yml                      # Main deployment playbook
├── destroy.yml                     # Cluster destruction playbook
├── status.yml                      # Status checking playbook
├── site.yml                        # Site-wide installation playbook
├── group_vars/
│   └── all.yml                     # Global variables and configuration
├── inventory/
│   └── hosts                       # Ansible inventory (localhost)
├── roles/
│   ├── openshift-install/          # Main installation role
│   │   ├── tasks/
│   │   │   ├── main.yml           # Primary installation tasks
│   │   │   ├── prerequisites.yml   # Environment validation
│   │   │   └── cidr_validation.yml # Network overlap detection
│   │   ├── templates/
│   │   │   └── install-config.yaml.j2 # OpenShift configuration template
│   │   └── handlers/
│   │       └── main.yml           # Cleanup handlers for failures
│   ├── openshift_destroy/          # Cluster destruction role
│   │   └── tasks/
│   │       ├── main.yml           # Destruction tasks
│   │       └── status_check.yml   # Pre-destruction validation
│   └── openshift_status/           # Status checking role
│       └── tasks/
│           └── main.yml           # Status checking tasks
├── scripts/
│   ├── setup-dns.sh               # DNS configuration script (macOS)
│   ├── cleanup-floating-ips.sh    # Floating IP cleanup utility
│   └── test-dns-setup.sh          # DNS testing utility
├── secrets/                        # Directory for sensitive files
│   ├── README.md                  # Setup instructions
│   ├── .gitkeep                   # Placeholder file
│   ├── pull-secret.json          # OpenShift pull secret (ignored)
│   └── ssh_key.pub               # SSH public key (ignored)
├── bin/                           # Downloaded OpenShift tools
│   ├── openshift-install         # OpenShift installer binary
│   └── oc                        # OpenShift client binary
├── openshift-install/             # Installation workspace
│   ├── install-config.yaml       # Generated cluster configuration
│   ├── manifests/                # Kubernetes manifests
│   ├── auth/                     # Authentication files
│   │   ├── kubeconfig            # Cluster access credentials
│   │   └── kubeadmin-password    # Admin password
│   └── metadata.json             # Cluster metadata
├── Makefile                       # Convenient make targets
└── README.md                      # This documentation
```

## ⚙️ Configuration

### Environment Setup

**⚠️ CRITICAL**: Always ensure your environment is properly configured before running any commands:

1. **Activate the Python virtual environment:**
   ```bash
   source ~/dev/venv/oc/bin/activate
   ```

2. **Set the OpenStack cloud environment:**
   ```bash
   export OS_CLOUD=psi
   ```

3. **Verify environment setup:**
   ```bash
   echo "Virtual environment: $VIRTUAL_ENV"
   echo "OpenStack cloud: $OS_CLOUD"
   ```

### OpenStack Configuration

The OpenStack client uses `~/.config/openstack/cloud.yaml` for cloud configurations. Ensure your PSI cloud configuration includes:

```yaml
clouds:
  psi:
    auth:
      auth_url: https://your-openstack-endpoint:5000/v3
      username: your-username
      password: your-password
      project_name: your-project
      domain_name: your-domain
    region_name: your-region
    interface: public
    identity_api_version: 3
```

### Cluster Variables

Edit `group_vars/all.yml` to customize your cluster configuration:

#### Core Cluster Settings
```yaml
# Cluster identification
openshift_cluster_name: "openshift-cluster"    # Cluster name
openshift_base_domain: "example.com"           # Base DNS domain
openshift_version: "stable-4.18"               # OpenShift version

# Cluster architecture
openshift_compute_replicas: 0                  # Worker nodes (0 for compact)
openshift_control_plane_replicas: 3            # Control plane nodes
```

#### Network Configuration
```yaml
# OpenShift networking (automatically validated for conflicts)
openshift_cluster_network_cidr: "10.128.0.0/14"    # Pod network
openshift_service_network_cidr: "172.30.0.0/16"    # Service network
openshift_host_network_cidr: "172.16.0.0/16"       # Machine network (auto-resolved)
```

#### OpenStack Platform Settings
```yaml
# OpenStack configuration
os_cloud: "psi"                                     # Cloud name from clouds.yaml
openshift_external_network: "provider_net_shared_3" # External network name
openshift_image: "Ubuntu-22.04"                    # Base image
openshift_master_flavor: "m1.xlarge"               # Instance flavor
```

### Required Files Setup

**⚠️ Important**: Sensitive files are stored in the `secrets/` directory and are **NOT** committed to the repository.

#### 1. OpenShift Pull Secret
```bash
# Download from https://cloud.redhat.com/openshift/install/pull-secret
mkdir -p secrets
curl -o secrets/pull-secret.json 'https://cloud.redhat.com/openshift/install/pull-secret'
chmod 600 secrets/pull-secret.json

# Validate the pull secret
jq . secrets/pull-secret.json  # Should parse without errors
```

#### 2. SSH Key Pair
```bash
# Generate SSH key pair for cluster access
ssh-keygen -t rsa -b 4096 -C "openshift-cluster-key" -f ~/.ssh/openshift_rsa
cp ~/.ssh/openshift_rsa.pub secrets/ssh_key.pub
chmod 644 secrets/ssh_key.pub

# Validate the SSH key
ssh-keygen -l -f secrets/ssh_key.pub  # Should show key fingerprint
```

#### 3. File Validation
```bash
# Verify all required files are present and valid
make validate
```

## 🖥️ Supported Platforms

This project has been tested and validated on:
- **macOS** (Darwin) - Including Apple Silicon (M1/M2/M3)
- **Fedora 42**
- **Red Hat Enterprise Linux (RHEL) 9**

All scripts automatically detect the operating system and use appropriate commands and paths. Platform-specific features:
- **Binary Downloads**: Automatically downloads correct OpenShift binaries (mac/linux)
- **DNS Configuration**: Uses `/etc/resolver` on macOS, `/etc/hosts` on Linux
- **Package Management**: Detects brew (macOS), dnf/yum (Fedora/RHEL)
- **Completion Installation**: Finds appropriate directories for each platform

## 🚀 Usage

### Quick Start

1. **Environment Setup:**
   ```bash
   # Activate virtual environment
   source ~/dev/venv/oc/bin/activate

   # Set OpenStack cloud
   export OS_CLOUD=psi

   # Verify environment
   make validate
   ```

2. **Deploy Cluster:**
   ```bash
   make deploy
   ```

3. **Check Status:**
   ```bash
   make status
   ```

4. **Access Cluster:**
   ```bash
   make cluster-info
   ```

### Make Targets Reference

#### Core Operations
- `make deploy` - Deploy OpenShift compact cluster
- `make destroy` - Destroy cluster and clean up files
- `make status` - Check cluster status
- `make cluster-info` - Show cluster access information

#### Maintenance Operations
- `make clean` - Clean up installation files (preserve cluster)
- `make validate` - Validate configuration and prerequisites
- `make lint` - Run ansible-lint on all files
- `make deps` - Install Python dependencies

#### DNS Operations
- `make setup-dns` - Setup DNS resolution (auto-detects best method)
- `make setup-dns-hosts` - Setup DNS using /etc/hosts (all platforms)
- `make remove-dns` - Remove DNS configuration
- `make show-dns` - Show current DNS configuration
- `make test-dns` - Test DNS setup functionality

#### Floating IP Operations
- `make fip-status` - Show floating IP usage summary
- `make fip-list` - List unused floating IPs
- `make fip-cleanup` - Clean up unused floating IPs (dry run)

#### Tab Completion Operations
- `make install-completion` - Install bash and zsh tab completion for make targets
- `make test-completion` - Test tab completion functionality and show installation status

### Direct Ansible Usage

For advanced users who prefer direct ansible commands:

```bash
# Ensure environment is set up
source ~/dev/venv/oc/bin/activate
export OS_CLOUD=psi

# Deploy cluster
ansible-playbook -i inventory/hosts deploy.yml

# Check status
ansible-playbook -i inventory/hosts status.yml

# Destroy cluster
ansible-playbook -i inventory/hosts destroy.yml
```

## 🔧 Advanced Features

### CIDR Overlap Detection

The playbook automatically detects and resolves network CIDR overlaps:

1. **Detection**: Scans existing OpenStack subnets for conflicts
2. **Resolution**: Automatically selects alternative CIDR ranges
3. **Validation**: Ensures no conflicts with OpenShift internal networks

**Candidate CIDR ranges tested:**
- `172.16.0.0/16` (default)
- `192.168.0.0/16`
- `10.1.0.0/16`
- `10.2.0.0/16`
- `10.3.0.0/16`
- Additional ranges as needed

### Floating IP Management

Intelligent floating IP handling:

1. **Reuse Detection**: Checks for existing floating IPs by description
2. **Automatic Creation**: Creates new IPs only when needed
3. **Cleanup on Failure**: Removes newly created IPs on installation failure
4. **Validation**: Ensures IPs are properly allocated and accessible

### DNS Setup Automation

Automatic DNS configuration across all platforms:

1. **OS Detection**: Automatically identifies operating system
2. **Methods**:
   - macOS: Uses `/etc/resolver` (preferred) or `/etc/hosts`
   - Linux: Uses `/etc/hosts` for DNS resolution
3. **Interactive Prompting**: Handles sudo password requirements seamlessly
4. **Validation**: Tests DNS resolution before cluster creation

## 🧪 Testing and Validation

### Pre-deployment Testing
```bash
# Validate environment and configuration
make validate

# Test DNS setup (macOS only)
make test-dns

# Check OpenStack connectivity
openstack token issue

# Verify floating IP availability
make fip-status
```

### Post-deployment Testing
```bash
# Check cluster status
make status

# Test cluster access
export KUBECONFIG=./openshift-install/auth/kubeconfig
./bin/oc cluster-info

# Validate nodes
./bin/oc get nodes
```

## 🔍 Troubleshooting

### Common Issues and Solutions

#### Environment Issues
**Problem**: "Virtual environment is not active"
```bash
# Solution
source ~/dev/venv/oc/bin/activate
```

**Problem**: "OS_CLOUD environment variable is not set"
```bash
# Solution
export OS_CLOUD=psi
```

#### Network Issues
**Problem**: CIDR overlap detected
- **Solution**: Automatic resolution through candidate CIDR testing
- **Manual**: Update `openshift_host_network_cidr` in `group_vars/all.yml`

**Problem**: DNS resolution failures
```bash
# Test DNS configuration
make test-dns

# Manual DNS setup
sudo vim /etc/hosts
# Add entries for api.cluster.domain and *.apps.cluster.domain
```

#### OpenStack Issues
**Problem**: "External network not found"
```bash
# Check available networks
openstack network list

# Update configuration
vim group_vars/all.yml
# Set correct openshift_external_network
```

**Problem**: Insufficient floating IP quota
```bash
# Check quota
openstack quota show

# Clean up unused IPs
make fip-cleanup FIP_DELETE=true
```

#### Installation Issues
**Problem**: Installation timeout or failure
```bash
# Check installer logs
tail -f ./openshift-install/.openshift_install.log

# Check OpenStack resources
openstack server list
openstack port list
```

**Problem**: Bootstrap failures
```bash
# SSH to bootstrap node (if accessible)
ssh -i ~/.ssh/openshift_rsa core@bootstrap-ip

# Check bootstrap logs
journalctl -u bootkube
```

### Debug Information Locations

#### Log Files
- **Installer Log**: `./openshift-install/.openshift_install.log`
- **Ansible Log**: Check console output during playbook execution

#### Configuration Files
- **Install Config**: `./openshift-install/install-config.yaml`
- **Cluster Metadata**: `./openshift-install/metadata.json`
- **Kubeconfig**: `./openshift-install/auth/kubeconfig`
- **Admin Password**: `./openshift-install/auth/kubeadmin-password`

#### OpenStack Resources
```bash
# Check created resources
openstack server list --name "*$(jq -r .infraID ./openshift-install/metadata.json)*"
openstack port list --name "*$(jq -r .infraID ./openshift-install/metadata.json)*"
openstack security group list --name "*$(jq -r .infraID ./openshift-install/metadata.json)*"
```

### Recovery Procedures

#### Partial Installation Recovery
```bash
# If installation fails mid-process
make destroy  # Clean up partial resources
make clean    # Remove installation files
make deploy   # Restart installation
```

#### Manual Cluster Destruction
```bash
# Direct OpenShift installer destroy command
./bin/openshift-install destroy cluster --dir openshift-install/

# Use this if make destroy fails or for manual cleanup
# Note: This is the same command used by 'make destroy'
```

#### Manual Resource Cleanup
```bash
# List resources by infrastructure ID
export INFRA_ID=$(jq -r .infraID ./openshift-install/metadata.json)
openstack server list --name "*$INFRA_ID*"
openstack port list --name "*$INFRA_ID*"

# Manual cleanup (use with caution)
openstack server delete server-name
openstack port delete port-name
```

## 📈 Performance and Optimization

### Resource Requirements

#### Minimum Requirements
- **Control Plane**: 3 x m1.xlarge instances
- **Storage**: 100GB per control plane node
- **Network**: 2 floating IPs (API + Ingress)
- **Memory**: 16GB RAM per control plane node

#### Optimal Configuration
- **Flavor**: m1.xlarge or larger
- **Storage**: SSD-backed volumes
- **Network**: High-bandwidth external network
- **Placement**: Anti-affinity for control plane nodes

### Performance Tuning

#### OpenStack Optimization
```yaml
# In group_vars/all.yml
openshift_master_flavor: "m1.xlarge"  # Adjust based on requirements
openshift_image: "Ubuntu-22.04"      # Use optimized images
```

#### Network Optimization
- Use dedicated external networks
- Ensure sufficient bandwidth for image pulls
- Configure appropriate security groups

## 🔐 Security Considerations

### Access Control
- **SSH Keys**: Use dedicated keys for cluster access
- **Pull Secrets**: Rotate regularly and secure storage
- **Passwords**: Change default kubeadmin password post-installation

### Network Security
- **Floating IPs**: Monitor and audit external access
- **Security Groups**: Review and customize as needed
- **DNS**: Secure DNS configuration for production use

### Operational Security
- **Secrets Management**: Never commit sensitive files
- **Logging**: Monitor installation and access logs
- **Updates**: Keep OpenShift and tools updated

## 📚 Additional Resources

### Documentation
- [OpenShift Installation Guide](https://docs.openshift.com/container-platform/4.18/installing/index.html)
- [OpenStack Provider Documentation](https://docs.openshift.com/container-platform/4.18/installing/installing_openstack/index.html)
- [Compact Cluster Documentation](https://docs.openshift.com/container-platform/4.18/installing/installing_bare_metal/installing-bare-metal.html#installation-three-node-cluster_installing-bare-metal)

### Community
- [OpenShift Community](https://www.openshift.com/community)
- [Red Hat Customer Portal](https://access.redhat.com/)
- [OpenShift GitHub](https://github.com/openshift)

### Tools
- [OpenShift Console](https://console.redhat.com/openshift)
- [OpenShift CLI Documentation](https://docs.openshift.com/container-platform/4.18/cli_reference/openshift_cli/getting-started-cli.html)
- [Ansible Documentation](https://docs.ansible.com/)

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📞 Support

For support and questions:
- Review the troubleshooting section above
- Check the installation logs
- Consult the OpenShift documentation
- Submit an issue in this repository

## Resource Cleanup

### Automatic Cleanup
The project includes several mechanisms to prevent orphaned resources:

1. **Proper cluster destruction**: The `make clean` target now properly destroys clusters before removing local files
2. **Cleanup handlers**: Installation failures automatically clean up newly created resources
3. **Floating IP reuse**: Existing floating IPs are reused instead of creating new ones

### Manual Cleanup by Signature
For cleaning up orphaned resources from failed installations, use the signature-based cleanup script:

```bash
# Auto-detect signature from metadata.json
make cleanup-by-signature

# Or specify signature manually (5 alphanumeric characters)
make cleanup-by-signature SIGNATURE=ff9fw

# Direct script usage
./scripts/cleanup-by-signature.sh        # Auto-detect from metadata.json
./scripts/cleanup-by-signature.sh ff9fw  # Manual signature
```

**Auto-Detection Feature**: If no signature is provided, the script will attempt to extract it from `openshift-install/metadata.json` by parsing the `infraID` field.

The script searches for and can delete:
- **Instances**: `openshift-cluster-<signature>-*`
- **Images**: `openshift-cluster-<signature>-rhcos`, `openshift-cluster-<signature>-ignition`
- **Server Groups**: `openshift-cluster-<signature>-*`
- **Security Groups**: `openshift-cluster-<signature>-*`
- **Networks & Subnets**: `openshift-cluster-<signature>-*`
- **Ports**: `openshift-cluster-<signature>-*`
- **Volumes**: `openshift-cluster-<signature>-*`
- **Routers**: `*<signature>*` (e.g., `k8s-clusterapi-cluster-openshift-cluster-api-guests-openshift-cluster-ff9fw`)
  - Automatically clears external gateways
  - Removes all subnet interfaces
  - Handles router ports with retry logic
- **Floating IPs**: Associated with the cluster signature

**Safety Features**:
- Lists all found resources before deletion
- Requires explicit `yes` confirmation
- Validates signature format (5 alphanumeric characters)
- Deletes resources in proper dependency order to prevent failures:
  1. Clear router gateways
  2. Delete instances and volumes
  3. Delete ports
  4. Delete subnets
  5. Delete networks
  6. Delete routers
  7. Delete security groups, server groups, images, and floating IPs
- Provides detailed status feedback

**Prerequisites**:
- Virtual environment activated: `source ~/dev/venv/oc/bin/activate`
- OpenStack environment set: `export OS_CLOUD=psi`
- jq installed for JSON processing: `brew install jq` (macOS) or `apt-get install jq` (Ubuntu/Debian)

**Example Usage**:
```bash
# Search for resources with signature ff9fw
make cleanup-by-signature SIGNATURE=ff9fw

# Example output:
# 🖥️  Instances (4):
#    - openshift-cluster-ff9fw-bootstrap
#    - openshift-cluster-ff9fw-master-0
#    - openshift-cluster-ff9fw-master-1
#    - openshift-cluster-ff9fw-master-2
#
# 💿 Images (2):
#    - openshift-cluster-ff9fw-rhcos
#    - openshift-cluster-ff9fw-ignition
#
# 🔀 Routers (1):
#    - k8s-clusterapi-cluster-openshift-cluster-api-guests-openshift-cluster-ff9fw
#
# Are you sure you want to delete all these resources? Type 'yes' to confirm:
```
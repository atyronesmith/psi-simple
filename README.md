# OpenShift Compact Cluster Ansible Playbook

This repository provides Ansible playbooks to automate the preparation, deployment, and management of a compact OpenShift cluster (with 0 compute nodes, only control plane nodes). The playbooks follow the official OpenShift installation process and create the necessary manifests and ignition configs.

## Features
- Modular Ansible roles for different operations
- Downloads and extracts the OpenShift installer and client tools
- Generates a compact cluster `install-config.yaml` (0 compute nodes)
- Creates manifests and removes worker machine sets for compact cluster
- Sets mastersSchedulable to false for compact cluster
- Generates ignition configs for bootstrap, master, and worker nodes
- Follows the official OpenShift installation process
- Includes destroy and status checking capabilities
- Makefile for easy management

## Prerequisites
- Ansible 2.9+
- Python 3.x on the control node
- Internet access to download OpenShift installer and client
- OpenShift pull secret ([get one here](https://cloud.redhat.com/openshift/install/pull-secret))
- SSH key pair for cluster access
- `jq` command-line tool (for JSON processing)

## Directory Structure
```
.
├── ansible.cfg
├── group_vars/
│   └── all.yml
├── inventory/
│   └── hosts
├── roles/
│   ├── openshift-install/
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   └── templates/
│   │       └── install-config.yaml.j2
│   ├── openshift-destroy/
│   │   └── tasks/
│   │       └── main.yml
│   └── openshift-status/
│       └── tasks/
│           └── main.yml
├── deploy.yml
├── destroy.yml
├── status.yml
├── site.yml
├── Makefile
└── README.md
```

## Configuration

### Variables
Edit `group_vars/all.yml` to set cluster-wide variables:
- `openshift_cluster_name`: Name of your cluster
- `openshift_base_domain`: Base DNS domain
- `openshift_version`: OpenShift version (e.g., 4.18)
- `openshift_pull_secret_path`: Path to your pull secret file
- `openshift_ssh_key_path`: Path to your SSH public key
- Platform-specific settings (bare metal, AWS, etc.)

### Required Files
- Place your OpenShift pull secret at the path specified in `openshift_pull_secret_path` (default: `pull-secret.json` in the playbook directory)
- Place your SSH public key at the path specified in `openshift_ssh_key_path` (default: `ssh_key` in the playbook directory)

## Usage

### Using Makefile (Recommended)

1. **Install dependencies:**
   ```sh
   make deps
   ```

2. **Validate configuration:**
   ```sh
   make validate
   ```

3. **Deploy OpenShift cluster:**
   ```sh
   make deploy
   ```

4. **Check cluster status:**
   ```sh
   make status
   ```

5. **Destroy cluster:**
   ```sh
   make destroy
   ```

6. **Clean up files (without destroying cluster):**
   ```sh
   make clean
   ```

7. **Show cluster information:**
   ```sh
   make info
   ```

8. **Export environment variables:**
   ```sh
   make export-env
   ```

### Using Ansible Playbooks Directly

1. **Deploy:**
   ```sh
   ansible-playbook -i inventory/hosts deploy.yml
   ```

2. **Check status:**
   ```sh
   ansible-playbook -i inventory/hosts status.yml
   ```

3. **Destroy:**
   ```sh
   ansible-playbook -i inventory/hosts destroy.yml
   ```

## Generated Files
After running the deploy playbook, you'll find these files in `openshift-install/`:
- `install-config.yaml`: Cluster configuration
- `manifests/`: Kubernetes manifests (worker machine sets removed, mastersSchedulable set to false)
- `bootstrap.ign`: Bootstrap node ignition config
- `master.ign`: Master nodes ignition config
- `worker.ign`: Worker nodes ignition config (not used in compact cluster)
- `metadata.json`: Cluster metadata
- `openshift-install`: OpenShift installer binary
- `oc`: OpenShift client binary

## Roles

### openshift-install
- Downloads OpenShift installer and client tools
- Creates install-config.yaml for compact cluster
- Generates manifests and removes worker machine sets
- Sets mastersSchedulable to false
- Creates ignition configs

### openshift-destroy
- Checks cluster status before destruction
- Runs OpenShift installer destroy command
- Removes installation files and directories
- Cleans up downloaded files

### openshift-status
- Checks installation directory and kubeconfig existence
- Displays cluster metadata
- Checks cluster installation status
- Provides detailed status information

## Next Steps

The playbooks prepare the installation files. To complete the OpenShift installation:

1. **For Bare Metal:**
   - Use tools like [coreos-installer](https://coreos.github.io/coreos-installer/) to provision nodes with the ignition configs
   - Follow the [bare metal installation guide](https://docs.openshift.com/container-platform/latest/installing/installing_bare_metal/installing-bare-metal.html)

2. **For Cloud Platforms:**
   - Use the platform-specific tools to provision nodes with the ignition configs
   - Follow the appropriate [cloud installation guide](https://docs.openshift.com/container-platform/latest/installing/installing_platforms/installing-platforms.html)

3. **Complete the Installation:**
   - Start the bootstrap process
   - Monitor the installation progress
   - Complete the cluster installation

## Compact Cluster Configuration

This playbook is specifically configured for a compact cluster with:
- 0 compute (worker) nodes (`openshift_compute_replicas: 0`)
- 3 control plane (master) nodes
- Worker machine sets are automatically removed from manifests
- Control plane nodes configured to not schedule regular workloads

## Notes
- The playbooks run entirely on localhost and don't require SSH access to target nodes
- All installation files are created in the `openshift-install/` directory
- The worker machine sets are automatically removed to prevent worker node creation
- The destroy playbook includes a confirmation prompt for safety
- For more information, see the [OpenShift documentation](https://docs.openshift.com/container-platform/latest/install/index.html)

## Troubleshooting
- Run `make validate` to check prerequisites and configuration
- Ensure you have internet access to download the OpenShift installer and client
- Check that your pull secret and SSH key are valid and accessible
- Review the output of the playbooks for any errors
- Consult the OpenShift documentation for platform-specific guidance

## License
MIT
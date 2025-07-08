.PHONY: help deploy destroy status clean validate

# Default target
help:
	@echo "OpenShift Compact Cluster Management"
	@echo ""
	@echo "Available targets:"
	@echo "  deploy    - Deploy OpenShift compact cluster (prepare installation files)"
	@echo "  destroy   - Destroy OpenShift cluster and clean up files"
	@echo "  status    - Check OpenShift cluster status"
	@echo "  clean     - Clean up installation files without destroying cluster"
	@echo "  validate  - Validate configuration and prerequisites"
	@echo "  help      - Show this help message"

# Deploy OpenShift cluster
deploy:
	@echo "Deploying OpenShift compact cluster..."
	ansible-playbook -i inventory/hosts deploy.yml

# Destroy OpenShift cluster
destroy:
	@echo "Destroying OpenShift cluster..."
	@read -p "Are you sure you want to destroy the cluster? [y/N]: " confirm && [ "$$confirm" = "y" ] || exit 1
	ansible-playbook -i inventory/hosts destroy.yml

# Check cluster status
status:
	@echo "Checking OpenShift cluster status..."
	ansible-playbook -i inventory/hosts status.yml

# Clean up installation files (without destroying cluster)
clean:
	@echo "Cleaning up installation files..."
	rm -rf openshift-install/
	rm -f openshift-install.tar.gz openshift-client.tar.gz

# Validate configuration and prerequisites
validate:
	@echo "Validating configuration and prerequisites..."
	@echo "Checking Ansible installation..."
	@which ansible-playbook > /dev/null || (echo "Error: ansible-playbook not found. Please install Ansible." && exit 1)
	@echo "Checking inventory file..."
	@test -f inventory/hosts || (echo "Error: inventory/hosts not found." && exit 1)
	@echo "Checking group_vars file..."
	@test -f group_vars/all.yml || (echo "Error: group_vars/all.yml not found." && exit 1)
	@echo "Checking pull secret..."
	@test -f pull-secret.json || (echo "Warning: pull-secret.json not found. Please ensure it exists before deployment." && exit 0)
	@echo "Checking SSH key..."
	@test -f ssh_key || (echo "Warning: ssh_key not found. Please ensure it exists before deployment." && exit 0)
	@echo "Validation completed successfully!"

# Install dependencies
deps:
	@echo "Installing dependencies..."
	pip install ansible

# Show cluster info (if available)
info:
	@echo "Cluster Information:"
	@if [ -f openshift-install/metadata.json ]; then \
		echo "Cluster metadata:"; \
		cat openshift-install/metadata.json | jq '.' 2>/dev/null || echo "  (requires jq to format)"; \
	else \
		echo "No cluster metadata found. Run 'make deploy' first."; \
	fi

# Export environment variables for cluster access
export-env:
	@if [ -f openshift-install/auth/kubeconfig ]; then \
		echo "export KUBECONFIG=$(PWD)/openshift-install/auth/kubeconfig"; \
		echo "export PATH=$(PWD)/openshift-install:$$PATH"; \
	else \
		echo "No kubeconfig found. Run 'make deploy' first."; \
	fi
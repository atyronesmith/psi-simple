.PHONY: help deploy destroy status clean validate lint cluster-info deps info export-env setup-dns setup-dns-hosts remove-dns show-dns fip-status fip-list fip-cleanup test-dns cleanup-by-signature install-completion test-completion

# Default target
help:
	@echo "OpenShift Compact Cluster Management"
	@echo ""
	@echo "⚠️  IMPORTANT: Before running any commands, ensure your environment is set up:"
	@echo "   source ~/dev/venv/oc/bin/activate"
	@echo "   export OS_CLOUD=psi"
	@echo ""
	@echo "Available targets:"
	@echo "  deploy      - Deploy OpenShift compact cluster"
	@echo "  destroy     - Destroy OpenShift cluster and clean up files"
	@echo "  status      - Check OpenShift cluster status"
	@echo "  cluster-info - Show cluster access information when ready"
	@echo "  clean       - Safely destroy cluster and clean up installation files"
	@echo "  validate    - Validate configuration and prerequisites"
	@echo "  lint        - Run ansible-lint on all Ansible files"
	@echo "  shellcheck  - Run shellcheck on all shell scripts"
	@echo "  deps        - Install Python dependencies"
	@echo "  info        - Show cluster metadata information"
	@echo "  export-env  - Show environment variables for cluster access"
	@echo "  setup-dns   - Setup DNS resolution for cluster (auto-detects best method)"
	@echo "  setup-dns-hosts - Setup DNS using /etc/hosts (works on all platforms)"
	@echo "  remove-dns  - Remove DNS configuration"
	@echo "  show-dns    - Show current DNS configuration"
	@echo "  fip-status  - Show floating IP usage summary"
	@echo "  fip-list    - List unused floating IPs"
	@echo "  fip-cleanup - Clean up unused floating IPs (dry run)"
	@echo "  test-dns    - Test DNS setup functionality"
	@echo "  cleanup-by-signature - Clean up OpenStack resources by signature (use SIGNATURE=<value> or auto-detect)"
	@echo "  install-completion - Install bash and zsh tab completion for make targets"
	@echo "  test-completion - Test tab completion functionality and show installation status"
	@echo "  help        - Show this help message"

# Deploy OpenShift cluster
deploy:
	@echo "Deploying OpenShift compact cluster..."
	@echo "⚠️  Environment check: Ensure 'source ~/dev/venv/oc/bin/activate' and 'export OS_CLOUD=psi' are set"
	ansible-playbook -i inventory/hosts deploy.yml

# Destroy OpenShift cluster
destroy:
	@echo "Destroying OpenShift cluster..."
	@echo "⚠️  Environment check: Ensure 'source ~/dev/venv/oc/bin/activate' and 'export OS_CLOUD=psi' are set"
	@read -p "Are you sure you want to destroy the cluster? [y/N]: " confirm && [ "$$confirm" = "y" ] || exit 1
	ansible-playbook -i inventory/hosts destroy.yml

# Check cluster status
status:
	@echo "Checking OpenShift cluster status..."
	@echo "⚠️  Environment check: Ensure 'source ~/dev/venv/oc/bin/activate' and 'export OS_CLOUD=psi' are set"
	ansible-playbook -i inventory/hosts status.yml

# Show cluster access information when deployment is complete
cluster-info:
	@echo "Checking cluster deployment status and access information..."
	@if [ ! -f openshift-install/install-config.yaml ]; then \
		echo "❌ No cluster configuration found. Run 'make deploy' first."; \
		exit 1; \
	fi
	@if [ ! -f openshift-install/metadata.json ]; then \
		echo "❌ No cluster metadata found. Run 'make deploy' first."; \
		exit 1; \
	fi
	@if [ ! -f openshift-install/auth/kubeconfig ]; then \
		echo "⏳ Cluster deployment in progress..."; \
		echo "   Kubeconfig not yet available."; \
		echo "   Run 'make status' to check deployment progress."; \
		exit 0; \
	fi
	@if [ ! -f openshift-install/auth/kubeadmin-password ]; then \
		echo "⏳ Cluster deployment in progress..."; \
		echo "   Admin password not yet available."; \
		echo "   Run 'make status' to check deployment progress."; \
		exit 0; \
	fi
	@echo "✅ Cluster deployment completed successfully!"
	@echo ""
	@echo "🔗 Cluster Access Information:"
	@echo "================================"
	@CLUSTER_NAME=$$(grep -A1 "clusterName:" openshift-install/install-config.yaml | tail -1 | tr -d ' ') && \
	BASE_DOMAIN=$$(grep -A1 "baseDomain:" openshift-install/install-config.yaml | tail -1 | tr -d ' ') && \
	echo "🌐 Console URL: https://console-openshift-console.apps.$$CLUSTER_NAME.$$BASE_DOMAIN" && \
	echo "🔧 API URL: https://api.$$CLUSTER_NAME.$$BASE_DOMAIN:6443" && \
	echo "👤 Username: kubeadmin" && \
	echo "🔑 Password: $$(cat openshift-install/auth/kubeadmin-password)" && \
	echo "📁 Kubeconfig: $(PWD)/openshift-install/auth/kubeconfig" && \
	echo "🌍 API Floating IP: $$(grep -A1 "apiFloatingIP:" openshift-install/install-config.yaml | tail -1 | tr -d ' ')" && \
	echo "🌍 Ingress Floating IP: $$(grep -A1 "ingressFloatingIP:" openshift-install/install-config.yaml | tail -1 | tr -d ' ')"
	@echo ""
	@echo "🚀 Quick Start Commands:"
	@echo "========================"
	@echo "export KUBECONFIG=$(PWD)/openshift-install/auth/kubeconfig"
	@echo "export PATH=$(PWD)/bin:$$PATH"
	@echo "oc login -u kubeadmin -p $$(cat openshift-install/auth/kubeadmin-password) https://api.$$(grep -A1 "clusterName:" openshift-install/install-config.yaml | tail -1 | tr -d ' ').$$(grep -A1 "baseDomain:" openshift-install/install-config.yaml | tail -1 | tr -d ' '):6443"
	@echo ""
	@echo "📊 Check cluster status:"
	@echo "oc cluster-info"
	@echo "oc get nodes"

# Clean up installation files (properly destroy cluster first)
clean:
	@echo "Cleaning up installation files..."
	@echo "⚠️  IMPORTANT: This will first destroy any existing cluster to prevent orphaned resources."
	@read -p "Are you sure you want to destroy the cluster and delete installation files? [y/N]: " confirm && [ "$$confirm" = "y" ] || exit 1
	@if [ -d "openshift-install" ] && [ -f "openshift-install/metadata.json" ] && [ -f "bin/openshift-install" ]; then \
		echo "🔧 Destroying cluster to prevent orphaned resources..."; \
		source ~/dev/venv/oc/bin/activate && export OS_CLOUD=psi && \
		./bin/openshift-install destroy cluster --dir=openshift-install --log-level=info || \
		echo "⚠️  Cluster destruction completed (some errors may be expected if resources were already deleted)"; \
	else \
		echo "ℹ️  No cluster to destroy (missing installation directory, metadata, or installer binary)"; \
	fi
	@echo "🧹 Removing local installation files..."
	rm -rf openshift-install/
	rm -f openshift-install.tar.gz openshift-client.tar.gz
	@echo "✅ Cleanup completed successfully"

# Validate configuration and prerequisites
validate:
	@echo "Validating configuration and prerequisites..."
	@echo "Checking environment setup..."
	@echo "⚠️  Virtual environment should be active: source ~/dev/venv/oc/bin/activate"
	@echo "⚠️  OS_CLOUD should be set: export OS_CLOUD=psi"
	@echo "Checking Ansible installation..."
	@which ansible-playbook > /dev/null || (echo "Error: ansible-playbook not found. Please install Ansible." && exit 1)
	@echo "Checking inventory file..."
	@test -f inventory/hosts || (echo "Error: inventory/hosts not found." && exit 1)
	@echo "Checking group_vars file..."
	@test -f group_vars/all.yml || (echo "Error: group_vars/all.yml not found." && exit 1)
	@echo "Checking pull secret..."
	@test -f secrets/pull-secret.json || (echo "Warning: secrets/pull-secret.json not found. Please ensure it exists before deployment." && exit 0)
	@echo "Checking SSH key..."
	@test -f secrets/ssh_key.pub || (echo "Warning: secrets/ssh_key.pub not found. Please ensure it exists before deployment." && exit 0)
	@echo "Checking required tools..."
	@which jq > /dev/null || (echo "Warning: jq not found. Required for CIDR validation and JSON processing." && exit 0)
	@which openstack > /dev/null || (echo "Warning: openstack CLI not found. Required for OpenStack operations." && exit 0)
	@echo "✅ Validation completed successfully!"
	@echo ""
	@echo "📋 Features included in deployment:"
	@echo "  - Prerequisite validation (environment, tools, files, OpenStack connectivity)"
	@echo "  - CIDR overlap detection and automatic resolution"
	@echo "  - Floating IP reuse and smart management"
	@echo "  - Enhanced error handling with retries and debugging"
	@echo "  - Status checking before destruction"

# Run ansible-lint on all Ansible files
lint:
	@echo "Running ansible-lint on all Ansible files..."
	@which ansible-lint > /dev/null || (echo "Error: ansible-lint not found. Please install ansible-lint." && exit 1)
	@ansible-lint --version
	@ansible-lint --show-relpath
	@echo "Ansible linting completed successfully!"

# Run shellcheck on all shell scripts
shellcheck:
	@echo "Running shellcheck on all shell scripts..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		echo "ShellCheck version: $$(shellcheck --version | grep version:)"; \
		find scripts -name "*.sh" -type f -exec echo "Checking: {}" \; -exec shellcheck {} \; && \
		echo "✅ ShellCheck validation completed successfully!"; \
	else \
		echo "❌ shellcheck not found. Please install shellcheck:"; \
		if [[ "$$(uname)" == "Darwin" ]]; then \
			echo "   brew install shellcheck"; \
		elif command -v dnf >/dev/null 2>&1; then \
			echo "   sudo dnf install -y ShellCheck"; \
		elif command -v yum >/dev/null 2>&1; then \
			echo "   sudo yum install -y ShellCheck"; \
		else \
			echo "   Visit: https://github.com/koalaman/shellcheck#installing"; \
		fi; \
		exit 1; \
	fi

# Install dependencies
deps:
	@echo "Installing dependencies..."
	pip install ansible ansible-lint

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
		echo "export PATH=$(PWD)/bin:$$PATH"; \
	else \
		echo "No kubeconfig found. Run 'make deploy' first."; \
	fi

# Setup DNS resolution for OpenShift cluster (auto-detects best method)
setup-dns:
	@echo "Setting up DNS resolution for OpenShift cluster..."
	@if [ ! -f scripts/setup-dns.sh ]; then \
		echo "❌ DNS setup script not found: scripts/setup-dns.sh"; \
		exit 1; \
	fi
	@./scripts/setup-dns.sh setup

# Setup DNS using /etc/hosts (works on all platforms)
setup-dns-hosts:
	@echo "Setting up DNS resolution using /etc/hosts..."
	@if [ ! -f scripts/setup-dns.sh ]; then \
		echo "❌ DNS setup script not found: scripts/setup-dns.sh"; \
		exit 1; \
	fi
	@./scripts/setup-dns.sh setup true

# Remove DNS configuration
remove-dns:
	@echo "Removing DNS configuration..."
	@if [ ! -f scripts/setup-dns.sh ]; then \
		echo "❌ DNS setup script not found: scripts/setup-dns.sh"; \
		exit 1; \
	fi
	@./scripts/setup-dns.sh remove

# Show current DNS configuration
show-dns:
	@echo "Showing current DNS configuration..."
	@if [ ! -f scripts/setup-dns.sh ]; then \
		echo "❌ DNS setup script not found: scripts/setup-dns.sh"; \
		exit 1; \
	fi
	@./scripts/setup-dns.sh show

# Show floating IP usage summary
fip-status:
	@echo "Showing floating IP usage summary..."
	@echo "⚠️  Environment check: Ensure 'source ~/dev/venv/oc/bin/activate' and 'export OS_CLOUD=psi' are set"
	@if [ ! -f scripts/cleanup-floating-ips.sh ]; then \
		echo "❌ Floating IP cleanup script not found: scripts/cleanup-floating-ips.sh"; \
		exit 1; \
	fi
	@./scripts/cleanup-floating-ips.sh show

# List unused floating IPs
fip-list:
	@echo "Listing unused floating IPs..."
	@echo "⚠️  Environment check: Ensure 'source ~/dev/venv/oc/bin/activate' and 'export OS_CLOUD=psi' are set"
	@if [ ! -f scripts/cleanup-floating-ips.sh ]; then \
		echo "❌ Floating IP cleanup script not found: scripts/cleanup-floating-ips.sh"; \
		exit 1; \
	fi
	@./scripts/cleanup-floating-ips.sh list

# Clean up unused floating IPs (dry run - use FIP_DELETE=true for actual deletion)
fip-cleanup:
	@echo "Cleaning up unused floating IPs..."
	@echo "⚠️  Environment check: Ensure 'source ~/dev/venv/oc/bin/activate' and 'export OS_CLOUD=psi' are set"
	@if [ ! -f scripts/cleanup-floating-ips.sh ]; then \
		echo "❌ Floating IP cleanup script not found: scripts/cleanup-floating-ips.sh"; \
		exit 1; \
	fi
	@if [ "$(FIP_DELETE)" = "true" ]; then \
		./scripts/cleanup-floating-ips.sh cleanup openshift-cluster example.com --delete; \
	else \
		echo "Running in DRY RUN mode. Use 'make fip-cleanup FIP_DELETE=true' to actually delete floating IPs."; \
		./scripts/cleanup-floating-ips.sh cleanup; \
	fi

# Test DNS setup functionality
test-dns:
	@echo "Testing DNS setup functionality..."
	@if [ ! -f scripts/test-dns-setup.sh ]; then \
		echo "❌ DNS setup test script not found: scripts/test-dns-setup.sh"; \
		exit 1; \
	fi
	@./scripts/test-dns-setup.sh

# Clean up OpenStack resources by signature
cleanup-by-signature:
	@echo "Cleaning up OpenStack resources by signature..."
	@echo "⚠️  Environment check: Ensure 'source ~/dev/venv/oc/bin/activate' and 'export OS_CLOUD=psi' are set"
	@if [ ! -f scripts/cleanup-by-signature.sh ]; then \
		echo "❌ Cleanup script not found: scripts/cleanup-by-signature.sh"; \
		exit 1; \
	fi
	@if [ -n "$(SIGNATURE)" ]; then \
		echo "Using provided signature: $(SIGNATURE)"; \
		./scripts/cleanup-by-signature.sh $(SIGNATURE); \
	else \
		echo "No signature provided, will attempt to extract from openshift-install/metadata.json"; \
		echo "ℹ️  To provide a signature manually, use: make cleanup-by-signature SIGNATURE=<signature>"; \
		./scripts/cleanup-by-signature.sh; \
	fi

# Install bash and zsh tab completion for make targets
install-completion:
	@echo "Installing tab completion for make targets..."
	@if [ ! -f scripts/bash_completion.sh ]; then \
		echo "❌ Bash completion script not found: scripts/bash_completion.sh"; \
		exit 1; \
	fi
	@if [ ! -f scripts/zsh_completion.sh ]; then \
		echo "❌ Zsh completion script not found: scripts/zsh_completion.sh"; \
		exit 1; \
	fi
	@echo ""
	@echo "🔍 Installing Bash completion..."
	@OS_TYPE="$$(uname -s | tr '[:upper:]' '[:lower:]')"; \
	if [ "$$OS_TYPE" = "darwin" ] && command -v brew >/dev/null 2>&1 && [ -d "$$(brew --prefix)/etc/bash_completion.d" ]; then \
		COMPLETION_DIR="$$(brew --prefix)/etc/bash_completion.d"; \
		echo "📁 Using Homebrew bash completion directory: $$COMPLETION_DIR"; \
		sudo cp scripts/bash_completion.sh "$$COMPLETION_DIR/openshift-cluster-make"; \
		echo "✅ Bash completion installed to $$COMPLETION_DIR/openshift-cluster-make"; \
	elif [ -d "/usr/local/etc/bash_completion.d" ]; then \
		COMPLETION_DIR="/usr/local/etc/bash_completion.d"; \
		echo "📁 Using system bash completion directory: $$COMPLETION_DIR"; \
		sudo cp scripts/bash_completion.sh "$$COMPLETION_DIR/openshift-cluster-make"; \
		echo "✅ Bash completion installed to $$COMPLETION_DIR/openshift-cluster-make"; \
	elif [ -d "/etc/bash_completion.d" ]; then \
		COMPLETION_DIR="/etc/bash_completion.d"; \
		echo "📁 Using system bash completion directory: $$COMPLETION_DIR"; \
		sudo cp scripts/bash_completion.sh "$$COMPLETION_DIR/openshift-cluster-make"; \
		echo "✅ Bash completion installed to $$COMPLETION_DIR/openshift-cluster-make"; \
	elif [ -d "/usr/share/bash-completion/completions" ]; then \
		COMPLETION_DIR="/usr/share/bash-completion/completions"; \
		echo "📁 Using system bash completion directory: $$COMPLETION_DIR"; \
		sudo cp scripts/bash_completion.sh "$$COMPLETION_DIR/openshift-cluster-make"; \
		echo "✅ Bash completion installed to $$COMPLETION_DIR/openshift-cluster-make"; \
	else \
		echo "⚠️  No bash completion directory found. Installing to ~/.bash_completion.d/"; \
		mkdir -p ~/.bash_completion.d; \
		cp scripts/bash_completion.sh ~/.bash_completion.d/openshift-cluster-make; \
		echo "✅ Bash completion installed to ~/.bash_completion.d/openshift-cluster-make"; \
		echo "📋 Add this line to your ~/.bashrc: source ~/.bash_completion.d/openshift-cluster-make"; \
	fi
	@echo ""
	@echo "🔍 Installing Zsh completion..."
	@ZSH_COMPLETION_DIR=""; \
	OS_TYPE="$$(uname -s | tr '[:upper:]' '[:lower:]')"; \
	if [ -n "$$ZSH_VERSION" ] && [ -d "$$HOME/.oh-my-zsh/completions" ]; then \
		ZSH_COMPLETION_DIR="$$HOME/.oh-my-zsh/completions"; \
		echo "📁 Using Oh My Zsh completion directory: $$ZSH_COMPLETION_DIR"; \
	elif [ "$$OS_TYPE" = "darwin" ] && command -v brew >/dev/null 2>&1; then \
		BREW_PREFIX=$$(brew --prefix); \
		if [ -d "$$BREW_PREFIX/share/zsh/site-functions" ]; then \
			ZSH_COMPLETION_DIR="$$BREW_PREFIX/share/zsh/site-functions"; \
			echo "📁 Using Homebrew zsh completion directory: $$ZSH_COMPLETION_DIR"; \
		elif [ -d "$$BREW_PREFIX/share/zsh-completions" ]; then \
			ZSH_COMPLETION_DIR="$$BREW_PREFIX/share/zsh-completions"; \
			echo "📁 Using Homebrew zsh-completions directory: $$ZSH_COMPLETION_DIR"; \
		fi; \
	fi; \
	if [ -z "$$ZSH_COMPLETION_DIR" ] && [ -d "/usr/local/share/zsh/site-functions" ]; then \
		ZSH_COMPLETION_DIR="/usr/local/share/zsh/site-functions"; \
		echo "📁 Using system zsh completion directory: $$ZSH_COMPLETION_DIR"; \
	elif [ -z "$$ZSH_COMPLETION_DIR" ] && [ -d "/usr/share/zsh/site-functions" ]; then \
		ZSH_COMPLETION_DIR="/usr/share/zsh/site-functions"; \
		echo "📁 Using system zsh completion directory: $$ZSH_COMPLETION_DIR"; \
	fi; \
	if [ -z "$$ZSH_COMPLETION_DIR" ]; then \
		ZSH_COMPLETION_DIR="$$HOME/.zsh/completions"; \
		echo "⚠️  No zsh completion directory found. Installing to $$ZSH_COMPLETION_DIR"; \
		mkdir -p "$$ZSH_COMPLETION_DIR"; \
		cp scripts/zsh_completion.sh "$$ZSH_COMPLETION_DIR/_make"; \
		echo "✅ Zsh completion installed to $$ZSH_COMPLETION_DIR/_make"; \
		echo "📋 Add this line to your ~/.zshrc: fpath=($$ZSH_COMPLETION_DIR $$fpath)"; \
		echo "📋 Then run: autoload -U compinit && compinit"; \
	else \
		if [ -w "$$ZSH_COMPLETION_DIR" ]; then \
			cp scripts/zsh_completion.sh "$$ZSH_COMPLETION_DIR/_make"; \
		else \
			sudo cp scripts/zsh_completion.sh "$$ZSH_COMPLETION_DIR/_make"; \
		fi; \
		echo "✅ Zsh completion installed to $$ZSH_COMPLETION_DIR/_make"; \
	fi
	@echo ""
	@echo "🎉 Tab completion installation complete!"
	@echo ""
	@echo "📋 To enable completion:"
	@echo "   • For Bash: Restart terminal or run 'source ~/.bashrc'"
	@echo "   • For Zsh: Restart terminal or run 'source ~/.zshrc'"
	@echo ""
	@echo "🚀 Usage examples:"
	@echo "   make <TAB>                           # Show all targets"
	@echo "   make dep<TAB>                        # Complete to 'deploy'"
	@echo "   make cleanup-by-signature <TAB>      # Suggest 'SIGNATURE=' (optional)"
	@echo "   make cleanup-by-signature SIGNATURE=<TAB>  # Ready for input"
	@echo ""
	@echo "ℹ️  Note: Completion only works when in the project directory"

# Test tab completion functionality and show installation status
test-completion:
	@echo "🧪 Testing tab completion functionality..."
	@if [ ! -f scripts/test-completion.sh ]; then \
		echo "❌ Test script not found: scripts/test-completion.sh"; \
		exit 1; \
	fi
	@./scripts/test-completion.sh
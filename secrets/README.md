# Secrets Directory

This directory contains sensitive files that should **NOT** be committed to the repository.

## Required Files

### 1. pull-secret.json
Your OpenShift pull secret obtained from the Red Hat OpenShift website.

To obtain your pull secret:
1. Go to https://cloud.redhat.com/openshift/install/pull-secret
2. Download the pull secret
3. Save it as `pull-secret.json` in this directory

Example format:
```json
{
  "auths": {
    "cloud.openshift.com": {
      "auth": "your-auth-token-here",
      "email": "your-email@example.com"
    }
  }
}
```

### 2. ssh_key.pub
Your SSH public key for cluster access.

To generate an SSH key pair:
```bash
ssh-keygen -t rsa -b 4096 -C "your-email@example.com" -f ~/.ssh/openshift_rsa
```

Then copy the public key to this directory:
```bash
cp ~/.ssh/openshift_rsa.pub secrets/ssh_key.pub
```

Example format:
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDExample... your-email@example.com
```

## Security Notes

- This directory is excluded from Git via `.gitignore`
- Never commit these files to the repository
- These files contain sensitive authentication information
- Ensure proper file permissions (600 for pull-secret.json, 644 for ssh_key.pub)

## Setup Commands

```bash
# Set proper permissions
chmod 600 secrets/pull-secret.json
chmod 644 secrets/ssh_key.pub

# Verify files are valid
jq . secrets/pull-secret.json  # Should parse without errors
ssh-keygen -l -f secrets/ssh_key.pub  # Should show key fingerprint
```
# GKE Cluster Module

This module creates a production-ready Google Kubernetes Engine (GKE) cluster with security best practices and configurable privacy settings.

## Features

- ✅ **Private Cluster** (default) - API server and nodes are private by default
- ✅ **etcd Encryption** (default) - Kubernetes secrets encrypted at rest using Cloud KMS
- ✅ **Workload Identity** - Secure identity for pods
- ✅ **Network Policies** - Pod-level network security with Calico
- ✅ **Binary Authorization** - Enforce deployment of trusted images
- ✅ **Shielded Nodes** - Enhanced node security with Secure Boot and integrity monitoring
- ✅ **Automatic Key Rotation** - KMS key rotates every 90 days (configurable)
- ✅ **Multiple Node Pools** - Support for different workload types

## Security by Default

This module is **secure by default** with the following settings:

| Setting | Default | Description |
|---------|---------|-------------|
| `enable_private_endpoint` | `true` | API server only accessible from within VPC |
| `enable_private_nodes` | `true` | Nodes have no public IPs |
| `enable_etcd_encryption` | `true` | Kubernetes secrets encrypted with Cloud KMS |
| `master_authorized_networks` | `[]` | No public access to API server |
| `kms_key_rotation_period` | `7776000s` | 90-day automatic key rotation |

## Usage

### Basic (Secure by Default)

```terraform
module "cluster" {
  source = "./modules/cluster"

  project_id  = "my-project-id"
  region      = "us-central1"
  cluster_name = "my-cluster"
  
  network_name = "my-vpc"
  subnet_name  = "my-subnet"
  
  subnet_secondary_ranges = {
    pods     = { range_name = "pods" }
    services = { range_name = "services" }
  }
  
  master_ipv4_cidr = "172.16.0.0/28"
  
  node_pools = [
    {
      name         = "default-pool"
      machine_type = "e2-standard-2"
      min_count    = 1
      max_count    = 3
      disk_size_gb = 50
      disk_type    = "pd-standard"
      auto_repair  = true
      auto_upgrade = true
      preemptible  = false
      spot         = false
      labels       = {}
      taints       = []
    }
  ]
}
```

This will create:
- ✅ **Fully private cluster** (API and nodes not accessible from internet)
- ✅ **etcd encrypted** with Cloud KMS (90-day key rotation)
- ✅ **Secure node pools** with shielded nodes

### Public API Server (Less Secure)

If you need the API server to be publicly accessible (not recommended for production):

```terraform
module "cluster" {
  source = "./modules/cluster"
  
  # ... other required variables ...
  
  enable_private_endpoint = false  # API server gets public IP
  
  # Optionally restrict access to specific IPs
  master_authorized_networks = [
    {
      cidr_block   = "203.0.113.0/24"
      display_name = "Office Network"
    }
  ]
}
```

### Disable etcd Encryption (Not Recommended)

If you want to disable etcd encryption (not recommended for production):

```terraform
module "cluster" {
  source = "./modules/cluster"
  
  # ... other required variables ...
  
  enable_etcd_encryption = false  # Secrets stored unencrypted
}
```

### Custom Key Rotation Period

```terraform
module "cluster" {
  source = "./modules/cluster"
  
  # ... other required variables ...
  
  kms_key_rotation_period = "2592000s"  # 30 days instead of 90
}
```

## Variables

### Required Variables

| Name | Description | Type |
|------|-------------|------|
| `project_id` | GCP project ID | `string` |
| `region` | GCP region for cluster | `string` |
| `cluster_name` | Name of the GKE cluster | `string` |
| `network_name` | VPC network name | `string` |
| `subnet_name` | Subnet name | `string` |
| `subnet_secondary_ranges` | Secondary IP ranges for pods and services | `object` |
| `master_ipv4_cidr` | IP range for GKE control plane | `string` |
| `node_pools` | List of node pool configurations | `list(object)` |

### Optional Variables (Security)

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_private_endpoint` | Make API server private (accessible only from VPC) | `bool` | `true` ✅ |
| `enable_private_nodes` | Give nodes private IPs only | `bool` | `true` ✅ |
| `enable_etcd_encryption` | Encrypt Kubernetes secrets at rest with KMS | `bool` | `true` ✅ |
| `kms_key_rotation_period` | KMS key rotation period (seconds) | `string` | `"7776000s"` (90 days) |
| `master_authorized_networks` | CIDR blocks that can access API server | `list(object)` | `[]` (none) |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_id` | The GKE cluster ID |
| `cluster_endpoint` | The GKE cluster endpoint (private IP if private) |
| `cluster_ca_certificate` | The cluster CA certificate |
| `kms_key_id` | The Cloud KMS key used for etcd encryption (if enabled) |

## etcd Encryption Details

When `enable_etcd_encryption = true` (default), the module:

1. Creates a Cloud KMS key ring: `{cluster_name}-keyring`
2. Creates a crypto key: `{cluster_name}-etcd-key`
3. Grants the GKE service account permission to use the key
4. Configures the cluster to encrypt etcd with this key
5. Sets up automatic key rotation (90 days by default)

**Benefits**:
- 🔒 Kubernetes secrets are encrypted at rest
- 🔒 Even if someone gains access to etcd, they cannot decrypt secrets
- 🔒 Key rotation happens automatically
- 📊 All encryption operations are logged in Cloud Audit Logs

**Cost**: ~$1/month for key storage + $0.03 per 10,000 operations

## Accessing the Cluster

### Private Cluster (Default)

Since the cluster is private by default, you need one of these access methods:

1. **Cloud Shell** (easiest):
   ```bash
   gcloud container clusters get-credentials CLUSTER_NAME --region REGION
   kubectl get nodes
   ```

2. **OpenVPN Access Server** (recommended for teams):
   - Set up a VPN tunnel to your VPC
   - Use native tools (kubectl, Lens, k9s) from your laptop
   - See main repo docs for setup

3. **Authorized Networks** (less secure):
   ```terraform
   master_authorized_networks = [
     {
       cidr_block   = "YOUR_IP/32"
       display_name = "My IP"
     }
   ]
   ```

### Public Cluster

If you set `enable_private_endpoint = false`:

```bash
gcloud container clusters get-credentials CLUSTER_NAME --region REGION
kubectl get nodes
```

## Security Best Practices

### ✅ DO (Recommended)

- Keep `enable_private_endpoint = true` for production
- Keep `enable_private_nodes = true` for all environments
- Keep `enable_etcd_encryption = true` for production
- Use `master_authorized_networks = []` (no public access)
- Access cluster via VPN or Cloud Shell
- Use Workload Identity for pod authentication
- Enable Binary Authorization

### ❌ DON'T (Not Recommended)

- Don't set `enable_private_endpoint = false` in production
- Don't disable etcd encryption in production
- Don't use overly broad `master_authorized_networks` (e.g., 0.0.0.0/0)
- Don't use long-lived service account keys

## Troubleshooting

### "Cannot access cluster endpoint"

**Cause**: Cluster has private endpoint and you're trying to access from public internet

**Solution**: Use Cloud Shell or connect via VPN

### "Permission denied" when creating KMS resources

**Cause**: Service account lacks Cloud KMS permissions

**Solution**: Grant `roles/cloudkms.admin` to the Terraform service account

### "Key already exists"

**Cause**: KMS key from previous deployment still exists

**Solution**: Import existing key or change cluster name


## License

This module is part of the terraform-gke-platform repository.

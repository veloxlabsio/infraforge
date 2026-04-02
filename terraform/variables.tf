variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "infraforge"
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "blr1"
}

variable "k8s_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31.1-do.5"
}

variable "node_size" {
  description = "Droplet size for worker nodes"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

data "google_client_config" "default" {}

provider "kubernetes" {
    config_path = "~/.kube/config"
    host                   = google_container_cluster.primary.endpoint
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)   
}

resource "google_compute_network" "vpc_network" {
  name = "cloud-native-vpc"
  routing_mode = "REGIONAL"
  mtu = 1500
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
  network       = google_compute_network.vpc_network.self_link
  name          = "subnetwork-gke"
  ip_cidr_range = "10.0.0.0/24"
  region        = "asia-east1"
  secondary_ip_range {
      range_name = "pod"
      ip_cidr_range    = "10.1.1.0/24"
    }
  secondary_ip_range {
      range_name = "service"
      ip_cidr_range    = "10.0.1.0/24"
    }
  private_ip_google_access = true
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "firewall_rule" {
  name        = "allow-all-ingress"
  network     = google_compute_network.vpc_network.self_link
  source_ranges = ["0.0.0.0/0"]
  priority    = 1
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
  allow {
    protocol = "all"
  }
}

resource "google_container_cluster" "primary" {
  name     = "cloud-native-cluster"
  location = "asia-east1"
  node_locations = ["asia-east1-b"]
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection = false
  default_max_pods_per_node = 20

  network       = google_compute_network.vpc_network.id
  subnetwork = google_compute_subnetwork.subnetwork.id

  ip_allocation_policy {
    cluster_secondary_range_name = "pod"
    services_secondary_range_name = "service" 
  }

  cluster_autoscaling {
    enabled = false
  }

  timeouts {
    create = "30m"
    update = "40m"
  }
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "cloud-native-node-pool"
  location   = "asia-east1"
  cluster    = google_container_cluster.primary.name
  node_count = 1
  node_config {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    disk_size_gb = 10
    machine_type = "e2-medium"
    preemptible  = true
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}


resource "kubernetes_namespace" "prod-namespace" {
 metadata {
   name = "prod"
 }
}




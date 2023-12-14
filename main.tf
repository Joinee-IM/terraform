terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
  }
}

provider "google" {
}


resource "google_storage_bucket" "static" {
 name          = "cloud-native-storage-db"
 location      = "asia-east1"
 storage_class = "STANDARD"
 uniform_bucket_level_access = true
}

resource "google_sql_database_instance" "main" {
  name             = "cloud-native-db-instance"
  database_version = "POSTGRES_15"
  region           = "asia-east1"
  root_password = "xxxxxxxx"
  settings {
    tier = "db-f1-micro"
    edition = "ENTERPRISE"
    availability_type = "REGIONAL"
    backup_configuration {
        enabled = true
        point_in_time_recovery_enabled = true
    }
    ip_configuration {
        ipv4_enabled = true
        authorized_networks {
          name = "allow_all"
          value = "0.0.0.0/0"
        }
    }
  }
}

resource "google_sql_database_instance" "replica" {
  name             = "cloud-native-db-instance-replica"
  database_version = "POSTGRES_15"
  region           = "asia-east1"
  master_instance_name = google_sql_database_instance.main.name
  settings {
    tier = "db-f1-micro"
    edition = "ENTERPRISE"
    availability_type = "REGIONAL"
  }
  replica_configuration {
    failover_target = false
  }
}

resource "google_sql_database" "database" {
  name     = "cloud-native"
  instance = google_sql_database_instance.main.name
}


resource "google_artifact_registry_repository" "my-repo" {
  location      = "asia-east1"
  repository_id = "cloud-native-repository"
  format        = "DOCKER"
}

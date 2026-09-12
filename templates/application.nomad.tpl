job [[ var "name" . | quote ]] {
  namespace   = [[ var "environment" . | quote ]]
  datacenters = ["homelab"]
  type        = "service"

  meta {
    image = [[ var "image" . | quote ]]
  }

  constraint {
    attribute = "${node.class}"
    value     = "general"
  }

  group "web" {
    count = 1

[[ if var "volume_enabled" . ]]
    volume "data" {
      type            = "host"
      source          = [[ var "volume_name" . | quote ]]
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }
[[ end ]]

    update {
      max_parallel      = 1
      health_check      = "checks"
      min_healthy_time  = "10s"
      healthy_deadline  = "2m"
      progress_deadline = "5m"
      auto_revert       = true
    }

    network {
      mode = "host"

      port "http" {
        to = [[ var "port" . ]]
      }
    }

    task "web" {
      driver = "docker"

      config {
        image = [[ var "image" . | quote ]]
        ports = ["http"]
      }

[[ if var "volume_enabled" . ]]
      volume_mount {
        volume      = "data"
        destination = [[ var "volume_mount_path" . | quote ]]
      }
[[ end ]]

      service {
        name     = "[[ var "name" . ]]-[[ var "environment" . ]]"
        provider = "nomad"
        port     = "http"
        tags     = [[ var "service_tags" . | toStringList ]]

        check {
          name     = "HTTP health"
          type     = "http"
          path     = [[ var "health_path" . | quote ]]
          interval = "10s"
          timeout  = "2s"

          check_restart {
            limit = 3
            grace = "30s"
          }
        }
      }

      resources {
        cpu    = 200
        memory = 256
      }

      logs {
        max_files     = 5
        max_file_size = 10
      }

      kill_timeout = "30s"
    }
  }
}

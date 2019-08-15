variable "k8s_dashboard_enabled" {
    default = "true"
}

variable "k8s_dashboard_version" {
    default = "1.8.0"
}

data "template_file" "entrypoint" {
    template = "${file("${path.module}/entrypoint.sh")}"
}

data "template_file" "kubeconfig" {
    template = "${file("${path.module}/kubeconfig.yaml")}"
}

data "template_file" "helmfile" {
    template = "${file("${path.module}/helmfile.yaml")}"

    vars = {
        k8s_dashboard_enabled = "${var.k8s_dashboard_enabled}"
        k8s_dashboard_version = "${var.k8s_dashboard_version}"
    }
}

resource "null_resource" "dockerrm" {
    provisioner "local-exec" {
        command = "docker kill $(docker inspect --format={{.Id}} terraform-helmsman) && docker rm $(docker inspect --format={{.Id}} terraform-helmsman) || true"
    }

    triggers = {
        always_run = "${timestamp()}"
    }
}

resource "docker_container" "helmsman" {
    name = "terraform-helmsman"
    image = "quay.io/roboll/helmfile:v0.80.2"
    links = ["k3s-server"]
    entrypoint = ["/entrypoint.sh"]
    start = true

    upload = {
        content = "${data.template_file.entrypoint.rendered}"
        file = "/entrypoint.sh"
        executable = true
    }

    upload = {
        content = "${data.template_file.kubeconfig.rendered}"
        file = "/kubeconfig.yaml"        
    }

    upload = {
        content = "${data.template_file.helmfile.rendered}"
        file = "/helmfile.yaml"
    }

    depends_on = [
        "null_resource.dockerrm"
    ]
}

resource "null_resource" "dockerlogs" {
    provisioner "local-exec" {
        command = "./logtail.py $(docker inspect --format={{.Id}} terraform-helmsman)"
    }

    triggers = {
        always_run = "${timestamp()}"
    }

    depends_on = [
        "docker_container.helmsman",
    ]
}


DISK_SIZE     := "10G"
VM_NAME       := "edge-blog"
BCVK_PATH     := "/home/asv/.local/bin/bcvk"
IMAGE_URL     := "ghcr.io/wormt"
IMAGE_NAME    := "edge"
IMAGE_TAG     := "latest"
PODMAN_SOCKET := "unix:///run/user/6969/podman/podman.sock"

podman *args:
	podman --remote --url {{PODMAN_SOCKET}} {{args}}

podman-images:
	podman --remote --url {{PODMAN_SOCKET}} images

podman-ps:
	podman --remote --url {{PODMAN_SOCKET}} ps

podman-load *args:
	podman --remote --url {{PODMAN_SOCKET}} load -i {{args}}

build:
	nix build /home/asv/workspaces/roc/blog2/nix#caligaConfigurations.x86_64-linux.edge.config.build.image --refresh --repair
	@echo "image built at ./nix/image.tar"

qcow:
	{{BCVK_PATH}} to-disk {{IMAGE_URL}}/{{IMAGE_NAME}}:{{IMAGE_TAG}} nix/{{IMAGE_NAME}}.qcow2 --format=qcow2 --disk-size={{DISK_SIZE}}

vm:
	-just podman rm -f {{ VM_NAME }}
	distrobox-host-exec bash -lc 'export PATH=/var/home/asv/.local/bin:$PATH; cd /var/home/asv/workspaces/roc/blog2 && bcvk ephemeral run {{ IMAGE_URL }}/{{ IMAGE_NAME }}:{{ IMAGE_TAG }} --rm --name={{ VM_NAME }} --detach --ssh-keygen --console'

vm-ssh *args:
	distrobox-host-exec bash -lc 'export PATH=/var/home/asv/.local/bin:$PATH; cd /var/home/asv/workspaces/roc/blog2 && bcvk ephemeral ssh {{ VM_NAME }} {{ args }}'

build-qcow-vm: build qcow vm
	@echo "VM {{VM_NAME}} running"

build-qcow: build qcow
	@echo "nix/{{IMAGE_NAME}}.qcow2 ready"

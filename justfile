# bcvk must run on the host, not inside a distrobox container. A nested
# podman cannot create user namespaces, so every bcvk invocation here goes
# through distrobox-host-exec. The host copy of bcvk lives at
# /home/asv/.local/bin/bcvk; the host is secureblue/ostree, so the root is
# read-only and /usr/bin/bcvk resolves to the container copy.  I installed
# the host copy there and it is the one the recipes use
#
# every podman call targets the host socket:
# unix:///run/user/6969/podman/podman.sock
# I switched the host engine from the vfs store to overlay at
# /var/home/asv/.local/share/containers/storage because bcvk's to-disk
# validation requires overlay or overlay-images subdirectories, and vfs
# storage failed that check ("missing overlay subdirectories")
#
# bcvk ephemeral run takes a container image, not a qcow2.  The vm recipe
# boots ghcr.io/wormt/edge:latest directly via virtiofs; the qcow2 built by
# the qcow recipe is a separate, persistent boot image. --ssh-keygen must be
# present on ephemeral run or vm-ssh has no key to ssh with

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
	-distrobox-host-exec podman --remote --url '{{ PODMAN_SOCKET }}' rm -f {{ VM_NAME }}
	distrobox-host-exec bash -lc 'export PATH=/var/home/asv/.local/bin:$PATH; cd /var/home/asv/workspaces/roc/blog2 && bcvk ephemeral run {{ IMAGE_URL }}/{{ IMAGE_NAME }}:{{ IMAGE_TAG }} --rm --name={{ VM_NAME }} --detach --ssh-keygen --console'

vm-ssh *args:
	distrobox-host-exec bash -lc 'export PATH=/var/home/asv/.local/bin:$PATH; cd /var/home/asv/workspaces/roc/blog2 && bcvk ephemeral ssh {{ VM_NAME }} {{ args }}'

build-qcow-vm: build qcow vm
	@echo "VM {{VM_NAME}} running"

build-qcow: build qcow
	@echo "nix/{{IMAGE_NAME}}.qcow2 ready"

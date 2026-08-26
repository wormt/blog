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

DISK_SIZE     := "10G"
VM_NAME       := "edge-blog"
BCVK_PATH     := "/home/asv/.local/bin/bcvk"
IMAGE_URL     := "ghcr.io/wormt"
IMAGE_NAME    := "edge"
IMAGE_TAG     := "latest"
PODMAN_SOCKET := "unix:///run/user/6969/podman/podman.sock"
PODMAN        := "podman --remote --url unix:///run/user/6969/podman/podman.sock"
BCVK          := "distrobox-host-exec bash -lc 'export PATH=/var/home/asv/.local/bin:$PATH; cd /var/home/asv/workspaces/roc/blog2 && bcvk"

podman *args:
	{{PODMAN}} {{args}}

podman-images:
	{{PODMAN}} images

podman-ps:
	{{PODMAN}} ps

podman-load *args:
	{{PODMAN}} load -i {{args}}

build:
	nix build /home/asv/workspaces/roc/blog2/nix#caligaConfigurations.x86_64-linux.edge.config.build.image
	./result > nix/image.tar
	@echo "image built at ./nix/image.tar"
	{{PODMAN}} load -i nix/image.tar

vm:
	-distrobox-host-exec podman --remote --url '{{ PODMAN_SOCKET }}' rm -f {{ VM_NAME }}
	{{BCVK}} ephemeral run {{ IMAGE_URL }}/{{ IMAGE_NAME }}:{{ IMAGE_TAG }} --rm --name={{ VM_NAME }} --detach --ssh-keygen --console'

vm-ssh *args:
	{{BCVK}} ephemeral ssh {{ VM_NAME }} {{ args }}'

tunnel local_port="8080" guest_port="80":
	./scripts/tunnel-bridge.nu {{ local_port }} {{ guest_port }}

rebuild: build vm
	@echo "VM {{VM_NAME}} rebuilt"

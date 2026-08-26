#!/usr/bin/env nu
# Usage: tunnel-bridge.nu [LOCAL_PORT] [GUEST_PORT]

# @param local_port Host port to listen on (default 8080).
# @param guest_port Port inside the VM to forward to (default 80).
def main [
    local_port: int = 8080 # Host port to listen on.
    guest_port: int = 80   # Port inside the VM to forward to.
] {
    let vm_name = ($env.VM_NAME? | default "edge-blog")
    let podman_socket = (
        $env.PODMAN_SOCKET? | default "unix:///run/user/6969/podman/podman.sock"
    )
    let ssh_key = "/run/tmproot/var/lib/bcvk/ssh"

    ensure-ssh-forward $vm_name $podman_socket $ssh_key $local_port $guest_port
    run-bridge $vm_name $podman_socket $local_port $guest_port
}

# Ensure the ssh -L forward is running inside the container.
#
# Starts the forward detached if it is not already running, so the
# command is idempotent across repeated invocations.
def ensure-ssh-forward [
    vm_name: string
    podman_socket: string
    ssh_key: string
    local_port: int
    guest_port: int
] {
    let pattern = $"ssh .*-L ($local_port):localhost:($guest_port)"
    let running = (
        ^podman --remote --url $podman_socket exec $vm_name sh -c
            $"ps -ef | grep -q '[s]sh .*-L ($local_port):localhost:($guest_port)'"
        | complete
        | get exit_code
    ) == 0

    if $running {
        print $"ssh forward already running in container ($vm_name)"
        return
    }

    print $"Starting ssh forward in ($vm_name): ($local_port) -> VM:($guest_port)"
    ^podman --remote --url $podman_socket exec -d $vm_name ssh -i $ssh_key -o BatchMode=yes -o StrictHostKeyChecking=no -N -L $"($local_port):localhost:($guest_port)" root@127.0.0.1 -p 2222
    sleep 2sec
}

# Run the socat bridge on the host.
#
# socat's EXEC splits on spaces, so the podman exec is wrapped in a
# helper script that socat invokes per connection.
def run-bridge [
    vm_name: string
    podman_socket: string
    local_port: int
    guest_port: int
] {
    let bridge_wrapper = (mktemp)
    build-wrapper-body $podman_socket $vm_name $local_port | save -f $bridge_wrapper
    ^chmod +x $bridge_wrapper

    print $"Tunnel ready: http://localhost:($local_port) -> VM nginx \(guest :($guest_port)\)"
    print "Press Ctrl-C to stop."
    ^socat $"TCP-LISTEN:($local_port),reuseaddr,fork" $"EXEC:($bridge_wrapper)"
}

# Build the socat EXEC wrapper script body.
#
# socat's EXEC splits on spaces, so the podman exec command is wrapped
# in a small sh script that socat invokes per connection.
#
# @param podman_socket Podman socket URL.
# @param vm_name Name of the container hosting the VM.
# @param local_port Host port to listen on.
def build-wrapper-body [
    podman_socket: string
    vm_name: string
    local_port: int
] {
    [
        "#!/bin/sh"
        $"exec podman --remote --url ($podman_socket) exec -i ($vm_name) socat - TCP:127.0.0.1:($local_port)"
    ] | str join (char nl)
}

# Asmodeo

I use this repo to manage the deployment and configuration of my [Fedora Silverblue](https://docs.fedoraproject.org/en-US/fedora-silverblue/) Laptop.

This repo is based on the [JayDoubleu](https://github.com/JayDoubleu) [ansiblue work](https://github.com/JayDoubleu/ansiblue).

## Quickstart

1. Install Fedora Silverblue
2. Upgrade the system with `rpm-ostree upgrade`
3. Reboot the system or apply the layered packages live `rpm-ostree ex apply-live` (beware `ex` means **experimental**)
4. Install Ansible with pip `python3 -m ensurepip && python3 -m pip install psutil ansible`
5. Configure your environment modifying `configs/flatpak.yaml`, `configs/toolbox.yaml` and `config/host.yaml`
6. Run with `ansible-playbook asmodeo.yaml -K`

### Notes

- Flatpak names are case sensitive. While flatpak is ok with it, creation of symlinks will fail.
- To apply live the rpm-ostree overlay run `export RPM_OSTREE_LIVE_UPDATE=true` before execuring the playbook

### Targeting:
- `ansible-playbook asmodeo.yaml --tags flatpak` <- Run only flatpak tasks
- `ansible-playbook asmodeo.yaml --tags toolbox` <- Run only toolbox tasks ( for all toolboxes )
- `ansible-playbook asmodeo.yaml --tags toolbox:fedora-toolbox-35` <- Run only tasks for the toolbox `fedora-toolbox-35`
- `ansible-playbook asmodeo.yaml --tags host -K` <- Run only host tasks

## Configuration

Main system configuration is managed via the yaml files in the `configs` directory.

## Flatpak

The `configs/flatpak.yaml` defines a list of remotes and the flatpaks you want to add to the system.

* Through the `flatpaks.cmds` field you can define one or more wrapper script into `~/.local/bin/ calling the flatpak:
```
$ cat configs/flatpak.yaml
[...]
flatpaks:
  - name: org.gnome.TextEditor
    state: present
    method: user
    remote: flathub-beta
    cmds: [gtedit, gnome-text-editor]

$ ls ~/.local/bin/gedit ~/.local/bin/gnome-text-editor 
/var/home/pietro/.local/bin/gedit  /var/home/pietro/.local/bin/gnome-text-editor

$ cat ~/.local/bin/gedit
#!/bin/sh
exec flatpak run --branch=stable --arch=x86_64 org.gnome.gedit "$@"
```
* with the `flatpaks.overrides` you can define one or more override to apply to the installed flatpack
* for the other fields please refer to the `community.general.flatpak` ansible module

## Toolbox

The `configs/toolbox.yaml` defines the [Fedora toolbox](https://containertoolbx.org/) you want to deploy on the system.

You can define:
- The name of the toolbox
- The container image to use
- Define any variable to use on the ansible tasks
- Execute some additional ansible tasks
- Which packages to install (you must run the task file `playbooks/toolbox/tasks_fedora_system.yaml`)
- The user and group to configure (you must run the task file `playbooks/common/tasks_toolbox_default.yaml`)
- A list of commands to be executed on the toolbox from the host (you must run the task file `playbooks/toolbox/tasks_toolbox_cmd.yaml`)

### Toolbox shims

Shims are commands that when executed from the toolbox container are executed on the host (see [#toolbox-145](https://github.com/containers/toolbox/issues/145))

### Toolbox cmds

Cmds are the opposite to shims: a command is executed on the toolbox with `toolbox run $container $command`

## Host

The `configs/host.yaml` manages the host configuration:

- The `name` defines the hostname
- `tasks` defines the playbooks to execute
- `layered_packages` is the list of packages to install with `rpm-ostree`
- `local_packages` are binary files downloaded into `~/.local/bin`
- `pip_packages` are Python pip packages to install
- `git_config` are basic git settings
- `gnome` manages extensions and dconf settings
- `systemd_services` lists all the services to enable/disable

## TODO

- [] Use the [unarchive](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/unarchive_module.html) ansible module to unzip local packages
- [] Manage the local firewall


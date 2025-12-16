# Importing an OVA VM into Proxmox

This guide explains how to import a virtual machine in OVA format into Proxmox, a useful task for quickly setting up a lab environment, for example when preparing for certifications like RHCSA.

## Prerequisites

- An accessible Proxmox server (example: `192.168.7.32`)
- An OVA file to import (example: `librenms-ubuntu-18.04-amd64.ova`)
- An available VM ID (example: `333`)
- A defined storage location in Proxmox (example: `pve1_local_zfs`)

## Import Steps

### 1. Upload the OVA file to the Proxmox server

Use SCP (or any other transfer method) to copy the OVA file to your Proxmox server:

```bash
scp librenms-ubuntu-18.04-amd64.ova root@192.168.7.32:/root/
```

### 2. Extract the OVA archive contents
Log into your Proxmox server and extract the OVA files:
tar xvf librenms-ubuntu-18.04-amd64.ova
This command will extract several files, including a .ovf file essential for the import.

### 3. Import the VM using the qm importovf command
Execute the following command, adjusting parameters to match your configuration:
qm importovf 333 librenms-ubuntu-18.04-amd64.ovf pve1_local_zfs
Parameters:

- 333: The VM ID
- librenms-ubuntu-18.04-amd64.ovf: The extracted OVF file
- pve1_local_zfs: The storage name in Proxmox

### 4. Verification
The new VM with ID 333 should now appear in the Proxmox web interface.
Troubleshooting: Manual Disk Import
If you encounter an error like:
warning: unable to parse the VM name in this OVF manifest, generating a default value
invalid host resource /disk/vmdisk1, skipping
The VM configuration is imported but without a disk. Manually import the VMDK disk instead.

**Option A:** Direct import with specified format
qm importdisk 333 librenms-ubuntu-18.04-amd64-disk001.vmdk pve1_local_zfs --format qcow2

**Option B:** Convert first, then import

# Convert from VMDK to QCOW2 format
qemu-img convert -f vmdk -O qcow2 librenms-ubuntu-18.04-amd64-disk001.vmdk librenms-ubuntu-18.04-amd64-disk001.qcow2

# Import the disk
qm importdisk 333 librenms-ubuntu-18.04-amd64-disk001.qcow2 pve1_local_zfs
Final Configuration in Web Interface

Attach the disk: In the Proxmox web interface, go to Hardware > Unused Disk 0 and click Edit.
Change the controller: Modify Bus/Device from IDE to SATA, VirtIO, or SCSI.
Rename the VM (optional): Go to Options > Name to give your VM a meaningful name.
Start the VM: Your VM is now ready to use.

# Notes

OVA format is an archive that typically contains an OVF file (descriptor) and one or more VMDK files (disks)
The qm tool is included in Proxmox and greatly simplifies VM imports
Using qcow2 format is recommended for better performance in Proxmox

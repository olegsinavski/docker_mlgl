# Google Cloud setup

Here is a small tutorial on how to setup a remote dev machine on Google Cloud.
If you haven't used GCE before, [start here](https://cloud.google.com/compute/docs) and complete some turial.

## Make ssh key for your dev instances
https://cloud.google.com/compute/docs/connect/create-ssh-keys
The `USERNAME` below is your 
```bash
ssh-keygen -t rsa -f ~/.ssh/gce_key -C <USERNAME> -b 2048
```
To see the generated public key that you're going to add to GCE:
```bash
cat ~/.ssh/gce_key.pub 
```
(optional) Add this ssh key [globally](https://cloud.google.com/compute/docs/connect/add-ssh-keys)

## Create the cheapest test CPU VM to practice from scratch

Go to [Google Compute Engine (GCE)](https://console.cloud.google.com/compute), turn on GCE API.
You should see creating
Create a VM with the following options:
 - default region is the cheapest
 - E2 is a good cheapest option, but you need at least 16GB of RAM if you'll use `pip`
 - "Availability policies", choose "Spot" to save money
 - Check "Enable display service"
 - Boot disk, "Change", Choose Debian Deep Learning with CUDA 11 for GPU support (or Ubuntu with at least 20gb disk size for CPU-only)
 - Firewall, check "Allow HTTP/HTTPS traffic"
 - Advanced options, Disks, Add new disk, pick "Standard" (cheapest)
 - Advanced options, Security, Manage Access, Add manually generated SSH keys, add the content of `~/.ssh/gce_key.pub`

Now create the instance, you should see a green checkmark in "Status" column.

Add this to your `~/.ssh/config`. Your `USERNAME` is what's before your `@gmail.com`.
`EXTERNAL_IP` is what you see in "External IP" column of your running instance
```shell
Host gce
  HostName <EXTERNAL_IP>
  User <USERNAME>
  IdentityFile ~/.ssh/gce_key
```

You should be able to login `ssh gce` from your laptop.
Call `sudo passwd` to change the password.

### Format your empty disk or attach existing disk
Follow (this tutorial)[https://cloud.google.com/compute/docs/disks/format-mount-disk-linux].
In short, for empty disk:
```bash
sudo lsblk
# you should see your large disk size under sdb. Now create the filesystem
sudo mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb
# mount the disk
sudo mkdir -p /mnt/disks/disk-1
sudo mount -o discard,defaults /dev/sdb /mnt/disks/disk-1
# mount on boot
# copy UUID returned by the following command:
sudo blkid /dev/sdb
# then
sudo vim /etc/fstab , Shift+G, o
# add this:
UUID="<UUID_FROM_ABOVE>" /mnt/disks/disk-1 ext4 discard,defaults 0 2
```
If you attached an existing disk and you used a debian deep learning image,
the disk is by default mounted to `/home/jupyter`

## Move home folder onto new large drive:
If you used a debian deep learning image, see below.
For a new mounted image:
```
cd /mnt/disks/disk-1
mkdir -p home/<USERNAME> 
sudo rsync -avz --progress /home/<USERNAME>/ /mnt/disks/disk-1/home/<USERNAME>/
sudo vim /etc/passwd
# find your username entry and change /home/<USERNAME> to /mnt/disks/disk-1/home/<USERNAME>
sudo chown -R <USERNAME>:<USERNAME> /mnt/disks/disk-1/home/<USERNAME> 
sudo reboot
```

If you used a debian deep learning image, the disk is by default mounted to `/home/jupyter`
```bash
sudo vim /etc/passwd
# find your username entry and change /home/<USERNAME> to /home/jupyter/home/<USERNAME>
sudo chown -R <USERNAME>:<USERNAME> /home/jupyter/home/<USERNAME>
sudo reboot
```

Now when you ssh again into `~` and call `pwd` you should see your new home location.


## Setup github keys

```bash
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
```

Add a `~/.ssh/gce_key` to your GitHub account.
Copy the keys from your laptop to the dev VM:
`scp ~/.ssh/gce_key* gce:~/.ssh/`
Add the following at the end of `~/.bashrc`
```bash
# If not running interactively, return early
# https://stackoverflow.com/questions/64790393/indicated-packet-length-too-large-error-when-using-remote-interpreter-in-pycha
[[ $- == *i* ]] || return
eval $(ssh-agent)
ssh-add ~/.ssh/gce_key
```
Now you should be able to clone your repo.

If you're running GCE deeplearning image, disable jupyter service:
```
sudo systemctl stop jupyter.service
sudo rm /etc/systemd/system/multi-user.target.wants/jupyter.service
```

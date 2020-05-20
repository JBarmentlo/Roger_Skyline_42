# 1. Creating the Virtual Machine

**Prerequisites**

For this project we will be using VirtualBox and an Ubuntu 18.04 .iso.

**VM installation**

Create a new virtual machine in VirtualBox and create an 8GB .vdi (all the hard drive formats will do but the dynamically allocated .vdi uses least disk space)

Start the machine, choose the ubuntu .iso as start-up media and proceed to install linux on your machine.

You may choose the hostname and username of your choice.
Leave the Proxy field blank.
For every field leave the default installation setting, until the following.

Software to install :
- [ ] Debian desktop environment
- [ ] ... GNOME
- [ ] ... Xfce
- [ ] ... KDE
- [ ] ... Cinnamon
- [ ] ... MATE
- [ ] ... LXDE
- [ ] web server
- [ ] print server
- [x] SSH server
- [ ] Standard system utilities

We do not need a desktop interface for this project.

# 2. Basic Utilities

**sudo**

```
apt install sudo
```

**Non-Root user**

Create a non-root user and add hom to the sudoers group.
```
sudo useradd username

usermod -aG sudo username
```

**Text editor**

```
sudo apt install vim
```

**Update your packages**

You should always keep your packages up to date unless you have a specific reason not to do so !
```
sudo apt update -y
sudo apt upgrade -y
```
# 3. Network configuration

Ubuntu 18.04 network configuration is edited through the ``/etc/netplan/*.yaml`` file and applied with ``sudo netplan apply``. We will require the ``ifconfig`` command which is installed with :

```
sudo apt install net-tools
```

**editing the netplan configuration :**

```
sudo vim /etc/netplan/
```

Replace the contents with this :

```
network:
  version: 2
  renderer: networkd 
  ethernets:
    enp0s3:
      dhcp4: no
      addresses: [10.0.2.0/30]
      gateway4: 10.0.2.2
      nameservers:
              addresses: [10.0.2.3,8.8.8.8]
    enp0s8:
            dhcp4: no

```

We disable DHCP. To understand the how's and why's of the other parameters I recommend [this](https://forums.virtualbox.org/viewtopic.php?f=1&t=49066) page. Basically they need to be compatible with VirtualBox.

> The Dynamic Host Configuration Protocol (DHCP) is a network management protocol used on Internet Protocol networks whereby a DHCP server dynamically assigns an IP address and other network configuration parameters to each device on a network so they can communicate with other IP networks.

We apply the configuration with ``sudo netplan apply`` and we can check our IP with ``hostname -I`` or ``ifconfig | grep inet``. Do verify your internet is still functionnal with ``sudo apt update``.

# 3. SSH Configuration

## Install ssh

```
sudo apt install openssh-server
```

The SSH configuration of your machine is done by editing  ``/etc/ssh/sshd_config``. The ``/etc/ssh/ssh_config`` file concerns outgoing ssh whereas the sshd_config file concerns incoming ssh traffic (_sshd stands for ssh daemon_)

**``/etc/ssh/sshd_config``** :
```
PasswordAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin	no
Port 2222
```

Here we disable forms of authentification apart from publickey (which is enabled by default) and we disable root login via ssh. Then we run ``sudo systemctl restart ssh`` to restart the service and apply our settings. ``sudo systemctl status ssh`` can be used to check the status of this service.

## Connect via SSH

To connect to our machine via SSH a few additionnal steps are required. The essential problem is **our machine does not have a public IP address**. This means if you ask the internet "where is 10.0.2.0 ?" (with a ``ping 10.0.2.0`` command for example) it does not know. Indeed all the IP adresses displayed by ``ifconfig`` or ``hostname -I`` are **local** IP addresses used to differenciate devices in your local network (i.e. all the device connected to your router). In this case we are connected to the VirtualBox NAT and virtualbox knows where 10.0.2.0 is. So we need to set up **Port Forwarding**.

**Port Forwarding**

In VirtualBox right click on the machine and go to ``Settings->Network->Advanced->Port-Forwarding``. Here we create a new rule:

| Name | Protocol | Host IP   | Host Port | Guest IP | Guest Port |
|------|----------|-----------|-----------|----------|------------|
| SSH  | TCP      | 127.0.0.1 | 1234      |          | 2222       |

We can choose the port we want for Host Port and the Guest Port has to match the ``sshd_config`` port. 127.0.0.1 is simply localhost.
So the traffic we send to 127.0.0.1 at port 1234 will be redirected to the virtual machine at port 2222. We can test this with :
```
ssh -p 1234 username@127.0.0.1
```
Which should return :
```
username@127.0.0.1: Permission denied (publickey).
```

**Authorizing access**

Since SSH authentification on the machine is only possible by publickey we will have to copy an RSA key from our host machine to the guest machine. The keys that give acces to an account on a machine are stored in ``/home/username/.ssh/authorized_keys``. If you do not have a RSA key create one with ``ssh-keygen``.
The command to copy the key:

```
ssh-copy-id -p 1234 -i ~/.ssh/id_rsa.pub username@127.0.0.1
```

Obviously the connection is refused (otherwise anyone could give themselves access to the machine). So we must :
* edit ``sshd_config`` to authorize password authentification.
* apply the new settings ``sudo systemctl restart ssh`` .
* copy our key to the guest machine.
* disable password authentification again.
 
Test the setup with :
```
ssh -p 1234 username@127.0.0.1
```

# 4. Firewall

We shall use the UFW firewall.

```
sudo apt install ufw
```

and set the default policy of refusing all incoming connections :

```
sudo ufw default deny incoming
```
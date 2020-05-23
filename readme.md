# 0. Lingo

* Guest machine will refer to the virtual machine
* Host machine refers to your computer
* Username is the name of the user on the guest machine, replace it in code snippets
 

# 1. Creating the Virtual Machine

**Prerequisites**

For this project we will be using VirtualBox and an Ubuntu 18.04 .iso.

**VM installation**

Create a new virtual machine in VirtualBox and create an 8GB .vdi (all the hard drive formats will do but the dynamically allocated .vdi uses least disk space).

Verify in ``Settings->Network`` that ``Adapter 1`` is enabled and set to ``NAT``.

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

We want to allow incoming connections only for the ssh service which uses port 2222.

```
sudo ufw allow 2222
```

# 5. Fail2ban

We will use fail2ban for DOS protection and to protect against port scanning.

```
sudo apt install fail2ban
```
Fail2ban works in a very simple fashion. We create "jails" for specific behaviors we want to block. We define our first jail like this:

``/etc/fail2ban/jail.d/custom.conf`` :
>[portscanner]    
>enabled  = true    
>filter   = portscanner    
>logpath  = /var/log/syslog    
>bantime = 60    
>findtime = 100    
>maxretry = 1   

This means fail2ban will create a jail called ``portscanner`` which will scan ``/var/log/syslog`` using the regex defined by the ``filter = portscanner`` and after ``maxretry = 1`` in the past ``findtime = 100`` seconds it will ban the IP for ``bantime = 60`` seconds.


The filter used by the above jail is defined in   
``/etc/fail2ban/filter.d/portscanner.conf`` :
>[Definition]   
>failregex = UFW BLOCK.* SRC=<HOST>   
>ignoreregex =  

The above jail will protect us against port scanning. We still have to protect against DOS. Since all incoming traffic is blocked by UFW except for port 2222 we only have to protect that one.


``/etc/fail2ban/jail.d/custom.conf`` replace contents by this:

>[DEFAULT]  
>  
>findtime = 3600   
>bantime = 60   
>maxretry = 3   
>   
>[sshd]   
>enabled = true   
>port = 2222    
>filter = sshd   
>bantime =  60   
>findtime = 100   
>maxretry = 1     
>  
>[portscanner]    
>enabled  = true    
>filter   = portscanner    
>logpath  = /var/log/syslog    
>bantime = 60    
>findtime = 100    
>maxretry = 1    

## Testing our jails

**Setting up a host-only network**

To test out jails we will need to set up an IP for our guest machine that our host machine can find. For this purpose we will set up a "Host-Only Network".   
In VirtualBox go to ``File->Host Network Manager`` and create a new host network. After creating it enable DHCP for it (in the same menu).
Then turn of your VM and go to settings of your virtual machine in ``Settings->Network->Adaptator 2`` enable it and set it to host only adapter.

Start your machine and type :

```
ifconfig
```

There should be a new network adapter, called ``enp0s8`` in my case. We want to add it to our ``netplan`` and be configured by DHCP.   
Edit your netplan config to look like this    
``/etc/netplan/*.yaml`` :

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
and apply it with :

```
sudo netplan apply
```
 
The command ``hostname -I`` should display two IP addresses, try to ping the second one from your host machine, in my case :   

```
ping 192.168.56.101
```
The ping should work, if not, do not go ahead, you have problems to fix. You can now test your guest machine for port scanning and DOS.    
For portscanning try on host :

```
sudo apt install nmap
sudo nmap -p 192.168.56.101
```
Replace ``192.168.56.101`` with the IP of your guest machine.

# 6. Crontab

To planify scripts linux uses crontab. every user has a crontab that he can edit with ``crontab -e`` and there is a system-wide crontab in ``/etc/crontab``. We shall write the scripts and edit our crontab to run them automatically.
I wrote two scripts :  
``/home/username/update_and_log.sh`` :

```
#!/bin/bash
date >> /var/log/update_script.log
apt update -y >> /var/log/update_script.log
apt upgrade -y >> /var/log/update_script.log
```
``/home/username/check_modif.sh`` :  

```
#!/bin/bash
[ ` find /etc/crontab -mmin -1440 ` ] && echo "crontab was modified in the last 24h" | mailx -s "crontab alert" root@roguehost 
```

Make the files executable with:
```
chmod u+x check_modif.sh
chmod u+x update_and_log.sh
```

We will need ``mailx`` to run the previous script

```
sudo apt-get install bsd-mailx.
```

To verify the scripts modify ``etc/crontab`` then run ``sudo ./check_modif.sh`` followed by ``sudo mailx``. You should have mail.

Now we must add the scripts to the end of   
``/etc/crontab``:  

```
@reboot root /home/jbarment/update_and_log.sh
0 4 * * 2 root /update_and_log.sh
0 0 * * * root /check_modif.sh
```


# 7. Stopping unnecessary services

As all Linux distros are somewhat different you just have to figure this one out. To display all services :

```
sudo systemctl --type=service
```

You may either ask google or simply take a snapshot of your machine, disable a service with 

```
systemctl disable servicename
```

Then reboot and see if it crashes.

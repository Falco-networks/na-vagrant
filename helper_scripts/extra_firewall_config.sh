#!/bin/bash

echo "#################################"
echo "  Running Extra_Server_Config.sh"
echo "#################################"
sudo su

useradd cumulus -m -s /bin/bash
echo "cumulus:CumulusLinux!" | chpasswd
usermod -aG sudo cumulus

#Test for Debian-Based Host
which apt &> /dev/null
if [ "$?" == "0" ]; then
    #These lines will be used when booting on a debian-based box
    echo -e "note: ubuntu device detected"
    
    #install ssh key
    echo ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSCPvbPvw3sNytx1B7zIYoEA3cgKkYCYXnJgEk1gMBbPVmcOxXyuIoH7oL25UCCO/s3ZTwIyIMOIK2TH3wEovbjbE268O5og1P6DEbazA+wzC6cHC1QLCjtZ/bDlyCX9ka6nJ8KbF+o6JFMncT+wkRve7z7WXN8SevPebj3Crvu/ppJkvB9VbFZ/ej5GZQOxpXELLlpRZ/cYNEzSUDlGk1pqO23303/l5svblMv2uoMRWxHX3ZPK05Gn3tUDbDmToxs3nn4lH32758Rdc8EgM9sJNcg1k0V8MHFbJ0BDZKb6JM5QXt+ek/xYn8jQpEkJDiqNb7d8aFHrqGPSTHDblN root@oob-mgmt-server | sudo tee -a /home/cumulus/.ssh/authorized_keys

    #Install LLDP, frr
    curl -s https://deb.frrouting.org/frr/keys.asc | sudo apt-key add -
    echo deb https://deb.frrouting.org/frr xenial frr-stable | sudo tee -a /etc/apt/sources.list.d/frr.list
    apt-get update -qy && apt-get install lldpd frr frr-pythontools -qy
    echo "configure lldp portidsubtype ifname" > /etc/lldpd.d/port_info.conf

    #Replace existing network interfaces file
    echo -e "auto lo" > /etc/network/interfaces
    echo -e "iface lo inet loopback\n\n" >> /etc/network/interfaces
    echo -e  "source /etc/network/interfaces.d/*.cfg\n" >> /etc/network/interfaces

    #Add vagrant interface
    echo -e "\n\nauto vagrant" > /etc/network/interfaces.d/vagrant.cfg
    echo -e "iface vagrant inet dhcp\n\n" >> /etc/network/interfaces.d/vagrant.cfg

    echo -e "\n\nauto eth0" > /etc/network/interfaces.d/eth0.cfg
    echo -e "iface eth0 inet dhcp\n\n" >> /etc/network/interfaces.d/eth0.cfg

    echo "retry 1;" >> /etc/dhcp/dhclient.conf
    echo "timeout 600;" >> /etc/dhcp/dhclient.conf
fi

#Test for Fedora-Based Host
which yum &> /dev/null
if [ "$?" == "0" ]; then
    echo -e "note: fedora-based device detected"
    /usr/bin/dnf install python -y
    echo -e "DEVICE=vagrant\nBOOTPROTO=dhcp\nONBOOT=yes" > /etc/sysconfig/network-scripts/ifcfg-vagrant
    echo -e "DEVICE=eth0\nBOOTPROTO=dhcp\nONBOOT=yes" > /etc/sysconfig/network-scripts/ifcfg-eth0
fi


echo "#################################"
echo "   Finished"
echo "#################################"

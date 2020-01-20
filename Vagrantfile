# Created by Topology-Converter v4.7.1
#    Template Revision: v4.7.1
#    https://github.com/cumulusnetworks/topology_converter
#    using topology data from: na.dot
#    built with the following args: /home/patrick/github/topology_converter/topology_converter.py na.dot -c -p libvirt
#
#    NOTE: in order to use this Vagrantfile you will need:
#       -Vagrant(v2.0.2+) installed: http://www.vagrantup.com/downloads
#       -the "helper_scripts" directory that comes packaged with topology-converter.py
#        -Libvirt Installed -- guide to come
#       -Vagrant-Libvirt Plugin installed: $ vagrant plugin install vagrant-libvirt
#       -Start with \"vagrant up --provider=libvirt --no-parallel\n")

#  Libvirt Start Port: 8000
#  Libvirt Port Gap: 1000

#Set the default provider to libvirt in the case they forget --provider=libvirt or if someone destroys a machine it reverts to virtualbox
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'libvirt'

# Check required plugins
REQUIRED_PLUGINS_LIBVIRT = %w(vagrant-libvirt)
exit unless REQUIRED_PLUGINS_LIBVIRT.all? do |plugin|
  Vagrant.has_plugin?(plugin) || (
    puts "The #{plugin} plugin is required. Please install it with:"
    puts "$ vagrant plugin install #{plugin}"
    false
  )
end

Vagrant.require_version ">= 2.0.2"

# Fix for Older versions of Vagrant to Grab Images from the Correct Location
unless Vagrant::DEFAULT_SERVER_URL.frozen?
  Vagrant::DEFAULT_SERVER_URL.replace('https://vagrantcloud.com')
end

$script = <<-SCRIPT
function setup_ztp(){
    echo "### Disabling ZTP service..."
    systemctl stop ztp.service
    ztp -d 2>&1
    echo "### Resetting ZTP to work next boot..."
    ztp -R 2>&1
    ztp -i &> /dev/null

    if [ -e /tmp/cumulus-ztp ]; then
        echo "  ### Found ZTP Script, moving into preload directory... ###"
        mv /tmp/cumulus-ztp /var/lib/cumulus/ztp/cumulus-ztp
        chmod +x /var/lib/cumulus/ztp/cumulus-ztp
        ls -lha /var/lib/cumulus/ztp/cumulus-ztp
    fi
}

function disable_remap(){
    echo "### Disabling default remap on Cumulus VX..."
    mv -v /etc/hw_init.d/S10rename_eth_swp.sh /etc/S10rename_eth_swp.sh.backup &> /dev/null
}

function vagrant_user_nclu(){
    echo "### Giving Vagrant User Ability to Run NCLU Commands ###"
    adduser vagrant netedit
    adduser vagrant netshow
}

if grep -q -i 'cumulus' /etc/lsb-release &> /dev/null; then
    echo "### RUNNING CUMULUS EXTRA CONFIG ###"
    source /etc/lsb-release
    echo "  INFO: Detected Cumulus Linux v$DISTRIB_RELEASE Release"
    if [ -e /etc/app-release ]; then
        echo "  INFO: Detected NetQ TS Server"
        source /etc/app-release
        echo "  INFO: Running NetQ TS Appliance Version $APPLIANCE_VERSION"
        disable_remap
        vagrant_user_nclu
        setup_ztp
    else
        if [[ $DISTRIB_RELEASE =~ ^2.* ]]; then
            echo "  INFO: Detected a 2.5.x Based Release"
            echo "     2.5.x: adding fake cl-acltool..."
            echo -e "#!/bin/bash\nexit 0" > /usr/bin/cl-acltool
            chmod 755 /usr/bin/cl-acltool
            echo "     2.5.x: adding fake cl-license..."
            echo -e "#!/bin/bash\nexit 0" > /usr/bin/cl-license
            chmod 755 /usr/bin/cl-license
            echo "     2.5.x: Disabling default remap on Cumulus VX..."
            mv -v /etc/init.d/rename_eth_swp /etc/init.d/rename_eth_swp.backup
        elif [[ $DISTRIB_RELEASE =~ ^3.* ]]; then
            echo "  INFO: Detected a 3.x Based Release ($DISTRIB_RELEASE)"
            echo "### Disabling default remap on Cumulus VX..."
            mv -v /etc/hw_init.d/S10rename_eth_swp.sh /etc/S10rename_eth_swp.sh.backup &> /dev/null
            if [[ $DISTRIB_RELEASE =~ ^3.[1-9].* ]]; then
                echo "### Fixing ONIE DHCP to avoid Vagrant Interface ###"
                echo "     Note: Installing from ONIE will undo these changes."
                mkdir /tmp/foo
                mount LABEL=ONIE-BOOT /tmp/foo
                sed -i 's/eth0/eth1/g' /tmp/foo/grub/grub.cfg
                sed -i 's/eth0/eth1/g' /tmp/foo/onie/grub/grub-extra.cfg
                umount /tmp/foo
            fi
            if [[ $DISTRIB_RELEASE =~ ^3.2.* ]]; then
                if [[ $(grep "vagrant" /etc/netd.conf | wc -l ) == 0 ]]; then
                    echo "### Giving Vagrant User Ability to Run NCLU Commands ###"
                    sed -i 's/users_with_edit = root, cumulus/users_with_edit = root, cumulus, vagrant/g' /etc/netd.conf
                    sed -i 's/users_with_show = root, cumulus/users_with_show = root, cumulus, vagrant/g' /etc/netd.conf
                fi
            elif [[ $DISTRIB_RELEASE =~ ^3.[3-9].* ]]; then
                vagrant_user_nclu
            fi
            setup_ztp
        elif [[ $DISTRIB_RELEASE =~ ^4.* ]]; then
            echo "  INFO: Detected a 4.x Based Release ($DISTRIB_RELEASE)"
            disable_remap
            vagrant_user_nclu
            setup_ztp
        fi
    fi
fi
echo "### DONE ###"
echo "### Rebooting Device to Apply Remap..."
nohup bash -c 'sleep 10; shutdown now -r "Rebooting to Remap Interfaces"' &
SCRIPT

Vagrant.configure("2") do |config|
  config.ssh.forward_agent = true

  wbid = 1
  offset = wbid * 100


  config.vm.provider :libvirt do |domain|
    domain.management_network_address = "10.255.#{wbid}.0/24"
    domain.management_network_name = "wbr#{wbid}"
    # increase nic adapter count to be greater than 8 for all VMs.
    domain.nic_adapter_count = 130
  end




  ##### DEFINE VM for oob-mgmt-server #####
  config.vm.define "oob-mgmt-server" do |device|
    
    device.vm.hostname = "oob-mgmt-server" 
    
    device.vm.box = "generic/ubuntu1804"

    device.vm.provider :libvirt do |v|
      v.memory = 1024

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth1 --> oob-mgmt-switch:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:e2",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9114 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8114 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    # Copy over DHCP files and MGMT Network Files
    device.vm.provision "file", source: "./helper_scripts/auto_mgmt_network/dhcpd.conf", destination: "~/dhcpd.conf"
    device.vm.provision "file", source: "./helper_scripts/auto_mgmt_network/dhcpd.hosts", destination: "~/dhcpd.hosts"
    device.vm.provision "file", source: "./helper_scripts/auto_mgmt_network/hosts", destination: "~/hosts"
    device.vm.provision "file", source: "./helper_scripts/auto_mgmt_network/ansible_hostfile", destination: "~/ansible_hostfile"
    device.vm.provision "file", source: "./helper_scripts/auto_mgmt_network/cumulus-ztp", destination: "~/cumulus-ztp"
    device.vm.provision "file", source: "./helper_scripts/auto_mgmt_network/ssh_config", destination: "~/ssh_config"

    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/auto_mgmt_network/OOB_Server_Config_auto_mgmt.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:e2 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:e2", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for oob-mgmt-switch #####
  config.vm.define "oob-mgmt-switch" do |device|
    
    device.vm.hostname = "oob-mgmt-switch" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> NOTHING:NOTHING
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:3f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8161 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9161 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> oob-mgmt-server:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:e1",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8114 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9114 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc1-server4:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:e3",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8115 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9115 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp3 --> dc2-spine2:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:e5",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8116 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9116 + offset }",
            :libvirt__iface_name => 'swp3',
            auto_config: false
      # link for swp4 --> dc1-server6:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:e7",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8117 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9117 + offset }",
            :libvirt__iface_name => 'swp4',
            auto_config: false
      # link for swp5 --> dc2-server5:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:e9",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8118 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9118 + offset }",
            :libvirt__iface_name => 'swp5',
            auto_config: false
      # link for swp6 --> dc1-leaf8:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:eb",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8119 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9119 + offset }",
            :libvirt__iface_name => 'swp6',
            auto_config: false
      # link for swp7 --> dc2-fw1:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:ed",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8120 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9120 + offset }",
            :libvirt__iface_name => 'swp7',
            auto_config: false
      # link for swp8 --> dc1-server1:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:ef",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8121 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9121 + offset }",
            :libvirt__iface_name => 'swp8',
            auto_config: false
      # link for swp9 --> dc2-server2:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:f1",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8122 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9122 + offset }",
            :libvirt__iface_name => 'swp9',
            auto_config: false
      # link for swp10 --> dc1-spine2:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:f3",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8123 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9123 + offset }",
            :libvirt__iface_name => 'swp10',
            auto_config: false
      # link for swp11 --> dc1-server2:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:f5",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8124 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9124 + offset }",
            :libvirt__iface_name => 'swp11',
            auto_config: false
      # link for swp12 --> dc1-leaf10:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:f7",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8125 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9125 + offset }",
            :libvirt__iface_name => 'swp12',
            auto_config: false
      # link for swp13 --> dc1-leaf3:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:f9",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8126 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9126 + offset }",
            :libvirt__iface_name => 'swp13',
            auto_config: false
      # link for swp14 --> dc1-leaf1:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:fb",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8127 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9127 + offset }",
            :libvirt__iface_name => 'swp14',
            auto_config: false
      # link for swp15 --> dc1-fw1:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:fd",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8128 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9128 + offset }",
            :libvirt__iface_name => 'swp15',
            auto_config: false
      # link for swp16 --> dc1-spine1:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:ff",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8129 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9129 + offset }",
            :libvirt__iface_name => 'swp16',
            auto_config: false
      # link for swp17 --> dc2-server1:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:01",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8130 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9130 + offset }",
            :libvirt__iface_name => 'swp17',
            auto_config: false
      # link for swp18 --> dc1-leaf6:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:03",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8131 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9131 + offset }",
            :libvirt__iface_name => 'swp18',
            auto_config: false
      # link for swp19 --> dc2-server6:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:05",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8132 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9132 + offset }",
            :libvirt__iface_name => 'swp19',
            auto_config: false
      # link for swp20 --> dc2-leaf7:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:07",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8133 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9133 + offset }",
            :libvirt__iface_name => 'swp20',
            auto_config: false
      # link for swp21 --> dc2-server9:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:09",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8134 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9134 + offset }",
            :libvirt__iface_name => 'swp21',
            auto_config: false
      # link for swp22 --> dc1-leaf7:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:0b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8135 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9135 + offset }",
            :libvirt__iface_name => 'swp22',
            auto_config: false
      # link for swp23 --> dc1-server7:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:0d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8136 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9136 + offset }",
            :libvirt__iface_name => 'swp23',
            auto_config: false
      # link for swp24 --> dc2-server8:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:0f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8137 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9137 + offset }",
            :libvirt__iface_name => 'swp24',
            auto_config: false
      # link for swp25 --> dc1-server9:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:11",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8138 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9138 + offset }",
            :libvirt__iface_name => 'swp25',
            auto_config: false
      # link for swp26 --> dc2-spine1:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:13",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8139 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9139 + offset }",
            :libvirt__iface_name => 'swp26',
            auto_config: false
      # link for swp27 --> dc1-server8:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:15",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8140 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9140 + offset }",
            :libvirt__iface_name => 'swp27',
            auto_config: false
      # link for swp28 --> dc1-server10:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:17",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8141 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9141 + offset }",
            :libvirt__iface_name => 'swp28',
            auto_config: false
      # link for swp29 --> dc2-server10:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:19",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8142 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9142 + offset }",
            :libvirt__iface_name => 'swp29',
            auto_config: false
      # link for swp30 --> dc1-leaf9:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:1b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8143 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9143 + offset }",
            :libvirt__iface_name => 'swp30',
            auto_config: false
      # link for swp31 --> dc1-leaf2:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:1d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8144 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9144 + offset }",
            :libvirt__iface_name => 'swp31',
            auto_config: false
      # link for swp32 --> dc2-server4:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:1f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8145 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9145 + offset }",
            :libvirt__iface_name => 'swp32',
            auto_config: false
      # link for swp33 --> dc1-leaf5:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:21",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8146 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9146 + offset }",
            :libvirt__iface_name => 'swp33',
            auto_config: false
      # link for swp34 --> dc2-leaf1:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:23",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8147 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9147 + offset }",
            :libvirt__iface_name => 'swp34',
            auto_config: false
      # link for swp35 --> dc2-leaf5:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:25",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8148 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9148 + offset }",
            :libvirt__iface_name => 'swp35',
            auto_config: false
      # link for swp36 --> dc2-leaf10:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:27",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8149 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9149 + offset }",
            :libvirt__iface_name => 'swp36',
            auto_config: false
      # link for swp37 --> dc2-leaf3:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:29",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8150 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9150 + offset }",
            :libvirt__iface_name => 'swp37',
            auto_config: false
      # link for swp38 --> dc1-leaf4:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:2b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8151 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9151 + offset }",
            :libvirt__iface_name => 'swp38',
            auto_config: false
      # link for swp39 --> dc2-leaf2:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:2d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8152 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9152 + offset }",
            :libvirt__iface_name => 'swp39',
            auto_config: false
      # link for swp40 --> dc1-server3:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:2f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8153 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9153 + offset }",
            :libvirt__iface_name => 'swp40',
            auto_config: false
      # link for swp41 --> dc2-leaf8:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:31",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8154 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9154 + offset }",
            :libvirt__iface_name => 'swp41',
            auto_config: false
      # link for swp42 --> dc2-leaf6:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:33",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8155 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9155 + offset }",
            :libvirt__iface_name => 'swp42',
            auto_config: false
      # link for swp43 --> dc1-server5:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:35",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8156 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9156 + offset }",
            :libvirt__iface_name => 'swp43',
            auto_config: false
      # link for swp44 --> dc2-leaf4:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:37",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8157 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9157 + offset }",
            :libvirt__iface_name => 'swp44',
            auto_config: false
      # link for swp45 --> dc2-leaf9:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:39",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8158 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9158 + offset }",
            :libvirt__iface_name => 'swp45',
            auto_config: false
      # link for swp46 --> dc2-server7:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:3b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8159 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9159 + offset }",
            :libvirt__iface_name => 'swp46',
            auto_config: false
      # link for swp47 --> dc2-server3:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:3d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8160 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9160 + offset }",
            :libvirt__iface_name => 'swp47',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


      # Transfer Bridge File
      device.vm.provision "file", source: "./helper_scripts/auto_mgmt_network/bridge-untagged", destination: "~/bridge-untagged"

    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/oob_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:3f --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:3f", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:e1 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:e1", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:e3 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:e3", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:e5 --> swp3"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:e5", NAME="swp3", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:e7 --> swp4"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:e7", NAME="swp4", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:e9 --> swp5"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:e9", NAME="swp5", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:eb --> swp6"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:eb", NAME="swp6", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:ed --> swp7"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:ed", NAME="swp7", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:ef --> swp8"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:ef", NAME="swp8", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:f1 --> swp9"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:f1", NAME="swp9", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:f3 --> swp10"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:f3", NAME="swp10", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:f5 --> swp11"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:f5", NAME="swp11", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:f7 --> swp12"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:f7", NAME="swp12", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:f9 --> swp13"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:f9", NAME="swp13", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:fb --> swp14"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:fb", NAME="swp14", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:fd --> swp15"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:fd", NAME="swp15", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:ff --> swp16"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:ff", NAME="swp16", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:01 --> swp17"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:01", NAME="swp17", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:03 --> swp18"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:03", NAME="swp18", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:05 --> swp19"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:05", NAME="swp19", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:07 --> swp20"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:07", NAME="swp20", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:09 --> swp21"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:09", NAME="swp21", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:0b --> swp22"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:0b", NAME="swp22", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:0d --> swp23"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:0d", NAME="swp23", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:0f --> swp24"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:0f", NAME="swp24", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:11 --> swp25"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:11", NAME="swp25", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:13 --> swp26"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:13", NAME="swp26", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:15 --> swp27"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:15", NAME="swp27", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:17 --> swp28"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:17", NAME="swp28", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:19 --> swp29"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:19", NAME="swp29", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:1b --> swp30"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:1b", NAME="swp30", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:1d --> swp31"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:1d", NAME="swp31", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:1f --> swp32"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:1f", NAME="swp32", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:21 --> swp33"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:21", NAME="swp33", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:23 --> swp34"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:23", NAME="swp34", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:25 --> swp35"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:25", NAME="swp35", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:27 --> swp36"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:27", NAME="swp36", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:29 --> swp37"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:29", NAME="swp37", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:2b --> swp38"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:2b", NAME="swp38", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:2d --> swp39"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:2d", NAME="swp39", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:2f --> swp40"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:2f", NAME="swp40", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:31 --> swp41"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:31", NAME="swp41", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:33 --> swp42"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:33", NAME="swp42", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:35 --> swp43"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:35", NAME="swp43", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:37 --> swp44"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:37", NAME="swp44", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:39 --> swp45"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:39", NAME="swp45", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:3b --> swp46"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:3b", NAME="swp46", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:3d --> swp47"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:3d", NAME="swp47", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-spine2 #####
  config.vm.define "dc2-spine2" do |device|
    
    device.vm.hostname = "dc2-spine2" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp3
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:e6",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9116 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8116 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc2-leaf1:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:24",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9018 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8018 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc2-leaf2:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:50",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9040 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8040 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp3 --> dc2-leaf3:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:96",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9075 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8075 + offset }",
            :libvirt__iface_name => 'swp3',
            auto_config: false
      # link for swp4 --> dc2-leaf4:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:38",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9028 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8028 + offset }",
            :libvirt__iface_name => 'swp4',
            auto_config: false
      # link for swp5 --> dc2-leaf5:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:2a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9021 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8021 + offset }",
            :libvirt__iface_name => 'swp5',
            auto_config: false
      # link for swp6 --> dc2-leaf6:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:36",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9027 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8027 + offset }",
            :libvirt__iface_name => 'swp6',
            auto_config: false
      # link for swp7 --> dc2-leaf7:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:e0",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9112 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8112 + offset }",
            :libvirt__iface_name => 'swp7',
            auto_config: false
      # link for swp8 --> dc2-leaf8:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:90",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9072 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8072 + offset }",
            :libvirt__iface_name => 'swp8',
            auto_config: false
      # link for swp9 --> dc2-leaf9:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:9c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9078 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8078 + offset }",
            :libvirt__iface_name => 'swp9',
            auto_config: false
      # link for swp10 --> dc2-leaf10:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:42",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9033 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8033 + offset }",
            :libvirt__iface_name => 'swp10',
            auto_config: false
      # link for swp21 --> dc2-fw1:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:c3",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8098 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9098 + offset }",
            :libvirt__iface_name => 'swp21',
            auto_config: false
      # link for swp49 --> dc2-spine1:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:b8",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9092 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8092 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc2-spine1:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:40",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9032 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8032 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc1-spine2:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:2b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8022 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9022 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc1-spine2:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:20",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9016 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8016 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:e6 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:e6", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:24 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:24", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:50 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:50", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:96 --> swp3"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:96", NAME="swp3", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:38 --> swp4"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:38", NAME="swp4", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:2a --> swp5"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:2a", NAME="swp5", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:36 --> swp6"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:36", NAME="swp6", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:e0 --> swp7"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:e0", NAME="swp7", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:90 --> swp8"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:90", NAME="swp8", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:9c --> swp9"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:9c", NAME="swp9", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:42 --> swp10"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:42", NAME="swp10", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:c3 --> swp21"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:c3", NAME="swp21", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:b8 --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:b8", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:40 --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:40", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:2b --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:2b", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:20 --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:20", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-spine2 #####
  config.vm.define "dc1-spine2" do |device|
    
    device.vm.hostname = "dc1-spine2" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp10
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:f4",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9123 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8123 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc1-leaf1:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:ce",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9103 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8103 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc1-leaf2:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:26",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9019 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8019 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp3 --> dc1-leaf3:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:48",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9036 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8036 + offset }",
            :libvirt__iface_name => 'swp3',
            auto_config: false
      # link for swp4 --> dc1-leaf4:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:d8",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9108 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8108 + offset }",
            :libvirt__iface_name => 'swp4',
            auto_config: false
      # link for swp5 --> dc1-leaf5:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:60",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9048 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8048 + offset }",
            :libvirt__iface_name => 'swp5',
            auto_config: false
      # link for swp6 --> dc1-leaf6:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:30",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9024 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8024 + offset }",
            :libvirt__iface_name => 'swp6',
            auto_config: false
      # link for swp7 --> dc1-leaf7:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:68",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9052 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8052 + offset }",
            :libvirt__iface_name => 'swp7',
            auto_config: false
      # link for swp8 --> dc1-leaf8:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:0e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9007 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8007 + offset }",
            :libvirt__iface_name => 'swp8',
            auto_config: false
      # link for swp9 --> dc1-leaf9:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:08",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9004 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8004 + offset }",
            :libvirt__iface_name => 'swp9',
            auto_config: false
      # link for swp10 --> dc1-leaf10:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:80",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9064 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8064 + offset }",
            :libvirt__iface_name => 'swp10',
            auto_config: false
      # link for swp21 --> dc1-fw1:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:ad",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8087 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9087 + offset }",
            :libvirt__iface_name => 'swp21',
            auto_config: false
      # link for swp49 --> dc1-spine1:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:7e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9063 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8063 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc1-spine1:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:b2",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9089 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8089 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc2-spine2:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:2c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9022 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8022 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc2-spine2:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:1f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8016 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9016 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:f4 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:f4", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:ce --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:ce", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:26 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:26", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:48 --> swp3"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:48", NAME="swp3", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:d8 --> swp4"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:d8", NAME="swp4", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:60 --> swp5"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:60", NAME="swp5", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:30 --> swp6"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:30", NAME="swp6", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:68 --> swp7"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:68", NAME="swp7", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0e --> swp8"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0e", NAME="swp8", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:08 --> swp9"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:08", NAME="swp9", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:80 --> swp10"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:80", NAME="swp10", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:ad --> swp21"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:ad", NAME="swp21", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:7e --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:7e", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:b2 --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:b2", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:2c --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:2c", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1f --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1f", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-spine1 #####
  config.vm.define "dc1-spine1" do |device|
    
    device.vm.hostname = "dc1-spine1" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp16
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:00",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9129 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8129 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc1-leaf1:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:88",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9068 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8068 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc1-leaf2:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:b6",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9091 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8091 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp3 --> dc1-leaf3:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:5a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9045 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8045 + offset }",
            :libvirt__iface_name => 'swp3',
            auto_config: false
      # link for swp4 --> dc1-leaf4:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:c0",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9096 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8096 + offset }",
            :libvirt__iface_name => 'swp4',
            auto_config: false
      # link for swp5 --> dc1-leaf5:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:dc",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9110 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8110 + offset }",
            :libvirt__iface_name => 'swp5',
            auto_config: false
      # link for swp6 --> dc1-leaf6:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:28",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9020 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8020 + offset }",
            :libvirt__iface_name => 'swp6',
            auto_config: false
      # link for swp7 --> dc1-leaf7:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:22",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9017 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8017 + offset }",
            :libvirt__iface_name => 'swp7',
            auto_config: false
      # link for swp8 --> dc1-leaf8:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:18",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9012 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8012 + offset }",
            :libvirt__iface_name => 'swp8',
            auto_config: false
      # link for swp9 --> dc1-leaf9:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:02",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9001 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8001 + offset }",
            :libvirt__iface_name => 'swp9',
            auto_config: false
      # link for swp10 --> dc1-leaf10:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:86",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9067 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8067 + offset }",
            :libvirt__iface_name => 'swp10',
            auto_config: false
      # link for swp21 --> dc1-fw1:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:65",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8051 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9051 + offset }",
            :libvirt__iface_name => 'swp21',
            auto_config: false
      # link for swp49 --> dc1-spine2:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:7d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8063 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9063 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc1-spine2:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:b1",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8089 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9089 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc2-spine1:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:04",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9002 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8002 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc2-spine1:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:9f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8080 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9080 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:00 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:00", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:88 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:88", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:b6 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:b6", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:5a --> swp3"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:5a", NAME="swp3", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:c0 --> swp4"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:c0", NAME="swp4", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:dc --> swp5"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:dc", NAME="swp5", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:28 --> swp6"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:28", NAME="swp6", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:22 --> swp7"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:22", NAME="swp7", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:18 --> swp8"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:18", NAME="swp8", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:02 --> swp9"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:02", NAME="swp9", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:86 --> swp10"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:86", NAME="swp10", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:65 --> swp21"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:65", NAME="swp21", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:7d --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:7d", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:b1 --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:b1", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:04 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:04", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:9f --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:9f", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-spine1 #####
  config.vm.define "dc2-spine1" do |device|
    
    device.vm.hostname = "dc2-spine1" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp26
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:14",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9139 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8139 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc2-leaf1:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:58",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9044 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8044 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc2-leaf2:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:ca",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9101 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8101 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp3 --> dc2-leaf3:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:8e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9071 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8071 + offset }",
            :libvirt__iface_name => 'swp3',
            auto_config: false
      # link for swp4 --> dc2-leaf4:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:72",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9057 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8057 + offset }",
            :libvirt__iface_name => 'swp4',
            auto_config: false
      # link for swp5 --> dc2-leaf5:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:a6",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9083 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8083 + offset }",
            :libvirt__iface_name => 'swp5',
            auto_config: false
      # link for swp6 --> dc2-leaf6:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:92",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9073 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8073 + offset }",
            :libvirt__iface_name => 'swp6',
            auto_config: false
      # link for swp7 --> dc2-leaf7:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:94",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9074 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8074 + offset }",
            :libvirt__iface_name => 'swp7',
            auto_config: false
      # link for swp8 --> dc2-leaf8:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:4e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9039 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8039 + offset }",
            :libvirt__iface_name => 'swp8',
            auto_config: false
      # link for swp9 --> dc2-leaf9:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:d4",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9106 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8106 + offset }",
            :libvirt__iface_name => 'swp9',
            auto_config: false
      # link for swp10 --> dc2-leaf10:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:9a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9077 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8077 + offset }",
            :libvirt__iface_name => 'swp10',
            auto_config: false
      # link for swp21 --> dc2-fw1:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:5d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8047 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9047 + offset }",
            :libvirt__iface_name => 'swp21',
            auto_config: false
      # link for swp49 --> dc2-spine2:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:b7",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8092 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9092 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc2-spine2:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:3f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8032 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9032 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc1-spine1:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:03",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8002 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9002 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc1-spine1:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:a0",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9080 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8080 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:14 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:14", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:58 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:58", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:ca --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:ca", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:8e --> swp3"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:8e", NAME="swp3", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:72 --> swp4"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:72", NAME="swp4", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:a6 --> swp5"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:a6", NAME="swp5", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:92 --> swp6"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:92", NAME="swp6", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:94 --> swp7"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:94", NAME="swp7", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:4e --> swp8"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:4e", NAME="swp8", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:d4 --> swp9"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:d4", NAME="swp9", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:9a --> swp10"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:9a", NAME="swp10", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:5d --> swp21"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:5d", NAME="swp21", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:b7 --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:b7", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:3f --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:3f", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:03 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:03", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:a0 --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:a0", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-leaf8 #####
  config.vm.define "dc1-leaf8" do |device|
    
    device.vm.hostname = "dc1-leaf8" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp6
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:ec",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9119 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8119 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc1-server7:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:32",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9025 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8025 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc1-server8:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:da",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9109 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8109 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc1-leaf7:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:0a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9005 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8005 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc1-leaf7:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:c6",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9099 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8099 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc1-spine1:swp8
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:17",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8012 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9012 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc1-spine2:swp8
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:0d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8007 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9007 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:ec --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:ec", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:32 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:32", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:da --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:da", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0a --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0a", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:c6 --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:c6", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:17 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:17", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0d --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0d", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-leaf10 #####
  config.vm.define "dc1-leaf10" do |device|
    
    device.vm.hostname = "dc1-leaf10" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp12
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:f8",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9125 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8125 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc1-server9:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:2e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9023 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8023 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc1-server10:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:78",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9060 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8060 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc1-leaf9:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:5c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9046 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8046 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc1-leaf9:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:10",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9008 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8008 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc1-spine1:swp10
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:85",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8067 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9067 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc1-spine2:swp10
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:7f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8064 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9064 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:f8 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:f8", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:2e --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:2e", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:78 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:78", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:5c --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:5c", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:10 --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:10", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:85 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:85", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:7f --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:7f", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-leaf3 #####
  config.vm.define "dc1-leaf3" do |device|
    
    device.vm.hostname = "dc1-leaf3" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp13
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:fa",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9126 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8126 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc1-server3:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:c8",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9100 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8100 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc1-server4:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:d2",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9105 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8105 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc1-leaf4:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:33",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8026 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9026 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc1-leaf4:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:9d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8079 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9079 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc1-spine1:swp3
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:59",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8045 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9045 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc1-spine2:swp3
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:47",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8036 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9036 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:fa --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:fa", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:c8 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:c8", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:d2 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:d2", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:33 --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:33", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:9d --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:9d", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:59 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:59", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:47 --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:47", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-leaf1 #####
  config.vm.define "dc1-leaf1" do |device|
    
    device.vm.hostname = "dc1-leaf1" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp14
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:fc",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9127 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8127 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc1-server1:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:4a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9037 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8037 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc1-server2:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:82",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9065 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8065 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc1-leaf2:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:ab",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8086 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9086 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc1-leaf2:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:1d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8015 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9015 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc1-spine1:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:87",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8068 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9068 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc1-spine2:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:cd",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8103 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9103 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:fc --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:fc", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:4a --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:4a", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:82 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:82", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:ab --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:ab", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1d --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1d", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:87 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:87", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:cd --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:cd", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-leaf6 #####
  config.vm.define "dc1-leaf6" do |device|
    
    device.vm.hostname = "dc1-leaf6" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp18
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:04",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9131 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8131 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc1-server5:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:b4",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9090 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8090 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc1-server6:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:d6",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9107 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8107 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc1-leaf5:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:12",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9009 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8009 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc1-leaf5:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:4c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9038 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8038 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc1-spine1:swp6
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:27",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8020 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9020 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc1-spine2:swp6
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:2f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8024 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9024 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:04 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:04", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:b4 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:b4", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:d6 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:d6", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:12 --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:12", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:4c --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:4c", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:27 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:27", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:2f --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:2f", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-leaf7 #####
  config.vm.define "dc2-leaf7" do |device|
    
    device.vm.hostname = "dc2-leaf7" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp20
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:08",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9133 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8133 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc2-server7:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:3e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9031 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8031 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc2-server8:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:a2",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9081 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8081 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc2-leaf8:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:6b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8054 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9054 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc2-leaf8:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:1b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8014 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9014 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc2-spine1:swp7
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:93",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8074 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9074 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc2-spine2:swp7
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:df",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8112 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9112 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:08 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:08", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:3e --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:3e", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:a2 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:a2", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:6b --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:6b", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1b --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1b", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:93 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:93", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:df --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:df", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-leaf7 #####
  config.vm.define "dc1-leaf7" do |device|
    
    device.vm.hostname = "dc1-leaf7" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp22
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:0c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9135 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8135 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc1-server7:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:d0",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9104 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8104 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc1-server8:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:46",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9035 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8035 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc1-leaf8:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:09",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8005 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9005 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc1-leaf8:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:c5",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8099 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9099 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc1-spine1:swp7
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:21",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8017 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9017 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc1-spine2:swp7
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:67",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8052 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9052 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:0c --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:0c", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:d0 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:d0", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:46 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:46", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:09 --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:09", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:c5 --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:c5", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:21 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:21", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:67 --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:67", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-leaf9 #####
  config.vm.define "dc1-leaf9" do |device|
    
    device.vm.hostname = "dc1-leaf9" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp30
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:1c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9143 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8143 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc1-server9:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:7c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9062 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8062 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc1-server10:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:de",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9111 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8111 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc1-leaf10:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:5b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8046 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9046 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc1-leaf10:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:0f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8008 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9008 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc1-spine1:swp9
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:01",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8001 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9001 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc1-spine2:swp9
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:07",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8004 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9004 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:1c --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:1c", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:7c --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:7c", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:de --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:de", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:5b --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:5b", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0f --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0f", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:01 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:01", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:07 --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:07", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-leaf2 #####
  config.vm.define "dc1-leaf2" do |device|
    
    device.vm.hostname = "dc1-leaf2" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp31
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:1e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9144 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8144 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc1-server1:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:44",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9034 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8034 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc1-server2:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:8a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9069 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8069 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc1-leaf1:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:ac",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9086 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8086 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc1-leaf1:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:1e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9015 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8015 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc1-spine1:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:b5",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8091 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9091 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc1-spine2:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:25",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8019 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9019 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:1e --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:1e", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:44 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:44", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:8a --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:8a", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:ac --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:ac", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1e --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1e", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:b5 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:b5", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:25 --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:25", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-leaf5 #####
  config.vm.define "dc1-leaf5" do |device|
    
    device.vm.hostname = "dc1-leaf5" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp33
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:22",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9146 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8146 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc1-server5:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:1a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9013 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8013 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc1-server6:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:a4",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9082 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8082 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc1-leaf6:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:11",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8009 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9009 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc1-leaf6:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:4b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8038 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9038 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc1-spine1:swp5
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:db",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8110 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9110 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc1-spine2:swp5
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:5f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8048 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9048 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:22 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:22", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1a --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1a", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:a4 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:a4", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:11 --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:11", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:4b --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:4b", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:db --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:db", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:5f --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:5f", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-leaf1 #####
  config.vm.define "dc2-leaf1" do |device|
    
    device.vm.hostname = "dc2-leaf1" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp34
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:24",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9147 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8147 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc2-server1:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:c2",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9097 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8097 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc2-server2:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:06",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9003 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8003 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc2-leaf2:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:53",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8042 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9042 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc2-leaf2:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:b9",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8093 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9093 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc2-spine1:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:57",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8044 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9044 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc2-spine2:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:23",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8018 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9018 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:24 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:24", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:c2 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:c2", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:06 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:06", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:53 --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:53", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:b9 --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:b9", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:57 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:57", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:23 --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:23", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-leaf5 #####
  config.vm.define "dc2-leaf5" do |device|
    
    device.vm.hostname = "dc2-leaf5" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp35
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:26",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9148 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8148 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc2-server5:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:64",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9050 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8050 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc2-server6:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:76",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9059 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8059 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc2-leaf6:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:73",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8058 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9058 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc2-leaf6:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:69",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8053 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9053 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc2-spine1:swp5
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:a5",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8083 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9083 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc2-spine2:swp5
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:29",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8021 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9021 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:26 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:26", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:64 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:64", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:76 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:76", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:73 --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:73", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:69 --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:69", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:a5 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:a5", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:29 --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:29", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-leaf10 #####
  config.vm.define "dc2-leaf10" do |device|
    
    device.vm.hostname = "dc2-leaf10" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp36
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:28",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9149 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8149 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc2-server9:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:6e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9055 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8055 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc2-server10:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:7a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9061 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8061 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc2-leaf9:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:62",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9049 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8049 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc2-leaf9:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:0c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9006 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8006 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc2-spine1:swp10
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:99",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8077 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9077 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc2-spine2:swp10
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:41",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8033 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9033 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:28 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:28", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:6e --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:6e", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:7a --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:7a", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:62 --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:62", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0c --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0c", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:99 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:99", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:41 --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:41", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-leaf3 #####
  config.vm.define "dc2-leaf3" do |device|
    
    device.vm.hostname = "dc2-leaf3" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp37
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:2a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9150 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8150 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc2-server3:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:cc",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9102 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8102 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc2-server4:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:8c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9070 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8070 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc2-leaf4:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:97",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8076 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9076 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc2-leaf4:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:83",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8066 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9066 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc2-spine1:swp3
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:8d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8071 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9071 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc2-spine2:swp3
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:95",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8075 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9075 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:2a --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:2a", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:cc --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:cc", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:8c --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:8c", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:97 --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:97", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:83 --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:83", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:8d --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:8d", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:95 --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:95", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-leaf4 #####
  config.vm.define "dc1-leaf4" do |device|
    
    device.vm.hostname = "dc1-leaf4" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp38
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:2c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9151 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8151 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc1-server3:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:52",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9041 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8041 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc1-server4:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:3c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9030 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8030 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc1-leaf3:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:34",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9026 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8026 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc1-leaf3:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:9e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9079 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8079 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc1-spine1:swp4
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:bf",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8096 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9096 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc1-spine2:swp4
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:d7",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8108 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9108 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:2c --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:2c", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:52 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:52", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:3c --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:3c", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:34 --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:34", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:9e --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:9e", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:bf --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:bf", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:d7 --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:d7", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-leaf2 #####
  config.vm.define "dc2-leaf2" do |device|
    
    device.vm.hostname = "dc2-leaf2" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp39
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:2e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9152 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8152 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc2-server1:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:70",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9056 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8056 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc2-server2:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:aa",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9085 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8085 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc2-leaf1:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:54",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9042 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8042 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc2-leaf1:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:ba",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9093 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8093 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc2-spine1:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:c9",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8101 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9101 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc2-spine2:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:4f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8040 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9040 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:2e --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:2e", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:70 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:70", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:aa --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:aa", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:54 --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:54", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:ba --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:ba", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:c9 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:c9", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:4f --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:4f", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-leaf8 #####
  config.vm.define "dc2-leaf8" do |device|
    
    device.vm.hostname = "dc2-leaf8" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp41
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:32",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9154 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8154 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc2-server7:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:be",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9095 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8095 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc2-server8:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:14",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9010 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8010 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc2-leaf7:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:6c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9054 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8054 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc2-leaf7:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:1c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9014 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8014 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc2-spine1:swp8
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:4d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8039 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9039 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc2-spine2:swp8
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:8f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8072 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9072 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:32 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:32", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:be --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:be", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:14 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:14", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:6c --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:6c", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1c --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1c", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:4d --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:4d", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:8f --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:8f", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-leaf6 #####
  config.vm.define "dc2-leaf6" do |device|
    
    device.vm.hostname = "dc2-leaf6" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp42
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:34",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9155 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8155 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc2-server5:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:16",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9011 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8011 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc2-server6:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:3a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9029 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8029 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc2-leaf5:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:74",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9058 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8058 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc2-leaf5:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:6a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9053 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8053 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc2-spine1:swp6
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:91",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8073 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9073 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc2-spine2:swp6
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:35",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8027 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9027 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:34 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:34", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:16 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:16", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:3a --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:3a", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:74 --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:74", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:6a --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:6a", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:91 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:91", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:35 --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:35", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-leaf4 #####
  config.vm.define "dc2-leaf4" do |device|
    
    device.vm.hostname = "dc2-leaf4" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp44
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:38",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9157 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8157 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc2-server3:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:a8",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9084 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8084 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc2-server4:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:56",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9043 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8043 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc2-leaf3:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:98",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9076 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8076 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc2-leaf3:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:84",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9066 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8066 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc2-spine1:swp4
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:71",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8057 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9057 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc2-spine2:swp4
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:37",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8028 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9028 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:38 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:38", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:a8 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:a8", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:56 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:56", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:98 --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:98", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:84 --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:84", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:71 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:71", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:37 --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:37", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-leaf9 #####
  config.vm.define "dc2-leaf9" do |device|
    
    device.vm.hostname = "dc2-leaf9" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 768

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp45
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:3a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9158 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8158 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> dc2-server9:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:b0",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9088 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8088 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> dc2-server10:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:bc",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9094 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8094 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp49 --> dc2-leaf10:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:61",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8049 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9049 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> dc2-leaf10:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:0b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8006 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9006 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> dc2-spine1:swp9
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:d3",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8106 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9106 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> dc2-spine2:swp9
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:9b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8078 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9078 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Copy over Topology.dot File
    device.vm.provision "file", source: "na.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:3a --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:3a", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:b0 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:b0", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:bc --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:bc", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:61 --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:61", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0b --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0b", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:d3 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:d3", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:9b --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:9b", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-server4 #####
  config.vm.define "dc1-server4" do |device|
    
    device.vm.hostname = "dc1-server4" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:e4",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9115 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8115 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc1-leaf3:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:d1",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8105 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9105 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc1-leaf4:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:3b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8030 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9030 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:e4 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:e4", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:d1 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:d1", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:3b --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:3b", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-server6 #####
  config.vm.define "dc1-server6" do |device|
    
    device.vm.hostname = "dc1-server6" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp4
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:e8",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9117 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8117 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc1-leaf5:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:a3",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8082 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9082 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc1-leaf6:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:d5",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8107 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9107 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:e8 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:e8", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:a3 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:a3", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:d5 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:d5", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-server5 #####
  config.vm.define "dc2-server5" do |device|
    
    device.vm.hostname = "dc2-server5" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp5
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:ea",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9118 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8118 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc2-leaf5:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:63",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8050 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9050 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc2-leaf6:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:15",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8011 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9011 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:ea --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:ea", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:63 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:63", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:15 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:15", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-fw1 #####
  config.vm.define "dc2-fw1" do |device|
    
    device.vm.hostname = "dc2-fw1" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp7
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:ee",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9120 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8120 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc2-spine1:swp21
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:5e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9047 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8047 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc2-spine2:swp21
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:c4",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9098 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8098 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:ee --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:ee", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:5e --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:5e", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:c4 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:c4", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-server1 #####
  config.vm.define "dc1-server1" do |device|
    
    device.vm.hostname = "dc1-server1" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp8
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:f0",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9121 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8121 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc1-leaf1:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:49",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8037 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9037 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc1-leaf2:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:43",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8034 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9034 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:f0 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:f0", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:49 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:49", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:43 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:43", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-server2 #####
  config.vm.define "dc2-server2" do |device|
    
    device.vm.hostname = "dc2-server2" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp9
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:f2",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9122 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8122 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc2-leaf1:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:05",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8003 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9003 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc2-leaf2:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:a9",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8085 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9085 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:f2 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:f2", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:05 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:05", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:a9 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:a9", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-server2 #####
  config.vm.define "dc1-server2" do |device|
    
    device.vm.hostname = "dc1-server2" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp11
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:f6",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9124 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8124 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc1-leaf1:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:81",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8065 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9065 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc1-leaf2:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:89",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8069 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9069 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:f6 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:f6", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:81 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:81", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:89 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:89", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-fw1 #####
  config.vm.define "dc1-fw1" do |device|
    
    device.vm.hostname = "dc1-fw1" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp15
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:fe",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9128 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8128 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc1-spine1:swp21
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:66",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9051 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8051 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc1-spine2:swp21
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:ae",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9087 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8087 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:fe --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:fe", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:66 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:66", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:ae --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:ae", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-server1 #####
  config.vm.define "dc2-server1" do |device|
    
    device.vm.hostname = "dc2-server1" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp17
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:02",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9130 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8130 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc2-leaf1:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:c1",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8097 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9097 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc2-leaf2:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:6f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8056 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9056 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:02 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:02", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:c1 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:c1", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:6f --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:6f", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-server6 #####
  config.vm.define "dc2-server6" do |device|
    
    device.vm.hostname = "dc2-server6" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp19
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:06",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9132 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8132 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc2-leaf5:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:75",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8059 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9059 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc2-leaf6:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:39",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8029 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9029 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:06 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:06", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:75 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:75", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:39 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:39", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-server9 #####
  config.vm.define "dc2-server9" do |device|
    
    device.vm.hostname = "dc2-server9" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp21
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:0a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9134 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8134 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc2-leaf9:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:af",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8088 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9088 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc2-leaf10:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:6d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8055 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9055 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:0a --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:0a", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:af --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:af", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:6d --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:6d", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-server7 #####
  config.vm.define "dc1-server7" do |device|
    
    device.vm.hostname = "dc1-server7" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp23
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:0e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9136 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8136 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc1-leaf7:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:cf",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8104 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9104 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc1-leaf8:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:31",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8025 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9025 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:0e --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:0e", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:cf --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:cf", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:31 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:31", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-server8 #####
  config.vm.define "dc2-server8" do |device|
    
    device.vm.hostname = "dc2-server8" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp24
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:10",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9137 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8137 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc2-leaf7:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:a1",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8081 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9081 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc2-leaf8:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:13",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8010 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9010 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:10 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:10", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:a1 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:a1", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:13 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:13", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-server9 #####
  config.vm.define "dc1-server9" do |device|
    
    device.vm.hostname = "dc1-server9" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp25
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:12",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9138 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8138 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc1-leaf9:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:7b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8062 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9062 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc1-leaf10:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:2d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8023 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9023 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:12 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:12", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:7b --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:7b", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:2d --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:2d", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-server8 #####
  config.vm.define "dc1-server8" do |device|
    
    device.vm.hostname = "dc1-server8" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp27
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:16",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9140 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8140 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc1-leaf7:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:45",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8035 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9035 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc1-leaf8:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:d9",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8109 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9109 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:16 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:16", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:45 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:45", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:d9 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:d9", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-server10 #####
  config.vm.define "dc1-server10" do |device|
    
    device.vm.hostname = "dc1-server10" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp28
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:18",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9141 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8141 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc1-leaf9:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:dd",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8111 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9111 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc1-leaf10:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:77",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8060 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9060 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:18 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:18", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:dd --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:dd", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:77 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:77", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-server10 #####
  config.vm.define "dc2-server10" do |device|
    
    device.vm.hostname = "dc2-server10" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp29
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:1a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9142 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8142 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc2-leaf9:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:bb",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8094 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9094 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc2-leaf10:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:79",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8061 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9061 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:1a --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:1a", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:bb --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:bb", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:79 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:79", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-server4 #####
  config.vm.define "dc2-server4" do |device|
    
    device.vm.hostname = "dc2-server4" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp32
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:20",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9145 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8145 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc2-leaf3:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:8b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8070 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9070 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc2-leaf4:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:55",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8043 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9043 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:20 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:20", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:8b --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:8b", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:55 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:55", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-server3 #####
  config.vm.define "dc1-server3" do |device|
    
    device.vm.hostname = "dc1-server3" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp40
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:30",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9153 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8153 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc1-leaf3:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:c7",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8100 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9100 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc1-leaf4:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:51",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8041 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9041 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:30 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:30", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:c7 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:c7", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:51 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:51", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc1-server5 #####
  config.vm.define "dc1-server5" do |device|
    
    device.vm.hostname = "dc1-server5" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp43
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:36",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9156 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8156 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc1-leaf5:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:19",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8013 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9013 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc1-leaf6:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:b3",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8090 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9090 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:36 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:36", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:19 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:19", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:b3 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:b3", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-server7 #####
  config.vm.define "dc2-server7" do |device|
    
    device.vm.hostname = "dc2-server7" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp46
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:3c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9159 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8159 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc2-leaf7:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:3d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8031 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9031 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc2-leaf8:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:bd",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8095 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9095 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:3c --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:3c", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:3d --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:3d", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:bd --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:bd", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for dc2-server3 #####
  config.vm.define "dc2-server3" do |device|
    
    device.vm.hostname = "dc2-server3" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp47
      device.vm.network "private_network",
            :mac => "44:38:39:00:01:3e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9160 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8160 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> dc2-leaf3:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:cb",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8102 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9102 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> dc2-leaf4:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:a7",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8084 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9084 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:01:3e --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:01:3e", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:cb --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:cb", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:a7 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:a7", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule



    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end



end
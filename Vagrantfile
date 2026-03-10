# to be able to configure hyper-v vm.
ENV['VAGRANT_EXPERIMENTAL'] = 'typed_triggers'

$domain = "example.com"
$domain_ip_address = "192.168.56.2"
$ums_ip_address = "192.168.56.3"

Vagrant.configure("2") do |config|
    config.vm.box = "windows-2022-uefi-amd64"
    config.vm.define "windows-domain-controller" do |dc|
        dc.vm.hostname = "dc"
        dc.vm.network "private_network", ip: $domain_ip_address, libvirt__forward_mode: "route", libvirt__dhcp_enabled: false
        dc.vm.provision "shell", path: "provision/ps.ps1", args: ["domain-controller.ps1", $domain]
        dc.vm.provision "shell", reboot: true
        dc.vm.provision "shell", path: "provision/ps.ps1", args: "domain-controller-wait-for-ready.ps1"
        dc.vm.provision "shell", path: "provision/ps.ps1", args: "set-vagrant-domain-admin.ps1"
        dc.vm.provision "shell", path: "provision/ps.ps1", args: "domain-controller-configure.ps1"
        dc.vm.provision "shell", inline: "$env:chocolateyVersion='2.5.0'; Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')", name: "Install Chocolatey"
        dc.vm.provision "shell", path: "provision/ps.ps1", args: "provision-base.ps1"
        dc.vm.provision "shell", reboot: true
        dc.vm.provision "shell", path: "provision/ps.ps1", args: "domain-controller-wait-for-ready.ps1"
        # TODO after https://github.com/FriedrichWeinmann/GPOTools/issues/5#issuecomment-781598022 is fixed use ps.ps1 to call provision-gpos.ps1.
        dc.vm.provision "shell", inline: "cd c:/vagrant/provision; ./provision-gpos.ps1"
        dc.vm.provision "shell", path: "provision/ps.ps1", args: "ad-explorer.ps1"
        dc.vm.provision "shell", path: "provision/ps.ps1", args: "ca.ps1"
        dc.vm.provision "shell", reboot: true
        dc.vm.provision "shell", path: "provision/ps.ps1", args: "provision-winrm-https-listener.ps1"
        dc.vm.provision "shell", path: "provision/ps.ps1", args: "provision-msys2.ps1"
        dc.vm.provision "shell", path: "provision/ps.ps1", args: "provision-firewall.ps1"
        dc.vm.provision "shell", path: "provision/ps.ps1", args: "summary.ps1"
    end

    config.vm.define "ums" do |ums|
        ums.vm.hostname = "ums"
        ums.vm.network "private_network", ip: $ums_ip_address, libvirt__forward_mode: "route", libvirt__dhcp_enabled: false
        ums.vm.provision "shell", path: "provision/ps.ps1", args: "sysprep.ps1", reboot: true
        ums.vm.provision "shell", path: "provision/ps.ps1", args: ["ums-join-domain.ps1", $domain, $domain_ip_address]
        ums.vm.provision "shell", reboot: true
    end

    # use the plaintext WinRM transport and force it to use basic authentication.
    # NB this is needed because the default negotiate transport stops working
    #    after the domain controller is installed.
    #    see https://groups.google.com/forum/#!topic/vagrant-up/sZantuCM0q4
    config.winrm.transport = :plaintext
    config.winrm.basic_auth_only = true

    config.vm.provider :libvirt do |lv, config|
        lv.loader = "/usr/share/edk2/ovmf/OVMF_CODE.fd"
        lv.machine_type = 'q35'
        lv.memory = 2048
        lv.cpus = 2
        lv.cpu_mode = 'host-passthrough'
        lv.keymap = 'pt'
        lv.input :type => "tablet", :bus => "virtio"

        # Enable Hyper-V enlightenments for performance and stability
        lv.features = ['acpi', 'apic', 'pae']
        lv.hyperv_feature :name => 'relaxed',   :state => 'on'
        lv.hyperv_feature :name => 'vapic',     :state => 'on'
        lv.hyperv_feature :name => 'spinlocks', :state => 'on', :retries => '8191'

        # Configure timers for Windows stability
        lv.clock_timer :name => 'hypervclock', :present => 'yes'
        lv.clock_timer :name => 'hpet', :present => 'yes'

        # replace the default synced_folder with something that works in the base box.
        # NB for some reason, this does not work when placed in the base box Vagrantfile.
        config.vm.synced_folder '.', '/vagrant', type: 'rsync', rsync__exclude: ['.git/', '.vagrant/', 'packer_cache/', '*.box', '*.iso', '*.log']
    end
end

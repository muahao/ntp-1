require 'spec_helper'

describe 'ntp::default' do
  let(:chef_run) { ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '16.04').converge('ntp::default') }

  it 'installs the ntp package' do
    expect(chef_run).to install_package('ntp')
  end

  context 'on a virtualized guest' do
    let(:chef_run) do
      runner = ChefSpec::SoloRunner.new
      runner.node.normal['virtualization']['role'] = 'guest'
      runner.converge('ntp::default')
    end

    it 'should disable tinker panic' do
      expect(chef_run.node['ntp']['tinker']['panic']).to eq(0)
    end
  end

  context 'the varlibdir directory' do
    let(:directory) { chef_run.directory('/var/lib/ntp') }

    it 'creates the directory' do
      expect(chef_run).to create_directory('/var/lib/ntp')
    end

    it 'is owned by ntp:ntp' do
      expect(directory.owner).to eq('ntp')
      expect(directory.group).to eq('ntp')
    end

    it 'has 0755 permissions' do
      expect(directory.mode).to eq('0755')
    end
  end

  context 'the statsdir directory' do
    let(:directory) { chef_run.directory('/var/log/ntpstats/') }

    it 'creates the directory' do
      expect(chef_run).to create_directory('/var/log/ntpstats/')
    end

    it 'is owned by ntp:ntp' do
      expect(directory.owner).to eq('ntp')
      expect(directory.group).to eq('ntp')
    end

    it 'has 0755 permissions' do
      expect(directory.mode).to eq('0755')
    end
  end

  context 'the leapfile' do
    let(:cookbook_file) { chef_run.cookbook_file('/etc/ntp.leapseconds') }

    it 'creates the cookbook_file' do
      expect(chef_run).to create_cookbook_file('/etc/ntp.leapseconds')
    end

    it 'is owned by ntp:ntp' do
      expect(cookbook_file.owner).to eq('root')
      expect(cookbook_file.group).to eq('root')
    end

    it 'has 0644 permissions' do
      expect(cookbook_file.mode).to eq('0644')
    end

    it 'notifies ntp service to restart' do
      resource = chef_run.cookbook_file(chef_run.node['ntp']['leapfile'])
      service = "service[#{chef_run.node['ntp']['service']}]"
      expect(resource).to notify(service).to(:restart).delayed
    end
  end

  context 'the ntp.conf' do
    let(:template) { chef_run.template('/etc/ntp.conf') }

    it 'creates the template' do
      expect(chef_run).to create_template('/etc/ntp.conf')
    end

    it 'has the chef marker and server entries' do
      expect(chef_run).to render_file('/etc/ntp.conf')
        .with_content('Auto-generated by Chef.')
      expect(chef_run).to render_file('/etc/ntp.conf')
        .with_content(
          'tinker panic 1000 allan 1500 dispersion 15 step 0.128 stepout 900'
        )
      expect(chef_run).to render_file('/etc/ntp.conf')
        .with_content(
          'server 0.pool.ntp.org iburst minpoll 6 maxpoll 10
restrict 0.pool.ntp.org nomodify notrap noquery'
        )
    end

    it 'is owned by ntp:ntp' do
      expect(template.owner).to eq('root')
      expect(template.group).to eq('root')
    end

    it 'has 0644 permissions' do
      expect(template.mode).to eq('0644')
    end
  end

  it 'does not execute the "Force sync system clock with ntp server" command' do
    expect(chef_run).not_to run_execute("ntpd -q -u #{chef_run.node['ntp']['var_owner']}")
  end

  it 'does not execute the "Force sync hardware clock with system clock" command' do
    expect(chef_run).not_to run_execute('hwclock --systohc')
  end

  it 'starts the ntp service' do
    expect(chef_run).to start_service('ntp')
  end

  it 'sets ntp to start on boot' do
    expect(chef_run).to enable_service('ntp')
  end

  context 'the sync_clock attribute is set' do
    let(:chef_run) do
      runner = ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '16.04')
      runner.node.normal['ntp']['sync_clock'] = true
      runner.converge('ntp::default')
    end

    it 'executes the "Force sync system clock with ntp server" command' do
      expect(chef_run).to run_execute("ntpd -q -u #{chef_run.node['ntp']['var_owner']}")
    end
  end

  context 'the sync_hw_clock attribute is set on a non-Windows OS' do
    let(:chef_run) do
      runner = ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '16.04')
      runner.node.normal['ntp']['sync_hw_clock'] = true
      runner.converge('ntp::default')
    end

    it 'executes the "Force sync hardware clock with system clock" command' do
      expect(chef_run).to run_execute('hwclock --systohc')
    end
  end

  context 'ntp["listen_network"] is set to "primary"' do
    let(:chef_run) do
      runner = ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '16.04')
      runner.node.normal['ntp']['listen_network'] = 'primary'
      runner.converge('ntp::default')
    end

    it 'expect ntp["listen"] to be equal node["ipaddress"]' do
      expect(chef_run.node['ntp']['listen']).to eq(chef_run.node['ipaddress'])
    end
  end

  context 'ntp["listen_network"] is set to a CIDR' do
    let(:chef_run) do
      runner = ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '16.04')
      runner.node.normal['network']['interfaces']['eth0']['addresses']['192.168.253.254'] = {
        'netmask' => '255.255.255.0',
        'broadcast' => '192.168.253.255',
        'family' => 'inet'
      }
      runner.node.normal['ntp']['listen_network'] = '192.168.253.0/24'
      runner.converge('ntp::default')
    end

    it 'expect ntp["listen"] to be the CIDR interface address' do
      expect(chef_run.node['ntp']['listen']).to eq('192.168.253.254')
    end
  end

  context 'ntp["listen"] is set to a specific address' do
    let(:chef_run) do
      runner = ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '16.04')
      runner.node.normal['ntp']['listen'] = '192.168.254.254'
      runner.converge('ntp::default')
    end

    it 'expect ntp["listen"] to be the specified address' do
      expect(chef_run.node['ntp']['listen']).to eq('192.168.254.254')
    end
  end

  context 'ntp["listen"] and ntp["listen_network"] are both set (primary test)' do
    let(:chef_run) do
      runner = ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '16.04')
      runner.node.normal['network']['interfaces']['eth0']['addresses']['192.168.253.254'] = {
        'netmask' => '255.255.255.0',
        'broadcast' => '192.168.253.255',
        'family' => 'inet'
      }
      runner.node.normal['network']['interfaces']['eth1']['addresses']['192.168.254.254'] = {
        'netmask' => '255.255.255.0',
        'broadcast' => '192.168.254.255',
        'family' => 'inet'
      }
      runner.node.normal['network']['default_gateway'] = '192.168.253.1'
      runner.node.normal['ntp']['listen_network'] = 'primary'
      runner.node.normal['ntp']['listen'] = '192.168.254.254'
      runner.converge('ntp::default')
    end

    it 'expect ntp["listen"] to be the specified address from ntp["listen"]' do
      expect(chef_run.node['ntp']['listen']).to eq('192.168.254.254')
    end
  end

  context 'ntp["listen"] and ntp["listen_network"] are both set (CIDR test)' do
    let(:chef_run) do
      runner = ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '16.04')
      runner.node.normal['network']['interfaces']['eth0']['addresses']['192.168.253.254'] = {
        'netmask' => '255.255.255.0',
        'broadcast' => '192.168.253.255',
        'family' => 'inet'
      }
      runner.node.normal['network']['interfaces']['eth1']['addresses']['192.168.254.254'] = {
        'netmask' => '255.255.255.0',
        'broadcast' => '192.168.254.255',
        'family' => 'inet'
      }
      runner.node.normal['ntp']['listen_network'] = '192.168.253.0/24'
      runner.node.normal['ntp']['listen'] = '192.168.254.254'
      runner.converge('ntp::default')
    end

    it 'expect ntp["listen"] to be the specified address from ntp["listen"]' do
      expect(chef_run.node['ntp']['listen']).to eq('192.168.254.254')
    end
  end

  context 'the sync_hw_clock attribute is set on a Windows OS' do
    let(:chef_run) do
      runner = ChefSpec::SoloRunner.new(platform: 'windows', version: '2008R2')
      runner.node.normal['ntp']['sync_hw_clock'] = true
      runner.converge('ntp::default')
    end

    it 'does not executes the "Force sync hardware clock with system clock" command' do
      expect(chef_run).not_to run_execute('hwclock --systohc')
    end
  end

  context 'on CentOS 5' do
    let(:chef_run) { ChefSpec::SoloRunner.new(platform: 'centos', version: '5.11').converge('ntp::default') }

    it 'installs the ntp package' do
      expect(chef_run).to install_package('ntp')
    end

    it 'does not install the ntpdate package' do
      expect(chef_run).to_not install_package('ntpdate')
    end

    it 'starts the ntpd service' do
      expect(chef_run).to start_service('ntpd')
    end

    it 'sets ntpd to start on boot' do
      expect(chef_run).to enable_service('ntpd')
    end
  end

  context 'ubuntu' do
    let(:chef_run) { ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '16.04').converge('ntp::default') }

    it 'starts the ntp service' do
      expect(chef_run).to start_service('ntp')
    end

    it 'sets ntp to start on boot' do
      expect(chef_run).to enable_service('ntp')
    end

    it 'removes ntpdate to avoid ntp & ntpdate conflicts' do
      expect(chef_run).to remove_package('ntpdate')
    end

    context 'with apparmor enabled' do
      let(:chef_run) do
        runner = ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '16.04')
        runner.node.normal['ntp']['apparmor_enabled'] = true
        runner.converge('ntp::default')
      end

      it 'includes the apparmor recipe' do
        expect(chef_run).to include_recipe('ntp::apparmor')
      end
    end

    context 'with apparmor disabled' do
      let(:chef_run) { ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '16.04').converge('ntp::default') }

      it "does not include the apparmor recipe when apparmor doesn't exist" do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with('/etc/init.d/apparmor').and_return(false)
        expect(chef_run).to_not include_recipe('ntp::apparmor')
      end

      it 'does include the apparmor recipe when apparmor exists' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with('/etc/init.d/apparmor').and_return(true)
        expect(chef_run).to include_recipe('ntp::apparmor')
      end
    end
  end

  context 'freebsd' do
    let(:chef_run) { ChefSpec::SoloRunner.new(platform: 'freebsd', version: '10.3').converge('ntp::default') }

    it 'installs the ntp package' do
      expect(chef_run).to install_package('ntp')
    end

    it 'does not install the ntpdate package' do
      expect(chef_run).to_not install_package('ntpdate')
    end

    it 'starts the ntpd service' do
      expect(chef_run).to start_service('ntpd')
    end

    it 'sets ntpd to start on boot' do
      expect(chef_run).to enable_service('ntpd')
    end
  end
end

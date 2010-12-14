class TestWrapper
  attr_reader :config, :path, :fail_flag, :usr_home
  def initialize(config,path=nil)
    @config = config
    @path = path
    @fail_flag = 0
    @usr_home = ENV['HOME']
    #
    # We put this on each wrapper (rather than the class) so that methods
    # defined in the tests don't leak out to other tests. 
    class << self
      def run_test
        test = File.read(path)
        eval test
        classes = test.split(/\n/).collect { |l| l[/^ *class +(\w+) *$/,1]}.compact
        case classes.length
        when 0; self
        when 1; eval(classes[0]).new(config)
        else fail "More than one class found in #{path}"
        end
      end
    end
  end
  def hosts(desired_role=nil)
    config["HOSTS"].
      keys.
      select { |host| 
        desired_role.nil? or config["HOSTS"][host]['roles'].any? { |role| role =~ desired_role }
      }
  end
  def agents
    hosts /agent/
  end
  def master
    masters = hosts /master/
    fail "There must be exactly one master" unless masters.length == 1
    masters.first
  end
  def dashboard
    dashboards = hosts /dashboard/
    fail "There must be exactly one dashboard" unless dashboards.length == 1
    dashboards.first
  end
  def prep_nodes
    # 1: SCP ptest/bin code to all nodes
    test_name="Copy ptest.tgz executables to all hosts"
    hosts.each do |host|
      BeginTest.new(host, test_name)
      scper = ScpFile.new(host)
      result = scper.do_scp("#{$work_dir}/dist/ptest.tgz", "/")
      result.log(test_name)
      @fail_flag+=result.exit_code
    end

    # Execute remote command on each node, regardless of role
    test_name="Untar ptest.tgz executables to all hosts"
    hosts.each do|host|
      BeginTest.new(host, test_name)
      runner = RemoteExec.new(host)
      result = runner.do_remote("cd / && tar xzf ptest.tgz")
      result.log(test_name)
      @fail_flag+=result.exit_code
    end

    # 1: SCP puppet code to master
    test_name="Copy puppet.tgz code to Master"
    BeginTest.new(master, test_name)
    scper = ScpFile.new(master)
    result = scper.do_scp("#{$work_dir}/dist/puppet.tgz", "/etc/puppetlabs")
    result.log(test_name)
    @fail_flag+=result.exit_code

    # Set filetimeout= 0 in puppet.conf
    test_name="Set filetimeout= 0 in puppet.conf"
    BeginTest.new(master, test_name)
    runner = RemoteExec.new(master)
    result = runner.do_remote("cd /etc/puppetlabs/puppet; (grep filetimeout puppet.conf > /dev/null 2>&1) || sed -i \'s/\\[master\\]/\\[master\\]\\n    filetimeout = 0\/\' puppet.conf")
    result.log(test_name)
    @fail_flag+=result.exit_code

    # untar puppet code on master
    test_name="Untar Puppet code on Master"
    BeginTest.new(master, test_name)
    runner = RemoteExec.new(master)
    result = runner.do_remote("cd /etc/puppetlabs && tar xzf puppet.tgz")
    result.log(test_name)
    @fail_flag+=result.exit_code
    @fail_flag
  end
end

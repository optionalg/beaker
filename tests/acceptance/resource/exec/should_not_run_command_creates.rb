test_name "should not run command creates"

touch      = "/tmp/touched-#{$$}"
donottouch = "/tmp/not-touched-#{$$}"

manifest = %Q{
  exec { "test#{$$}": command => '/bin/touch #{donottouch}', creates => "#{touch}"}
}

step "prepare the agents for the test"
on agents, "touch #{touch} ; rm -f #{donottouch}"

step "test using puppet apply"
apply_manifest_on(agents, manifest) do
    fail_test "looks like the thing executed, which it shouldn't" if
        stdout.include? 'executed successfully'
end

step "verify the file didn't get created"
on agents, "test -f #{donottouch}", :acceptable_exit_codes => [1]

step "prepare the agents for the second part of the test"
on agents, "touch #{touch} ; rm -f #{donottouch}"

step "test using puppet resource"
run_puppet_on(agents, :resource, 'exec', "test#{$$}",
              "command='/bin/touch #{donottouch}'",
              "creates='#{touch}'") do
    fail_test "looks like the thing executed, which it shouldn't" if
        stdout.include? 'executed successfully'
end

step "verify the file didn't get created the second time"
on agents, "test -f #{donottouch}", :acceptable_exit_codes => [1]

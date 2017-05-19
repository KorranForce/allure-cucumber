$LOAD_PATH.unshift(__dir__ + "/../../../lib")
require __dir__ + "/../../../lib/allure-cucumber"
$stdout.sync=true;$stderr.sync=true;
AllureRubyAdaptorApi.configure do |c|
  c.logging_level = Logger::DEBUG
end
AllureCucumber.configure do |c|
  c.output_dir = __dir__ + "/../../report_xml/"
end

Before do
	p "in before hook"
	#pending("before hook pending")
	#raise "before hook exception1"
	#sleep 2
end
# Before do
# 	#pending("before hook pending")
# 	#raise "before hook exception2"
# end
# AfterStep do
# 	raise "after step hook exception"
# end
After do
	p "in after hook"
	#raise "after hook exception"
	#sleep 2
end
# AfterStep do |result, source_step|
# 	p result
#   p source_step
# end
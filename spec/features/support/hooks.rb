$LOAD_PATH.unshift(__dir__ + "/../../../lib")
require __dir__ + "/../../../lib/allure-cucumber"

AllureRubyAdaptorApi.configure do |c|
  c.logging_level = Logger::DEBUG
end
AllureCucumber.configure do |c|
  c.output_dir = __dir__ + "/../../report_xml/"
end
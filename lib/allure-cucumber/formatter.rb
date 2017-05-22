require 'pathname'
require 'uuid'
require 'allure-ruby-adaptor-api'

module AllureCucumber
	class Formatter

		TEST_HOOK_NAMES_TO_IGNORE = ['Before hook', 'After hook', 'AfterStep hook']
		#ALLOWED_SEVERITIES = ['blocker', 'critical', 'normal', 'minor', 'trivial']
		POSSIBLE_STATUSES = ['passed', 'failed', 'undefined', 'unknown', 'skipped', 'pending']

		def initialize(config)
			#@output_stream = config.out_stream
			config.on_event :before_test_case, &method(:on_before_test_case)
			config.on_event :after_test_case, &method(:on_after_test_case)
			config.on_event :before_test_step, &method(:on_before_test_step)
			config.on_event :after_test_step, &method(:on_after_test_step)
			config.on_event :finished_testing, &method(:on_finished_testing)
			#config.on_event :step_match, &method(:method_missing)

			AllureCucumber::Config.output_dir = config.out_stream if config.out_stream.is_a?(String)
			dir = Pathname.new(AllureCucumber::Config.output_dir)
			FileUtils.rm_rf(dir) unless AllureCucumber::Config.clean_dir == false
			FileUtils.mkdir_p(dir)
			@tracker = AllureCucumber::FeatureTracker.create
			@tracker.step_index = -1
			@tracker.feature_name = nil
		end
		def before_feature(feature)
			@tracker.feature_name = feature.name
			AllureRubyAdaptorApi::Builder.start_suite(@tracker.feature_name)
		end
		def after_feature(feature=nil)
			AllureRubyAdaptorApi::Builder.stop_suite(@tracker.feature_name)
			@tracker.feature_name = nil
		end
		def on_before_test_case(event)
			test_case = event.test_case
			feature = test_case.feature
			if feature.name != @tracker.feature_name
				after_feature if @tracker.feature_name != nil
				before_feature(feature)
			end

			scenario_data = obtain_scenario_data(test_case)
			#TODO: handle background steps
			if scenario_data.scenario_outline
				@tracker.scenario_name = proper_scenario_outline_name(scenario_data)
			else
				@tracker.scenario_name = test_case.name
			end
			AllureRubyAdaptorApi::Builder.start_test(@tracker.feature_name, @tracker.scenario_name, {feature: @tracker.feature_name, story: @tracker.scenario_name, start: Time.now})
		end
		def on_after_test_case(event)
			result = event.result
			allure_result = {stop: Time.now}.merge(cucumber_result_to_allure_result(result))
			AllureRubyAdaptorApi::Builder.stop_test(@tracker.feature_name, @tracker.scenario_name, allure_result)
			@tracker.scenario_name = nil
			@tracker.step_index = -1
		end
		def on_before_test_step(event)
			test_step = event.test_step
			if !TEST_HOOK_NAMES_TO_IGNORE.include?(test_step.name)
				@tracker.step_index += 1
				@tracker.step_name = test_step.name
				AllureRubyAdaptorApi::Builder.start_step(@tracker.feature_name, @tracker.scenario_name, {index: @tracker.step_index, title: @tracker.step_name, start: Time.now})
			end
		end
		def on_after_test_step(event)
			test_step = event.test_step
			if !TEST_HOOK_NAMES_TO_IGNORE.include?(test_step.name)
				result = event.result
				allure_status = cucumber_status_to_allure_status(result)
				AllureRubyAdaptorApi::Builder.stop_step(@tracker.feature_name, @tracker.scenario_name, {index: @tracker.step_index, title: @tracker.step_name, stop: Time.now}, allure_status)
			end
		end
		def on_finished_testing(event)
			after_feature
			AllureRubyAdaptorApi::Builder.build!
		end

		private
		def cucumber_status_to_allure_status(result)
			allure_status = nil
			POSSIBLE_STATUSES.each do |status|
				if result.send("#{status}?")
					case status.to_s
						when "undefined"
							allure_status = "broken"
						when "skipped"
							allure_status = "canceled"
						else
							allure_status = status.to_s
					end
				end
			end
			allure_status
		end
		def cucumber_result_to_allure_result(result)
			exception = nil
			if result.failed?
				exception = result.exception
			elsif result.pending?
				exception = RuntimeError.new(result.message)
				exception.set_backtrace(result.exception.backtrace)
			end

			allure_status = cucumber_status_to_allure_status(result)

			{status: allure_status, exception: exception}
		end

		ScenarioData = Struct.new(:background, :scenario, :scenario_outline, :examples_table, :examples_table_row)
		def obtain_scenario_data(test_case)
			background = test_case.feature.background
			scenario = nil
			scenario_outline = nil
			examples_table = nil
			examples_table_row = nil
			test_case.source.each {|source_object|
				case source_object
					when Cucumber::Core::Ast::Scenario
						scenario = source_object
					when Cucumber::Core::Ast::ScenarioOutline
						scenario_outline = source_object
					when Cucumber::Core::Ast::Examples
						examples_table = source_object
					when Cucumber::Core::Ast::ExamplesTable::Row
						examples_table_row = source_object
				end
			}
			ScenarioData.new(background, scenario, scenario_outline, examples_table, examples_table_row)
		end
		def proper_scenario_outline_name(scenario_data)
			headers = scenario_data.examples_table.header.values
			values = scenario_data.examples_table_row.values
			key_value_pairs = []
			headers.size.times {|i| key_value_pairs << "#{headers[i]}: #{values[i]}"}
			"#{scenario_data.scenario_outline.name}: {#{key_value_pairs.join(", ")}}"
		end
	end
end

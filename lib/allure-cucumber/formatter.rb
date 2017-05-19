require 'pathname'
require 'uuid'
require 'allure-ruby-adaptor-api'

module AllureCucumber
	class Formatter
		include AllureCucumber::DSL

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
		# def method_missing(*args)
		# 	p args
		# end

# feature.methods
# [:language, :location, :background, :comments, :tags, :keyword, :description, :feature_elements,
#  :children, :short_name, :to_sexp, :describe_to, :file_colon_line, :file, :line, :all_locations,
#  :attributes, :multiline_arg, :name, :legacy_conflated_name_and_description, :to_s, :inspect]

# test_case.methods
# [:source, :test_steps, :around_hooks, :step_count, :describe_to, :describe_source_to,
#  :with_steps, :with_around_hooks, :name, :keyword, :tags, :match_tags?, :match_name?,
#  :language, :location, :match_locations?, :all_locations, :all_source, :inspect, :feature]

# result.methods #with exception
# [:duration, :exception, :describe_to, :to_s, :ok?, :with_duration, :with_appended_backtrace,
#  :with_filtered_backtrace, :to_sym, :passed?, :failed?, :undefined?, :unknown?, :skipped?, :pending?]
# result.methods #without exception
# [:duration, :duration=, :describe_to, :to_s, :ok?, :with_appended_backtrace, :with_filtered_backtrace,
#  :to_sym, :passed?, :failed?, :undefined?, :unknown?, :skipped?, :pending?]
# result.methods #pending
# [:describe_to, :to_s, :ok?, :to_sym, :passed?, :failed?, :undefined?, :unknown?, :skipped?,
#  :pending?, :message, :duration, :with_message, :with_duration, :with_appended_backtrace,
#  :with_filtered_backtrace, :exception, :==, :inspect, :backtrace, :backtrace_locations, :set_backtrace, :cause]


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
			@tracker.scenario_name = test_case.name
			AllureRubyAdaptorApi::Builder.start_test(@tracker.feature_name, @tracker.scenario_name, {feature: @tracker.feature_name, story: @tracker.scenario_name, start: Time.now})
		end
		def on_after_test_case(event)
			result = event.result
			allure_result = {stop: Time.now}.merge(cucumber_result_to_allure_result(result))
			AllureRubyAdaptorApi::Builder.stop_test(@tracker.feature_name, @tracker.scenario_name, allure_result)
			@tracker.scenario_name = nil
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
	end  
end

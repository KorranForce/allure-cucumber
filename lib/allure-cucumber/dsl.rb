module AllureCucumber
	module DSL
		def attach_file(step, file, file_title)
			@tracker = AllureCucumber::FeatureTracker.tracker
			if @tracker.scenario_name
				AllureRubyAdaptorApi::Builder.add_attachment(@tracker.feature_name,
				                                             @tracker.scenario_name,
				                                             step: step,
				                                             file: file,
				                                             title: file_title)
			else
				# TODO: This is possible for background steps.  
				puts "Cannot attach #{file_title} to step #{@tracker.step_name} as scenario name is undefined"
			end
		end
	end
end

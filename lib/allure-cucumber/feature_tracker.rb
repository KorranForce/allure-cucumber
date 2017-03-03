module AllureCucumber
  
  class FeatureTracker

    attr_accessor :feature_name, :scenario_name, :scenario_start_time, :step_name, :step_index, :step_start_time, :step_stop_time
    @@tracker = nil

    def self.create
      @@tracker = FeatureTracker.new unless @@tracker
      private_class_method :new
      @@tracker
    end

    def self.tracker
      @@tracker
    end
    
  end
end

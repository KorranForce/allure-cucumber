require 'pathname'
require 'uuid'
require 'allure-ruby-adaptor-api'

module AllureCucumber
  class Formatter

    include AllureCucumber::DSL

    def initialize(step_mother, io, options)
      dir = Pathname.new(AllureCucumber::Config.output_dir)      
      FileUtils.rm_rf(dir)
      @tracker = AllureCucumber::FeatureTracker.create
    end
    
    def before_feature(feature)
      @has_background = false
      feature_identifier = ENV['FEATURE_IDENTIFIER'] && "#{ENV['FEATURE_IDENTIFIER']} - "
      @tracker.feature_name = "#{feature_identifier}#{feature.name.gsub(/\n/, " ")}"
      AllureRubyAdaptorApi::Builder.start_suite(@tracker.feature_name, :severity => :normal)
    end

    def before_background(*args)
      @in_background = true
      @has_background = true
      @background_before_steps = []
      @background_after_steps = []
    end

    def after_background(*args)
      @in_background = false
    end

    def before_feature_element(feature_element)
      @scenario_outline = feature_element.instance_of?(Cucumber::Ast::ScenarioOutline) 
    end

    def scenario_name(keyword, name, file_colon_line, source_indent)
      unless @scenario_outline
        @tracker.scenario_name = (name.nil? || name == "") ? "Unnamed scenario" : name.gsub(/\n/, " ")
        AllureRubyAdaptorApi::Builder.start_test(@tracker.feature_name, @tracker.scenario_name, :feature => @tracker.feature_name, :story => @tracker.scenario_name)
        @tracker.scenario_started_at = Time.now
        post_background_steps if  @has_background
      else
        @scenario_outline_name = (name.nil? || name == "") ? "Unnamed scenario" : name.gsub(/\n/, " ")
      end      
    end
    
    def before_steps(steps)
      @example_before_steps = []
      @example_after_steps = []
      @exception = nil
    end

    def before_step(step)
      unless step.background?
        unless @scenario_outline
          @tracker.step_id = step.backtrace_line
          @tracker.step_name = step.name
          AllureRubyAdaptorApi::Builder.start_step(@tracker.feature_name, @tracker.scenario_name, {:id=>@tracker.step_id, :name=>@tracker.step_name}) 
          attach_multiline_arg(step.multiline_arg)
        else
          @example_before_steps << step
        end
      else
        @background_before_steps << step
      end
    end

    def after_step(step)
      unless step.background?
        unless @scenario_outline
         AllureRubyAdaptorApi::Builder.stop_step(@tracker.feature_name, @tracker.scenario_name, {:id=>@tracker.step_id, :name=>@tracker.step_name}, step.status.to_sym)
        else
          @example_after_steps << step
        end
      else
        @background_after_steps << step
      end
    end
    
    def exception(exception, status)
      if !@before_hook_exception && exception.backtrace.last.include?("`Before'")
        @before_hook_exception = exception
      end
    end

    def after_steps(steps)
      return if @in_background || @scenario_outline
      exception = @before_hook_exception ? @before_hook_exception : steps.exception
      @before_hook_exception = nil
      result = { :status => steps.status, :exception => exception, :started_at => @tracker.scenario_started_at, :finished_at => Time.now }
      AllureRubyAdaptorApi::Builder.stop_test(@tracker.feature_name, @tracker.scenario_name, result)
    end

    def before_examples(*args)
      @header_row = true
      @in_examples = true
    end

    def before_examples(*args)
      @header_row = true
      @in_examples = true
    end

    def before_outline_table(outline_table)
      headers = outline_table.headers
      rows = outline_table.rows
      @current_row = -1
      @table = []
      rows.each do |element|
        row_hash = {}
        element.each_with_index do |item, index|
          row_hash[headers[index]] = item
        end
        @table << row_hash
      end
    end
    
    def before_table_row(table_row)
      return unless @in_examples
      unless @header_row
        @scenario_status = :passed 
        @exception = nil
        @tracker.scenario_name = "#{@scenario_outline_name} Example: #{table_row.name}"
        AllureRubyAdaptorApi::Builder.start_test(@tracker.feature_name, @tracker.scenario_name, :feature => @tracker.feature_name, :story => @tracker.scenario_name)
        @tracker.scenario_started_at = Time.now
        post_background_steps if @has_background
        @current_row += 1
        @example_before_steps.each do |step|
          @tracker.step_name = transform_step_name_for_outline(step.name, @current_row)
          AllureRubyAdaptorApi::Builder.start_step(@tracker.feature_name, @tracker.scenario_name, {:id=>step.backtrace_line, :name=>@tracker.step_name})
          attach_multiline_arg(step.multiline_arg)  
        end
      end
    end
    
    def after_table_row(table_row)
      return unless @in_examples or Cucumber::Ast::OutlineTable::ExampleRow === table_row
      unless @header_row
        @example_after_steps.each do |step|
          @tracker.step_name = transform_step_name_for_outline(step.name, @current_row)
          if table_row.status == :failed
            @exception = table_row.exception
            @scenario_status = :failed
          end      
          AllureRubyAdaptorApi::Builder.stop_step(@tracker.feature_name, @tracker.scenario_name, {:id=>step.backtrace_line, :name=>@tracker.step_name}, step.status.to_sym)
        end
        AllureRubyAdaptorApi::Builder.stop_test(@tracker.feature_name, @tracker.scenario_name, {:status => @scenario_status, :exception => @exception, :started_at => @tracker.scenario_started_at, :finished_at => Time.now })
      end
      @header_row = false if @header_row
    end

    def after_outline_table(*args)
      @in_examples = false
    end
    
    def after_feature(feature)
      AllureRubyAdaptorApi::Builder.stop_suite(@tracker.feature_name)
    end

    def after_features(features)
      AllureRubyAdaptorApi::Builder.build!
    end
    
    private
    
    def transform_step_name_for_outline(step_name, row_num)
      transformed_name = ''
      @table[row_num].each do |k, v| 
        transformed_name == '' ? transformed_name = step_name.gsub(k, v) : transformed_name = transformed_name.gsub(k,v)
      end
      transformed_name
    end

    def attach_multiline_arg(multiline_arg)
      if multiline_arg
        File.open('tmp_file.txt', 'w'){ |file| file.write(multiline_arg.to_s.gsub(/\e\[(\d+)(;\d+)*m/,'')) }
        attach_file("table", File.open('tmp_file.txt'))
      end
    end

    def post_background_steps
      @background_before_steps.each do |step|
        @tracker.step_name = "Background : #{step.name}"
        AllureRubyAdaptorApi::Builder.start_step(@tracker.feature_name, @tracker.scenario_name, {:name=>@tracker.step_name})
        attach_multiline_arg(step.multiline_arg)
      end
      @background_before_steps.each do |step|
        @tracker.step_name = "Background : #{step.name}"
        AllureRubyAdaptorApi::Builder.stop_step(@tracker.feature_name, @tracker.scenario_name, {:name=>@tracker.step_name}, step.status.to_sym)        
        attach_multiline_arg(step.multiline_arg)
      end     
    end
    
  end  
end

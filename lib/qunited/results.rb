module QUnited

  # Simple tests results compiler. Takes a raw results hash that was produced by a runner.
  class Results
    def initialize(modules_results_array)
      @data = modules_results_array
      @data.freeze
    end

    # Results output methods

    def to_s
      all_output = dots
      all_output << "\n\n#{failures_output}" unless failures_output.empty?
      all_output << "\n\n#{bottom_line}"
      all_output
    end

    def passed?
      total_failures.zero? && total_errors.zero?
    end

    def failed?
      !passed?
    end

    def dots
      tests.map do |test|
        if test[:failed] == 0
          '.'
        elsif test[:assertion_data].find { |assert| assert[:message] =~ /^Died on test/ }
          'E'
        else
          'F'
        end
      end.join
    end

    def bottom_line
      "#{total_tests} tests, #{total_assertions} assertions, " +
      "#{total_failures} failures, #{total_errors} errors, 0 skips"
    end

    def failures_output
      failures_output_array.join("\n")
    end

    # Array of failure output block strings
    def failures_output_array
      return @failures_output_array if @failures_output_array

      failures_output = []
      failures.each_with_index do |failure, i|
        out =  "  #{i+1}) Failure:\n"
        out << "#{failure[:test_name]} (#{failure[:module_name]}) [#{failure[:file]}]\n"
        out << "#{failure[:message] || 'Failed assertion, no message given.'}\n"

        # Results can be nil. Also, JavaScript nulls will be converted, by the YAML serializer, to
        # Ruby nil. Convert that back to 'null' for the output.
        if failure.key? :expected
          expected, actual = failure[:expected], failure[:actual]
          out << "Expected: #{expected.nil? ? 'null' : expected.inspect}\n"
          out <<   "  Actual: #{actual.nil? ? 'null' : actual.inspect}\n"
        end

        failures_output << out
      end
      @failures_output_array = failures_output
    end

    # Other data compilation methods

    def total_tests
      tests.size
    end

    def total_assertions
      assertions.size
    end

    def total_failures
      failures.size
    end

    def total_errors
      errors.size
    end

    def raw_results
      @data
    end

    private

    def modules
      @data
    end

    def tests
      @tests ||= modules.inject([]) do |tests, mod|
        tests += mod[:tests].map do |test_data|
          # Add module name for convenience in writing results
          test_data[:module_name] = mod[:name]
          test_data
        end
      end
    end

    def assertions
      @assertions ||= tests.inject([]) do |asserts, test|
        asserts += test[:assertion_data].map do |assertion_data|
          # Add test, module, and file name for convenience in writing results
          assertion_data[:test_name] = test[:name]
          assertion_data[:module_name] = test[:module_name]
          assertion_data[:file] = test[:file]
          assertion_data
        end
      end
    end

    def failures
      @failures ||= compile_failures_and_errors[0]
    end

    def errors
      @errors ||= compile_failures_and_errors[1]
    end

    def compile_failures_and_errors
      @failures, @errors = assertions.select { |assert| !assert[:result] }.partition do |assert|
        assert[:message] !~ /^Died on test/
      end
    end
  end
end

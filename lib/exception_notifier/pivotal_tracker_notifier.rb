module ExceptionNotifier
  class PivotalTrackerNotifier

    def initialize(options)
      PivotalTracker::Client.token = options.delete(:api_token)
      @project = PivotalTracker::Project.find(options.delete(:project_id))
    end

    def call(exception, options={})
      @env        = options[:env]
      @exception  = exception
      @request    = ActionDispatch::Request.new(@env)
      @options    = options.reverse_merge(@env['exception_notifier.options'] || {}).reverse_merge(options)
      @kontroller = @env['action_controller.instance'] || MissingController.new
      @backtrace  = exception.backtrace ? clean_backtrace(exception) : []
      @data       = (@env['exception_notifier.exception_data'] || {}).merge(options[:data] || {})

      create_story
    end

    private

    def create_story
      story = @project.stories.create(name: title, story_type: 'bug', description: body)
    end

    def title
      subject = "[#{Rails.env.titleize}] "
      subject << "#{@kontroller.controller_name}##{@kontroller.action_name} " if @kontroller
      subject << "(#{@exception.class})"
    end

    def body
      filtered_env = @request.filtered_env
      max = filtered_env.keys.map(&:to_s).max { |a, b| a.length <=> b.length }

      <<-EOF
      #{@exception.class.to_s =~ /^[aeiou]/i ? 'An' : 'A'} #{@exception.class} occurred in #{@kontroller.controller_name}##{@kontroller.action_name}

      **Message:**
      ````#{@exception.message}````

      ------------------------------

      * URL        : #{@request.url}
      * HTTP Method: `#{@request.request_method}`
      * IP address : `#{@request.remote_ip}`
      * Parameters : `#{@request.filtered_parameters.inspect}`
      * Timestamp  : `#{Time.current}`
      * Server     : `#{Socket.gethostname}`

      ------------------------------

      **Session**
      * session id: #{@request.ssl? ? "[FILTERED]" : ( (@request.session['session_id'] || (@request.env["rack.session.options"] and @request.env["rack.session.options"][:id])).inspect)}
      * data: #{@request.session.to_hash }

      ------------------------------

      **Data**
      #{@data}

      ------------------------------

      **Backtrace:**
      ````#{@backtrace.join("\n")}````
      EOF
    end

    def clean_backtrace(exception)
      if defined?(Rails) && Rails.respond_to?(:backtrace_cleaner)
        Rails.backtrace_cleaner.send(:filter, exception.backtrace)
      else
        exception.backtrace
      end
    end
  end
end

module MetaRequest
  module Middlewares
    class AppRequestHandler
      def initialize(app)
        @app = app
      end

      def call(env)
        app_request = AppRequest.new env["action_dispatch.request_id"]
        app_request.current!
        @app.call(env)
      rescue Exception => exception
        if defined?(ActionDispatch::ExceptionWrapper)
          wrapper = ActionDispatch::ExceptionWrapper.new(env, exception)
          app_request.events.push(*Event.events_for_exception(wrapper))
        else
          app_request.events.push(*Event.events_for_exception(exception))
        end
        raise
      ensure
        # Storage.new(app_request.id).write(app_request.events.to_json) unless app_request.events.empty?
        unless app_request.events.empty?
          Storage.new(app_request.id).write(app_request.events.to_json)
          controller_event = app_request.events.find do |event|
            event.name == "process_action.action_controller"
          end
          controller_name = controller_event.payload[:controller]
          action_name = controller_event.payload[:action]
          event_time = controller_event.time.strftime("%Y-%m-%d %H:%M:%S")
          output = "#{event_time} #{controller_name}##{action_name}"
          # puts output to rails root/log/meta_request.log
          File.open("#{Rails.root}/log/meta_request.log", "a") do |f|
            f.puts output
          end
        end
      end
    end
  end
end


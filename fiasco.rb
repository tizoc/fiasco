require 'rack'

module Fiasco
  Captures = Struct.new('Captures', *%w[matched named remaining])
  class Captures
    def [](name)
      named[name.to_s]
    end
  end

  class Matcher
    def initialize(rules)
      @rules = rules
    end

    def matches?(env)
      captures = Captures.new([], {}, "")

      @rules.all? do |rule|
        rule.call(env, captures)
      end && captures
    end
  end

  Mapping = Struct.new('Mapping', *%w[matcher bound handler params])
  class Mapping
    def invoke(target, captures)
      # TODO: handle SCRIPT_NAME and captures.remaining?
      handler_params = calculate_params(target, captures)
      target.send(handler, *handler_params)
    end

    def calculate_params(target, captures)
      # TODO: handle rest arguments
      @handler_arguments ||= target.method(handler).parameters
      @handler_arguments.map{|kind, name| captures[name]}
    end
  end

  class Application
    attr_reader :env, :request, :response, :mappings, :default_path_matcher

    def initialize(options = {})
      @handlers = []
      @mappings = []
      @default_path_matcher = options.fetch(:default_path_matcher)
    end

    def call(env)
      @env = env
      @request = Rack::Request.new(env)
      @response = Rack::Response.new

      catch(:complete) do
        pass

        @response.status = 404
        @response.finish
      end
    ensure
      @env = @request = @response = nil
    end

    def pass(options = {})
      to, skip = options[:to], options[:skip]
      targets = to ? [to] : @handlers

      targets.each do |target|
        next if target.equal?(skip)

        @mappings.each do |mapping|
          next unless
            target.equal?(mapping.bound) || target.is_a?(mapping.bound)

          if captures = mapping.matcher.matches?(@env)
            mapping.invoke(target, captures)
            throw(:complete, @response.finish)
          end
        end
      end
    end

    def add_handler(object)
      @handlers << object
    end
  end

  class Mapper
    def self.bind(mod, app, path_matcher = app.default_path_matcher)
      @@__fiasco__current_mapper = new(app, path_matcher).tap do
        def mod.method_added(name)
          super
          @@__fiasco__current_mapper.map(self, name)
        end
      end
    end

    def initialize(app, path_matcher_klass)
      @app, @stack, @path_match = app, [], path_matcher_klass
    end

    def push(url_pattern, options = {})
      defaults = options.fetch(:defaults, {})
      methods = options.fetch(:methods, %w[GET])
      partial = options.fetch(:partial, false)
      set_defaults = lambda{|_, captures|
        defaults.each{|k,v| captures.named[k.to_s] = v}
      }
      check_method = lambda{|env, _|
        methods.include?(env["REQUEST_METHOD"])
      }
      match_path = @path_match.new(url_pattern, partial)

      matcher = Matcher.new([set_defaults, check_method, match_path])

      @stack.push(matcher)
    end
    alias_method :[], :push

    def map(target, method)
      while matcher = @stack.pop
        @app.mappings.push(Mapping.new(matcher, target, method, nil))
      end
    end
  end
end

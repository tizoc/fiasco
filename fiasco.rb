require 'rack'
require 'set'

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
      @captures = []
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

        not_found
      end
    ensure
      @env = @request = @response = nil
    end

    def _pass(options = {})
      to, skip = options[:to], options[:skip]
      targets = to ? [to] : @handlers

      targets.each do |target|
        next if target.equal?(skip)

        @mappings.each do |mapping|
          next unless
            target.equal?(mapping.bound) || target.is_a?(mapping.bound)

          if captures = mapping.matcher.matches?(@env)
            begin
              @captures.push(captures)
              mapping.invoke(target, captures)
              throw(:complete, @response.finish)
            ensure
              @captures.pop
            end
          end
        end
      end
    end

    def pass(options = {})
      old_path, old_script = @env['PATH_INFO'], @env['SCRIPT_NAME']
      captures = @captures.last

      if captures && captures.remaining
        @env['PATH_INFO'] = '/' + captures.remaining
        @env['SCRIPT_NAME'] = captures.matched.gsub(%r{/$}, '')
      end

      _pass(options)
      not_found
    ensure
      @env['PATH_INFO'], @env['SCRIPT_NAME'] = old_path, old_script
    end

    def not_found
      @response.status = 404
      @response.finish
    end

    def add_handler(object)
      @handlers << object
    end
  end

  class Mapper
    @@__fiasco__current_mapper = nil
    @@__fiasco__bound_modules = Set.new

    def self.bind(mod, app, path_matcher = app.default_path_matcher)
      new(app, path_matcher).tap do
        unless @@__fiasco__bound_modules.include?(mod.object_id)
          @@__fiasco__bound_modules.add(mod.object_id)

          def mod.method_added(name)
            super
            if @@__fiasco__current_mapper
              @@__fiasco__current_mapper.map(self, name)
            end
          end
        end
      end
    end

    def initialize(app, path_matcher_klass)
      @app, @stack, @path_match = app, [], path_matcher_klass
    end

    def make_active!
      @@__fiasco__current_mapper = self
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

      make_active!
    end
    alias_method :[], :push

    def capture(url_pattern, options = {})
      push(url_pattern, {partial: true}.merge(options))
    end

    def map(target, method)
      while matcher = @stack.pop
        @app.mappings.push(Mapping.new(matcher, target, method, nil))
      end
    end
  end
end

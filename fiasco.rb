require 'forwardable'
require 'rack'
require 'set'
require_relative 'fiasco/global_state'
require_relative 'fiasco/thread_local_proxy'

module Fiasco
  class Captures < Struct.new(:matched, :named, :remaining)
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

  class Mapping < Struct.new(:matcher, :bound, :handler, :params)
    def invoke(target, captures)
      handler_params = _calculate_params(target, captures)
      target.send(handler, *handler_params)
    end

    def _calculate_params(target, captures)
      # TODO: handle rest arguments
      @params ||= target.method(handler).parameters
      @params.map{|kind, name| captures[name]}
    end
  end

  class Application
    Context = Struct.new(:captures, :g, :env, :request, :response)
    attr_reader :mappings, :default_path_matcher, :ctx

    extend Forwardable
    context_attributes = %w[env env= captures captures=
                            request request= response response=]
    def_delegators :ctx, *context_attributes

    def initialize(options = {})
      @ctx = ThreadLocalProxy.new
      @handlers = []
      @mappings = []
      @default_path_matcher = options.fetch(:default_path_matcher) do
        require_relative 'fiasco/extended_path_matcher'
        ExtendedPathMatcher
      end
    end

    def call(env)
      ctx.__setobj__(Context.new) if !ctx
      ctx.captures = []
      ctx.env = env
      ctx.request = Rack::Request.new(env)
      ctx.response = Rack::Response.new
      ctx.g = GlobalState.new

      catch(:complete) do
        pass
      end
    ensure
      ctx.env = ctx.request = ctx.response = ctx.g = nil
    end

    def _pass(options = {})
      to, skip = options[:to], options[:skip]
      targets = to ? [to] : @handlers

      targets.each do |target|
        next if target.equal?(skip)

        @mappings.each do |mapping|
          next unless
            target.equal?(mapping.bound) || target.is_a?(mapping.bound)

          if captured = mapping.matcher.matches?(env)
            begin
              captures.push(captured)
              mapping.invoke(target, captured)
              throw(:complete, response.finish)
            ensure
              captures.pop
            end
          end
        end
      end
    end

    def pass(options = {})
      old_path, old_script = env['PATH_INFO'], env['SCRIPT_NAME']
      captured = captures.last

      if captured && captured.remaining
        env['PATH_INFO'] = '/' + captured.remaining
        env['SCRIPT_NAME'] = captured.matched.gsub(%r{/$}, '')
      end

      _pass(options) # If :complete is thrown the following is skipped
      not_found
    ensure
      env['PATH_INFO'], env['SCRIPT_NAME'] = old_path, old_script
    end

    def not_found
      response.status = 404
      response.finish
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
      set_defaults = lambda{|_, captured|
        defaults.each{|k,v| captured.named[k.to_s] = v}
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

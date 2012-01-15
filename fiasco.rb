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

  Rule = Struct.new('Rule', *%w[matcher bound handler params])
  class Rule
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
    attr_reader :env, :request, :response

    def initialize(options = {})
      @handlers = []
      @rules = []
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
      targets = to ? [get_target(to)] : @handlers.map(&:first)

      targets.each do |target|
        next if target.equal?(skip)

        @rules.each do |rule|
          next unless target.equal?(rule.bound) || target.is_a?(rule.bound)

          if captures = rule.matcher.matches?(@env)
            rule.invoke(target, captures)
            throw(:complete, $app.response.finish)
          end
        end
      end
    end

    def get_target(name)
      @handlers.each do |target, options|
        return target if options[:name] == name
      end
    end

    def mount(object, options = {})
      @handlers << [object, options]
    end

    def rule(path_matcher = @default_path_matcher)
      RuleStack.new(@rules, path_matcher)
    end

    def bind(o)
      # TODO: force '@rule' as the name and avoid the global?
      $__rule = rule.tap do
        def o.method_added(name)
          super
          $__rule.register(self, name)
        end
      end
    end
  end

  class RuleStack
    def initialize(registry, url_matcher_klass)
      @registry, @stack, @url_match = registry, [], url_matcher_klass
    end

    def [](url_pattern, options = {})
      defaults = options.fetch(:defaults, {})
      methods = options.fetch(:methods, %w[GET])
      partial = options.fetch(:partial, false)
      set_defaults = lambda{|_, captures|
        defaults.each{|k,v| captures.named[k.to_s] = v}
      }
      check_method = lambda{|env, _|
        methods.include?(env["REQUEST_METHOD"])
      }
      match_path = @url_match.new(url_pattern, partial)

      matcher = Matcher.new([set_defaults, check_method, match_path])

      @stack.push(matcher)
    end

    def register(bound, method)
      while matcher = @stack.pop
        @registry.push(Rule.new(matcher, bound, method, nil))
      end
    end
  end
end

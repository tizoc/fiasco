require 'set'

module Fiasco
  class GlobalState < BasicObject
    def initialize
      @__attributes__ = ::Set.new
    end

    def inspect
      values = @__attributes__.inject([]) do |acc, v|
        acc << "#{v}=#{__send__(v).inspect}"
      end.join(' ')
      "<GlobalState #{values}>"
    end

    # required so that Delegate works
    def respond_to?(_)
      true
    end

    def method_missing(method, *args)
      attr = method.to_s
      attr = attr.chop if attr[-1] == '='

      methods = <<-EOS
        def #{attr}!
          #{attr}? ? #{attr} : nil
        end

        def #{attr}
          #{attr}? ? @#{attr} : ::Kernel.raise(::NoMethodError, '#{attr}')
        end

        def #{attr}?
          @__attributes__.include? :#{attr}
        end

        def #{attr}=(value)
          @__attributes__.add(:#{attr})
          @#{attr} = value
        end
      EOS

      ::Fiasco::GlobalState.module_eval(methods)

      __send__(method, *args)
    end
  end
end

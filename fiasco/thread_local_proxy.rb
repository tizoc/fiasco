require 'delegate'
require 'securerandom'

module Fiasco
  class ThreadLocalProxy < Delegator
    def initialize(name = ::SecureRandom.uuid)
      @name = name
    end

    def __getobj__
      ::Thread.current[@name]
    end

    def __setobj__(obj)
      ::Thread.current[@name] = obj
    end
  end

  class Proxy < Delegator
    def initialize(&block)
      @block = block
    end

    def __getobj__
      instance_eval(&@block)
    end
  end
end

if $0 == __FILE__
  def with_context(obj, ctx)
    old = obj.__getobj__
    obj.__setobj__(ctx)
    yield
  ensure
    obj.__setobj__(old)
  end

  $hash = Fiasco::ThreadLocalProxy.new
  $num = Fiasco::Proxy.new{$hash[:number]}

  (0...100).map do |n|
    Thread.new do
      with_context($hash, {number: n}) do
        sleep rand
        $num == n or raise "ERROR: value didn't match"
      end
    end
  end.each do |t|
    t.join
  end
end

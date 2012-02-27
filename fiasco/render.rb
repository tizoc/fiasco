require 'set'
require_relative 'template_compiler'

module Fiasco
  class Render
    Entry = Struct.new(:body, :filename)

    def initialize
      @content_blocks = Hash.new {|h,k| h[k] = [] }
      @template_locals = Hash.new {|h,k| h[k] = [] }
      @templates = {}
      @compiled = Set.new
      display_value = lambda{|literal| "(__tmp = (#{literal}); display_value(__tmp))"}
      @compiler = TemplateCompiler.new(display_value: display_value)
    end

    def block(key, &b)
      @content_blocks[key.to_sym] << b
    end

    def superblock(*args)
      @blocklevel += 1
      @content_blocks[@blockname][@blocklevel].call(*args)
    ensure
      @blocklevel -= 1
    end

    def yield_block(key, *args, &b)
      key = key.to_sym
      @content_blocks[key] << b if b

      if @content_blocks[key].length > 0
        begin
          old_blocklevel, @blocklevel = @blocklevel, -1
          old_blockname, @blockname = @blockname, key
          superblock(*args)
        ensure
          @blocklevel, @blockname = old_blocklevel, old_blockname
        end
      else
        ''
      end
    end

    def extends(base, *args)
      @extends = [base, args]
    end

    def _compile(name, entry, locals = [])
      src = "params ||= {}; @render_output ||= ''; "
      locals.each {|var| src += "#{var} = params[:#{var}]; "}
      src << "\n"
      src << @compiler.compile(entry.body)
      src << "\n@render_output"

      meth = <<-EOS
#coding:UTF-8
define_singleton_method(:'__view__#{name}') do |params|
#{src}
end
EOS
      eval(meth, binding, entry.filename || "(TEMPLATE:#{name})", -2)
      @compiled << name
    end

    def _process_locals(name, locals)
      seen_variables = @template_locals[name]
      diff = locals.keys - seen_variables

      unless diff.empty?
        seen_variables += diff
        @compiled.delete(name)
      end

      seen_variables
    end

    def _declare(options)
      contents = options[:path] ? File.read(options[:path]) : options[:contents]

      if contents.nil?
        raise ArgumentError.new("Need either path or contents")
      end

      entry = Entry.new(contents, options[:path])

      yield(entry)
    end

    def declare(name, options = {})
      name = name.to_sym
      _declare(options) {|e| @templates[name] = e}
    end

    def _render(name, locals = {})
      name = name.to_sym
      variables = _process_locals(name, locals)

      unless @compiled.include?(name)
        _compile(name, @templates[name], variables)
      end

      send("__view__#{name}", locals)

      if @extends
        parent, pargs = @extends
        @extends = nil
        _render(parent, *pargs)
      end

      @render_output
    end

    def render(name, locals = {})
      _render(name, locals)
    ensure
      @content_blocks.clear
      @render_output = nil
    end

    alias_method :[], :render

    def display_value(value)
      str = value.to_s
      value.tainted? ? Rack::Utils.escape(str) : str
    end

    def macro(mname, defaults = {}, &b)
      arguments = b.parameters
      define_singleton_method mname do |named = defaults, &block|
        args = arguments.select{|t| t[0] != :block}.map do |type, name|
          named.fetch(name) do
            defaults.fetch(name) do
              raise ArgumentError, "Macro invocation '#{mname}' is missing a required argument: #{name}", caller(10)
            end
          end
        end
        b.call(*args, &block)
      end
    end

    def load_macros(options)
      b = binding
      _declare(options) {|e| e.run(b)}
    end
  end
end

require 'set'
require 'erb'

module Fiasco
  class Render
    def initialize
      @content_blocks = Hash.new {|h,k| h[k] = [] }
      @template_locals = Hash.new {|h,k| h[k] = Set.new }
      @templates = {}
      @compiled = Set.new
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

    def _compile(name, erb, locals = [])
      src = "params ||= {}; @render_output ||= ''\n"
      locals.each {|var| parts += "#{var} = params[:#{var}]; "}
      src << erb.src
      src << "\n@render_output"

      self.class.module_eval do
        meth = <<-EOS
#coding:UTF-8
define_method(:'__view__#{name}') do |params|
#{src}
end
EOS
        eval(meth, binding, erb.filename || '(ERB)', -2)
      end
    end

    def _process_locals(name, locals)
      variables = Set.new(locals.keys)
      seen_variables = @template_locals[name]

      unless (variables - seen_variables).empty?
        seen_variables += variables
        @compiled.delete(name)
      end

      seen_variables
    end

    def declare(name, options = {})
      name = name.to_sym
      contents = options[:path] ? File.read(options[:path]) : options[:contents]

      if contents.nil?
        raise ArgumentError.new("Need either path or contents")
      end

      e = ERB.new(contents, nil, '%-', '@render_output')
      e.filename = options[:path]

      @templates[name] = e
    end

    def render(name, locals = {})
      name = name.to_sym
      variables = _process_locals(name, locals)

      unless @compiled.include?(name)
        _compile(name, @templates[name], variables)
      end

      send("__view__#{name}", locals)

      if @extends
        parent, pargs = @extends
        @extends = nil
        render(parent, *pargs)
      end

      @render_output
    end

    alias_method :'[]', :render
  end
end

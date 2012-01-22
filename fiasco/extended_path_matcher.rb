module Fiasco
  class ExtendedPathMatcher
    ISNAME = "[a-zA-Z_][a-zA-Z0-9_]"
    NAME_CAPTURE_RE = /<([^>]+)>/
    CAPTURE_RE =
      %r{^(?<static>[^<]*)<(?:(?<type>#{ISNAME}*):)?(?<name>#{ISNAME}*)>}
    CONVERTERS = {
      'int' => lambda {|v| v.to_i},
      'string' => lambda{|v| URI.unescape(v)},
      'path' => lambda{|v| URI.unescape(v)}
    }

    def initialize(pattern, captures)
      @captures = captures
      @types = {}
      rest = pattern
      segments = []

      while match = CAPTURE_RE.match(rest)
        static, name, type =
          match['static'], match['name'], match['type'] || 'string'
        @types[name] = type
        segments.push [static, nil] unless match['static'].empty?
        segments.push [name, type]
        rest = match.post_match
      end

      unless rest.empty?
        segments.push [rest, nil]
      end

      re = '^' + segments.map do |name, type|
        case type
        when 'string' then "(?<#{name}>[^/]+?)"
        when 'int' then "(?<#{name}>\\d+)"
        when 'path' then "(?<#{name}>.+?)"
        else name # for nil
        end
      end.to_a.join

      @pattern = Regexp.new(re + (captures ? '' : '$'))
    end

    def call(env, captures)
      @pattern.match(env["PATH_INFO"]).tap do |match|
        if match
          captures.matched = match.to_s
          match.names.each do |name|
            captures.named[name] = CONVERTERS[@types[name]].call(match[name])
          end

          captures.remaining = match.post_match if @captures
        end
      end
    end
  end
end

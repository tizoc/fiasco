module Fiasco
  class ExtendedPathMatcher
    ISNAME = "[a-zA-Z_][a-zA-Z0-9_]"
    NAME_CAPTURE_RE = /<([^>]+)>/
    CAPTURE_RE =
      %r{^(?<static>[^<]*)<(?:(?<type>#{ISNAME}*):)(?<name>#{ISNAME}*)>}
    CONVERTERS = {
      'int' => lambda {|v| v.to_i},
      'string' => lambda{|v| v}
    }

    def initialize(pattern, partial)
      rest = pattern
      segments = []

      while match = CAPTURE_RE.match(rest)
        segments.push [match['static'], nil] unless match['static'].empty?
        segments.push [match['name'], match['type'] || 'string']
        rest = match.post_match
      end

      unless rest.empty?
        segments.push [rest, nil]
      end

      re = '^' + segments.map do |name, type|
        case type
        when 'string' then "(?<#{name}>.+?)"
        when 'int' then "(?<#{name}>\\d+)"
        else name # for nil
        end
      end.to_a.join

      @pattern = Regexp.new(re + (partial ? '' : '$'))
    end

    def call(env, captures)
      # TODO convert capture types
      @pattern.match(env["PATH_INFO"]).tap do |match|
        if match
          captures.matched = match.to_s
          match.names.each do |name|
            captures.named[name] = match[name]
          end

          captures.remaining = match.post_match
        end
      end
    end
  end
end

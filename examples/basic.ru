# Example with the basics of Fiasco
# run with:
# $ rackup examples/basic.ru
# and visit http://localhost:9292 with your browser

BASEDIR = File.expand_path(File.dirname(__FILE__))

require File.expand_path('../fiasco', BASEDIR)
require File.expand_path('../fiasco/extended_path_matcher', BASEDIR)
require File.expand_path('../fiasco/render', BASEDIR)

# Fiasco::Application instances are the entry point
# (what receives the env from Rack)
# A default path matcher has to be specified, here we used the extended
# path matcher.
# Making the app instance a global is optional.
$app = Fiasco::Application.new(default_path_matcher: Fiasco::ExtendedPathMatcher)

# All these shorcuts are optional too
# These globals are thread-local proxies to the actual data
$g = Fiasco::Proxy.new{$app.ctx.g} # Global store
$request = Fiasco::Proxy.new{$app.ctx.request} # Rack Request object
$response = Fiasco::Proxy.new{$app.ctx.response} # Rack Response object
$env = Fiasco::Proxy.new{$app.ctx.env} # Rack env

# The renderer is responsible for compiling and rendering templates
$render = Fiasco::Render.new

# Fiasco::Render#declare takes a `name` and either `contents:` aString
# or `path:` aFilePath and registers the contents as a template that can
# be later referenced with the provided `name`.
# The templates are precompiled for performance.
# - `yield_block` accepts a `name`, and an optional block for the default contents
# - `extends` accepts the name of a template that will be used as the base
#   (templates can inherit from other templates)
# - `block` accepts a `name` and a block, and will fill the space left by a
# - `yield_block` call with the same name.
# - `superblock` can be called inside `block` blocks to render
#   the contents defined by the parent template

$render.declare 'base', contents: <<-EOT
<!doctype html>
<html>
  <head><title>{% yield_block(:title) do %}Default Title{% end %}</title><head>
  <body>
    <h1>{% yield_block(:title) %}</h1>
    {% yield_block(:contents) do %}{% end %}
  </body>
</html>
EOT

$render.declare 'home', contents: <<-EOT
{% extends :base %}
{% block(:title) do %}{% superblock %} | Home Page{% end %}
EOT

$render.declare 'hello', contents: <<-EOT
{% extends :base %}
{% block(:title) do %}Hello Page{% end %}
{% block(:contents) do %}
  Hello {{name}}!
{% end %}
EOT

module BasicHandler
  # Creates a mapper to define the routes
  # There is no need to assign this to an instance variable,
  # the only advantage in doing so is that if this module
  # is reopened later or another module is mixed in, the
  # same mapper can still be referenced.
  @route = Fiasco::Mapper.bind(self, $app)

module_function

  # A normal method (a helper)
  def out(value)
    $response.write(value)
  end

  # Route for the root
  @route["/"]
  def home
    # Render#[] is an alias for Render#render
    out $render['home']
  end

  # Many mappings can be defined for the same handler method
  # Defaults can be specified
  @route["/hello", defaults: {name: "World"}]
  @route["/hello/<name>"]
  def hello(name)
    out $render['hello', name: name]
  end

  # Handler methods can call other handler methods
  @route["/hello-ip"]
  def hello_ip
    hello($request.ip)
  end

  # Fiasco::Mapper#[] is an alias to Fiasco::Mapper#push
  # Types can be specified for the captured fragments
  # This ensures that the fragments match the desired format
  # and that they are converted when passed as params to the handler
  # The captures and the method parameters can be in different order,
  # they are matched by name.
  @route.push("/sum/<int:num2>/<int:num1>")
  def sum(num1, num2)
    out num1 + num2
  end

  # Mapper#capture defines a "capturing" mapping.
  # Capturing mappings match paths partially (the first part)
  # and promote it to SCRIPT_NAME, while replacing PATH_INFO
  # with the remaining of the path.
  # This can be used for global before/after hooks (by
  # matching on "/", or to call subhandlers.
  # Try visiting "/capturing/Hello/sum/10/33"
  @route.capture("/capturing/<string:title>/")
  def capturing(title)
    out "<h1>#{title}</h1>"
    $app.pass
  end
end

# Handler modules/classes have to be registered
$app.add_handler(BasicHandler)

run $app

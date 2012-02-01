.. Fiasco documentation master file, created by
   sphinx-quickstart on Tue Jan 17 14:58:41 2012.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

.. include:: ../README.rst

Notes
=====

In the examples I use global variables (``$app``, ``$request``, ``$env`` etc), this goes against the "globals are bad" dogma and hurts some sensibilities. This is just the way I choose to do things on my apps. Also keep in mind that Fiasco implements thread-local proxies, which means that the data stored in such globals are not shared between threads.

If this doesn't work for you you can always use other approaches like defining a constant inside the namespace where your application lives for storing those references. It is up to you, Fiasco doesn't prescribe a way of doing things here and it doesn't reference any globals internally.

The same applies to ``@route``. It can be named any way you want, and it doesn't have to be an instance variable, the reason I use it as an instance variable is that it stands out more than a plain 'route'.

Getting Started
===============

**TODO**

Overview
========

**TODO**

Routing
-------

**TODO**

URL Resolution
""""""""""""""

**TODO**

The Request Context
-------------------

**TODO**

Thread-Local Globals
""""""""""""""""""""

**TODO**

Rendering
---------

Rendering of templates is implemented on top of ERB, and provides a few extensions:

- Lines having ``%`` as the the first non-blank character are interpreted as if they were wrapped in ``<% ... %>`` (ERB supports this out of the box, but ``%`` has to be the first character of the line)
- There is support for template inheritance similar to what is found in Django templates and Jinja
- Support for defining macros (a mix between partials and helper methods)

Unlike Rails and Tilt, rendering doesn't share the context of the caller and is implemented in its own separate context.

Rendering is handled by instances of ``Fiasco::Render`` class. Any helper that has to be accessed from the templates, will have to be extended in the renderer instance (with a call to ``extend``):

.. code-block:: ruby

   renderer = Fiasco::Render.new
   renderer.extend MyHelpersModule

Templates have to be declared with the renderer. There are two kinds of declarations:

- File declarations, which specify a file to be parsed.
- Inline template declarations, which pass the template contents themselves.

A file declaration looks like this:

.. code-block:: ruby

   renderer.declare(:template_name, path: 'views/template.erb')

An inline declaration looks like this:

.. code-block:: ruby

   renderer.declare(:anoter_template, contents: '<% 10.times %>.<% end %>')

For an example on how to declare automatically all the templates inside a directory tree, check the Idioms section.

Once a template has been declared, it can be renderer:

.. code-block:: ruby

   render[:another_template] # => '..........'

Any variable that is referenced in the template has to be passed explicitly:

.. code-block:: ruby

   render[:template_with_vars, var1: value1, var2: value2]
   # [] is an alias to render
   render.render(:template_with_vars, var1: value1, var2: value2)


Template Inheritance
""""""""""""""""""""

**TODO**

Macros
""""""

Macros are similar in concept to what utility "partials" are in Rails or Sinatra. The difference is that macros are called directly (they are a method like any other, except that they can't yield, but they can receive explicit blocks)

An example macros file looks like this:

:file:`macros/my_macros.erb`

.. code-block:: template
   
   % macro :input, type: 'text', value: '', size: 20 do |name, type, value, size|
     <input type="<%= type %>" name="<%= name %>" value="<%= value %>" size="<%= size %>">
   % end
   % macro :label, required: false do |text, required|
     <label><%= text %><% if required %><span class=required>*</span><% end %></label>
   % end
   % macro :field, type: 'text', required: false, label: nil do |type, name, label, required|
     <div class=field>
       % label text: label || name.gsub(/[-_]/, ' ').capitalize, required: required
       % input name: name, type: type
     </div>
   % end

Here three macros where defined, ``input``, ``label`` and ``field``.

``macro`` arguments are a name for the macro, a list of default values for the macro arguments (optional), and a block that defines the body of the macro. ``input`` for example takes one required argument ``name:`` and three optional arguments ``type:``, ``value:`` and ``size:`` because they have defaults defined.

To load this file with your renderer object:

.. code-block:: ruby

   renderer = Fiasco::Render.new
   render.load_macros(path: 'macros/my_macros.erb')

After loading a macros file, the macros defined on tha file will be available for templates to invoke like in the following example:

:file:`views/users/signup_form.erb`

.. code-block:: template

   % extends :base

   % block(:main) do
     <form method=post>
       <fieldset>
         % field(name: 'username', value: user.name)
         % field(name: 'password', type: 'password')
         % field(name: 'password_confirm', type: 'password')
       </fieldset>

       <button>Submit</button>
     </form>
   % end

Arguments are all passed by name, for an alternative implementation check the idioms section.

API Reference
=============

.. rb:module:: Fiasco

Core
----

.. rb:class:: Application

    Application object which will be called by Rack.

    .. rb:method:: initialize([options = {}])

        Initializes the application object. A path matcher has to be passed in the ``default_path_matcher:`` option.

    .. rb:method:: add_handler(handler)

        Registers a handler with this application.

    .. rb:method:: call(env)

        Entry point for the application, Rack calls this.

    .. rb:method:: pass([options = {to: nil, skip: nil}])

        Passes control to another handler. If ``to:`` references a handler object, control is passed to it. If ``skip:`` references a handler, control is passed to any handler that isn't the one referenced by ``skip:`` (usually used with ``self``)

    .. rb:method:: not_found

        Sets the response status to 404 and finishes the request.

.. rb:class:: Captures

    Request match captures

    .. rb:method:: matched

        Returns the matched part of the request path.

    .. rb:method:: named

        A mapping of names to captured fragments of PATH_INFO.

    .. rb:method:: remaining

        The rest of PATH_INFO that wasn't captured by a capturing path matcher.

    .. rb:method:: [](name)

        Returns a value from the names to captured fragments mapping. Converts name to a string before using.

.. rb:class:: Matcher

    Request matcher

    .. rb:method:: matches?(env)

        Checks if the current environment matches the rules on this Marcher. If the request matches, a ``Captures`` object is returned.

.. rb:class:: Mapping

    Mapping from matchers to handlers

    .. rb:method:: invoke(target, captures)

        Invokes a handler.

.. rb:class:: Mapper

    Object that handles mapping definitions of matchers to handlers.
 
    .. rb:classmethod:: bind(mod, app[, patch_matcher = app.default_path_matcher])
 
        Returns a Mapper instance bound to the specified module or class and application instance.
 
        Optionally, a path_matcher can be specified, or the default defined by the application will be used

    .. rb:method:: initialize(app, path_matcher_kass)

        Initializes the mapper bound to app and using path_matcher_klass for path matching.
 
    .. rb:method:: push(url_pattern[, options = {}])
 
        Pushers a new matcher rule to the stack.

    .. rb:method:: capture(url_pattern[, options = {}])
 
        Like ``push`` but the matcher rule is defined as capturing.

    .. rb:method:: map(target, method)
 
        Maps a method on target for all the matchers accumulated so far. Clears the matchers stack.

Route Matching
--------------

.. rb:class:: ExtendedPathMatcher

   **TODO**

Rendering
---------

.. rb:class:: Render

   **TODO**


Idioms
======

Fiasco doesn't provide everything out of the box, and the way some parts are implemented may not be the right one for every project or developer taste. Here is a list of code snippets for modifications you can implement, and idioms for functionality not provided.

Application settings
--------------------

The usual way of solving this problem is to parse a YAML file, and to have different environment names for development, staging and production. A different approach will be shown here.

Overview:

- The settings file is just code
- There are two files, one defining the defaults and another defining the overrides
- Setting values can be passed as environment variables
- The path to the overrides file can be passed as an environment variable

Here is how the initialization looks:

.. code-block:: ruby
   :linenos:

    begin
      # Load overrides to the defaults
      require ENV['MYAPP_CONFIG'] || './conf.rb'
    rescue LoadError
      # display warnings if desired
    end

    # Load the defaults
    require './defaults.rb' # will set any options not set by conf.rb

    # ... <snip> ...

    # Use config
    DB = Sequel.connect(Conf::DATABASE_URL)
    Sequel.database_timezone = Conf::DATABASE_TIMEZONE
    Sequel.application_timezone = Conf::APPLICATION_TIMEZONE

    # ... <snip> ...

It first loads the ``conf.rb`` file, which contains the overrides for the current environment (in local it will contain settings for development mode, on staging the settings specific for staging, etc). The location is override-able using an environment variable, this way a different configuration file can be specified when running tests, or paths to configuration files on staging and production servers (Heroku has native support for setting environment variables before launching your application).

A :file:`conf.rb` file where the defaults are overridden for development mode would look like this:

.. code-block:: ruby
   :linenos:

   # conf.rb
   module Conf
     HOST         = 'localhost:9393'
     DATABASE_URL = "postgres://postgres@localhost/myappdb"

     S3_BUCKET    = "test.myapp"
     S3_ACCESS    = "<secret>"
     S3_SECRET    = "<secret>"
   end

And finally, :file:`defaults.rb`. This is the file that defines all the defaults. It is loaded after the file that overrides the defaults has been loaded and only defines values for settings that don't have one already.

.. code-block:: ruby
   :linenos:

   # defaults.rb
   module Conf
     HOST ||= ENV['HOSTNAME']
     
     # Database
     APPLICATION_TIMEZONE  ||= :pst
     DATABASE_TIMEZONE     ||= :utc
     DATABASE_URL          ||= ENV['DATABASE_URL']
  
     # S3
     S3_BUCKET             ||= ENV['S3_BUCKET']
     S3_ACCESS             ||= ENV['S3_ACCESS']
     S3_SECRET             ||= ENV['S3_SECRET']

     # Other
     SEARCH_ENGINES        ||= %w[duckduckgo bing google]

     module Mail
       # Other options can be referenced
       FROM     ||= "MyApp <no-reply@#{HOST}>"
       SERVER   ||= 'smtp.sendgrid.net'
       PORT     ||= '587'
       # Be careful with options that can have a false value
       USE_TLS  = true unless defined? USE_TLS
       USER     ||= ENV['SENDGRID_USERNAME']
       PASSWORD ||= ENV['SENDGRID_PASSWORD']
       DOMAIN   ||= 'heroku.com'
     end
   end

Loading templates from a directory
----------------------------------

Assuming that a project is structured so that all the template files live under a :file:`templates/` directory, here is a way to declare them in a ``Fiasco::Render`` instance without having to mention each of the templates in the code:

.. code-block:: ruby
   :linenos:

    $render = Fiasco::Render.new

    Dir['./templates/**/*.erb'].each do |path|
      # 'templates/home.erb' will be named 'home' ($render['home'])
      # 'templates/albums/edit.erb' will be named 'albums/edit' ($render['albums/edit'])
      # etc
      name = path.gsub(/\.erb$/, '').gsub('./views/', '')
      $render.declare(name, path: path)
    end


Positional arguments support in macros
--------------------------------------

Let's say you have this macro defined

.. code-block:: template

   %# Macro that takes 4 named parameters with some defaults defined
   % macro :input, type: 'text', value: '', size: 20 do |name, type, value, size|
     <input type="<%= type %>" name="<%= name %>" value="<%= value %>" size="<%= size %>">
   % end

Normally it would be invoked it like this:

.. code-block:: template

   <% input(name: 'username', value: user.name) %>

But lets say you want to support positional arguments (something ``Fiasco::Render`` macros don't implement by default) to invoke it like this:

.. code-block:: template

   <% input('username', value: user.name) %>

Here is how it is done:

.. code-block:: ruby
   :linenos:

    # in Fiasco::Render (or a subclass)
    def macro(mname, defaults = {}, &b)
      arguments = b.parameters
      define_singleton_method "__macro__#{mname}", b
      define_singleton_method mname do |*args|
        named = args.last.is_a?(Hash) ? defaults.merge(args.pop) : defaults
        macroargs =
          *(args + arguments.drop(args.length).map{|_, name| named[name]})

        send("__macro__#{mname}", *macroargs)
      end
    end

TODO
====

- Add more examples
- Generation of urls
- Autoescaping in templates
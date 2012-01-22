Fiasco
######

fi·as·co
   noun, plural -cos, -coes.

   #. a complete and ignominious failure.
   #. a round-bottomed glass flask for wine, especially Chianti, fitted with a woven, protective raffia basket that also enables the bottle to stand upright.

Summary
=======

Fiasco is a thin and modular layer on top of Rack inspired by `Flask`_, `Jinja2`_ and `Cuba`_.

It provides routing mechanisms similar to what `Flask`_ provides, and template rendering with support for template inheritance and explicit contexts similar to `Jinja2`_.

One of the goals is to keep the implementation lean and clean.

Fiasco takes a different approach when compared to other libraries:

First, it doesn't enclose access to the request and env objects in a context that is only accessible to the "controller" (there is no such thing as a controller in Fiasco, only methods bound to routes). Any object or module method can be a route handler, there is no need to inherit from a special class, all is needed is that they get mapped to a route by the route mapper.

Second, rendering of templates (also known as 'views') has its own context, any variables that have to be accessed by the template have to be passed explicitly. Helpers that have to be included in the template rendering context too. Basically, unlike in for example Sinatra, the context of your route handlers and your template rendering is completely disjoint.

If you have worked with Python web frameworks, then you are already familiar with this way of working.

Basic Example
=============

Check `examples/basic.ru <https://github.com/tizoc/fiasco/blob/master/examples/basic.ru>`_

To run::

    rackup examples/basic.ru

And visit http://localhost:9292 with your browser.

.. _Flask: http://flask.pocoo.org
.. _Jinja2: http://jinja.pocoo.org
.. _Cuba: http://cuba.is/

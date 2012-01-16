Fiasco
######

Summary
=======

Fiasco is a thin and modular layer on top of Rack inspired by `Flask`_, `Jinja2`_ and `Cuba`_.

It provides routing mechanisms similar to what `Flask`_ provides, and template rendering with support for template inheritance and explicit contexts similar to `Jinja2`_.

The implementation is intended to be lean and clean like in `Cuba`_.

Basic Example
=============

Check ``examples/basic.ru``

To run::

    rackup examples/basic.ru

And visit http://localhost:9292 with your browser.

.. _Flask: http://flask.pocoo.org
.. _Jinja2: http://jinja.pocoo.org
.. _Cuba: http://cuba.is/

import re

from pygments.lexers.web import HtmlLexer
from pygments.lexers.templates import ErbLexer, RhtmlLexer, HtmlLexer

from pygments.lexers.web import \
     PhpLexer, HtmlLexer, XmlLexer, JavascriptLexer, CssLexer
from pygments.lexers.agile import PythonLexer, PerlLexer
from pygments.lexers.compiled import JavaLexer
from pygments.lexer import Lexer, DelegatingLexer, RegexLexer, bygroups, \
     include, using, this
from pygments.token import Error, Punctuation, \
     Text, Comment, Operator, Keyword, Name, String, Number, Other, Token
from pygments.util import html_doctype_matches, looks_like_xml


class AdaptedErbLexer(ErbLexer):
    _block_re = re.compile(r'({{-|{{|{#-|{#|{%-|{%|-}}|-#}|-%}|%}|}}|#}|^\s*%[^%].*?$)', re.M)

    def get_tokens_unprocessed(self, text):
        tokens = self._block_re.split(text)
        tokens.reverse()
        state = idx = 0
        try:
            while True:
                # text
                if state == 0:
                    val = tokens.pop()
                    yield idx, Other, val
                    idx += len(val)
                    state = 1
                # block starts
                elif state == 1:
                    tag = tokens.pop()

                    # comment
                    if tag in ('{#', '{#-'):
                        yield idx, Comment.Preproc, tag
                        val = tokens.pop()
                        yield idx + 3, Comment, val
                        idx += 3 + len(val)
                        state = 2
                    # blocks or output
                    elif tag in ('{%', '{{', '{%-', '{{-'):
                        yield idx, Comment.Preproc, tag
                        idx += len(tag)
                        data = tokens.pop()
                        r_idx = 0
                        for r_idx, r_token, r_value in \
                            self.ruby_lexer.get_tokens_unprocessed(data):
                            yield r_idx + idx, r_token, r_value
                        idx += len(data)
                        state = 2
                    elif tag in ('%}', '-%}', '}}', '-}}', '#}', '-#}'):
                        yield idx, Error, tag
                        idx += len(tag)
                        state = 0
                    # % raw ruby statements
                    else:
                        spaces = tag.index('%') + 1
                        yield idx, Comment.Preproc, tag[0:spaces]
                        r_idx = 0
                        for r_idx, r_token, r_value in \
                            self.ruby_lexer.get_tokens_unprocessed(tag[spaces:]):
                            yield idx + spaces + r_idx, r_token, r_value
                        idx += len(tag)
                        state = 0
                # block ends
                elif state == 2:
                    tag = tokens.pop()
                    if tag not in ('%}', '-%}', '}}', '-}}', '#}', '-#}'):
                        yield idx, Other, tag
                    else:
                        yield idx, Comment.Preproc, tag
                    idx += len(tag)
                    state = 0
        except IndexError:
            return

class FiascoTemplateLexer(RhtmlLexer):
    def __init__(self, **options):
        super(RhtmlLexer, self).__init__(HtmlLexer, AdaptedErbLexer, **options)

def setup(sphinx):
    sphinx.add_lexer('template', FiascoTemplateLexer())

autoprefixer    = require 'autoprefixer'
sass            = require 'node-sass'
CoffeeScript    = require 'coffee-script'
CJSXTransform   = require 'coffee-react-transform'
babel           = require 'babel-core'
marked          = require 'marked'
path = require 'path'

UglifyJS = require 'uglify-js'
sqwish = require 'sqwish'
html_minifier = require 'html-minifier'
_minifyJS = (source) ->
    return UglifyJS.minify(source, mangle: false, fromString: true).code

_minifyCSS = (source) ->
    return sqwish.minify(source)

_minifyHTML = (source) ->
    return html_minifier.minify source,
        collapseWhitespace  : true
        decodeEntities      : true
        removeComments      : true
        minifyJS            : true
        minifyCSS           : true
        minifyURLs          : true

class File
    constructor: ({ @path, @content, @working_directory }) ->
        @filename = @path.split(path.sep).pop()
        [rest..., is_hydrator, ext] = @filename.split('.')
        @is_executable = rest.length > 0 and is_hydrator is 'hydrator'

    compile: (options={}) ->
        [path, content] = compileFile(@path, @content, options)

        if options.minify
            _path_parts = path.split('.')
            switch _path_parts.pop()
                when 'js'
                    unless _path_parts.pop() is 'hydrator'
                        content = _minifyJS(content.toString())
                when 'css'
                    content = _minifyCSS(content.toString())
                when 'html'
                    content = _minifyHTML(content.toString())

        return new CompiledFile({ path, content, @filename, @is_executable })


class CompiledFile
    constructor: ({ @path, @content, @filename, @is_executable }) ->




_processCSS = (css_source) ->
    return autoprefixer.process(css_source.toString()).css


_compileSass = (sass_source, use_indented_syntax=false) ->
    return sass.renderSync(
        data            : sass_source
        includePaths    : []
        indentedSyntax  : use_indented_syntax
    ).css

_compileCoffee = (coffee_source, options) ->
    return CoffeeScript.compile(coffee_source, options)


_compileCJSX = (cjsx_source, options) ->
    return CJSXTransform(cjsx_source)

_compileJSX = (jsx_source, options) ->
    return babel.transform(jsx_source, {
        plugins: [ 'transform-react-jsx' ]
    }).code

_compileMarkdown = (markdown_source, options, { title }) ->
    return """<!doctype html>
    <html>
        <head>
            <meta charset='utf-8' />
            <title>#{ title }</title>
            <style>
                body {
                    max-width: 800px;
                    margin: 0 auto;
                }
            </style>
        </head>
        <body>
            #{ marked(markdown_source) }
        </body>
    </html>"""

compileFile = (pathname, content, options) ->
    ext_match = pathname.match(/\.\w+$/)
    switch ext_match?[0]
        when '.css'
            return [
                pathname
                _processCSS(content.toString())
            ]
        when '.sass', '.scss'
            return [
                pathname.substring(0, ext_match.index) + '.css'
                _processCSS(_compileSass(content.toString(), ext_match[0] is '.sass'))
            ]
        when '.coffee'
            options.bare ?= true
            return [
                pathname.substring(0, ext_match.index) + '.js'
                _compileCoffee(content.toString(), options)
            ]
        when '.cjsx'
            options.bare ?= true
            return [
                pathname.substring(0, ext_match.index) + '.js'
                _compileCoffee(_compileCJSX(content.toString(), options))
            ]
        when '.jsx'
            return [
                pathname.substring(0, ext_match.index) + '.js'
                _compileJSX(content.toString(), options)
            ]
        when '.md'
            _filepath = pathname.substring(0, ext_match.index)
            return [
                _filepath + '.html'
                _compileMarkdown(content.toString(), options, title: _filepath.split('/').pop())
            ]
        # when '.js'
        #     return [
        #         pathname
        #         _compileES(content, options)
        #     ]
        else
            return [
                pathname
                content
            ]

module.exports = {
    CompiledFile
    File
}
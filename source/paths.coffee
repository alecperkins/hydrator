
# Public: convert the given URL pathname to possible paths of compiled files.
#
# url - a String URL pathname, MUST start with a leading /
#
# Returns an Array of String pathnames (with leading /). Empty if none can
# match.
mapURLToCompiled = (url) ->
    url_parts = url.split('/').filter (p) -> p.length > 0
    if url_parts.length is 0
        return ['/index.hydrator.js', '/index.html']

    # Don't allow any subtrees that start with '.', or '_'. These are
    # considered private.
    if url.match(/\/[\.\_]+/g)
        return []

    ext = url.match(/\.\w+$/)
    ext = ext[0] if ext

    # Disallow all source-type files.
    if ext and ext in ['.coffee', '.cjsx', '.jsx', '.sass', '.html', '.htm', '.md']
        return []

    if not ext
        # No extension, so try an executable file and an .html file.
        possibles = [0...url_parts.length].map (i) ->
            "/#{ url_parts[0...(url_parts.length - i)].join('/') }.hydrator.js"
        return [possibles..., "/#{ url_parts.join('/') }.html"]

    # Pass through for images, etc.
    return [url, '/catchall.hydrator.js']



# Public: convert a compiled pathname to possible source pathnames.
#
# pathname - a String path of a compiled file
#
# Returns an Array of String source file paths.
mapCompiledToSource = (pathname) ->
    matched_js = pathname.match(/\.js$/)
    if matched_js
        root = pathname.substring(0, matched_js.index)
        return ['coffee','cjsx','jsx','js'].map (ext) -> "#{ root }.#{ ext }"

    matched_css = pathname.match(/\.css$/)
    if matched_css
        root = pathname.substring(0, matched_css.index)
        return ['sass','css'].map (ext) -> "#{ root }.#{ ext }"

    matched_html = pathname.match(/.html$/)
    if matched_html
        root = pathname.substring(0, matched_html.index)
        # if root
        return ["#{ root }.html", "#{ root }.md"]
        # return ['/index.html', '/index.md']

    return [pathname]



# Public: a combination of mapURLToCompiled and mapCompiledToSource.
#
# url - a String URL path
#
# Returns an Array of String paths, or an empty Array if none match.
mapURLToSource = (url) ->
    paths = []
    mapURLToCompiled(url).forEach (compiled) ->
        paths.push(mapCompiledToSource(compiled)...)
    return paths



# Public: convert a source path to a compiled path. Files that are considered
# private, or are in an invalid location, cannot be compiled.
#
# source - a String source path
#
# Returns a String compiled path, or null if the file cannot be compiled.
mapSourceToCompiled = (source) ->

    if source.match(/\/[\.\_]+/g)
        return null

    ext_match = source.match(/\.\w+$/)
    if ext_match
    
        if ext_match[0] in ['.sass', '.css']
            return "#{ source.substring(0, ext_match.index) }.css"

        # CoffeeScript/(C)JSX/JavaScript
        if ext_match[0] in ['.coffee', '.cjsx', '.jsx', '.js']
            return "#{ source.substring(0, ext_match.index) }.js"

        if ext_match[0] is '.html'
            return "#{ source.substring(0, ext_match.index) }.html"

        if ext_match[0] is '.md'
            return "#{ source.substring(0, ext_match.index) }.md"

        # Disallow .htm files for clarity.
        if ext_match[0] is '.htm'
            return null
            
        return source

    return null

mapCompiledToURL = (compiled) ->
    
    # Don't allow any subtrees that start with '.', or '_'. These are
    # considered private.
    if compiled.match(/\/[\.\_]+/g)
        return null

    if compiled is 'catchall.hydrator.js'
        return '/*'

    match = compiled.match(/([\w\d\/\-\_\.]*\/)([\w\d\-\_\.]+).hydrator.js$/)
    if match
        if match[2] isnt 'index'
            return match[1] + match[2] + '/*'
        return match[1]

    match = compiled.match(/([\w\d\/\-\_\.]*\/)([\w\d\-\_\.]+).html$/)
    if match
        if match[2] isnt 'index'
            return match[1] + match[2] + '/'
        return match[1]

    return compiled

mapSourceToURL = (source) ->
    return mapCompiledToURL(
        mapSourceToCompiled(source)
    )

module.exports = {
    mapURLToCompiled
    mapCompiledToSource
    mapURLToSource
    mapSourceToCompiled
    mapCompiledToURL
    mapSourceToURL
}

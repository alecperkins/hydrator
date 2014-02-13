
{ CompilableFile, ExecutableFile, StaticFile } = require './File'

class Site
    constructor: (site_root) ->
        @root = site_root

    getTargetFile: (path_components) ->
        for f in @_getTargetFilePaths(path_components)
            return f if f.exists()
        return null

    # Internal: get the possible file paths that could handle the given
    #   request.
    #
    # path_components - the request path, split by `'/'`.
    #
    # Returns a list of Files and/or ExecutableFiles that match the request
    # path, in the order they should be tried.
    _getTargetFilePaths: (path_components) ->

        # Request is to /
        if path_components.length is 0
            return [
                new ExecutableFile(this, 'index')
                new StaticFile(this, 'index.html')
                new CompilableFile(this, 'index.md')
                new ExecutableFile(this, '*')
            ]

        # If any of the path components start with an underscore,
        # consider the path private and return no files.
        for c in path_components
            if c[0] is '_'
                return []

        # Request is to /<component>/ or /<file>.<ext>
        if path_components.length is 1

            component = path_components[0].split('.')

            # Request is to /<component>/
            if component.length is 1
                return [
                    new ExecutableFile(this, path_components[0])
                    new StaticFile(this, path_components..., 'index.html')
                    new CompilableFile(this, path_components..., 'index.md')
                    new CompilableFile(this, component + '.md')
                    new StaticFile(this, path_components...)
                    new ExecutableFile(this, '*')
                ]

            # Direct linking to root coffee files it not permitted,
            # so return an empty file list.
            if component[component.length - 1] is 'coffee'
                return []

            # Request is to /<file>.<ext>
            paths = [
                new StaticFile(this, path_components...)
            ]
            # /<file>.html
            if component[component.length - 1] is 'html'
                alt_version = [
                    [component[...-1]..., 'md'].join('.')
                ]
                paths.push(new CompilableFile(this, alt_version...))
            paths.push(new ExecutableFile(this, '*'))
            return paths

        # Request is to /<component>/<component>...
        last_c = path_components[path_components.length - 1].split('.')

        # Request is to /**/<component>/
        if last_c.length is 1
            return [
                new ExecutableFile(this, path_components[0])
                new StaticFile(this, path_components..., 'index.html')
                new CompilableFile(this, path_components..., 'index.md')
                new CompilableFile(this, path_components[0...-1]..., last_c[0] + '.md')
                new StaticFile(this, path_components...)
                new ExecutableFile(this, '*')
            ]

        # Request is to /**/<file>.<ext>
        paths = [
            new StaticFile(this, path_components...)
        ]
        # It's possibly the output of a compilable file, so include the possible
        # source file.
        if last_c[last_c.length - 1] is 'js'
            alt_version = [
                path_components[...- 1]...
                [last_c[...-1]..., 'coffee'].join('.')
            ]
            paths.push(new CompilableFile(this, alt_version...))
        else if last_c[last_c.length - 1] is 'html'
            alt_version = [
                path_components[...- 1]...
                [last_c[...-1]..., 'md'].join('.')
            ]
            paths.push(new CompilableFile(this, alt_version...))
        paths.push(new ExecutableFile(this, '*'))
        return paths

module.exports = Site

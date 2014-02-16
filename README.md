Hydrator - rehydrated static files
==================================

[![NPM version](https://badge.fury.io/js/hydrator.png)](http://badge.fury.io/js/hydrator) [![Build Status](https://travis-ci.org/alecperkins/hydrator.png)](https://travis-ci.org/alecperkins/hydrator)

Hydrator is a small web application framework for semi-static sites. It maps URL paths to files, compiling certain kinds of assets on-the-fly, as appropriate. Hydrator also allows for dynamic content, with CoffeeScript files that can be executed to generate a response.

Static files (`.html`, `.js`, `.css`, `.jpg`, …) are passed through. Compilable files (`.md`, `.coffee`) are compiled and returned. `.coffee` files in the root project folder are treated as dynamic content handlers. Instead of being compiled and returned, they are executed inside a sandbox and given helpers for generating a response.

The bare minimum for a dynamic file is calling `response.ok()` with response text:

    response.ok """
            <h1>Hello, world!</h1>
            <p>#{ new Date() }</p>
        """


## Usage

### Installation

Hydrator works as a CLI, and is best used when installed globally:

    $ npm install -g hydrator

### CLI

The Hydrator CLI has two commands: `create`, `serve`.

#### `create`

Create a Hydrator project of the given name:

    $ hydrator create <project_name>

This creates a folder named `<project_name>`, and populates it with the files necessary to run the project as a Heroku app. It also initializes it as a git repository.

    <project_name>/
        www/
            index.coffee
        .env
        .gitignore
        package.json
        Procfile
        README.md

#### `serve`

Start the Hydrator server using the given current project.

    $ hydrator serve <project_name>

`$ hydrator serve .` also works. If using the [Heroku toolbelt](https://toolbelt.heroku.com), the recommended way of running the project is `$ foreman start` from inside the project, because this will automatically load environment variables from the `.env` file.


### Projects

A Hydrator project consists of a folder with a `package.json` and a subfolder, named `www`, that contains the actual web content. Other files, like those generated above, can be used to run the project on hosts like Heroku.

For example, the following project structure maps to these URLs:

    project_name/
        www/
            index.html          - /
            about.md            - /about/               or /about.html
            api.coffee          - /api/*
            data.json           - /data.json
            _info.md            - 404
            _api_modules/
                service.coffee  - 404
            some-path/
                index.md        - /some-path/           or /some-path/index.html
                info.md         - /some-path/info/      or /some-path/info.html
            assets/
                script.coffee   - /assets/script.js
                style.css       - /assets/style.css
                icon.png        - /assets/icon.png
            other-files/
                module.coffee   - /other-files/module.js
                library.js      - /other-files/library.js
        package.json

A request to `/` is served by the `/index.html` file (could also be `/index.coffee` or `/index.md`). `/about/` is handled by the `/about.md` file, which is compiled into HTML on-the-fly. `/assets/script.js` matches the corresponding CoffeeScript source file, which is compiled to JavaScript and served. `/api/`, and any paths under that, are handled by `/api.coffee`, which is compiled to JavaScript and executed inside a sandbox. The file `/package.json` is unaccessible externally.

URLs generally match the file by path. Non-compilable or -executable files are simply returned as is. Files that can be compiled from Markdown or CoffeeScript match a URL suitable for their output (and cannot be served in raw form). CoffeeScript files at the root level will match any path starting with their name. The `*.coffee` file can be used as a catch-all, and if present will handle any request if it’s not matched by something else. Like compiled files, these executable files cannot be served directly. Note: files and folders beginning with an underscore are considered private; they may be accessed by executable files, but will return a 404 if attempted to be reached directly. URLs that do not end in a trailing slash but should (as in not directed at a file) are redirected to the URL with a trailing slash. A URL like `/about` goes to `/about/`, while `/script.js` does not.

#### Sandbox

Executable CoffeeScript files are run inside a sandbox that is given globals with information about the current request, functions to send a response, and various helpers and utilities. These files cannot `require` any modules.

The sandbox globals are:

* `env`

  Environment variables.

* `restler`

  [`restler`](https://github.com/danwrong/restler) HTTP request library.

    * `get(url, headers={}, query={})`
    * `post(url, headers={}, query={}, data={})`    
    * `put(url, headers={}, query={}, data={})`
    * `patch(url, headers={}, query={}, data={})`
    * `delete(url, headers={}, query={})`

* `request`

  Information about the current request.

    * `url`
    
       The full URL of the request, eg `'http://example.com/hello/world/?parameter=value'`.

    * `path`
       
       The path of the URL in component form, eg `['hello','world']`.

    * `path_string`
    
       The path of the URL as a string, eg `'/hello/world/'`.

    * `query`
    
       The parsed query parameters of the URL, eg `{ parameter: 'value' }`.

    * `query_string`
    
       The raw query parameter string, eg `'?parameter=value'`.
    
    * `host`
    
       The host of the URL, eg `'example.com'`.
    
    * `method`
    
       The method of the request, eg `'PUT'`.

    * `headers`
        
       The headers of the request, eg `{ 'Accepts': 'application/json' }`.

* `response`

  Functions for sending a response. Each corresponds to a specific response status code. Only one function can be called once per request. These methods can generally all take JSON-serializable data in addition to Strings, and will serialize and set the appropriate `Content-Type` if that is the case.

  They generally follow the signature `function(response_data, headers={})`.

    * (200) `ok`
    * (201) `created`
    * (204) `noContent` - Does not take `response_data`
    * (301) `permanentRedirect` - `response_data` becomes the `Location` header
    * (302) `temporaryRedirect` - `response_data` becomes the `Location` header.
    * (400) `badRequest`
    * (401) `unauthorized`
    * (403) `forbidden`
    * (404) `notFound`
    * (405) `methodNotAllowed`
    * (410) `gone`
    * (500) `internalServerError`


#### Mult-tenant

A single project can support multiple sites, differentiated by host. To do this, group the content for each site into its own folder within the project’s `www/` folder. Then, in `package.json`, add an entry that maps the hosts to the folder names, like so:

```json
  "hydrator": {
    "sites": {
      "example.com": "site_name",
      "otherhost": "other_site"
    }
  }
```

Each folder name will be the root of the site as matched by the host. Note: you can omit the `www.` from the domain. It will be stripped when matching, so `www.example.com` and `example.com` would both match `site_name`.


## Examples

Some example single-serving sites:

* [Sample site](http://hydrator.herokuapp.com) ([source](https://github.com/alecperkins/hydrator-sample-site))
* [#flooralpatterns](http://flooralpatterns.net)
* [URLTEXT](http://urltext.cc)
* [nothisisepic.com](http://nothisisepic.com)
* [howthefuckdoitar.com](http://howthefuckdoitar.com)
* [What’s up, world?](http://whatsupworld.info)

Some are relatively low traffic and share infrastructure using the multi-tenant feature. This way they, can keep the Heroku instance awake and have improved response time.


## By

[Alec Perkins](http://alecperkins.net)
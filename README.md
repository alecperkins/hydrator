Hydra
=====

Hydra is a multi-tenant, semi-static web hosting application. In addition to
serving flat files, it can compile certain file types on the fly. Also, it
can execute [CoffeeScript](http://coffeescript.org)-based files that match
certain URL paths, allowing them to dynamically construct a response. It’s
best used for small, mostly static, low-traffic “single-serving” sites.

For example, the following project structure maps to these URLs:

    project_name/
        index.html          - /
        about.md            - /about/               or /about.html
        api.coffee          - /api/*
        data.json           - /data.json
        package.json        - 404
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

A request to `/` is served by the `/index.html` file (could also be
`/index.coffee` or `/index.md`). `/about/` is handled by the `/about.md` file,
which is compiled into HTML on-the-fly. `/assets/script.js` matches the
corresponding CoffeeScript source file, which is compiled to JavaScript and
served. `/api/`, and any paths under that, are handled by `/api.coffee`,
which is compiled to JavaScript and executed inside a sandbox. The file
`/package.json` is unaccessible externally.

URLs generally match the file by path. Non-compilable or -executable files are
simply returned as is. Files that can be compiled from Markdown or
CoffeeScript match a URL suitable for their output (and cannot be served in
raw form). CoffeeScript files at the root level will match any path starting
with their name. The `*.coffee` file can be used as a catch-all, and if
present will handle any request if it’s not matched by something else. Like
compiled files, these executable files cannot be served directly. Note: files
and folders beginning with an underscore are considered private; they may be
accessed by executable files, but will return a 404 if attempted to be reached
directly. URLs that do not end in a trailing slash but should (as in not
directed at a file) are redirected to the URL with a trailing slash. A URL
like `/about` goes to `/about/`, while `/script.js` does not.


## Sandbox

Executable CoffeeScript files are run inside a sandbox that is given globals
with information about the current request, functions to send a response, and
various helpers and utilities. These files cannot `require` any modules.

The bare minimum for an executable file is:

    response.ok('<p>Response text.</p>')

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
    
       The parse query parameters of the URL, eg `{ parameter: 'value' }`.

    * `query_string`
    
       The raw query parameter string, eg `'?parameter=value'`.
    
    * `host`
    
       The host of the URL, eg `'example.com'`.
    
    * `method`
    
       The method of the request, eg `'PUT'`.

    * `headers`
        
       The headers of the request, eg `{ 'Accepts': 'application/json' }`.

* `response`

  Functions for sending a response. Each corresponds to a specific response
  status code. Only one function can be called once per request. These methods
  can generally all take JSON-serializable data in addition to Strings, and
  will serialize and set the appropriate `Content-Type` if that is the case.

  They generally follow the signature `function(response_data, headers={})`

    * `ok` (200)
    * `created` (201)
    * `noContent` (204)

       Does not take `response_data`.

    * `permanentRedirect` (301)

       `response_data` becomes the `Location` header.

    * `temporaryRedirect` (302)

       `response_data` becomes the `Location` header.

    * `badRequest` (400)
    * `unauthorized` (401)
    * `forbidden` (403)
    * `notFound` (404)
    * `methodNotAllowed` (405)
    * `gone` (410)
    * `internalServerError` (500)

## Try it out

Requires [node.js](http://nodejs.org).

1. Clone the repo

  `$ git clone https://github.com/alecperkins/hydra.git`

2. Install dependencies

  `$ npm install`

3. Run

  `$ npm start`

4. Check out the sample site running at [`localhost:5000`](http://localhost:5000)

5. Add a site to the `sites` Object in `main.coffee`, and place its content
   in its own site folder within the `www` folder.

### Heroku

The project is all set up to run on Heroku.

0. Install the [Heroku toolbelt](http://toolbelt.heroku.com)

1. Remove the previous git repo, if any

   `$ rm -rf .git`

2. Initialize the repo

   `$ git init`

3. Create the Heroku app

   `$ heroku create`

4. Change the `sites` mapping in `main.coffee` to match the host of the created app

   `'foo-bar.herokuapp.com': 'sample_site'`

5. Commit the project

   `$ git commit -a -m 'Initial commit'`

6. Deploy the application

   `$ git push heroku master`


## Examples

Some example single-serving sites:

* [Sample site](http://app-hydra.herokuapp.com)
* [#flooralpatterns](http://flooralpatterns.net)
* [URLTEXT](http://urltext.cc)
* [nothisisepic.com](http://nothisisepic.com)
* [howthefuckdoitar.com](http://howthefuckdoitar.com)
* [What’s up, world?](http://whatsupworld.info)

They each are relatively low traffic sites. By sharing infrastructure, they
can keep the Heroku instance awake and have improved response time. Also, the
actual application code for each is simplified a bit (though that’s
independent of the multi-tenant aspect).

## Notes

Things to think about and explore:

* Additional compilers for stylus, jade
* Decouple sites from application repo
    * Storage backends: Dropbox, S3, GitHub
    * auth with Dropbox or GitHub

## By

[Alec Perkins](http://alecperkins.net)

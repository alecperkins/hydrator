Hydrator - rehydrated static files
==================================

[![NPM version](https://badge.fury.io/js/hydrator.png)](http://badge.fury.io/js/hydrator)

Hydrator is a web application tool and hosting service for semi-static sites. It maps URL paths to files, compiling certain kinds of assets on-the-fly, as appropriate. Hydrator also allows for dynamic content, with JavaScript files that can be executed to generate a response. Think [AWS Lambda](https://aws.amazon.com/lambda/) meets [Surge.sh](http://surge.sh/).

Static files (`.html`, `.js`, `.css`, `.jpg`, …) are passed through. Compilable files (`.md`, `.coffee`, `.sass`) are compiled and returned. JavaScript files with a `.hydrator.js` extension are considered executable. Instead of being compiled and returned, they are executed inside a sandbox and given helpers for generating a response.

The bare minimum for a dynamic file is calling `response.ok()` with response text:

```javascript
response.ok(`Hello, world! ${ new Date() }`)
```

[CoffeeScript](http://coffeescript.org/), [JSX](https://facebook.github.io/react/docs/jsx-in-depth.html), and [CJSX](https://github.com/jsdf/coffee-react) may also be used for executable files. For example, using CJSX

```cjsx
View = (props) ->
    <div>
        <h1>Hello, world!</h1>
        <p>{ props.date }</p>
    </div>

response.ok(<View date={ new Date() } />)
```


## Usage

### Quickstart

1. `npm install --global hydrator`
2. `mkdir my-project`
3. `echo "response.ok('Hello, world! ' + new Date())" > my-project/index.hydrator.js`
4. `hydrator deploy my-project --email user@example.com`

The project is now deployed at [sparkling-waterfall-62f644.rehydrated.site](http://sparkling-waterfall-62f644.rehydrated.site).



### Installation

Hydrator works as a CLI, and is best used when installed globally:

    $ npm install --global hydrator

### CLI

#### `serve`

Start the Hydrator server using the given current project.

    $ hydrator serve <project_name>
    Server listening at localhost:5000...

`hydrator serve .` or `hydrator serve` from inside the project folder also work.

By default, the server listens to hostname `localhost` and port `5000`. To customize this, use the `--host` and `--port` options, eg `hydrator serve --host 0.0.0.0 --port 8000`.

#### `urls`

List the mapping of source file to URLs.

#### `deploy`

Hydrator has a companion hosting service. Simply run `hydrator deploy` from the project folder and it will be deployed to the world:

    $ hydrator deploy
    Creating host...done!
    Uploading project...done!
    Project successfully uploaded to sparkling-waterfall-62f644.rehydrated.site

The details of the deployment are stored in a `.rehydrator.json` file in the project folder. Don‘t lose or share it! It contains the key for deploying to that host. If you do, [let me know](mailto:hydrator@alecperkins.me) and I’ll figure something out.

(The first deploy, an email address is required for verification in case of the above scenario. The address itself is not transmitted, only a bcrypt hash is. It will be saved and reused for all subsequent deployments, though it can be overridden using the `--email` option.)

##### Custom subdomain

By default, the hostname will be randomly generated. It can be customized using the `--host <name>` option:

`hydrator deploy --host example` will deploy to [example.rehydrated.site](http://example.rehydrated.site) (if available).

##### Fully custom host

`hydrator deploy --host example.com` will deploy to [example.com](http://example.com) (if available).
This requires changing your DNS settings to point an ALIAS/CNAME record to `rehydrated.site`. [CloudFlare](https://cloudflare.com) and [DNSimple](https://dnsimple.com) provide CNAME or ALIAS support for apex domains.

##### Multiple hosts

A project can be deployed to multiple hosts by specifying a new host through the `--host <hostname>` option, or to another randomly generated subdomain using `--auto`. There is no limit to how many hosts a project can be deployed to.

#### `hosts`

List the hosts the project is deployed to.

#### `destroy`

Destroy the specified remote host. The `--host <hostname>` option is required for this.



### Projects

A Hydrator project consists of a folder. No special files or directory structure need to be created. The URLs for the project will map onto the on-disk filenames.

For example, the following project structure maps to these URLs:

    project_name/
        index.html          - /
        about.md            - /about/
        api.hydrator.coffee - /api/*
        data.json           - /data.json
        _info.md            - 404
        some-path/
            index.md        - /some-path/
            info.md         - /some-path/info/
        assets/
            script.coffee   - /assets/script.js
            style.sass      - /assets/style.css
            icon.png        - /assets/icon.png
        other-files/
            module.coffee   - /other-files/module.js
            library.js      - /other-files/library.js

A request to `/` is served by the `/index.html` file (could also be `/index.hydrator.js` or `/index.md`). `/about/` is handled by the `/about.md` file, which is compiled into HTML on-the-fly. `/assets/script.js` matches the corresponding CoffeeScript source file, which is compiled to JavaScript and served. `/api/`, and any paths under that, are handled by `/api.hydrator.coffee`, which is compiled to JavaScript and executed inside a sandbox. The file `/_info.md` starts with an underscore, and is not visible externally.

URLs generally match the file by path. Non-compilable or -executable files are simply returned as-is. Files that can be compiled from Markdown or CoffeeScript match a URL suitable for their output (and cannot be served in raw form). Executable files will match anything in their subtree. The `catchall.hydrator.js` file can be used as a catch-all, and if present will handle any request if it’s not matched by something else. Like compiled files, these executable files cannot be served directly. Note: files and folders beginning with an underscore are considered private and will return a 404 if attempted to be reached directly. URLs that do not end in a trailing slash but should (as in not directed at a file) are redirected to the URL with a trailing slash. A URL like `/about` goes to `/about/`, while `/script.js` does not.

#### Sandbox

Executable files are run inside a sandbox that is given globals with information about the current request, functions to send a response, and various helpers and utilities. These files cannot `require` any modules.

The sandbox globals are:

* `http`

  Functions for making HTTP requests.

    * `get(_url, _query={}, _headers={})`
    * `getJSON(_url, _query={}, _headers={})`

* `request`

  Information about the current request.

    * `url` - The URL of the request, eg `'/hello/world/?parameter=value'`.
    * `pathname` - The path of the request URL, eg `'/hello/world/'`.
    * `query` - The parsed query parameters of the URL, eg `{ parameter: 'value' }`.
    * `host` - The host of the request, eg `'example.com'`.
    * `method` - The method of the request, eg `'PUT'`.
    * `headers` - The headers of the request, eg `{ 'Accepts': 'application/json' }`.
    * `body` - The body of the request, parsed into an Object.

* `response`

  Functions for sending a response. Each corresponds to a specific response status code. Only one function can be called once per request. These methods can generally all take JSON-serializable data in addition to Strings, and will serialize and set the appropriate `Content-Type` if that is the case.

  They generally follow the signature `function(response_data, headers={})`.

    * (`200`) `response.ok`
    * (`201`) `response.created`
    * (`204`) `response.noContent` - Does not take `response_data`
    * (`301`) `response.permanentRedirect` - `response_data` becomes the `Location` header
    * (`302`) `response.temporaryRedirect` - `response_data` becomes the `Location` header.
    * (`400`) `response.badRequest`
    * (`401`) `response.unauthorized`
    * (`403`) `response.forbidden`
    * (`404`) `response.notFound`
    * (`405`) `response.methodNotAllowed`
    * (`410`) `response.gone`
    * (`500`) `response.internalServerError`

  `response_data` can be a string, React element, or JSON-serializable object.

* `React`, `ReactDOMServer`

   The [React](https://facebook.github.io/react/) packages for server-side use.



## By

[Alec Perkins](http://alecperkins.net)


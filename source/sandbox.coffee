request_lib     = require 'request'
React           = require 'react'
ReactDOMServer  = require 'react-dom/server'
vm              = require 'vm'

makeHTTPGetRequest = (_url, _query={}, _headers={}) ->
    new Promise (resolve, reject) ->
        request_lib.get {
            uri: _url
            qs: _query
            headers: _headers
        }, (err, res, body) ->
            if err
                console.error(err)
                reject(err)
                return
            resolve(body)

makeHTTPGetJSONRequest = (_url, _query={}, _headers={}) ->
    new Promise (resolve, reject) ->
        request_lib.get {
            uri: _url
            qs: _query
            _headers: _headers
            json: true
        }, (err, res, body) ->
            if err
                console.error(err)
                reject(err)
                return
            resolve(body)



module.exports =
    executeFile: ({ project, request, file_to_execute }) ->

        return new Promise (resolve, reject) ->

            sandbox_script = """"use strict";
                (function () {
                    #{ file_to_execute }
                })();
            """

            script = new vm.Script(sandbox_script)

            _http =
                get: makeHTTPGetRequest
                getJSON: makeHTTPGetJSONRequest

            _sendResponse = (code, body='', headers={}) ->
                if React.isValidElement(body)
                    body = '<!doctype html>' + ReactDOMServer.renderToStaticMarkup(body)
                    content_type = 'text/html'
                else if typeof body is 'object'
                    body = JSON.stringify(body)
                    content_type = 'application/json'
                else
                    content_type = 'text/html'
                headers['Content-Type'] ?= content_type
                resolve
                    code    : code
                    body    : body
                    headers : headers
                return

            response =
                # (data, headers={})
                ok                  : -> _sendResponse(200, arguments...)
                created             : -> _sendResponse(201, arguments...)
                noContent           : -> _sendResponse(204, arguments...)
                permanentRedirect: (data, headers={}) ->
                    headers['Location'] = data
                    _sendResponse(301, '', headers)
                temporaryRedirect: (data, headers={}) ->
                    headers['Location'] = data
                    _sendResponse(302, '', headers)
                notModified: (data, headers={}) ->
                    _sendResponse(304, '', headers)
                badRequest          : -> _sendResponse(400, arguments...)
                unauthorized        : -> _sendResponse(401, arguments...)
                forbidden           : -> _sendResponse(403, arguments...)
                notFound            : -> _sendResponse(404, arguments...)
                methodNotAllowed    : -> _sendResponse(405, arguments...)
                gone                : -> _sendResponse(410, arguments...)
                internalServerError : -> _sendResponse(500, arguments...)

            try
                script.runInNewContext({
                        request         : request
                        response        : response
                        http            : _http
                        React           : React
                        ReactDOMServer  : ReactDOMServer
                    },
                    {
                        timeout: 10 * 1000
                    }
                )
            catch e
                console.error(e)
                reject(e)

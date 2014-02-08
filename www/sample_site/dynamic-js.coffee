
# This file demonstrates dynamically constructing JavaScript.

RENDER_TIME = Date.now()

output_js = """
    (function(){
        var RENDER_TIME = new Date(#{ RENDER_TIME });

        console.log('Rendered at', RENDER_TIME.toISOString());
        console.log('It is now', (new Date()).toISOString());
    })();
"""

response.ok(output_js, headers={'Content-Type':'application/javascript'})

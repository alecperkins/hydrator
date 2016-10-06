// _preprocessor.js
var coffee = require('coffee-script');
var CJSXTransform = require('coffee-react-transform');

module.exports = {
    process: function(src, path) {
        if (path.match(/\.coffee$/)) {
            return coffee.compile(src, {bare: true});
        }
        if (path.match(/\.cjsx$/)) {
            return coffee.compile(
                CJSXTransform(src),
                {bare: true}
            );
        }
        return src;
    }
};

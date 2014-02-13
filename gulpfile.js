var gulp    = require('gulp');

var coffee  = require('gulp-coffee');
var gutil   = require('gulp-util');


gulp.task('build', function() {
    gulp.src('source/*.coffee')
        .pipe(coffee({bare: true})).on('error', gutil.log)
        .pipe(gulp.dest('./build'));
});

gulp.task('default', function() {
    gulp.run('build');

    gulp.watch([
        'source/*.coffee'
    ], function(event) {
        gulp.run('build');
    });
});

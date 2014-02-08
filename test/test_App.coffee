require 'should'



describe 'App.getTargetFilePaths', ->
    { getTargetFilePaths } = require '../App.coffee'

    withInput = (input_path) ->
        return getTargetFilePaths(input_path).map (f) -> [f.path, f.executable]

    it 'should choose index files', ->
        withInput([]).should.eql([
                ['index.coffee', true]
                ['index.html', false]
                ['index.md', false]
                ['*.coffee', true]
            ])

    it 'should ignore private files', ->
        withInput(['test.coffee']).should.eql([])
        withInput(['_test.coffee']).should.eql([])
        withInput(['_test','.coffee']).should.eql([])
        withInput(['test','_test.coffee']).should.eql([])
        withInput(['test','test','_test.coffee']).should.eql([])
        withInput(['test','_test']).should.eql([])

    it 'should match directories', ->
        withInput(['test']).should.eql([
            ['test.coffee', true]
            ['test/index.html', false]
            ['test/index.md', false]
            ['test.md', false]
            ['test', false]
            ['*.coffee', true]
        ])
        withInput(['test1','test2']).should.eql([
            ['test1.coffee', true]
            ['test1/test2/index.html', false]
            ['test1/test2/index.md', false]
            ['test1/test2.md', false]
            ['test1/test2', false]
            ['*.coffee', true]
        ])

    it 'should match file paths', ->
        withInput(['test.ext']).should.eql([
            ['test.ext', false]
            ['*.coffee', true]
        ])
        withInput(['test1','test2.ext']).should.eql([
            ['test1/test2.ext', false]
            ['*.coffee', true]
        ])
        withInput(['test1','test2','test3.ext']).should.eql([
            ['test1/test2/test3.ext', false]
            ['*.coffee', true]
        ])

    it 'should match nested compilable file paths', ->
        withInput(['test.js']).should.eql([
            ['test.js', false]
            ['*.coffee', true]
        ])
        withInput(['test.html']).should.eql([
            ['test.html', false]
            ['test.md', false]
            ['*.coffee', true]
        ])
        withInput(['test1','test2.js']).should.eql([
            ['test1/test2.js', false]
            ['test1/test2.coffee', false]
            ['*.coffee', true]
        ])
        withInput(['test1','test2.html']).should.eql([
            ['test1/test2.html', false]
            ['test1/test2.md', false]
            ['*.coffee', true]
        ])
        withInput(['test1','test2','test3.js']).should.eql([
            ['test1/test2/test3.js', false]
            ['test1/test2/test3.coffee', false]
            ['*.coffee', true]
        ])
        withInput(['test1','test2','test3.html']).should.eql([
            ['test1/test2/test3.html', false]
            ['test1/test2/test3.md', false]
            ['*.coffee', true]
        ])
fs = require 'fs'
cli = require 'cli'
htmlencode = require 'htmlencode'

class XUnitReporter
  constructor: (emitter, stats, tests, path) ->
    @type = "xUnit"
    @stats = stats
    @tests = tests
    @path = @sanitizedPath(path)
    @configureEmitter emitter

  sanitizedPath: (path) =>
    filePath = process.cwd() + "/report.xml" unless path?
    if fs.existsSync(filePath)
      cli.info "File exists at #{filePath}, deleting..."
      fs.unlinkSync(filePath)
    filePath

  configureEmitter: (emitter) =>
    emitter.on 'start', =>
      appendLine @path, toTag('testsuite', {
              name: 'Dredd Tests'
            , tests: @stats.tests
            , failures: @stats.failures
            , errors: @stats.errors
            , skip: @stats.skipped
            , timestamp: (new Date).toUTCString()
            , time: @stats.duration / 1000
          }, false)

    emitter.on 'end', =>
      appendLine @path, '</testsuite>'
      updateSuiteStats(@path, @stats)

    emitter.on 'test pass', (test) =>
      attrs =
        name: htmlencode.htmlEncode test.title
        time: test.duration / 1000
      appendLine @path, toTag('testcase', attrs, true)

    emitter.on 'test skip', (test) =>
      logger.skip test.title

    emitter.on 'test fail', (test) =>
      attrs =
        name: htmlencode.htmlEncode test.title
        time: test.duration / 1000
      diff = "Message: \n" + test.message + "\nExpected: \n" +  (JSON.stringify test.expected, null, 4) + "\nActual:\n" + (JSON.stringify test.actual, null, 4)
      appendLine @path, toTag('testcase', attrs, false, toTag('failure', null, false, cdata(diff)))

    emitter.on 'test error', (test, error) =>
      attrs =
        name: htmlencode.htmlEncode test.title
        time: test.duration / 1000
      errorMessage = "Message: \n" + test.message + "\nError: \n"  + error
      appendLine @path, toTag('testcase', attrs, false, toTag('failure', null, false, cdata(test.message)))

  updateSuiteStats = (path, stats) ->
    fs.readFile path, (err, data) ->
      if !err
        data = data.toString()
        position = data.toString().indexOf('\n')
        if (position != -1)
          restOfFile = data.substr position + 1
          newStats = toTag 'testsuite', {
              name: 'Dredd Tests'
            , tests: stats.tests
            , failures: stats.failures
            , errors: stats.errors
            , skip: stats.skipped
            , timestamp: (new Date).toUTCString()
            , time: stats.duration / 1000
          }, false

          fs.writeFile path, newStats + '\n' + restOfFile, (err) ->
            if err
              cli.error err
      else
        cli.error err

  cdata = (str) ->
    return '<![CDATA[' + str + ']]>'

  appendLine = (path, line) ->
    fs.appendFileSync(path, line + "\n")

  toTag = (name, attrs, close, content) ->
    end = (if close then "/>" else ">")
    pairs = []
    tag = undefined
    for key of attrs
      pairs.push key + "=\"" + attrs[key] + "\""
    tag = "<" + name + ((if pairs.length then " " + pairs.join(" ") else "")) + end
    tag += content + "</" + name + end  if content
    tag

module.exports = XUnitReporter

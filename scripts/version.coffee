version = require('../package.json').version

module.exports = (robot) ->
  robot.respond /версия/i, (res) ->
    res.send(version)

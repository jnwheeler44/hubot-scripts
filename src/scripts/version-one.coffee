# Description:
#   Show VersionOne story information
#
# Dependencies:
#   "xml2js": "0.2.6",
#   "request": "2.16.6",
#   "underscore": ">=1.3.0"
#
# Configuration:
#   HUBOT_VERSION_ONE_USERNAME
#   HUBOT_VERSION_ONE_PASSWORD
#   HUBOT_VERSION_ONE_DOMAIN
#
# Commands:
#   hubot show [me] <story> - Shows story description
#
# Author:
#   jnwheeler44 https://github.com/jnwheeler44
#   Thanks to 29decibel for inspiration with thier versionone-cli repo
#   https://github.com/29decibel/versionone-cli/

module.exports = (robot) ->
  parseString = require('xml2js').parseString
  https       = require('https')
  crypto      = require('crypto')
  _           = require('underscore')
  Util        = require('util')
  exec        = require('child_process').exec
  inspect     = Util.inspect

  robot.respond /show\s+(me\s+)?(.*)\s+story?(.*)?/i, (msg)->
    story_number = msg.match[3].replace(' ', '')
    @config_errors = ''
    unless (api_domain = process.env.HUBOT_VERSION_ONE_DOMAIN)?
      @config_errors += "Please set the V1 Domain via HUBOT_VERSION_ONE_DOMAIN\n"
    unless (auth_username = process.env.HUBOT_VERSION_ONE_USERNAME)?
      @config_errors += "Please set the V1 Domain via HUBOT_VERSION_ONE_USERNAME\n"
    unless (auth_password_hash = process.env.HUBOT_VERSION_ONE_PASSWORD_HASH)?
      @config_errors += "Please set the V1 Domain via HUBOT_VERSION_ONE_PASSWORD_HASH\n"
    unless (auth_password_key = process.env.HUBOT_VERSION_ONE_KEY)?
      @config_errors += "Please set the V1 Domain via HUBOT_VERSION_ONE_PASSWORD_KEY\n"
    if @config_errors
      msg.send @config_errors
    else
      decipher = crypto.createDecipher("aes192", auth_password_key)
      decipher.update(auth_password_hash, "hex", "binary")
      auth_password = decipher.final("binary")

      # This is cheating.  Curl has NTLM.
      command = "curl https://#{encodeURIComponent(auth_username)}:#{encodeURIComponent(auth_password)}@v1.cblpath.com/VersionOne/rest-1.v1/Data/Story?where=Number=%27#{story_number}%27 -k --NTLM"
      result = exec command, (error, stdout, stderr)->
        parseString stdout, (err, result)->
          descriptions = _.select result.Assets.Asset[0].Attribute, (att)->
            att['$']?.name == 'Description'
          stories =  _.map result.Assets.Asset,(s)->
            new Story(s)
          msg.send "#{stories[0].description}"

  class Story
    constructor:(asset)->
      @asset = asset
      @name = getAttr(@asset, 'Name')
      @number = getAttr(@asset, 'Number')
      @sprint = getAttr(@asset, "Timebox.Name") || ""
      @description = getAttr(@asset, "Description")?.replace(/(<([^>]+)>)/ig,"").replace('&nbsp','') || ''
      @todo = getAttr(@asset, "ToDo") || '-'
      @estimate = getAttr(@asset, "DetailEstimate") || '-'

  getAttr = (asset, attrName) =>
    name = _.select asset.Attribute, (att)->
      att['$']?.name == attrName
    name[0]?['_']


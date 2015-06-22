settings   = require './settings'

Promise    = require 'bluebird'
NodeTrello = require 'node-trello'
moment     = require 'moment'
express    = require 'express'
bodyParser = require 'body-parser'

Trello = Promise.promisifyAll new NodeTrello settings.TRELLO_API_KEY, settings.TRELLO_BOT_TOKEN

app = express()
app.use '/static', express.static('static')
app.use bodyParser.json()

sendOk = (request, response) ->
  console.log 'trello checks this endpoint when creating a webhook'
  response.send 'ok'
app.get '/webhooks/trello-bot', sendOk
app.get '/webhooks/tracked-board', sendOk

app.post '/webhooks/trello-bot', (request, response) ->
  payload = request.body

  console.log '- bot: ' + payload.action.type
  response.send 'ok'

  switch payload.action.type
    when 'addMemberToBoard'
      # add webhook to this board
      Trello.putAsync('/1/webhooks',
        callbackURL: settings.SERVICE_URL + '/webhooks/tracked-board'
        idModel: payload.action.data.board.id
        description: 'refbot webhook for this board'
      ).then((data) ->
        console.log 'added to board', payload.action.data.board.name, 'webhook created'
      ).catch(console.log.bind console)

    when 'removeMemberFromBoard'
      Promise.resolve().then(->
        Trello.getAsync '/1/token/' + settings.TRELLO_BOT_TOKEN + '/webhooks'
      ).then((webhooks) ->
        for webhook in webhooks
          if webhook.idModel == payload.action.data.board.id
            Trello.delAsync '/1/webhooks/' + webhook.id
      ).spread(->
        console.log 'webhook deleted'
      ).catch(console.log.bind console)

app.post '/webhooks/tracked-board', (request, response) ->
  payload = request.body
  action = payload.action
  data = action.data

  console.log 'card ' + payload.model.shortUrl + ': ' + payload.action.type
  console.log JSON.stringify payload.action, null, 2
  response.send 'ok'

  if action.memberCreator.id == settings.TRELLO_BOT_ID
    return

  if action.type not in [
    "commentCard"
  ]
    return

  regex = /https?:\/\/trello.com\/c\/([\d\w]+)/g
  matches = data.text.match regex
  if matches
    commentDate = moment(action.date).format('MMM D, YYYY')
    for match in matches
      shortLink = regex.exec(match)[1]
      if shortLink in [data.card.shortLink, data.card.id]
        continue

      Trello.post "/1/cards/#{shortLink}/actions/comments"
      , text: """
      > :paperclip: [#{action.memberCreator.username}](https://trello.com/#{action.memberCreator.username}) referenced this card from a comment at https://trello.com/c/#{data.card.shortLink} on [#{commentDate}](https://trello.com/c/#{data.card.shortLink})
        """, (err, res) ->
        if err
          console.log err

port = process.env.PORT or 5000
app.listen port, '0.0.0.0', ->
  console.log 'running at 0.0.0.0:' + port

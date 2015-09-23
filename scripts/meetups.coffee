# Description:
#   Управление будущими мероприятиями и приглашением участников.
#
# Commands:
#   hubot я иду - Записаться на Четверг
#
# Notes:

Redis = require 'redis'

module.exports = (robot) ->
    client = Redis.createClient()
    PREFIX = 'thursday'
    GUESTS_SET = "#{PREFIX}:guests"

    okays = ['Хорошо', 'Ясно', 'Добро']

    # robot.hear /list/i, (res) ->
    #     res.send "No meetups for " + res.message.user.name

    robot.respond /(я )?иду/i, (res) ->
        guest = res.message.user.name
        client.sismember GUESTS_SET, guest, (err, reply) ->
            client.sadd GUESTS_SET, guest, (err) ->
                res.send res.random okays

    robot.respond /(я )?не иду/i, (res) ->
        guest = res.message.user.name
        client.srem GUESTS_SET, guest, (err, reply) ->
            res.send res.random okays

    robot.respond /кто идет/i, (res) ->
        client.smembers GUESTS_SET, (err, reply) ->
            switch reply.length
                when 0 then res.send "Пока никто не идет"
                when 1 then res.send "Идет #{reply[0]}"
                else
                    # list = reply.map (name) -> "@#{name}"
                    res.send "Идут " + reply[0...-1].join(', ') +
                        " и " + reply[reply.length - 1]

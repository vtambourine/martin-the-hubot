# Description:
#   Управление будущими мероприятиями и приглашением участников.
#
# Commands:
#   hubot я иду - Записаться на Четверг
#   hubot я не иду - Удалить себя из списка гостей
#   hubot кто идет?  - Показать список гостей
#   hubot предлагаю Место  - Добавить запись в список возможных мест для посещения
#   hubot куда идем?  - Показать список предложенных мест
#
# Notes:

Redis = require 'redis'

module.exports = (robot) ->
    client = Redis.createClient()
    PREFIX = 'thursday'
    GUESTS_SET = "#{PREFIX}:guests"
    GUESTS_IMAGES_HASH = "#{PREFIX}:images"
    PLACES_SET = "#{PREFIX}:places"
    SLACK_API_TOKEN = process.env.SLACK_API_TOKEN

    okays = ['Хорошо', 'Ясно', 'Добро']
    confirmation = ['Помедленнее, я записываю... Записал!', 'Принято!', 'Добавлено в список!']
    reject = ['К сожалению, я не смог найти это место в списке :(']
    add_one = ['+1', 'Добавил!', 'Инкрементировал!']

    # robot.hear /list/i, (res) ->
    #     res.send "No meetups for " + res.message.user.name

    robot.respond /привет!/, (res) ->
        res.send "Приветствую! Меня зовут Мартин, и я помогу вам зарегистрироваться на сегодняшний Нечетный четверг. Если вы хотите придти, просто скажите мне: \"Мартин, я иду\" и я тут же запишу вас в список гостей. Если вы передумаете, тогда скажите: \"Мартин, я не иду\", и я отдам ваше место кому-то другому. Список гостей, как всегда, можно увидеть на сайте sabantuy.koal.me. Удачи!"

    robot.respond /(я )?иду/i, (res) ->
        guestName = res.message.user.name
        guestId = res.message.user.id

        client.sismember GUESTS_SET, guestName, (err, reply) ->
            robot.http("https://slack.com/api/users.info?" +
                "token=#{SLACK_API_TOKEN}" +
                "&user=#{guestId}&pretty=1")
                .get() (err, res, body) ->
                    response = JSON.parse body
                    image = response.user.profile.image_192
                    client.hset GUESTS_IMAGES_HASH, guestName, image
            client.sadd GUESTS_SET, guestName, (err) ->
                res.send res.random okays

    robot.respond /(я )?не иду/i, (res) ->
        guestName = res.message.user.name
        client.srem GUESTS_SET, guestName, (err, reply) ->
            res.send res.random okays

    robot.respond /кто ид(е|ё)т/i, (res) ->
        client.smembers GUESTS_SET, (err, reply) ->
            switch reply.length
                when 0 then res.send "Пока никто не идет"
                when 1 then res.send "Идет #{reply[0]}"
                else
                    # list = reply.map (name) -> "@#{name}"
                    res.send "Идут " + reply[0...-1].join(', ') +
                        " и " + reply[reply.length - 1]

    robot.respond /предлагаю/i, (res) ->
        [_, place] = res.message.match /предлагаю(.*)/
        place_name = place.trim().toLowerCase()
        client.zscore [PLACES_SET, place_name], (err, count) ->
          count = if count then parseInt(count) + 1 else 1
          client.zadd [PLACES_SET, count, place_name], (err) ->
              res.send res.random confirmation

    robot.respond /(я )?за/i, (res) ->
        [_, place] = res.message.match /за(.*)/
        place_name = place.trim().toLowerCase()
        client.zscore [PLACES_SET, place_name], (err, count) ->
          if count
            client.zadd [PLACES_SET, parseInt(count) + 1, place_name], (err) ->
                res.send res.random add_one
          else
            res.send reject

    robot.respond /куда ид(е|ё)м/i, (res) ->
        params = [ PLACES_SET, '+inf', '-inf', 'WITHSCORES']
        client.zrevrangebyscore params, (err, reply) ->
            group_by_score = []
            reply.map (elem, i) ->
              if (i + 1) % 2
                place_name = reply[i][0].toUpperCase() + reply[i][1..-1]
                votes = reply[i+1]
                group_by_score.push([place_name, votes])
            switch group_by_score.length
                when 0 then res.send "Пока у меня нет идей!"
                when 1 then res.send "Кто-то предложил - #{group_by_score[0][0]}(#{ group_by_score[0][1] })"
                else res.send "Есть предложения посетить следующие места:\n#{ group_by_score.map((place) -> "#{place[1]}: #{place[0]}").join("\n") }"

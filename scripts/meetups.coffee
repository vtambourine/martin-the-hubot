# Description:
#   Управление будущими мероприятиями и приглашением участников.
#
# Commands:
#   Мартин, я иду - Записаться на Четверг
#   Мартин, я не иду - Удалить себя из списка гостей
#   Мартин, кто идет?  - Показать список гостей
#   Мартин, предлагаю Place  - Добавить запись в список возможных мест для посещения
#   Мартин, я за Place  - Проголосовать за определенное Place
#   Мартин, я против Place  - Проголосовать против определенного Place
#   Мартин, куда идем?  - Показать список предложенных мест
#
# Notes:

_     = require 'lodash-node'
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
    already_added = ['Упс... Кто-то опередил тебя дружок!', 'Подобная позиция уже имеется.']
    reject = ['К сожалению, я не смог найти это место в списке :(']
    add_one = ['+1', 'Добавил!', 'Инкрементировал!']
    remove_one = ['-1', 'Убрал!', 'Декрементировал!']

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
        place = res.message.match(/предлагаю(.*)/)[1]
        place_name = place.trim().toLowerCase()
        guest_name = res.message.user.name
        client.get PLACES_SET, (err, msg_places) ->
            places = if msg_places then JSON.parse(msg_places) else {}
            if places[place_name]
               res.send res.random already_added
            else
                places[place_name] = []
                client.set PLACES_SET, JSON.stringify(places), (err) ->
                    res.send res.random confirmation

    robot.respond /(я )?за/i, (res) ->
        place = res.message.match(/за(.*)/)[1]
        place_name = place.trim().toLowerCase()
        guest_name = res.message.user.name
        client.get PLACES_SET, (err, msg_places) ->
            places = if msg_places then JSON.parse(msg_places) else {}
            if places[place_name]
                for key in _.keys(places)
                  places[key] = _.without(places[key], '@' + guest_name)
                places[place_name] = _.union(places[place_name], ['@' + guest_name])
                client.set PLACES_SET, JSON.stringify(places), (err) ->
                    res.send res.random add_one
            else
              res.send reject

    robot.respond /(я )?против/i, (res) ->
        place = res.message.match(/против(.*)/)[1]
        place_name = place.trim().toLowerCase()
        guest_name = res.message.user.name
        client.get PLACES_SET, (err, msg_places) ->
            places = if msg_places then JSON.parse(msg_places) else {}
            if places[place_name]
                places[place_name] = _.without(places[place_name], '@' + guest_name)
                client.set PLACES_SET, JSON.stringify(places), (err) ->
                    res.send res.random remove_one
            else
              res.send reject

    robot.respond /куда ид(е|ё)м/i, (res) ->
        client.get PLACES_SET, (err, msg_places) ->
            places = if msg_places then JSON.parse(msg_places) else {}
            keys = _.keys(places)
            switch keys.length
                when 0 then res.send "Пока у меня нет идей!"
                when 1 then res.send "Кто-то предложил - #{keys[0]})"
                else res.send "Есть предложения посетить следующие места:\n#{ _.map(keys, (place) -> "- \x02#{ place }\x02#{'(' + places[place].join(', ') + ')' if places[place]}").join("\n") }"

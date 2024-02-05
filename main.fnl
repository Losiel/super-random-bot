;; -*- inferior-lisp-program: "luvit repl.lua"; -*-

(local discordia (require :discordia))
(local client (discordia.Client))
(local json (require :json))
(local fs (require :fs))
(local coro (require :coro-http))
(local {: sleep} (require :timer))
(local {:robloxcookie *ROBLOX-COOKIE*
        :token *DISCORD-TOKEN*}
       (if (or (fs.existsSync :security.lua)
               (fs.existsSync :security.fnl))
           (require :security)
           (error "A file called security.fnl with the structure
{:robloxcookie COOKIE :token BOTTOKEN}
must exist in order for the bot to run")))

(fn filter-game [{: description : name}]
  ;; must be a game in the format of https://games.roblox.com/v1/games?universeIds=1818
  (and (if description
         (and
          (not= description "This is your very first ROBLOX creation. Check it out, then make it your own with ROBLOX Studio!")
          (not= description "This is your very first Roblox creation. Check it out, then make it your own with Roblox Studio!")
          (not (description:find "Remember that this game is early in development, which means bugs will happen and some aspects of the game will be bare bones%. Thanks for understanding!"))
          (not (description:find "OBBY OBBY"))
          ; (not (description:find (.. name " " name)))
          ; ^ this one sometimes errors because of malformed patterns
          (not= description name))
         true)
       (not= name "Untitled Name")
       (not (name:find "'s Place$"))
       (not (name:find "'s #####$"))
       (not (name:find "'s Place Number: %d+$"))
       (not (: (name:lower) :find "killer"))
       (not (: (name:lower) :find "tycoon"))
       (name:find "[^%#%s]")
       (let [(a b c) (name:match "(.+)%s(.+)%s%[(.+)%]")]
         (if a (not= a b c) true))))

(fn find-games [attempts]
  ;; returns
  ;; (case (find-games)
  ;;   (true place-info) "Request went succesfully!"
  ;;   (false error-message) (error error-message))
  ;; place-info has the sme structure as https://games.roblox.com/v1/games
  (local attempts (if (= (type attempts) :number) attempts 5))
  (if (> attempts 0)
    (case-try
        ;; send an http request to get the games
        (coro.request :GET
                      (.. "https://games.roblox.com/v1/games?universeIds="
                          ;; cannot exceed 100 ids
                          ;; https://games.roblox.com/docs/index.html?urls.primaryName=Games%20Api%20v1
                          (-> (fcollect [i 1 15]
                                (math.random 10000 4047263777))
                              (table.concat ",")))
                      [[:Cookie *ROBLOX-COOKIE*]])
      ;; check the request was valid and now filter the games that match filter-game's criteria
      ({:code 200} body)
      (icollect [_ place (ipairs (. (json.decode body) :data))]
        (when (filter-game place)
          place))
      ;; if there is more than one good game, do an http request to check
      ;; which ones are public
      (where good-games (>= (# good-games) 1))
      (coro.request :GET
                    (.. "https://games.roblox.com/v1/games/multiget-place-details"
                        (accumulate [ids "" i game (ipairs good-games)]
                          (.. ids (if (= i 1) :? :&) "placeIds=" game.rootPlaceId)))
                    [[:Cookie *ROBLOX-COOKIE*]])
      ({:code 200} playable-status-body)
      (let [playable-status (json.decode playable-status-body)]
        (icollect [place-n place (ipairs good-games)]
          (when (. (. playable-status place-n) :isPlayable)
            place)))
      (where public-games (>= (# public-games) 1)) (values true public-games)
      (catch
       (where {:code num} num) (values false (.. "ERROR CODE: " num ". Did you set up the cookies properly?"))
       _ (find-games (- attempts 1))))
    (values false "ERROR: Timeout")))

(fn add-new-game-to-cache [cache]
  (var (output? success? cache-or-error-msg) (values false nil nil))
  (fn find-games-and-set-flag []
    (var coroutines-running 5)
    (for [i 1 coroutines-running]
      ((coroutine.wrap #(do
        (case (find-games 25)
          (true games)
          (do
            (set coroutines-running (- coroutines-running 1))
            (icollect [_ v (ipairs games) &into cache] v)
            (when (not output?)
              (set (output? success? cache-or-error-msg) (values true true cache))))
          (false err-msg)
          (do
            (set coroutines-running (- coroutines-running 1))
            (when (and (not output?)
                       (= coroutines-running 0))
              (set (output? success? cache-or-error-msg) (values true false err-msg))))))))))
  ((coroutine.wrap find-games-and-set-flag))
  (while (not output?)
    (sleep 100))
  (values success? cache-or-error-msg))

(fn place-info->embed [place]
  (local (upvotes downvotes)
         (case-try
             (coro.request :GET
                           (.. "https://games.roblox.com/"
                               "v1/games/votes?universeIds="
                               place.id)
                           [[:Cookie *ROBLOX-COOKIE*]])
           ({:code 200} body) (json.decode body)
           ({:data [{:downVotes downvotes :upVotes upvotes}]}) (values downvotes upvotes)
           (catch ? (values 0 0))))

  (local creator-headshot
       (case-try
           (coro.request :GET
                         (.. "https://thumbnails.roblox.com"
                             "/v1/users/avatar-headshot?userIds="
                             place.creator.id
                             "&size=48x48&format=Png&isCircular=false")
                         [[:Cookie *ROBLOX-COOKIE*]])
         ({:code 200} body) (json.decode body)
         {:data [{:imageUrl url}]} url
         (catch ? nil)))

  (local place-thumbnail
       (case-try
           (coro.request :GET
                         (.. "https://thumbnails.roblox.com"
                             "/v1/games/multiget/thumbnails?universeIds="
                             place.id
                             "&countPerUniverse=1&defaults=true&"
                             "size=768x432&format=Png&isCircular=false")
                         [[:Cookie *ROBLOX-COOKIE*]])
         ({:code 200} body) (json.decode body)
         {:data [{:thumbnails [{:imageUrl url}]}]} url
         (catch ? nil)))

  (local place-icon
       (case-try
           (coro.request :GET
                         (.. "https://thumbnails.roblox.com/v1"
                             "/places/gameicons?placeIds="
                             place.rootPlaceId
                             "&returnPolicy=PlaceHolder&size=50x50"
                             "&format=Png&isCircular=false")
                         [[:Cookie *ROBLOX-COOKIE*]])
         ({:code 200} body) (json.decode body)
         {:data [{:imageUrl url}]} url
         (catch ? nil)))
  
  (local created-date (place.created:sub 1 10))
  (local updated-date (place.updated:sub 1 10))
  {:embed
    {:title place.name
     :url (.. "https://www.roblox.com/games/" place.rootPlaceId)
     :description place.description
     :footer {:text (.. "Developer info · UniverseID: " place.id)}
     :author {:name place.creator.name
              :icon_url creator-headshot
              :url (.. "https://www.roblox.com/users/" place.creator.id "/profile/")}
     :image {:url place-thumbnail}
     :thumbnail {:url place-icon}
     :fields [{:name "General"
               :value (.. ":calendar: Create date " created-date "\n"
                          ":calendar: " (if (= updated-date created-date)
                                           "**Never updated**"
                                           (.. "Last updated " updated-date)) "\n"
                          ":busts_in_silhouette: "
                          (if (= place.playing 0)
                              "Nobody is playing"
                              (.. "Users playing " place.playing)) "\n"
                          ":busts_in_silhouette: Max players: " place.maxPlayers "\n"
                          ":eye: " (if (= place.visits 0)
                                      "**No visits**"
                                      (.. "Visits: " place.visits)) "\n"
                          ":star: " (if (= place.favoritedCount 0)
                                        "No favorites"
                                        (.. "Favorites: " place.favoritedCount)) "\n"
                          (if (= upvotes downvotes 0)
                              ":thumbsup: :thumbsdown: This game has no votes"
                              (: "(:thumbsup: %d) (:thumbsdown: %d)" :format upvotes downvotes)) "\n"
                          (if place.copyingAllowed
                              ":unlock: **THIS GAME IS UNCOPYLOCKED**\n"
                              "")
                          (if (<= (tonumber (created-date:sub 1 4)) 2014)
                              ":open_mouth: **THIS GAME IS OLD**\n"
                              "")
                          (if (> downvotes upvotes)
                              ":thumbsdown: **THIS GAME IS DISLIKED**\n"
                              ""))}]}})

(local *COMMANDS* {}) ;;format
                      ;; local command = {:name :command-name :action (fn [message]) :description "hello!"}
                      ;; table.insert(*COMMANDS*, command)
                      ;; *COMMANDS*[command.name] = command

(do
  (set client._listeners [])
  (client:on :messageCreate
    (fn [message]
      (local command-name (message.content:match "^!r(.+)%s?"))
      (local command (. *COMMANDS* command-name))
      (when command
        (command.action message)))))

(macro define-command [name params desc ...]
  (assert (= (type desc) :string))
  `(let [command# {:name ,name
                  :action (fn ,params ,...)
                  :description ,desc}
         old-command# (. *COMMANDS* ,name)]
     (if old-command#
         (do (set old-command#.action command#.action)
             (set old-command#.description command#.description))
         (do (table.insert *COMMANDS* command#)
             (tset *COMMANDS* ,name command#)))))

(local *PLACE-CACHE* [])
(define-command :game [message]
  "Shows you a random Roblox game"
  (local loading-msg?
         (when (= (# *PLACE-CACHE*) 0)
           (message:reply
            {:embed
             {:thumbnail
              {:url "https://media1.tenor.com/m/UnFx-k_lSckAAAAC/amalie-steiness.gif"}}})))
  (local (games-in-cache? cache-or-error-message)
         (if (> (# *PLACE-CACHE*) 0)
             (values true *PLACE-CACHE*)
             (add-new-game-to-cache *PLACE-CACHE*)))
  (when loading-msg?
    (loading-msg?:delete))
  (case (values games-in-cache? cache-or-error-message)
    (true cache) (do (local game (table.remove cache))
                     (message:reply (doto (place-info->embed game)
                                      (tset :reference {:message message
                                                        :mention false}))))
    (false err-msg) (message:reply {:embed {:description err-msg
                                            :color (. (discordia.Color.fromRGB 255 80 0) :value)}
                                    :reference {:message message
                                                :mention false}})))

(define-command :ad [message]
  "Shows you a Roblox ad (not random.)"
  (local (image-url ad-name ad-url)
         (case-try
             (coro.request :GET
                           (.. "https://www.roblox.com/user-sponsorship/" (math.random 1 3))
                           [[:Cookie *ROBLOX-COOKIE*]])
           ({:code 200} body) (values (body:match "<img%s+src=\"(.-)\"")
                                      (body:match "<a%s+class=\"ad\"%s+title=\"(.-)\"")
                                      (body:match "<a%s+class=\"ad\"%s+title=\".-\"%s+href=\"(.-)\""))
           (catch ? nil)))
  (message:reply
       {:embed (if (and image-url ad-name ad-url)
                   {:title ad-name
                    :url ad-url
                    :image {:url image-url}}
                   {:title "Couldn't get a Roblox ad"
                    :color (. (discordia.Color.fromRGB 255 80 0) :value)})
        :reference {:message message
                    :mention false}}))

(var *LAST-R34-POST-ID* nil)
(define-command :-34 [message]
  "You know what it does."
  (when (not= (type *LAST-R34-POST-ID*) :number)
    (set *LAST-R34-POST-ID*
         (case-try
             (coro.request :GET 
                           "https://api.rule34.xxx/index.php?page=dapi&s=post&q=index&pid=1&limit=1&json=1")
           ({:code 200} body) (json.decode body)
           [{:id id}] id
           (catch ? nil))))
  (local is-channel-nsfw? message.channel.nsfw)
  (local (tags score image-url id)
         (case-try (values is-channel-nsfw? *LAST-R34-POST-ID*)
           (true last-post)
           (coro.request :GET
                         (.. "https://api.rule34.xxx/index.php?page=dapi&s=post&q=index&json=1&id="
                             (math.random 1 last-post)))
           ({:code 200} body) (json.decode body)
           [{: tags : score : file_url : id}] (values tags score
                                                      file_url id)
           (catch ? nil)))
  (message:reply
   {:reference {:message message
                :mention false}
    :embed
    (if tags
        {:description
         (.. "[Link to image](https://rule34.xxx/index.php?page=post&s=view&id="
             id ")\n" tags)
         :image {:url image-url}
         :footer {:text (.. "Score: " score)}}
        (not is-channel-nsfw?)
        {:title ":warning: Channel is not marked as NSFW"
         :color (. (discordia.Color.fromRGB 255 80 0) :value)}
        {:title "Couldn't get an image from rule34.xxx"
         :color (. (discordia.Color.fromRGB 255 80 0) :value)})}))

(define-command :help [message]
  "Shows you this help"
  (message:reply
   {:embed
    {:title "Super Random Bot"
     :description "Omniscient god punished by [`alonzon`](https://github.com/Losiel)"
     :fields (icollect [_ command (ipairs *COMMANDS*)]
               {:name (.. "!r" command.name)
                :value (or command.description "<UNDOCUMENTED>")})}}))

(client:run (.. "Bot " *DISCORD-TOKEN*))


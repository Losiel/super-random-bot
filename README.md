# Super Random Bot
**[Join the Discord server!](https://discord.gg/82Er5KQxPk)**

This Discord bot is dedicated to crawling the internet for random content, as of right now the bot can:
- show a random Roblox game
- show a Roblox ad
- show a random rule34 image

![https://imgur.com/d2gAEMm.png](https://imgur.com/d2gAEMm.png)

# Reporting errors
Join [the Discord server](https://discord.gg/82Er5KQxPk) if you have any errors. My Discord username is `alonzon`.

# Running
This bot requires [Fennel](https://fennel-lang.org/), [Luvit](https://luvit.io/) and [Discordia](https://github.com/SinisterRectus/Discordia) to run

## Installing Fennel
Download [the Fennel binary](https://fennel-lang.org/setup#downloading-a-fennel-binary) and follow the steps if you're on Linux. If you're on Windows, download the `Windows x86` binary and put in your `%PATH` (browse the internet if you don't know how to do that. TBH if you don't know much about coding I don't know why you're trying to run this bot.)

## Installing Luvit and Discordia
To install Luvit [go here](https://luvit.io/install.html) and follow the instructions in **Get Lit and Luvit.**

With Luvit installed it's time to install Discordia. Go to the bot directory, open the terminal (or command prompt if you're on Windows) and type `lit install SinisterRectus/discordia` and now there should be a `deps` file on the bot directory.

## Compiling `main.fnl`
With the terminal open, type `fennel -c main.fnl >> main.lua`

## Making a `security.lua` file
The bot now requires your Discord token and your Roblox token, both obligatory. Make a `security.lua` file with the following contents:
```lua
return {
	robloxcookie = "YOURCOOKIE";
	token = "YOURDISCORDTOKEN";
}
```

## Finally running it
Hopefully you installed Luvit correctly and compiled `main.lua` successfully, run `luvit main.lua` in the terminal and it should start connecting.

# Developing with the REPL (Emacs required)
The best way to develop the bot is with the REPL because it allows you to add new features or change commands without having to restart it, something other bot developers might have envy of.

First, [get Fennel.lua](https://fennel-lang.org/setup#embedding-the-fennel-compiler-in-a-lua-application) and put it in the same directory.

Open `main.fnl` in Emacs and if it asks you "The local variables in main.fnl are a little risky bla bla bla" say yes. Then do `M-x inferior-lisp` and you should have a REPL.

**Note:** The REPL is kinda buggy and bad. I don't really know how to fix it but I would say that as of right now it works decently. Again, if you have a bug with the REPL report it to me.

# darak

```
config = {
        "TELEGRAM_TOKEN" => "your telegram token",
        "CHAT_ID" => "your chat id",
        "FURIGANA_APPID" => "your yahoo appid"
}

d = Darak.new config
d.config()

d.fetch()

d.load_last()
d.print()

d.mode = Darak::MODE_JAPANESE
d.print()

```

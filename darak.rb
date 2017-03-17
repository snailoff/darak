#!/usr/bin/env ruby

require 'open-uri'
require 'htmlentities'
require 'nokogiri'
require 'json'
require 'sqlite3'

class Darak
	MODE_MOST = "most"
	MODE_ENGLISH = "english" 
	MODE_JAPANESE = "japanse"
	MODE_CHINESE = "chinese"
	
	attr_accessor :mode

	def initialize config
		@config = config
		@abs_path = "#{File.expand_path "..", __FILE__}"

		@url = "https://api.telegram.org/bot#{@config["TELEGRAM_TOKEN"]}/sendMessage?chat_id=#{@config["CHAT_ID"]}&"
		@db = SQLite3::Database.new "#{@abs_path}/darak.db"

		@loaded = []
		@rendered = ''
		@mode = MODE_MOST

		db_checking
	end

	def fetch
		rs = @db.get_first_row("select count(*) as count from daraks where create_date = date('now');")
		if rs[0] != 0 
			puts "\n-- fetching is ignored."
			return
		end

		file = open('http://www.darakwon.co.kr/')

		contents = file.read
		matches = contents.scan(/<li class="txt_today">.*?<\/li>/)

		coder = HTMLEntities.new
		matches.map! do |x|
			coder.decode(x.gsub!(/<.*?>/, ''))
		end

		rs_furigana = furigana(matches[2])

		@db.execute("insert into daraks (korean, english, japanese, chinese, japanese_extra, send_count_main, send_count_english, send_count_japanese, send_count_chinese, create_date) values (?, ?, ?, ?, ?, 0, 0, 0, 0, date('now'));",
			[matches[0], matches[1], matches[2], matches[3], rs_furigana])
		puts "\n-- fetched."
	end

	def send
		puts "-- sending to #{@config['CHAT_ID']}..."
		`curl -S --data-urlencode "text=#{@rendered}" "#{@url}"`	
	end

	def load_last
		@loaded = @db.get_first_row("select korean, english, japanese, chinese, english_extra, japanese_extra, chinese_extra from daraks  order by create_date desc limit 1;" )
		render()
	end
	def load_lowcount
		@loaded = @db.get_first_row("select korean, english, japanese, chinese, english_extra, japanese_extra, chinese_extra from daraks  order by create_date desc limit 1;" )
		render()
	end
	def load_random
		@loaded = @db.get_first_row("select korean, english, japanese, chinese, english_extra, japanese_extra, chinese_extra from daraks  order by random() limit 1;" )
		render()
	end

	def mode=(m)
		@mode = m

		render() unless @loaded.empty?
	end
	
	def print
		puts "\n-- rendered (mode : #{@mode}) "
		puts @rendered
		puts "--"
	end

	def config
		puts "\n-- configuration"
		puts "TELEGRAM_TOKEN : #{@config["TELEGRAM_TOKEN"]}"
		puts "CHAT_ID : #{@config["CHAT_ID"]}"
		puts "FURIGANA_APPID : #{@config["FURIGANA_APPID"]}"
	end

	private

	def furigana(sentence)
		appid = @config["FURIGANA_APPID"]
		sentence = URI.escape(sentence)

		request="http://jlp.yahooapis.jp/FuriganaService/V1/furigana?appid=#{appid}&grade=1&sentence=#{sentence}"

		doc = Nokogiri::XML(open(request))
		doc.remove_namespaces!

		rs = []
		doc.xpath("//Word/Furigana").each do |x|
			surface = x.previous_element.content
			rs.push "#{surface}(#{x.content})"
		end

		return rs.join(",")
	end

	def db_checking
		rs = @db.get_first_row("select count(*) as count, name from sqlite_master where type='table' and name='daraks';")
		if rs[0] == 0
			@db.execute <<-SQL
				create table daraks (
					id integer primary key autoincrement,
					korean varchar2(1000),
					english varchar2(1000),
					japanese varchar2(1000),
					chinese varchar2(1000),
					english_extra varchar2(500),
					japanese_extra varchar2(500),
					chinese_extra varchar2(500),
					send_count_main int,
					send_count_english int,
					send_count_japanese int,
					send_count_chinese int,
					create_date datetime
				);
			SQL
		end
	end


	def render
		case @mode
		when MODE_MOST
			@rendered = render_most(@loaded)	
		when MODE_JAPANESE
			@rendered = render_japanese(@loaded)
		end
	end	


	def render_most(rs)
		date = Time.new.strftime('%Y. %m. %d.')
		text = <<-TEXT
#{date}

### #{rs[0]}
=> #{rs[1]}
=> #{rs[2]}
=> #{rs[3]}

#{rs[5].split(',').join("\n")}
		TEXT
		text
	end

	def render_japanese(rs)
		text = <<-TEXT
#{rs[2]}

#{rs[5].split(',').join("\n")}
		TEXT
		text
	end

end

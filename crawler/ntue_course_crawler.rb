require 'crawler_rocks'
require 'json'
require 'pry'

class NationalTaipeiUniversityOfEducationCrawler

	def initialize year: nil, term: nil, update_progress: nil, after_each: nil

		@year = year-1911
		@term = term
		@update_progress_proc = update_progress
		@after_each_proc = after_each

		@query_url = 'http://apstu.ntue.edu.tw/Secure/default.aspx'
	end

	def courses
		@courses = []

		r = RestClient.get(@query_url)
		doc = Nokogiri::HTML(r)

		hidden = Hash[doc.css('input[type="hidden"]').map{|hidden| [hidden[:name], hidden[:value]]}]

		r = RestClient.post(@query_url, hidden.merge({
			"LoginDefault$txtScreenWidth" => "1360",
			"LoginDefault$txtScreenHeight" => "768",
			"LoginDefault$ibtLoginGuest.x" => "20",
			"LoginDefault$ibtLoginGuest.y" => "20",
			}) )

		cookie = "ASP.NET_SessionId=#{r.cookies["ASP.NET_SessionId"]}; .PaAuth=#{r.cookies[".PaAuth"]}"

		@query_url = 'http://apstu.ntue.edu.tw/Message/Main.aspx'
		r = RestClient.get @query_url, {"Cookie" => cookie }
		doc = Nokogiri::HTML(r)

		hidden = Hash[doc.css('input[type="hidden"]').map{|hidden| [hidden[:name], hidden[:value]]}]

		r = RestClient.post(@query_url, hidden.merge({
			"CommonHeader$txtMsg" => "目前學年期為#{doc.css('title').text.split(' ')[1]}#{doc.css('title').text.split(' ')[2]}",
			"MenuDefault$dgData$ctl02$ibtMENU_ID.x" => "100",
			"MenuDefault$dgData$ctl02$ibtMENU_ID.y" => "20",
			}), {"Cookie" => cookie	})
		doc = Nokogiri::HTML(r)

		hidden = Hash[doc.css('input[type="hidden"]').map{|hidden| [hidden[:name], hidden[:value]]}]

		@query_url = "http://apstu.ntue.edu.tw/Message/SubMenuPage.aspx"
		r = RestClient.post(@query_url, hidden.merge({"__EVENTTARGET" => "SubMenu$dgData$ctl02$ctl00"}), {"Cookie" => cookie	})

		@query_url = 'http://apstu.ntue.edu.tw/A04/A0428S3Page.aspx'
		r = RestClient.get @query_url, {"Cookie" => cookie }
		doc = Nokogiri::HTML(r)

		for page in 0..28  # 104的課程一共有29頁*50個，換頁換得很討厭omO
			if page < 10
				page = "0" + page.to_s
			elsif page > 10 && page < 19
				page = "0" + (page - 9).to_s
			elsif page > 18 && page < 21
				page = page - 9
			elsif page > 20 && page < 28
				page = "0" + (page - 18).to_s
			elsif page == 28
				page = 10
			end
# print page,"\n"

			hidden = Hash[doc.css('input[type="hidden"]').map{|hidden| [hidden[:name], hidden[:value]]}]

			r = RestClient.post(@query_url, hidden.merge({
				"__EVENTTARGET" => "A0425S3$dgData$ctl54$ctl#{page}",
				"A0425SMenu$ddlSYSE" => "#{@year}#{@term}",
				}), {"Cookie" => cookie	})
			doc = Nokogiri::HTML(r)

			doc.css('table[class="DgTable"] tr[onmouseover="OnOver(this);"]').map{|tr| tr}.each do |tr|
				data = tr.css('td').map{|td| td.text}

				course = {
					year: @year,
					term: @term,
					general_code: data[0],    # 開課號
					name: data[1],    # 課程名稱
					required: data[2],    # 選別 (必選修)
					department_type: data[3],    # 修別 (XX課程)
					degree: data[4],    # 班級
					department: data[5],    # 開課系所
					study_type: data[6],    # 學制
					lecturer: data[7],    # 任課教師
					day: data[8],   # 上課時間
					location: data[9],    # 上課教室
					credits: data[10],   # 學分數
					people_minimum: data[11],    # 人數下限
					people_maximum: data[12],    # 人數上限
					people_1: data[13],    # 已選人數
					people_2: data[14],    # 選中人數
					notes: data[15],    # 備註說明
					}

				@after_each_proc.call(course: course) if @after_each_proc

				@courses << course
			end
		end
	# binding.pry
		@courses
	end
end

# crawler = NationalTaipeiUniversityOfEducationCrawler.new(year: 2015, term: 1)
# File.write('courses.json', JSON.pretty_generate(crawler.courses()))

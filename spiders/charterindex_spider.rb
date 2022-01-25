require 'kimurai'
require 'uri'
require 'set'
require 'mysql2'
require 'json'


def length_converter(length_str)
  ft_str = length_str.split(" / ", -1)[1]
  return ft_str.split("ft", -1)[0]
end

class DBClient
  
  def initialize(host: "charterboats.com", username: "charscom_yachts", password: "charscom_yachts")
    @client = Mysql2::Client.new(:host => host, :username => username, :password => password)
  end

  def query(query)
    a = @client.query(query)
    return a
  end

  def insert_listing(listing, original_data)

    specs = listing[:specs].reduce({}) {|map, el| map.merge!({ el[:heading] => el[:detail] })}
    
    price = listing[:key_details][:price] != nil ? listing[:key_details][:price] : "" 
    price = price.tr('^0-9', '')

    puts listing[:amenities]


    params = {
      "source" => "charterindex",
      "name" => listing[:name],
      "title" => listing[:title],
      "type" => "motor", # CHANGE THIS
      "length" => length_converter(listing[:key_details][:length]),
      "guests" => listing[:key_details][:sleeps],
      "cabins" => listing[:key_details][:cabins],
      "crew" => listing[:crew_profiles] != nil ? listing[:crew_profiles].length : 0,
      "price" => price,
      "charterindex_url" => listing[:url],
      "meta_description" => listing[:meta_description],
      "meta_keywords" => nil,
      "header_image" => listing[:header_image],
      "about_html" => listing[:about_html],
      "about_text" => listing[:about_text],
      "spec_yacht_name" => specs["Yacht name"],
      "spec_prior_name" => specs["Prior name"],
      "spec_length" => specs["Length"],
      "spec_beam" => specs["Beam"],
      "spec_draft" => specs["Draft"],
      "spec_cruising_speed" => specs["Speed (cruising)"],
      "spec_max_speed" => specs["Speed (max)"],
      "spec_engine" => specs["Engine"],
      "spec_hull" => specs["Hull"],
      "spec_stabilizers" => specs["Stabilizers"],
      "spec_flag" => specs["Flag"],
      "spec_launched" => specs["Launched"],
      "spec_refitted" => specs["Refitted"],
      "spec_builder" => specs["Builder"],
      "spec_designer" => specs["Designer"],
      "video_url" => listing[:video_url],
      "image_urls" => listing[:image_urls].to_json,
      "features_amenities" => listing[:amenities][:general].to_json,
      "features_electronics" => listing[:amenities][:electrical].to_json,
      "features_toys" => listing[:amenities][:toys].to_json,
      "features_diving" => listing[:amenities][:diving].to_json,
      "features_tenders" => listing[:amenities][:tenders].to_json,
      "crew_image" => "",
      "crew_profiles" => listing[:crew_profiles].to_json,
      "layout_html" => listing[:layout_html],
      "layout_text" => listing[:layout_text],
      "layout_image" => listing[:layout_image],
      "original_data" => original_data,
    }

    column_names_str = params.keys.join(", ")
    question_marks_str = params.keys.map{|p| "?"}.join(", ")

    statement_str = p %{
      INSERT INTO charscom_yachts.charterindex_listing (#{column_names_str}) VALUES (#{question_marks_str});
      }.gsub(/\s+/, " ").strip

    statement = @client.prepare(statement_str)

    statement.execute(*params.values)

    last_id = @client.query("SELECT LAST_INSERT_ID();").first.values[0]
  

    add_locations_to_id(last_id, listing[:locations])


  end


  def get_id_of_location(location)
    location.sub! "&amp;", "&"

    a = @client.query("select * from charscom_yachts.location where nice_name = '#{location}'").first&.values

    if a != nil
      return a[0]
    end

    return a
  end


  def add_locations_to_id(id, locations)

    statement_str = p %{
      INSERT INTO charscom_yachts.listing_location (listing_id, location_id) values (?, ?);
    }.gsub(/\s+/, " ").strip

    statement = @client.prepare(statement_str)

    locations.each{|place|
      id_loc = get_id_of_location(place)
      if id_loc != nil and id_loc != 0
        statement.execute(id, id_loc)
      end
    }
  end
  
end


class CharterIndexSpider < Kimurai::Base
  @name = "charterindex_spider"
  @engine = :selenium_chrome
  @start_urls = ["https://www.charterindex.com/search/yachts?categories=motor"] # OR categories=sailing CHANGE THIS
  @config = {
    user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/95.0.4638.54 Safari/537.36',
    retry_request_errors: [{ error: TimeoutError }],
    disable_images: true,
  }

  def parse(response, url:, data: {})
    yacht_link_path = "//a[@data-testid=\"yacht-card-link\"]"

    all_links = Set[]
    
    yachts_urls = response.xpath(yacht_link_path).map {|data| data[:href]}
    all_links.merge(yachts_urls)
    browser.send_keys(:tab)
    
    counter = 0

    loop do
      browser.send_keys(:page_down) ; sleep (0.5 + (counter * 0.5))
      
      
      response = browser.current_response
      
      logger.info "> Current item count is #{all_links.size()}"

      if all_links.size() > 1 
        break
      end

      yachts_urls = response.xpath(yacht_link_path).map {|data| data[:href]}

      if yachts_urls.to_set.subset?(all_links)
        counter = counter + 1;
        if counter == 5
          break
        end
      else
        counter = 0
      end

      all_links.merge(yachts_urls)
    end

    logger.info "> All links to yachts from page: #{yachts_urls.join('; ')}"

    # yachts_urls.slice(0,2).each do |url|
    #   request_to :parse_yacht_page, url: absolute_url(url, base: "https://www.charterindex.com/")
    # end

    in_parallel(:parse_yacht_page, yachts_urls.map{|url| absolute_url(url, base: "https://www.charterindex.com/")}, threads: 3)

  end

  def parse_yacht_page(response, url:, data: {})
    item = {}

    item[:url] = url
    item[:name] = response.xpath("//*[@id=\"layout\"]/main/div[1]/div[2]/div/div[1]/h1").text.squish
    item[:title] = response.title
    item[:meta_description] = response.at_css("meta[name='description']").attr('content')
    # item[:meta_keywords]

    item[:header_image] = response.xpath('//*[@id="layout"]/main/div[1]/div[1]/div/span/img')[0][:src]

    item[:key_details] = {
      length: response.xpath('//*[@id="layout"]/main/div[2]/section[2]/div[2]/ul/li[2]/p').text.squish,
      builder: response.xpath('//*[@id="layout"]/main/div[2]/section[2]/div[2]/ul/li[11]/p').text.squish,
      sleeps: response.xpath('//*[@id="layout"]/main/div[1]/div[2]/div/div[2]/div[1]/span[1]/span').inner_html,
      cabins: response.xpath('//*[@id="layout"]/main/div[1]/div[2]/div/div[2]/div[2]/span[1]/span').inner_html,
      built: response.xpath('//*[@id="layout"]/main/div[2]/section[2]/div[2]/ul/li[10]/p').text.squish,
      #refit: 
      price: response.xpath('//*[@id="layout"]/main/div[1]/div[2]/div/div[3]/span[1]').inner_html
    }

    item[:operating_in] = "Operating in " + response.xpath('//*[@id="layout"]/main/div[2]/section[2]/div[1]/section[2]/div/a')
    .map.with_index {|data, index| 
        response.xpath("//*[@id=\"layout\"]/main/div[2]/section[2]/div[1]/section[2]/div/a[#{index + 1}]/div/span[1]")[0].inner_html
    }
    .join(", ")

    item[:locations] = response.xpath('//*[@id="layout"]/main/div[2]/section[2]/div[1]/section[2]/div/a')
    .map.with_index {|data, index| 
        response.xpath("//*[@id=\"layout\"]/main/div[2]/section[2]/div[1]/section[2]/div/a[#{index + 1}]/div/span[1]")[0].inner_html
    }

    item[:about_html] = response.xpath("//*[@id=\"layout\"]/main/div[2]/section[2]/div[1]/section[1]/div/div/div")&.inner_html&.squish.to_s
    item[:about_text] = response.xpath("//*[@id=\"layout\"]/main/div[2]/section[2]/div[1]/section[1]/div/div/div")&.text&.squish.to_s

    # this does not always produce a video url
    possible_video_element = response.at_css("div.viewport > div.slides > a:nth-child(1)")

    if possible_video_element.attr('srl_video_thumbnail') 
      item[:video_url] = possible_video_element.attr('href').to_s
    else
      item[:video_url] = "" 
    end

    image_count = response.xpath("//*[@id=\"layout\"]/main/div[2]/section[1]/div/div/div[1]/div/a").count

    item[:image_urls] = (1..image_count).map{|index|
      {
        # keep in mind that not all images have an alt specified
        caption: response.xpath("//*[@id=\"layout\"]/main/div[2]/section[1]/div/div/div[1]/div/a[#{index}]/img")[0][:alt],
        url: response.xpath("//*[@id=\"layout\"]/main/div[2]/section[1]/div/div/div[1]/div/a[#{index}]/img")[0][:src]
      }
    }

    item[:specs] = response.css('section.wide.no-border > div > ul > li')
    .map {
      |row|
      {
        heading: row.at_css('span').inner_html.to_s,
        detail: row.at_css('p').text.squish
      }
    }

    item[:amenities] = {
      general: response.css('#tabpanel-amenities > ul > li')&.map {|li| li.text},
      electrical: response.css('#tabpanel-electronics > ul > li')&.map {|li| li.text},
      toys: response.css('#tabpanel-toys > ul > li')&.map {|li| li.text},
      tenders: response.css('#tabpanel-diving > ul > li')&.map {|li| li.text},
      diving: response.css('#tabpanel-tenders > ul > li')&.map {|li| li.text}
    }

    # i have not seen any crew image
    item[:crew_image] = ""
    crew_profiles = response.css("section:nth-child(5) > div > div.MuiPaper-elevation").map do | profile |
      attributes = {
        title: profile.at_css("div:nth-child(1) > div:nth-child(1) > div:nth-child(1) > span").text.squish + ": " + profile.at_css("div:nth-child(1) > div:nth-child(1) > div:nth-child(1) > p").text.squish,
        full_html: profile.to_html.squish,
        bio_text: profile.at_css("p.MuiTypography-root.MuiTypography-body2").text.squish
      }
      if bio_photo = profile.at_css('span > img')&.attr('src')
        attributes[:bio_photo] = bio_photo # this does not work. I do not know how to get it.
      end
      attributes
    end
    item[:crew_profiles] = crew_profiles unless crew_profiles.empty?
    
    # I do not know what layout is supposed to be
    #item[:layout] = 

    # save_to "result.json", item, format: :pretty_json 
    client = DBClient.new()
    client.insert_listing(item, response.to_html)
  end

  if listing_url = ARGV[0]
    CharterIndexSpider.parse!(:parse_yacht_page, url: listing_url)
  else
    CharterIndexSpider.crawl!
  end

end

# CharterIndexSpider.crawl!
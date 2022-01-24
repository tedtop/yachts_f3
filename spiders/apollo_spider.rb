require 'kimurai'
require 'pry'

class ApolloSpider < Kimurai::Base
  @name = "apollo_spider"
  @engine = :selenium_chrome
  @start_urls = ['https://apolloyachts.charterindex.com/rys/search']
  @config = {
    user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/95.0.4638.54 Safari/537.36',
    retry_request_errors: [{ error: TimeoutError }],
    disable_images: true,
  }

  def parse(response, url:, data: {})
    urls = response.css('div.row > div.boat > div > a').map do |a|
      absolute_url(a[:href], base: url)
    end

    in_parallel(:parse_listing, urls, threads: 3)

    if next_page = response.at_xpath("//a[contains(text(), 'Next >>')]")
      request_to :parse, url: absolute_url(next_page[:href], base: url)
    end
  end

  def parse_listing(response, url:, data: {})
    item = {}

    if response.text.match?(/Internal Server Error/)
      logger.error "Internal Server Error (#{url})"
      return
    end 

    item[:name] = response.at_css('div.brochure-heading > div > h1').text.squish
    item[:title] = response.title
    item[:apollo_url] = url
    item[:charterindex_link] = response.at_css("link[rel='canonical']").attr('href')
    
    item[:meta_description] = response.at_css("meta[name='description']").attr('content')
    item[:meta_keywords] = response.at_css("meta[name='keywords']").attr('content')

    header_image = response.at_css('head').text[/url\('(.*?)'\)/, 1].sub(/\?.*/, '')
    item[:header_image] = 'https:' + header_image if header_image

    item[:key_details] = {
      length: response.xpath("//ul[@class='key-details']//li[contains(text(), 'Length')]/span").text.squish,
      builder: response.xpath("//ul[@class='key-details']//li[contains(text(), 'Builder')]/span").inner_html,
      sleeps: response.xpath("//ul[@class='key-details']//li[contains(text(), 'Sleeps')]/span").inner_html,
      cabins: response.xpath("//ul[@class='key-details']//li[contains(text(), 'Cabins')]/span").inner_html,
      built: response.xpath("//ul[@class='key-details']//li[contains(text(), 'Built')]/span").inner_html,
      refit: response.xpath("//ul[@class='key-details']//li[contains(text(), 'Refit')]/span").inner_html,
    }
    price = response.xpath("//ul[@class='key-details']//li[contains(text(), 'Price')]/span")
    item[:key_details][:price] = price.inner_html
    item[:key_details][:price_from] = price.text.split(/ - /)[0].to_s
    item[:key_details][:price_to] = price.text.split(/ - /)[1].to_s

    item[:operating_in] = response.at_css('#about > div > div.key-spec > p').text.squish
    item[:about_html] = response.at_css('#about > div > div.text')&.inner_html&.squish.to_s
    item[:about_text] = response.at_css('#about > div > div.text')&.text&.squish.to_s
    
    item[:video_url] = response.at_css('#image-collection > div > div > div > a')&.attr('href').to_s
    item[:image_urls] = response.css('#image-collection > a').map do |a|
      {
        caption: a.text.squish,
        url: 'https:' + a.at_css('div').attr('data-src').sub(/\?.*/, ''),
      }
    end

    item[:specs] = response.css('div.slideshow > figure > div > div.row').map do |row|
      {
        heading: row.at_css('div.heading').text.squish,
        detail: row.at_css('div.detail').text.squish,
      }
    end

    item[:amenities] = {
      general: response.css('#generalTab > ul > li')&.map { |li| li.text },
      electrical: response.css('#electricalTab > ul > li')&.map { |li| li.text },
      toys: response.css('#toysTab > ul > li')&.map { |li| li.text },
      tenders: response.css('#tendersTab > ul > li')&.map { |li| li.text },
      diving: response.css('#divingTab > ul > li')&.map { |li| li.text },
    }

    crew_image = response.at_css('#crew > div > img.ship-crew')&.attr('data-src')&.sub(/\?.*/, '')
    item[:crew_image] = 'https:' + crew_image if crew_image
    crew_profiles = response.css('#crew > div > div.profiles > div').map do |profile|
      attributes = {
        title: profile.at_css('h5').text.squish,
        full_html: profile.to_html.squish,
        bio_text: profile.css('p').to_html.squish,
      }
      if bio_photo = profile.at_css('img')&.attr('src')
        attributes[:bio_photo] = 'https://yacht.link' + bio_photo
      end
      attributes
    end
    item[:crew_profiles] = crew_profiles unless crew_profiles.empty?

    item[:layout] = {
      html: response.at_css('#layout > div > p.text')&.inner_html&.squish.to_s,
      text: response.at_css('#layout > div > p.text')&.text&.squish.to_s
    }
    layout_image = response.at_css('#layout > div > img.ship-layout')&.attr('data-src')&.sub(/\?.*/, '')
    item[:layout][:image] = 'https:' + layout_image if layout_image

    save_to "apollo_listings.json", item, format: :pretty_json
    logger.info '=== PARSED LISTING === ' + response.title
  end
end


if listing_url = ARGV[0]
  ApolloSpider.parse!(:parse_listing, url: listing_url)
else
  ApolloSpider.crawl!
end

# ApolloSpider.parse!(:parse_listing, url: 'https://yacht.link/2BAAGGFA7') # price from only
# ApolloSpider.parse!(:parse_listing, url: 'https://yacht.link/2BAAGG1968') # price from & to

# ApolloSpider.parse!(:parse_listing, url: 'https://yacht.link/2BAAGG28BF') # crew profile
# ApolloSpider.parse!(:parse_listing, url: 'https://yacht.link/2BAAGG15CA') # crew profile with pics

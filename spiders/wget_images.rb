require 'json'
require 'colorize'

# String.color_samples

data = File.read("apollo_listings.json")
yachts = JSON.parse(data)

# === Yacht Header Photos ===
yachts.each do |yacht|
  puts yacht['header_image'].red
  `wget -P img_headers/ #{yacht['header_image']}`
end

# === Yacht Photos ===
yachts.each do |yacht|
  yacht['image_urls'].each do |image|
    puts image['url'].yellow
    `wget -P img_yachts/ #{image['url']}`
  end
end

# === Yacht Layouts ===
yachts.each do |yacht|
  if yacht['layout']['image']
    puts yacht['layout']['image'].blue
    `wget -P img_layouts/ #{yacht['layout']['image']}`
  end
end

# === Crew Photos ===
yachts.each do |yacht|
  if yacht['crew_image']
    puts yacht['crew_image'].magenta
    `wget -P img_crews/ #{yacht['crew_image']}`
  end
end

# === Crew Bio Photos ===
yachts.each do |yacht|
  yacht['crew_profiles']&.each do |person|
    if person['bio_photo']
      puts person['bio_photo'].light_magenta
      `wget -P img_crew_bios/ #{person['bio_photo']}`
    end
  end
end

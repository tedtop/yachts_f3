require 'json'

data = File.read("apollo_listings.json")
yachts = JSON.parse(data)

# === Yacht Header Photos ===
yachts.each do |yacht|
  puts yacht['header_image']
end

# === Yacht Photos ===
yachts.each do |yacht|
  yacht['image_urls'].each do |image|
    puts image['url']
  end
end

# === Yacht Layouts ===
yachts.each do |yacht|
  if yacht['layout']['image']
    puts yacht['layout']['image']
  end
end

# === Crew Photos ===
yachts.each do |yacht|
  if yacht['crew_image']
    puts yacht['crew_image']
  end
end

# === Crew Bio Photos ===
yachts.each do |yacht|
  yacht['crew_profiles']&.each do |person|
    if person['bio_photo']
      puts person['bio_photo']
    end
  end
end

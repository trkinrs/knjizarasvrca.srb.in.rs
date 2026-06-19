#!/usr/bin/env ruby

require 'csv'
require 'fileutils'
require 'json'
require 'net/http'
require 'nokogiri'
require 'open-uri'
require 'uri'
require 'yaml'

BASE_URL = 'https://www.knjizare-vulkan.rs'
CSV_PATH = '_data/schools/celarevo_2_razred.csv'
YAML_PATH = '_data/schools/vulkan.yml'
IMAGE_DIR = 'assets/images/schools/vulkan'

def get(url)
  uri = URI(url)
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Mozilla/5.0'
    response = http.request(request)
    raise "GET #{url} failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    response.body
  end
end

def normalize(value)
  value.to_s.downcase
       .tr('čćšđž', 'ccsdz')
       .gsub(/[^a-z0-9]+/, ' ')
       .strip
end

def price_number(value)
  value.to_s.delete(',').to_f
end

def query_for(name)
  name.sub(/\s*-\s*/, ' ')
      .sub(/\s+20\d{2}\b/, '')
      .strip
end

def product_cards(html)
  doc = Nokogiri::HTML(html)
  doc.css('.nbf-product').filter_map do |card|
    link = card.at_css('.nb-product-name a') || card.at_css('a[href*="/"]')
    next unless link

    {
      title: card['data-productname'].to_s.strip,
      product_id: card['data-productid'].to_s.strip,
      sifra: card['data-productcode'].to_s.strip,
      izdavac: card['data-productbrand'].to_s.strip,
      category: card['data-productcat'].to_s.strip,
      price: price_number(card['data-productprice']),
      url: link['href']
    }
  end
end

def score(card, row)
  wanted = normalize(row[:name])
  title = normalize(card[:title])
  subject = normalize(row[:subject])
  score = 0
  wanted.split.each { |word| score += 3 if title.include?(word) && word.length > 1 }
  subject.split.first(2).each { |word| score += 2 if normalize(card[:category]).include?(word) && word.length > 2 }
  score += 8 if (card[:price] - row[:price]).abs < 0.01
  score += 3 if card[:izdavac].include?('VULKAN')
  score
end

def product_json(doc)
  doc.css('script[type="application/ld+json"]').each do |script|
    text = script.text.strip
    next unless text.include?('"@type": "Product"')
    return JSON.parse(text)
  rescue JSON::ParserError
    next
  end
  {}
end

def detail_for(url)
  html = get(url)
  doc = Nokogiri::HTML(html)
  data = product_json(doc)
  author = doc.at_css('#block5844 .nb-product-author-component .author-name')&.text&.strip
  image = Array(data['image']).first || doc.at_css('meta[property="og:image"]')&.[]('content')

  {
    title: data['name'].to_s.strip,
    description: data['description'].to_s.strip.gsub(/\s+/, ' '),
    autor: author.to_s,
    izdavac: data.dig('brand', 'name').to_s.strip,
    sifra: data['sku'].to_s.strip,
    isbn: data['isbn'].to_s.strip,
    image_url: image.to_s,
    link: data.dig('offers', 'url').to_s.strip.empty? ? url : data.dig('offers', 'url').to_s.strip
  }
end

def image_filename(item)
  ext = File.extname(URI(item[:image_url]).path)
  ext = '.webp' if ext.empty?
  "#{item[:sifra]}#{ext}"
end

csv_rows = CSV.read(CSV_PATH)
headers = csv_rows[1]
rows = csv_rows.drop(2).map do |values|
  row = headers.zip(values).to_h
  next if row['Predmet'].nil? || row['Naziv udžbenika'].nil?
  {
    subject: row['Predmet'].to_s.strip,
    name: row['Naziv udžbenika'].to_s.strip,
    price: price_number(row['MPC']),
    csv_izdavac: row['Izdavač'].to_s.strip
  }
end.compact

FileUtils.mkdir_p(IMAGE_DIR)

items = rows.map.with_index(1) do |row, index|
  query = query_for(row[:name])
  search_url = "#{BASE_URL}/proizvodi?#{URI.encode_www_form(search: query)}"
  candidates = product_cards(get(search_url))
  if candidates.empty?
    fallback_query = row[:name].split(/\s*-\s*/).first
    candidates = product_cards(get("#{BASE_URL}/proizvodi?#{URI.encode_www_form(search: fallback_query)}"))
  end

  best = candidates.max_by { |candidate| score(candidate, row) }
  raise "No Vulkan match for #{row[:name]}" unless best

  detail = detail_for(best[:url])
  filename = image_filename(detail)
  image_path = File.join(IMAGE_DIR, filename)
  URI.open(detail[:image_url], 'User-Agent' => 'Mozilla/5.0') do |remote|
    File.binwrite(image_path, remote.read)
  end

  warn format('%2d. %-45s -> %s', index, row[:name], detail[:sifra])

  {
    'predmet' => row[:subject],
    'naziv_udzbenika' => row[:name],
    'mpc' => row[:price],
    'title' => detail[:title],
    'description' => detail[:description],
    'autor' => detail[:autor],
    'izdavac' => detail[:izdavac],
    'sifra' => detail[:sifra],
    'isbn' => detail[:isbn],
    'link' => detail[:link],
    'image_url' => detail[:image_url],
    'image' => "/#{image_path}"
  }
end

File.write(YAML_PATH, items.to_yaml(line_width: -1))

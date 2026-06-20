#!/usr/bin/env ruby

require 'csv'
require 'fileutils'
require 'json'
require 'net/http'
require 'nokogiri'
require 'open-uri'
require 'uri'
require 'yaml'

CSV_PATH = ARGV[0] || File.join(__dir__, 'celarevo_7_razred.csv')
DATA_DIR = __dir__
IMAGE_ROOT = 'assets/images/schools'
TARGETS = { 'Bigz' => 'bigz', 'Klett' => 'klett', 'Vulkan' => 'vulkan', 'Eduka' => 'eduka', 'Logos' => 'logos', 'Gerundijum' => 'gerundijum', 'Zavod' => 'zavod' }

PUBLISHER_NAMES = {
  'bigz' => 'BIGZ školstvo',
  'klett' => 'Klett',
  'vulkan' => 'VULKAN ZNANJE',
  'eduka' => 'Eduka',
  'logos' => 'Logos',
  'gerundijum' => 'Gerundijum',
  'zavod' => 'Zavod za udžbenike'
}

# Exact matches kept here for products where site search returns ambiguous or stale results.
BIGZ_OVERRIDES = {
  ['Biologija', 'Udžbenik 7 - Bošković'] => 'https://www.bigzskolstvo.rs/proizvod/biologija-7/'
}

EDUKA_OVERRIDES = {
  ['Informatika i računarstvo', 'Udžbenik 7 - Aleksić'] => 'https://edukadoo.rs/product/informatika-i-racunarstvo-7/'
}

VULKAN_OVERRIDES = {
  ['Fizika', 'Udžbenik 7 - Nešić'] => 'https://www.knjizare-vulkan.rs/fizika7/275246-fizika-za-7-razred-udzbenik-novo',
  ['Fizika', 'Zbirka zadataka 7 - Nešić'] => 'https://www.knjizare-vulkan.rs/fizika7/275251-fizika-za-7-razred-zbirka-zadataka-novo'
}

ZAVOD_OVERRIDES = {
  ['Ruski jezik', 'Udžbenik 7 - Naš  klass 3 - Nikolić'] => 'https://www.sintra.rs/kupi/nas-klass-3-udzbenik-i-cd-za-ruski-jezik-za-7-razred-osnovne-skole-3601',
  ['Ruski jezik', 'Radna sveska 7 - Naš Klass 3 - Nikolić'] => 'https://www.sintra.rs/kupi/nas-klass-3-radna-sveska-za-ruski-jezik-za-7-razred-osnovne-skole-3602'
}

def get(url, limit = 5)
  raise "Too many redirects for #{url}" if limit <= 0

  uri = URI(url)
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Mozilla/5.0'
    response = http.request(request)

    case response
    when Net::HTTPSuccess
      response.body
    when Net::HTTPRedirection
      get(URI.join(url, response['location']).to_s, limit - 1)
    else
      raise "GET #{url} failed: #{response.code}"
    end
  end
end

def clean(text)
  text.to_s.gsub(/\s+/, ' ').strip
end

TRANSLITERATION = {
  "\u0410" => 'A', "\u0411" => 'B', "\u0412" => 'V', "\u0413" => 'G', "\u0414" => 'D', "\u0402" => 'Đ', "\u0415" => 'E', "\u0416" => 'Ž', "\u0417" => 'Z', "\u0418" => 'I', "\u0408" => 'J', "\u041A" => 'K', "\u041B" => 'L', "\u0409" => 'Lj', "\u041C" => 'M', "\u041D" => 'N', "\u040A" => 'Nj', "\u041E" => 'O', "\u041F" => 'P', "\u0420" => 'R', "\u0421" => 'S', "\u0422" => 'T', "\u040B" => 'Ć', "\u0423" => 'U', "\u0424" => 'F', "\u0425" => 'H', "\u0426" => 'C', "\u0427" => 'Č', "\u040F" => 'Dž', "\u0428" => 'Š',
  "\u0430" => 'a', "\u0431" => 'b', "\u0432" => 'v', "\u0433" => 'g', "\u0434" => 'd', "\u0452" => 'đ', "\u0435" => 'e', "\u0436" => 'ž', "\u0437" => 'z', "\u0438" => 'i', "\u0458" => 'j', "\u043A" => 'k', "\u043B" => 'l', "\u0459" => 'lj', "\u043C" => 'm', "\u043D" => 'n', "\u045A" => 'nj', "\u043E" => 'o', "\u043F" => 'p', "\u0440" => 'r', "\u0441" => 's', "\u0442" => 't', "\u045B" => 'ć', "\u0443" => 'u', "\u0444" => 'f', "\u0445" => 'h', "\u0446" => 'c', "\u0447" => 'č', "\u045F" => 'dž', "\u0448" => 'š'
}.freeze

def latinize(text)
  text.to_s.gsub(/[\u0400-\u04FF]/) { |char| TRANSLITERATION.fetch(char, char) }
end

def normalize(text)
  latinize(clean(text)).downcase
                       .gsub(/[čć]/, 'c')
                       .gsub('š', 's')
                       .gsub('đ', 'dj')
                       .gsub('ž', 'z')
                       .gsub(/[^a-z0-9]+/, ' ')
                       .strip
end

def price_number(value)
  s = latinize(value).gsub(/[[:space:]]/, '').gsub(/rsd|din\.?/i, '')
  if s.include?(',') && s.include?('.')
    s.index(',') < s.index('.') ? s.delete(',').to_f : s.delete('.').sub(',', '.').to_f
  elsif s.include?(',')
    s.split(',').last.to_s.length == 3 ? s.delete(',').to_f : s.sub(',', '.').to_f
  else
    s.to_f
  end
end

def csv_rows
  csv = CSV.read(CSV_PATH)
  headers = csv[1]
  csv.drop(2).filter_map do |values|
    row = headers.zip(values).to_h
    next if row['Predmet'].to_s.strip.empty? && row['Naziv udžbenika'].to_s.strip.empty?

    publisher = row['Izdavač'].to_s.strip
    {
      subject: row['Predmet'].to_s.strip,
      name: row['Naziv udžbenika'].to_s.strip,
      price: price_number(row['MPC']),
      publisher: publisher,
      target: TARGETS[publisher],
      link: row['link'].to_s.strip
    }
  end
end

def alert_unprocessed(rows, processed_rows, failed_rows)
  unsupported = rows.select { |row| row[:target].to_s.empty? }
  missing = unsupported + failed_rows
  return if missing.empty?

  warn ''
  warn 'ALERT: some CSV rows were not processed:'
  missing.each do |row|
    reason = row[:error] || "unsupported publisher #{row[:publisher]}"
    warn format(' - %-22s | %-52s | %-12s | %s', row[:subject], row[:name], row[:publisher], reason)
  end
end

def yaml_path(target)
  File.join(DATA_DIR, "#{target}.yml")
end

def image_dir(target)
  File.join(IMAGE_ROOT, target)
end

def load_existing(target)
  path = yaml_path(target)
  File.exist?(path) ? (YAML.load_file(path) || {}) : {}
end

def save_yaml(target, data)
  File.write(yaml_path(target), data.sort.to_h.to_yaml(line_width: -1))
end

def download_image(target, key, image_url)
  return '' if image_url.to_s.empty?

  FileUtils.mkdir_p(image_dir(target))
  ext = File.extname(URI(image_url).path)
  ext = '.jpg' if ext.empty?
  path = File.join(image_dir(target), "#{key}#{ext}")
  URI.open(image_url, 'User-Agent' => 'Mozilla/5.0') { |remote| File.binwrite(path, remote.read) }
  "/#{path}"
end

def product_json(doc)
  doc.css('script[type="application/ld+json"]').each do |script|
    data = JSON.parse(script.text.strip)
    nodes = data.is_a?(Hash) && data['@graph'] ? data['@graph'] : [data]
    product = nodes.find { |node| node.is_a?(Hash) && node['@type'].to_s == 'Product' }
    return product if product
  rescue JSON::ParserError
    next
  end
  {}
end

def meta_content(doc, key)
  doc.xpath('//meta').find { |meta| meta['property'] == key || meta['name'] == key }&.[]('content')
end

def linked_product(row)
  url = row[:link].to_s.strip
  raise "No link for #{row[:publisher]} #{row[:name]}" if url.empty?

  doc = Nokogiri::HTML(get(url))
  data = product_json(doc)
  title = clean(data['name'] || meta_content(doc, 'og:title') || doc.at_css('h1, h2, title')&.text || row[:name])
  description = clean(data['description'] || meta_content(doc, 'og:description') || doc.at_css('#content_tab_description, .product-details__info p, .opis, .description, p')&.text)
  image_url = clean(Array(data['image']).first || meta_content(doc, 'og:image') || doc.at_css('.woocommerce-product-gallery__image a')&.[]('href') || doc.at_css('img.wp-post-image, img')&.[]('src'))
  image_url = URI.join(url, image_url).to_s if !image_url.empty? && image_url !~ /^https?:/i
  key = clean(data['sku'] || doc.at_css('.sku')&.text || URI(url).query.to_s[/id=([^&]+)/, 1] || normalize(title).split.first(4).join('-'))

  detail = {
    title: title,
    description: description,
    autor: extract_author_from_description(description),
    izdavac: PUBLISHER_NAMES[row[:target]] || row[:publisher],
    isbn: clean(data['isbn']),
    link: url,
    image_url: image_url
  }
  [key, detail]
end

def extract_author_from_description(desc)
  clean(desc)[/(?:Autori|Autor):\s*([^\.]+)/, 1].to_s.strip
end

def item_hash(row, detail, key)
  item = {
    'naziv_udzbenika' => latinize(row[:name]),
    'mpc' => row[:price],
    'title' => latinize(detail[:title]),
    'description' => latinize(detail[:description]),
    'autor' => latinize(detail[:autor]),
    'izdavac' => latinize(detail[:izdavac]),
    'isbn' => detail[:isbn].to_s,
    'link' => detail[:link],
    'image_url' => detail[:image_url],
    'image' => download_image(row[:target], key, detail[:image_url])
  }
  item['predmet'] = latinize(row[:subject]) unless row[:target] == 'vulkan'
  item
end

def score_text(candidate, row)
  ignored = %w[udzbenik radna sveska sveskka zbirka zadataka laboratorijske vezbe deo]
  wanted = normalize(row[:name]).split.reject { |word| word.length < 2 || ignored.include?(word) }
  title = normalize(candidate[:title])
  score = wanted.sum { |word| title.include?(word) ? 3 : 0 }
  score += 8 if (candidate[:price].to_f - row[:price]).abs < 0.01
  score
end

def bigz_candidates(query)
  doc = Nokogiri::HTML(get("https://www.bigzskolstvo.rs/?#{URI.encode_www_form(s: query)}"))
  doc.css('article.product').filter_map do |article|
    link = article.at_css('h2.entry-title a') || article.at_css('a[href*="/proizvod/"]')
    next unless link

    { title: clean(link.text), url: link['href'], price: price_number(article.at_css('.price')&.text) }
  end
end

def scrape_bigz(row)
  return linked_product(row) unless row[:link].to_s.empty?

  url = BIGZ_OVERRIDES[[row[:subject], row[:name]]]
  unless url
    candidates = bigz_candidates(row[:name].sub('Radna sveskka', 'Radna sveska'))
    candidates = bigz_candidates("#{row[:subject]} 7 #{row[:publisher]}") if candidates.empty?
    best = candidates.max_by { |candidate| score_text(candidate, row) }
    raise "No BIGZ match for #{row[:name]}" unless best

    url = best[:url]
  end

  doc = Nokogiri::HTML(get(url))
  data = product_json(doc)
  key = clean(data['sku'].to_s.empty? ? doc.at_css('.sku')&.text : data['sku'])
  desc = clean(data['description'] || doc.at_css('#content_tab_description')&.text || doc.at_css('.entry-content')&.text || doc.at_css('meta[property="og:description"]')&.[]('content'))
  image_url = clean(data['image'] || doc.xpath('//meta').find { |meta| meta['property'] == 'og:image' }&.[]('content') || doc.at_css('img.wp-post-image')&.[]('src'))

  detail = {
    title: clean(data['name'] || doc.at_css('h1.product_title')&.text || doc.at_css('h1')&.text || row[:name]),
    description: desc,
    autor: extract_author_from_description(desc),
    izdavac: PUBLISHER_NAMES['bigz'],
    isbn: '',
    link: clean(data['url'] || url),
    image_url: image_url
  }
  [key, detail]
end

def klett_listing_url(row)
  subject = case row[:subject]
            when 'Muzička kultura' then 'muzicka-kultura'
            when 'Likovna kultura' then 'likovna-kultura'
            else normalize(row[:subject]).tr(' ', '-')
            end
  "https://klett.rs/izdanja/?pretraga=1&type=udzbenici-na-srpskom-jeziku&age=7-razred-osnovna-skola&subject=#{subject}"
end

def scrape_klett(row)
  return linked_product(row) unless row[:link].to_s.empty?

  doc = Nokogiri::HTML(get(klett_listing_url(row)))
  candidates = doc.css('.product-item-wrapper').filter_map do |wrap|
    product = wrap.at_css('.gtm4wp_productdata')
    link = wrap.at_css('.woocommerce-loop-product__title') || wrap.at_css('a[href*="/izdanje/"]')
    next unless product && link

    {
      key: product['data-gtm4wp_product_id'],
      title: clean(product['data-gtm4wp_product_name'] || link.text),
      price: price_number(product['data-gtm4wp_product_price']),
      url: product['data-gtm4wp_product_url'] || link['href']
    }
  end
  best = candidates.max_by { |candidate| score_text(candidate, row) }
  raise "No Klett match for #{row[:name]}" unless best

  detail_doc = Nokogiri::HTML(get(best[:url]))
  info = detail_doc.at_css('.product-details__info')
  authors = detail_doc.css('.product-details__authors li a').map { |a| clean(a.text).sub(/,\z/, '') }.reject(&:empty?).join(', ')
  isbn = nil
  detail_doc.css('.product-details__other-info').each do |node|
    isbn = clean(node.at_css('span')&.text) if node.at_css('h3')&.text.to_s.include?('ISBN')
  end

  detail = {
    title: clean(detail_doc.at_css('.product-details__title.mobile-hide')&.text || best[:title]),
    description: clean(info&.at_css('p')&.text),
    autor: authors,
    izdavac: PUBLISHER_NAMES['klett'],
    isbn: isbn.to_s,
    link: best[:url],
    image_url: clean(detail_doc.at_css('.woocommerce-product-gallery__image a')&.[]('href') || detail_doc.at_css('.wp-post-image')&.[]('src'))
  }
  [best[:key], detail]
end

def logos_listing_url(row)
  subject = case row[:subject]
            when 'Engleski jezik' then 'engleski-jezik'
            when 'Istorija' then 'istorija'
            when 'Hemija' then 'hemija'
            when 'Tehnika i tehnologija' then 'tehnika-i-tehnologija'
            else normalize(row[:subject]).tr(' ', '-')
            end
  "https://logos-edu.rs/izdanja/?pretraga=1&type=udzbenici-na-srpskom-jeziku&age=7-razred-osnovna-skola&subject=#{subject}"
end

def scrape_logos(row)
  return linked_product(row) unless row[:link].to_s.empty?

  doc = Nokogiri::HTML(get(logos_listing_url(row)))
  candidates = doc.css('.product-item-wrapper').filter_map do |wrap|
    product = wrap.at_css('.gtm4wp_productdata')
    link = wrap.at_css('.woocommerce-loop-product__title') || wrap.at_css('a[href*="/izdanje/"]')
    next unless product && link

    {
      key: product['data-gtm4wp_product_id'],
      title: clean(product['data-gtm4wp_product_name'] || link.text),
      price: price_number(product['data-gtm4wp_product_price']),
      url: product['data-gtm4wp_product_url'] || link['href']
    }
  end
  best = candidates.max_by { |candidate| score_text(candidate, row) }
  raise "No Logos match for #{row[:name]}" unless best

  detail_doc = Nokogiri::HTML(get(best[:url]))
  info = detail_doc.at_css('.product-details__info')
  authors = detail_doc.css('.product-details__authors li a').map { |a| clean(a.text).sub(/,\z/, '') }.reject(&:empty?).join(', ')
  isbn = nil
  detail_doc.css('.product-details__other-info').each do |node|
    isbn = clean(node.at_css('span')&.text) if latinize(node.at_css('h3')&.text).include?('ISBN')
  end

  detail = {
    title: clean(detail_doc.at_css('.product-details__title.mobile-hide')&.text || best[:title]),
    description: clean(info&.at_css('p')&.text),
    autor: authors,
    izdavac: PUBLISHER_NAMES['logos'],
    isbn: isbn.to_s,
    link: best[:url],
    image_url: clean(detail_doc.at_css('.woocommerce-product-gallery__image a')&.[]('href') || detail_doc.at_css('.wp-post-image')&.[]('src'))
  }
  [best[:key], detail]
end

def scrape_eduka(row)
  return linked_product(row) unless row[:link].to_s.empty?

  url = EDUKA_OVERRIDES[[row[:subject], row[:name]]]
  raise "No Eduka override for #{row[:name]}" unless url

  doc = Nokogiri::HTML(get(url))
  attrs = doc.css('.woocommerce-product-attributes-item')
  detail = {
    title: clean(doc.at_css('h1.product_title')&.text || doc.at_css('h1')&.text),
    description: clean(doc.at_css('.woocommerce-product-details__short-description')&.text || doc.at_css('meta[property="og:description"]')&.[]('content')),
    autor: attrs.filter_map { |node| clean(node.at_css('td')&.text) if latinize(node.at_css('th')&.text).include?('Autor') }.first.to_s,
    izdavac: PUBLISHER_NAMES['eduka'],
    isbn: attrs.filter_map { |node| clean(node.at_css('td')&.text) if node.at_css('th')&.text.to_s.downcase.include?('isbn') }.first.to_s,
    link: url,
    image_url: clean(doc.at_css('.woocommerce-product-gallery__image a')&.[]('href') || doc.at_css('meta[property="og:image"]')&.[]('content'))
  }
  [clean(doc.at_css('.sku')&.text), detail]
end

def scrape_vulkan(row)
  return linked_product(row) unless row[:link].to_s.empty?

  url = VULKAN_OVERRIDES[[row[:subject], row[:name]]]
  raise "No Vulkan override for #{row[:name]}" unless url

  doc = Nokogiri::HTML(get(url))
  data = product_json(doc)
  detail = {
    title: clean(data['name'] || doc.at_css('h1')&.text),
    description: clean(data['description']),
    autor: clean(doc.at_css('#block5844 .nb-product-author-component .author-name')&.text),
    izdavac: clean(data.dig('brand', 'name') || PUBLISHER_NAMES['vulkan']),
    isbn: clean(data['isbn']),
    link: clean(data.dig('offers', 'url') || url),
    image_url: clean(Array(data['image']).first || doc.at_css('meta[property="og:image"]')&.[]('content'))
  }
  [clean(data['sku']), detail]
end

def scrape_zavod(row)
  url = row[:link].to_s.strip
  url = ZAVOD_OVERRIDES[[row[:subject], row[:name]]] if url.empty?
  raise "No Zavod/Sintra link for #{row[:name]}" if url.to_s.empty?

  doc = Nokogiri::HTML(get(url))
  title = clean(doc.at_css('h1, .product-single__title, .product__title')&.text || meta_content(doc, 'og:title') || row[:name])
  description = clean(meta_content(doc, 'og:description') || doc.css('.product-single__description, .product-description, .description, .tab-content, p').map(&:text).join(' '))
  page_text = clean(doc.text)
  image_url = clean(meta_content(doc, 'og:image') || doc.css('img').map { |img| img['src'].to_s }.find { |src| src.include?('nas-klass-3') })
  image_url = URI.join(url, image_url).to_s if !image_url.empty? && image_url !~ /^https?:/i
  key = URI(url).path[/-(\d+)\z/, 1]
  sku = description[/SKU\s+(\S+)/, 1]
  ean = page_text[/EAN\s+(\S+)/, 1] || description[/EAN\s+(\S+)/, 1]
  authors = (page_text[/Autori\s+(.+?)\s+Predmet\s+/m, 1] || description[/Autori\s+(.+?)\s+Predmet\s+/m, 1]).to_s

  detail = {
    title: title,
    description: description,
    autor: authors,
    izdavac: PUBLISHER_NAMES['zavod'],
    isbn: ean.to_s,
    link: '',
    image_url: image_url
  }
  [clean(sku || key), detail]
end

def scrape_gerundijum(row)
  url = row[:link].to_s.strip
  raise "No Gerundijum link for #{row[:name]}" if url.empty?

  doc = Nokogiri::HTML(get(url))
  text = clean(doc.text)
  title = text[/((?:МАТЕМАТИКА|ЗБИРКА ЗАДАТАКА ИЗ МАТЕМАТИКЕ) за 7\. разред основне школе)/, 1]
  title = row[:name] if title.to_s.empty?
  authors = text[/Аутори\s*:\s*(.+?)Формат\s*:/, 1].to_s.gsub(/(?<=[[:lower:]а-я])(?=[А-ЯЂЈЉЊЋЏA-Z]\.)/, ', ')
  isbn = text[/ISBN број\s*:\s*([^Ц]+)/, 1]
  image_url = doc.css('img').map { |img| img['src'].to_s }.find { |src| src.include?('img/udzbenici/') }.to_s
  image_url = URI.join(url, image_url).to_s unless image_url.empty?
  key = URI(url).query.to_s[/id=([^&]+)/, 1]

  detail = {
    title: latinize(title),
    description: latinize([title, authors].reject(&:empty?).join(' - ')),
    autor: latinize(authors),
    izdavac: PUBLISHER_NAMES['gerundijum'],
    isbn: clean(isbn),
    link: url,
    image_url: image_url
  }
  [key, detail]
end

all_rows = csv_rows
rows = all_rows.select { |row| row[:target] }
failed_rows = []
processed_rows = []
by_target = Hash.new { |hash, target| hash[target] = load_existing(target) }
rows.each_with_index do |row, index|
  begin
    key, detail = case row[:target]
                  when 'bigz' then scrape_bigz(row)
                  when 'klett' then scrape_klett(row)
                  when 'logos' then scrape_logos(row)
                  when 'gerundijum' then scrape_gerundijum(row)
                  when 'zavod' then scrape_zavod(row)
                  when 'eduka' then scrape_eduka(row)
                  when 'vulkan' then scrape_vulkan(row)
                  end
    raise "Empty key for #{row[:publisher]} #{row[:name]}" if key.to_s.empty?

    by_target[row[:target]][key] = item_hash(row, detail, key)
    processed_rows << row.merge(key: key)
    warn format('%2d. %-7s %-44s -> %s', index + 1, row[:publisher], row[:name], key)
  rescue StandardError => e
    failed_rows << row.merge(error: e.message)
    warn format('%2d. %-7s %-44s -> FAILED: %s', index + 1, row[:publisher], row[:name], e.message)
  end
end
by_target.each { |target, data| save_yaml(target, data) }
alert_unprocessed(all_rows, processed_rows, failed_rows)
exit 1 unless failed_rows.empty? && all_rows.all? { |row| row[:target] }

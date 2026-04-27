#!/usr/bin/env ruby
# Downloads images from tmp/export.csv (Shopify export) and writes them into
# the matching article post's front matter (image / images fields).
# Skips image fields that are already set.

require "csv"
require "yaml"
require "uri"
require "net/http"
require "openssl"
require "fileutils"

REPO_DIR        = File.expand_path("..", __dir__)
COLLECTIONS_DIR = File.join(REPO_DIR, "_data/collections")
CSV_PATH        = File.join(REPO_DIR, "tmp/export.csv")
IMAGES_DIR      = File.join(REPO_DIR, "assets/images")

# Build SKU -> file path index
sku_to_path = {}
Dir.glob(File.join(COLLECTIONS_DIR, "*.yml")).each do |yml_path|
  collection_name = File.basename(yml_path, ".yml")
  Dir.glob(File.join(REPO_DIR, "_#{collection_name}", "*.md")).each do |md_path|
    sku = File.basename(md_path, ".md").split("-").first.to_i
    sku_to_path[sku] = md_path
  end
end

# Group rows by Handle, collecting SKU and image URLs in order
products = {}
CSV.foreach(CSV_PATH, headers: true) do |row|
  handle    = row["Handle"].to_s.strip
  image_src = row["Image Src"].to_s.strip
  sku_raw   = row["Variant SKU"].to_s.strip

  next if handle.empty? || image_src.empty?

  products[handle] ||= { sku: nil, images: [] }
  products[handle][:sku] ||= sku_raw.to_i unless sku_raw.empty?
  products[handle][:images] << image_src
end

def download(url, dest)
  uri = URI.parse(url)
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                  verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
    response = http.get(uri.request_uri)
    File.binwrite(dest, response.body)
  end
end

def ext_from_url(url)
  path = URI.parse(url).path
  ext  = File.extname(path)
  ext.empty? ? ".jpg" : ext
end

updated = skipped = missing = 0

products.each do |handle, product|
  sku     = product[:sku]
  urls    = product[:images]
  md_path = sku_to_path[sku]

  unless md_path
    puts "  MISSING sku=#{sku} handle=#{handle}"
    missing += 1
    next
  end

  raw           = File.read(md_path)
  front_matter  = YAML.safe_load(raw.match(/\A---\n(.*?\n)---\n/m)&.send(:[], 1) || "") || {}

  if front_matter["image"]
    skipped += 1
    next
  end

  image_dir = File.join(IMAGES_DIR, sku.to_s)
  FileUtils.mkdir_p(image_dir)

  local_paths = urls.each_with_index.map do |url, i|
    ext      = ext_from_url(url)
    filename = "#{i + 1}#{ext}"
    dest     = File.join(image_dir, filename)
    unless File.exist?(dest)
      print "  Downloading #{url[0..60]}... "
      download(url, dest)
      puts "ok"
    end
    "/assets/images/#{sku}/#{filename}"
  end

  front_matter["image"]  = local_paths.first
  front_matter["images"] = local_paths[1..] if local_paths.size > 1

  new_fm      = front_matter.to_yaml
  body        = raw.match(/\A---\n.*?\n---\n(.*)\z/m)&.send(:[], 1) || ""
  File.write(md_path, "#{new_fm}---\n#{body}")

  updated += 1
end

puts "Done: #{updated} updated, #{skipped} skipped (already have image), #{missing} SKUs not found"

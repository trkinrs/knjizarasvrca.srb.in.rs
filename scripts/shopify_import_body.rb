#!/usr/bin/env ruby
# Reads tmp/export.csv (Shopify export) and writes the Body (HTML) converted to
# Markdown into the matching article post, found by Variant SKU.

require "csv"
require "reverse_markdown"

REPO_DIR        = File.expand_path("..", __dir__)
COLLECTIONS_DIR = File.join(REPO_DIR, "_data/collections")
CSV_PATH        = File.join(REPO_DIR, "tmp/export.csv")

# Build a SKU -> file path index across all collection dirs
sku_to_path = {}
Dir.glob(File.join(COLLECTIONS_DIR, "*.yml")).each do |yml_path|
  collection_name = File.basename(yml_path, ".yml")
  Dir.glob(File.join(REPO_DIR, "_#{collection_name}", "*.md")).each do |md_path|
    filename = File.basename(md_path, ".md")
    sku = filename.split("-").first.to_i
    sku_to_path[sku] = md_path
  end
end

updated = skipped = missing = 0

CSV.foreach(CSV_PATH, headers: true) do |row|
  sku_raw  = row["Variant SKU"].to_s.strip
  body_html = row["Body (HTML)"].to_s.strip

  next if sku_raw.empty? || body_html.empty?

  sku = sku_raw.to_i
  md_path = sku_to_path[sku]

  unless md_path
    print "  MISSING sku=#{sku} (title: #{row["Title"]}) — nastavi? [y/N] "
    answer = $stdin.gets.to_s.strip.downcase
    unless answer == "y"
      puts "Prekinuto. #{updated} updated, #{skipped} skipped, #{missing} SKUs not found."
      exit 1
    end
    missing += 1
    next
  end

  markdown_body = ReverseMarkdown.convert(body_html, unknown_tags: :bypass).strip

  content = File.read(md_path)

  # Replace everything after the closing --- of front matter
  if content =~ /\A(---\n.*?\n---\n)/m
    front_matter = $1
    new_content  = "#{front_matter}\n#{markdown_body}\n"
    if content == new_content
      skipped += 1
    else
      File.write(md_path, new_content)
      updated += 1
    end
  else
    puts "  SKIPPED (no front matter): #{md_path}"
    skipped += 1
  end
end

puts "Done: #{updated} updated, #{skipped} skipped, #{missing} SKUs not found"

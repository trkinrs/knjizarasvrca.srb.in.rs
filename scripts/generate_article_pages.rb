#!/usr/bin/env ruby
# Syncs _data/collections/*.yml into _{collection}/{sku}-{title}.md pages.
# Run to create/update/remove pages whenever collection data changes.

require "yaml"
require "fileutils"

COLLECTIONS_DIR = File.expand_path("../_data/collections", __dir__)
REPO_DIR        = File.expand_path("..", __dir__)

LATIN_MAP = {
  "č" => "c", "ć" => "c", "š" => "s", "ž" => "z", "đ" => "dj",
  "Č" => "c", "Ć" => "c", "Š" => "s", "Ž" => "z", "Đ" => "dj",
}.freeze

def slug(str)
  s = str.dup
  LATIN_MAP.each { |k, v| s.gsub!(k, v) }
  s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
end

def page_content(sku, item)
  front_matter = {
    "layout" => "article",
    "title"  => item["title"].to_s,
    "sku"    => sku,
  }

  "#{front_matter.to_yaml}---\n"
end

# Collect all pages that should exist after this run
desired_files = {}

Dir.glob(File.join(COLLECTIONS_DIR, "*.yml")).sort.each do |yml_path|
  collection_name = File.basename(yml_path, ".yml")
  collection_dir  = File.join(REPO_DIR, "_#{collection_name}")

  items = YAML.safe_load(File.read(yml_path))
  next unless items.is_a?(Hash)

  items.each do |sku, item|
    next unless item.is_a?(Hash)

    title_slug = slug(item["title"].to_s)
    file_path  = File.join(collection_dir, "#{sku}-#{title_slug}.md")
    desired_files[file_path] = page_content(sku, item)
  end
end

# Existing files across all collection dirs
existing_files = Dir.glob(File.join(COLLECTIONS_DIR, "*.yml")).flat_map do |yml_path|
  collection_name = File.basename(yml_path, ".yml")
  Dir.glob(File.join(REPO_DIR, "_#{collection_name}", "*.md"))
end

# Create or update pages
created = updated = 0
desired_files.each do |path, content|
  FileUtils.mkdir_p(File.dirname(path))
  if File.exist?(path)
    if File.read(path) != content
      File.write(path, content)
      updated += 1
    end
  else
    File.write(path, content)
    created += 1
  end
end

# Remove pages that no longer correspond to any item
removed = 0
existing_files.each do |path|
  unless desired_files.key?(path)
    File.delete(path)
    removed += 1
  end
end

puts "Done: #{created} created, #{updated} updated, #{removed} removed"

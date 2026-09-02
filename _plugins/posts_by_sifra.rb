# frozen_string_literal: true

module Jekyll
  # Builds a constant-time lookup for product documents:
  #   {% assign product = site.posts_by_sifra[book.sifra] %}
  #   {{ product.image }}
  class PostsBySifraGenerator < Generator
    safe true
    priority :highest

    IMAGE_EXTENSIONS = %w[.avif .gif .jpeg .jpg .png .webp].freeze

    def generate(site)
      posts_by_sifra = {}

      site.collections.each_value do |collection|
        collection.docs.each do |post|
          sifra = post.data["sifra"] || post.data["sku"]
          next if sifra.nil? || sifra.to_s.empty?

          key = sifra.to_s
          if posts_by_sifra.key?(key)
            Jekyll.logger.warn(
              "posts_by_sifra:",
              "duplicate sifra #{key.inspect}; keeping #{posts_by_sifra[key].relative_path}"
            )
            next
          end

          add_images(site, post, key)
          posts_by_sifra[key] = post
        end
      end

      site.config["posts_by_sifra"] = posts_by_sifra
    end

    private

    def add_images(site, post, sifra)
      return if post.data["image"]

      relative_dir = File.join("assets", "images", sifra)
      image_dir = File.join(site.source, relative_dir)
      return unless Dir.exist?(image_dir)

      images = Dir.children(image_dir)
        .select { |filename| IMAGE_EXTENSIONS.include?(File.extname(filename).downcase) }
        .sort
        .map { |filename| "/#{File.join(relative_dir, filename)}" }

      return if images.empty?

      post.data["image"] = images.first
      post.data["images"] = images.drop(1) if images.length > 1
    end
  end
end

module Jekyll
  class RedirectGenerator < Generator
    safe true

    def generate(site)
      docs = []
      docs.concat(site.pages) if site.respond_to?(:pages)
      docs.concat(site.posts.docs) if site.respond_to?(:posts)
      @admin_dirs = []
      docs.each do |doc|
        create_redirect_page(site, doc)
      end
    end

    private

    # Debug in console
    # irb -r jekyll
    # site = Jekyll::Site.new(Jekyll.configuration); site.read
    # doc = site.posts.docs.last
    # doc = site.pages.last
    def create_redirect_page(site, doc)
      doc_url = doc.url # "/jekyll/pixyll/2014/06/10/see-pixyll-in-action/"
      relative_path = doc.relative_path # "_posts/2014-06-10-see-pixyll-in-action.md"

      # site.pages.map &:url
      # => ["/404.html", "/about/", "/contact/", "/fb-instant-articles.xml", "/feed.xml", "/", "/manifest.json", "/css/pixyll.css", "/sw.js", "/thanks/"]
      dir = if doc_url.include? "." # eg: "index.html"
        File.dirname(doc_url)
      else
        doc_url
      end
      admin_dir = File.join(dir.sub(%r{^/}, ""), "admin")
      return if @admin_dirs.include? admin_dir
      @admin_dirs << admin_dir

      redirect_page = Jekyll::Page.new(site, site.source, admin_dir, "index.html")
      redirect_page.data["layout"] = "admin_redirect"
      redirect_page.data["relative_path"] = relative_path

      site.pages << redirect_page
      admin_dir
    end
  end
end

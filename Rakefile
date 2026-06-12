require "rake"
require "digest"
require "fileutils"
require "tmpdir"

GITHUB_PAGES_BRANCH = "gh-pages"
PLATFORM = "--platform linux/amd64"
JEKYLL_IMAGE = "jekyll/jekyll:latest"
REPO_DIR = File.expand_path(__dir__)
BUILD_DIR = "#{REPO_DIR}_site"

def sync_changed_files(source_dir, target_dir)
  source_paths = Dir.glob("#{source_dir}/**/*", File::FNM_DOTMATCH)
    .reject { |path| [ ".", ".." ].include? File.basename(path) }
    .reject { |path| File.directory?(path) }
    .map { |path| path.delete_prefix("#{source_dir}/") }

  target_paths = Dir.glob("#{target_dir}/**/*", File::FNM_DOTMATCH)
    .reject { |path| [ ".", ".." ].include? File.basename(path) }
    .reject { |path| File.directory?(path) }
    .map { |path| path.delete_prefix("#{target_dir}/") }
    .reject { |path| path == ".git" || path.start_with?(".git/") }

  (target_paths - source_paths).each do |relative_path|
    FileUtils.rm_f File.join(target_dir, relative_path)
  end

  source_paths.each do |relative_path|
    source_path = File.join(source_dir, relative_path)
    target_path = File.join(target_dir, relative_path)

    next if File.file?(target_path) && Digest::SHA256.file(source_path).hexdigest == Digest::SHA256.file(target_path).hexdigest

    FileUtils.mkdir_p File.dirname(target_path)
    FileUtils.cp source_path, target_path
  end
end

desc "Build the site with Jekyll"
task :build, [ :baseurl ] do |task, args|
  baseurl = args[:baseurl] || ""
  if ENV["LP_USE_DOCKER_INSTEAD_OF_LOCAL_RUBY"] == "true"
    # TODO: does not work on macOS
    sh <<~HERE_DOC
      docker run --rm \
        #{PLATFORM} \
        --volume "#{REPO_DIR}:/srv/jekyll" \
        --volume "#{BUILD_DIR}:/srv/jekyll/_site" \
        -w /srv/jekyll \
        #{JEKYLL_IMAGE} \
        jekyll build \
        --baseurl '#{baseurl}'
    HERE_DOC
  else
    sh "bundle install"
    sh "bundle exec jekyll build -d #{BUILD_DIR} --baseurl '#{baseurl}'"
  end
end

desc "Commit source code to main, rebase, and push"
task :commit_and_push_with_rebase do
  sh "git add ."
  sh %(git commit -m "Update source site content" || echo 'Nothing to commit on main')
  sh "git pull --rebase || echo 'cannot rebase, probably no main branch on remote yet'"
  sh "git push origin main"
end

desc "Deploy to #{GITHUB_PAGES_BRANCH} branch using a temporary build dir (does not touch #{BUILD_DIR})"
task :deploy do
  origin = `git config --get remote.origin.url`.strip
  fail "origin is empty" if origin.empty?

  Dir.mktmpdir do |tmp|
    build_dir = File.join(tmp, "build")
    pages_dir = File.join(tmp, "pages")
    FileUtils.mkdir_p [ build_dir, pages_dir ]

    if ENV["LP_USE_DOCKER_INSTEAD_OF_LOCAL_RUBY"] == "true"
      sh <<~HERE_DOC
        docker run --rm \
          #{PLATFORM} \
          --volume "#{REPO_DIR}:/srv/jekyll" \
          --volume "#{build_dir}:/srv/jekyll/_site" \
          -w /srv/jekyll \
          #{JEKYLL_IMAGE} \
          jekyll build
      HERE_DOC
    else
      sh "bundle exec jekyll build -d #{build_dir}"
    end

    Dir.chdir pages_dir do
      sh "git init"
      sh "git remote add origin #{origin}"

      if system("git fetch --depth=1 origin #{GITHUB_PAGES_BRANCH}")
        sh "git checkout -B #{GITHUB_PAGES_BRANCH} origin/#{GITHUB_PAGES_BRANCH}"
      else
        sh "git checkout --orphan #{GITHUB_PAGES_BRANCH}"
      end

      sync_changed_files build_dir, pages_dir

      sh "git add -A"
      if system("git diff --cached --quiet")
        puts "No changes to publish on #{GITHUB_PAGES_BRANCH}"
        next
      end

      sh "git commit -m 'Site updated at #{Time.now.utc}'"

      puts "Pushing to #{origin}"
      sh "git push origin #{GITHUB_PAGES_BRANCH}"
    end
  end
end

desc "Full deploy: commit source and publish site"
task commit_and_push: [ :commit_and_push_with_rebase, :deploy ]

desc "Pull the repo"
task :pull do |task, args|
  sh "git pull --rebase"
end


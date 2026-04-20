require "rake"
require "fileutils"
require "tmpdir"

GITHUB_PAGES_BRANCH = "gh-pages"
PLATFORM = "--platform linux/amd64"
JEKYLL_IMAGE = "jekyll/jekyll:latest"
REPO_DIR = File.expand_path(__dir__)
BUILD_DIR = "#{REPO_DIR}_site"

desc "Build the site with Jekyll"
task :build, [:baseurl] do |task, args|
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
    # sh "bundle install"
    sh "bundle exec jekyll build -d #{BUILD_DIR} --baseurl '#{baseurl}'"
  end
end

desc "Commit source code to main"
task :commit_source do
  sh "git add ."
  sh %(git commit -m "Update source site content" || echo 'Nothing to commit on main')
  sh "git push origin main"
end

desc "Deploy #{BUILD_DIR} to #{GITHUB_PAGES_BRANCH} branch"
task :deploy do
  origin = `git config --get remote.origin.url`
  fail "origin is empty" if origin.empty?

  Rake::Task[:build].invoke

  current_public_folder = Dir.pwd
  Dir.mktmpdir do |tmp|
    cp_r "#{BUILD_DIR}/.", tmp

    Dir.chdir tmp

    sh "git init"
    sh "git checkout #{GITHUB_PAGES_BRANCH} 2>/dev/null || git checkout --orphan #{GITHUB_PAGES_BRANCH}"
    sh "git add . && git commit -m 'Site updated at #{Time.now.utc}'"

    sh "git remote add origin #{origin}"

    puts "Pushing to #{origin}"
    sh "git push --force origin #{GITHUB_PAGES_BRANCH}"

    Dir.chdir current_public_folder
  end
end

desc "Full deploy: commit source and publish site"
task commit_and_push: [ :commit_source, :deploy ]

desc "Pull the repo"
task :pull do |task, args|
  sh "git pull"
end

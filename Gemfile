# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }

# TODO: check on clean install if those are needed
gem 'gem-release'
gem 'faraday-retry'

group :jekyll_plugins do
  gem 'github-pages', group: :jekyll_plugins
  # gem 'jekyll-admin', group: :jekyll_plugins  
end

group :test do
  gem 'html-proofer'
end

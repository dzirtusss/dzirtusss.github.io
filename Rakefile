require 'html-proofer'

task :test do
  sh "bundle exec jekyll build"
  options = {
    assume_extension: true,
    internal_domains: ["dzirtusss.github.io"]
  }
  HTMLProofer.check_directory("./_site", options).run
end

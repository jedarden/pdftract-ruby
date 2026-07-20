# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

Rake::TestTask.new(:conformance) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/codegen/conformance_test.rb"]
  t.warning = false
end

task default: :test

desc "Build the gem"
task :build do
  sh "gem build pdftract.gemspec"
end

desc "Install the gem locally"
task install: :build do
  sh "gem install pdftract-*.gem"
end

desc "Clean build artifacts"
task :clean do
  sh "rm -f *.gem"
end

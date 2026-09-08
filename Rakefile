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

# The fast static pre-filter gates the slow containerized suite
# (pdftract-ruby/docs/plan/plan.md ADR-001): a visibility-keyword regression
# fails in milliseconds, before the conformance suite spins up.
task conformance: :"lint:visibility"

task default: [:test, :"lint:visibility"]

desc "Static lint for Ruby visibility-keyword bugs in generated lib/ output " \
     "(see docs/plan/plan.md ADR-001, Alternative 3)"
task :"lint:visibility" do
  ruby "tools/lint_visibility.rb lib"
end

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

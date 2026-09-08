# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "tempfile"
require "open3"
require "rbconfig"

require_relative "../../tools/lint_visibility"

module Pdftract
  module Codegen
    #
    # Tests for the static visibility-keyword lint (tools/lint_visibility.rb).
    #
    # The lint exists because the codegen template emitted a bare `private`
    # above the internal helpers with no `public` before the contract-method
    # block, making the entire generated Client API private
    # (docs/plan/plan.md ADR-001, bug #2 of the 2026-07-20 audit). The
    # regression fixtures below reproduce that exact shape.
    #
    class LintVisibilityTest < Minitest::Test
      BUGGY_GENERATED = <<~RUBY
        class Client
          def initialize(binary_path = "pdftract")
            @binary_path = binary_path
          end

          private

          def exec(*args)
            args
          end

          def map_error(stderr, exit_code)
            stderr
          end

          def extract(source, options = nil)
            exec("extract")
          end

          def extract_text(source, options = nil)
            exec("extract", "--text")
          end
        end
      RUBY

      PATCHED_GENERATED = <<~RUBY
        class Client
          def initialize(binary_path = "pdftract")
            @binary_path = binary_path
          end

          private

          def exec(*args)
            args
          end

          def map_error(stderr, exit_code)
            stderr
          end

          public

          def extract(source, options = nil)
            exec("extract")
          end

          def extract_text(source, options = nil)
            exec("extract", "--text")
          end
        end
      RUBY

      def test_buggy_generated_shape_flags_every_contract_method
        methods = PdftractVisibilityLint.analyze(BUGGY_GENERATED)
        private_names = methods.select { |m| m[:visibility] != :public }.map { |m| m[:name] }

        assert_equal %w[exec map_error extract extract_text].sort, private_names.sort
      end

      def test_buggy_generated_shape_reports_the_offending_keyword_line
        methods = PdftractVisibilityLint.analyze(BUGGY_GENERATED)
        extract = methods.find { |m| m[:name] == "extract" }

        assert_equal :private, extract[:visibility]
        assert_equal 6, extract[:switch_line], "must point at the bare `private' that hid the API"
      end

      def test_patched_generated_shape_is_clean
        assert_empty lint_source(PATCHED_GENERATED)
      end

      def test_default_allowlist_permits_the_internal_helpers
        methods = PdftractVisibilityLint.analyze(PATCHED_GENERATED)
        exec = methods.find { |m| m[:name] == "exec" }

        assert_equal :private, exec[:visibility], "exec is intentionally private in the generated file"
        assert_empty lint_source(PATCHED_GENERATED), "but it is allowlisted, so no violation"
      end

      def test_no_default_allowlist_flag
        violations = lint_source(PATCHED_GENERATED, allowlist: [])
        assert_equal %w[exec map_error], violations.map(&:name).sort
      end

      def test_explicit_allow_private_option
        violations = lint_source(BUGGY_GENERATED, allowlist: %w[exec map_error extract extract_text])
        assert_empty violations
      end

      def test_initialize_is_never_reported
        source = "class Client\n  private\n  def initialize(x); end\nend\n"
        assert_empty lint_source(source, allowlist: [])
      end

      def test_inline_private_def_does_not_leak_to_following_methods
        source = <<~RUBY
          class Client
            private def helper
              1
            end

            def extract(source)
              helper
            end
          end
        RUBY
        methods = PdftractVisibilityLint.analyze(source)

        assert_equal :private, methods.find { |m| m[:name] == "helper" }[:visibility]
        assert_equal :public, methods.find { |m| m[:name] == "extract" }[:visibility]
      end

      def test_symbol_list_form_does_not_change_section_state
        source = <<~RUBY
          class Client
            def extract(source)
              1
            end

            private :extract

            def extract_text(source)
              2
            end
          end
        RUBY
        methods = PdftractVisibilityLint.analyze(source)

        assert_equal :public, methods.find { |m| m[:name] == "extract_text" }[:visibility],
                     "`private :extract` names one method; it must not privatize what follows"
      end

      def test_singleton_methods_are_not_governed_by_bare_private
        source = <<~RUBY
          class Client
            private

            def helper; end

            def self.build
              new
            end
          end
        RUBY
        methods = PdftractVisibilityLint.analyze(source)

        assert_equal :public, methods.find { |m| m[:name] == "build" }[:visibility]
      end

      def test_visibility_state_does_not_leak_across_class_bodies
        source = <<~RUBY
          module Pdftract
            class Internal
              private

              def helper; end
            end

            class Client
              def extract(source)
                1
              end
            end
          end
        RUBY
        methods = PdftractVisibilityLint.analyze(source)

        assert_equal :private, methods.find { |m| m[:name] == "helper" }[:visibility]
        assert_equal :public, methods.find { |m| m[:name] == "extract" }[:visibility]
      end

      def test_accessors_are_checked_too
        source = <<~RUBY
          class Client
            private

            attr_reader :binary_path
            attr_accessor(:version)
          end
        RUBY
        names = lint_source(source, allowlist: []).map(&:name)

        assert_equal %w[binary_path version], names.sort
      end

      def test_unparseable_source_is_reported_not_silently_passed
        Dir.mktmpdir do |dir|
          file = File.join(dir, "broken.rb")
          File.write(file, "class Client\ndef extract(\n")

          result = PdftractVisibilityLint.lint_path([dir])

          assert_equal [file], result[:parse_errors]
        end
      end

      def test_test_and_spec_files_are_skipped
        Dir.mktmpdir do |dir|
          Dir.mkdir(File.join(dir, "test"))
          buggy = File.join(dir, "test", "something_test.rb")
          File.write(buggy, BUGGY_GENERATED)

          result = PdftractVisibilityLint.lint_path([dir])

          assert_empty result[:violations]
          assert_empty result[:files_scanned]
        end
      end

      # The live guard: the checked-in generated tree must stay clean. If the
      # pdftract codegen template regresses (see bf-3c9yia), regenerating
      # lib/ turns this red in seconds, before any containerized run.
      def test_checked_in_generated_tree_is_clean
        repo_root = File.expand_path("../..", __dir__)
        result = PdftractVisibilityLint.lint_path([File.join(repo_root, "lib")])

        assert_empty result[:parse_errors]
        assert_empty result[:violations],
                     "generated lib/ contains non-public methods: " \
                     "#{result[:violations].map { |v| "#{v.file}:#{v.line} #{v.name}" }.join(', ')}"
      end

      def test_cli_exits_nonzero_on_buggy_file_and_zero_on_clean_tree
        ruby = RbConfig.ruby
        tool = File.expand_path("../../tools/lint_visibility.rb", __dir__)
        repo_root = File.expand_path("../..", __dir__)

        Dir.mktmpdir do |dir|
          buggy = File.join(dir, "methods.rb")
          File.write(buggy, BUGGY_GENERATED)

          _out, err, status = Open3.capture3(ruby, tool, buggy)
          assert_equal 1, status.exitstatus, "buggy generated file must fail the lint\n#{err}"

          out, _err, status = Open3.capture3(ruby, tool, File.join(repo_root, "lib"))
          assert_equal 0, status.exitstatus, "checked-in lib/ must pass the lint\n#{out}"
          assert_includes out, "no visibility-keyword violations"
        end
      end

      private

      def lint_source(source, allowlist: PdftractVisibilityLint::DEFAULT_ALLOWLIST)
        Dir.mktmpdir do |dir|
          file = File.join(dir, "sample.rb")
          File.write(file, source)
          PdftractVisibilityLint.lint_path([file], allowlist: allowlist)[:violations]
        end
      end
    end
  end
end

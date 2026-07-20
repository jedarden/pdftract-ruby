# frozen_string_literal: true

# NOTE: manual stopgap patch (2026-07-20, artifact-improvement audit) — these
# require_relative paths were "codegen/*", which resolve relative to this
# file's own directory (lib/) to lib/codegen/*.rb. The actual generated files
# live at lib/pdftract/codegen/*.rb, so `require "pdftract"` raised LoadError
# immediately — the gem could not be loaded at all, before even reaching the
# `private`-visibility bug in methods.rb. Root cause is in the source template
# (pdftract repo: templates/sdk-skeleton/ruby/lib/pdftract.rb.tera) and must be
# fixed there too or this will regress on the next codegen run.
require_relative "pdftract/codegen/methods"
require_relative "pdftract/codegen/errors"
require_relative "pdftract/codegen/types"

module Pdftract
  VERSION = "0.1.0"

  class << self
    def client(binary_path = "pdftract")
      Codegen::Client.new(binary_path)
    end
  end
end

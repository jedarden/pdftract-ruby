# frozen_string_literal: true

require "tempfile"

module Pdftract
  module Codegen
    #
    # This file is auto-generated. Do not edit manually.
    #

    class Source
      def to_args
        raise NotImplementedError
      end
    end

    class PathSource < Source
      def initialize(path)
        @path = path
      end

      def to_args
        [@path]
      end
    end

    class URLSource < Source
      def initialize(url)
        @url = url
      end

      def to_args
        [@url]
      end
    end

    class BytesSource < Source
      def initialize(bytes)
        @bytes = bytes
      end

      # NOTE: manual stopgap patch (2026-07-20, artifact-improvement audit) — the
      # generator template shipped this as `raise NotImplementedError`, so 1 of the
      # 3 documented Source types was a non-functional stub. Root cause is in the
      # source template (pdftract repo:
      # templates/sdk-skeleton/ruby/lib/pdftract/codegen/types.rb.tera) and must be
      # fixed there too or this will regress on the next codegen run.
      def to_args
        @tempfile = Tempfile.new(["pdftract-bytes-source", ".pdf"])
        @tempfile.binmode
        @tempfile.write(@bytes)
        @tempfile.flush
        [@tempfile.path]
      end
    end
  end
end

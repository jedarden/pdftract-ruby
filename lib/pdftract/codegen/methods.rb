# frozen_string_literal: true

require "open3"
require "json"
require "ostruct"

module Pdftract
  module Codegen
    #
    # This file is auto-generated. Do not edit manually.
    #

    class Client
      attr_reader :binary_path, :version

      def initialize(binary_path = "pdftract")
        @binary_path = binary_path
        @version = "0.1.0"
      end

      private

      def exec(*args)
        stdout, stderr, status = Open3.capture3(@binary_path, *args)

        unless status.success?
          raise map_error(stderr, status.exitstatus)
        end

        stdout
      end

      def map_error(stderr, exit_code)
        case exit_code
        
        
        when 2
          CorruptPdfError.new(stderr, exit_code)
        
        
        
        when 3
          EncryptionError.new(stderr, exit_code)
        
        
        
        when 4
          SourceUnreachableError.new(stderr, exit_code)
        
        
        
        when 5
          RemoteFetchInterruptedError.new(stderr, exit_code)
        
        
        
        when 6
          TlsError.new(stderr, exit_code)
        
        
        
        when 10
          ReceiptVerifyError.new(stderr, exit_code)
        
        
        else
          PdftractError.new(stderr, exit_code)
        end
      end

      # NOTE: manual stopgap patch (2026-07-20, artifact-improvement audit) — the
      # generator template emits a single `private` above `exec`/`map_error` with
      # no `public` before the contract methods below, so every method in this
      # class (extract, extract_text, extract_markdown, extract_stream, search,
      # get_metadata, hash, classify, verify_receipt) was unintentionally private.
      # As shipped this made the entire SDK unusable — every README example raised
      # NoMethodError. Root cause is in the source template
      # (pdftract repo: templates/sdk-skeleton/ruby/lib/pdftract/codegen/methods.rb.tera)
      # and must be fixed there too or this will regress on the next codegen run.
      public



      def extract(source, options = nil)
        args = ["extract", *source.to_args]

        
        args.concat(options.to_args) if options
        

        

        output = exec(*args)

        
        JSON.parse(output, object_class: OpenStruct)
        
      end
      
      
      
      def extract_text(source, options = nil)
        args = ["extract", *source.to_args]

        
        args.concat(options.to_args) if options
        

        
        args << "--text"
        

        output = exec(*args)

        
        output
        
      end
      
      
      
      def extract_markdown(source, options = nil)
        args = ["extract", *source.to_args]

        
        args.concat(options.to_args) if options
        

        
        args << "--md"
        

        output = exec(*args)

        
        output
        
      end
      
      
      
      def extract_stream(source, options = nil)
        args = ["extract", *source.to_args]
        args.concat(options.to_args) if options

        Open3.popen3(@binary_path, *args) do |stdin, stdout, stderr, wait_thr|
          return Enumerator.new do |yielder|
            stdout.each_line do |line|
              next if line.strip.empty?

              result = JSON.parse(line, object_class: OpenStruct)
              yielder << result
            end

            unless wait_thr.value.success?
              raise map_error(stderr.read, wait_thr.value.exitstatus)
            end
          end
        end
      end
      
      
      
      def search(source, pattern, options = nil)
        args = ["grep", pattern, *source.to_args]
        args.concat(options.to_args) if options

        Open3.popen3(@binary_path, *args) do |stdin, stdout, stderr, wait_thr|
          return Enumerator.new do |yielder|
            stdout.each_line do |line|
              next if line.strip.empty?

              result = JSON.parse(line, object_class: OpenStruct)
              yielder << result
            end

            unless wait_thr.value.success?
              raise map_error(stderr.read, wait_thr.value.exitstatus)
            end
          end
        end
      end
      
      
      
      def get_metadata(source, options = nil)
        args = ["extract", *source.to_args]

        
        args.concat(options.to_args) if options
        

        
        args << "--metadata-only"
        

        output = exec(*args)

        
        JSON.parse(output, object_class: OpenStruct)
        
      end
      
      
      
      def hash(source, options = nil)
        args = ["hash", *source.to_args]

        
        args.concat(options.to_args) if options
        

        

        output = exec(*args)

        
        JSON.parse(output, object_class: OpenStruct)
        
      end
      
      
      
      def classify(source)
        args = ["classify", *source.to_args]

        

        

        output = exec(*args)

        
        JSON.parse(output, object_class: OpenStruct)
        
      end
      
      
      
      def verify_receipt(path, receipt)
        output = exec("verify-receipt", path, receipt)
        output.strip == "true"
      end
      
      
    end
  end
end

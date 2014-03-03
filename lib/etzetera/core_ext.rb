require 'http'

class Array
  def swap!(a,b)
    self[a], self[b] = self[b], self[a]
    self
  end
end

if HTTP::VERSION == '0.5.0'
  module HTTP
    class Client
      # Make an HTTP request
      def request(method, uri, options = {})
        opts = @default_options.merge(options)
        host = URI.parse(uri).host
        opts.headers["Host"] = host
        headers = opts.headers
        proxy = opts.proxy

        method_body = body(opts, headers)
        if opts.params && !opts.params.empty?
          uri="#{uri}?#{URI.encode_www_form(opts.params)}"
        end

        request = HTTP::Request.new method, uri, headers, proxy, method_body
        if opts.follow
          code = 302
          while code == 302 or code == 301
            # if the uri isn't fully formed complete it
            if not uri.match(/\./)
              uri = "#{method}://#{host}#{uri}"
            end
            host = URI.parse(uri).host
            opts.headers["Host"] = host
            method_body = body(opts, headers)
            request = HTTP::Request.new method, uri, headers, proxy, method_body
            response = perform request, opts
            code = response.code
            uri = response.headers["Location"]
          end
        end

        opts.callbacks[:request].each { |c| c.call(request) }
        response = perform request, opts
        opts.callbacks[:response].each { |c| c.call(response) }

        format_response method, response, opts.response
      end
    end
  end
end

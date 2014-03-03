require 'celluloid/io'
require 'http'
require 'multi_json'

module Etzetera
  class Client
    include Celluloid::IO

    API_ENDPOINT = 'v2'.freeze

    execute_block_on_receiver :wait

    attr_accessor :servers, :consistent

    def initialize(servers = ['http://127.0.0.1:4001'],
      consistent = true,
      default_options = {})

      self.servers            = servers
      self.consistent         = consistent

      opts = {}
      opts[:follow]           = true
      opts[:headers]          = {:accept => 'application/json'}
      opts[:response]         = :object
      opts[:socket_class]     = Celluloid::IO::TCPSocket
      opts[:ssl_socket_class] = Celluloid::IO::SSLSocket

      @default_options = ::HTTP::Options.new(default_options.merge(opts))
    end

    def get(key, params = {})
      request(:get, keys_path(key), :params => params)
    end

    def set(key, form, params = {})
      request(:put, keys_path(key), form: form, :params => params)
    end

    def delete(key, params = {})
      request(:delete, keys_path(key), :params => params)
    end

    def wait(key, params = {}, &callback)
      response = request(:get, keys_path(key), :params => params.merge({:wait => true}))

      if block_given?
        yield response
      elsif callback
        sleep 0.5
        callback.call(response)
      else
        parse_response(response)
      end
    end

    def create(key, form, params = {})
      request(:put, keys_path(key), form: form, :params => params.merge({:prevExist => false}))
    end

    def update(key, form, params = {})
      request(:put, keys_path(key), form: form, :params => params.merge({:prevExist => true}))
    end

    def dir(dir, params = {})
      request(:get, keys_path(dir), :params => params.merge({:recursive => true}))
    end

    def rmdir(dir, params = {})
      request(:delete, keys_path(dir), :params => {:recursive => true}.merge(params))
    end

    def compareAndSwap(key, prevValue)
      request(:put, keys_path(key), :params => {:prevValue => prevValue})
    end

    def compareAndDelete(key, prevValue)
      request(:delete, keys_path(key), :params => {:prevValue => prevValue})
    end

    def acquire_lock(name, ttl)
      request(:post, lock_path(name), :form => {:ttl => ttl})
    end

    def renew_lock(name, form)
      request(:put, lock_path(name), :form => form)
    end

    def release_lock(name, form)
      request(:delete, lock_path(name), :form => form)
    end

    def retrieve_lock(name, params)
      request(:get, lock_path(name), :params => params)
    end

    def set_leader(clustername, name, ttl)
      request(:put, leader_path(clustername), :form => {:name => name, :ttl => ttl})
    end

    def get_leader(clustername, params = {})
      request(:get, leader_path(clustername), :params => params)
    end

    def delete_leader(clustername, name)
      request(:delete, leader_path(clustername), :form => {:name => name})
    end

    def stats(type)
      request(:get, stats_path(type))
    end

    private
    def keys_path(key)
      "/#{API_ENDPOINT}/keys/#{key}"
    end

    def lock_path(name)
      "/mod/#{API_ENDPOINT}/lock/#{name}"
    end

    def leader_path(clustername)
      "/mod/#{API_ENDPOINT}/leader/#{clustername}"
    end

    def stats_path(type)
      "/#{API_ENDPOINT}/stats/#{type}"
    end

    def request(verb, path, options = {})
      opts = @default_options.merge(options)

      client  = ::HTTP::Client.new(opts)
      server  = servers.first
      retries = servers.count - 1
      request = nil

      begin
        request = client.request(verb, "#{server}#{path}")
      rescue IOError => e
        abort e if retries < 1

        old_server  = server
        new_servers = servers.dup
        new_servers.delete(old_server)
        # Would be nice if you could get the host:port combination of the new leader via etcd.
        # Or maybe i haven't looked good enough ^^
        server = new_servers.sample

        servers.swap!(servers.index(old_server), servers.index(server))

        retries -= 1

        sleep 0.5
        retry
      else
        response = {}
        begin
          response = MultiJson.load(request.body)
          if response['errorCode']
            abort Error::CODES[response['errorCode']].new(response['message'])
          end
        # Have to rescue here, etcd sends error codes in the 200-399 Range
        # and even json responses with Content-Type: text/html
        rescue MultiJson::LoadError => e
          if request.code.between?(400, 499)
            abort Error::HttpClientError.new("#{request.reason}\n#{request.body.to_s}")
          elsif request.code.between?(500, 599)
            abort Error::HttpServerError.new("#{request.reason}\n#{request.body.to_s}")
          else
            abort Error::EtzeteraError.new(e)
          end
        else
          parse_response(response)
        end
      end
    end

    def parse_response(response)
      response
    end
  end
end

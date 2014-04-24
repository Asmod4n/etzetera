require 'celluloid/io'
require 'multi_json'

module Etzetera
  class Client
    include Celluloid::Logger
    include Celluloid::IO

    API_VERSION   = 'v2'.freeze
    KEYS_PREFIX   = "/#{API_VERSION}/keys".freeze
    LOCK_PREFIX   = "/mod/#{API_VERSION}/lock/".freeze
    LEADER_PREFIX = "/mod/#{API_VERSION}/leader/".freeze
    STATS_PREFIX  = "/#{API_VERSION}/stats/".freeze

    execute_block_on_receiver :wait

    attr_accessor :servers

    def initialize(servers = ['http://127.0.0.1:4001'], default_options = {})

      self.servers = servers.dup

      def_opts = default_options.dup

      opts = {}
      opts[:headers]          = {:accept => 'application/json'}
      opts[:response]         = :object
      opts[:socket_class]     = Celluloid::IO::TCPSocket
      opts[:ssl_socket_class] = Celluloid::IO::SSLSocket

      @etcd_opts = {}
      @etcd_opts[:election_timeout]   = def_opts.delete(:election_timeout) {|key| 200}
      @etcd_opts[:heartbeat_interval] = def_opts.delete(:heartbeat_interval) {|key| 50}

      @default_options = ::HTTP::Options.new(opts.merge(def_opts))
    end

    def get(key, params = {})
      request(:get, KEYS_PREFIX, key, :params => params)
    end

    def set(key, form, params = {})
      request(:put, KEYS_PREFIX, key, form: form, :params => params)
    end

    def delete(key, params = {})
      request(:delete, KEYS_PREFIX, key, :params => params)
    end

    def wait(key, callback = nil, params = {})
      response = request(:get, KEYS_PREFIX, key, :params => params.merge({:wait => true}))

      if block_given?
        yield response
      elsif callback
        #sleep (@etcd_opts[:heartbeat_interval] / 1000.0)
        callback.call(response)
      else
        response
      end
    end

    def create(key, form, params = {})
      request(:put, KEYS_PREFIX, key, :form => form, :params => params.merge({:prevExist => false}))
    end

    def update(key, form, params = {})
      request(:put, KEYS_PREFIX, key, :form => form, :params => params.merge({:prevExist => true}))
    end

    def mkdir(dir)
      request(:put, KEYS_PREFIX, dir, :params => {:dir => true})
    end

    def dir(dir, params = {})
      request(:get, KEYS_PREFIX, dir, :params => params.merge({:recursive => true}))
    end

    def rmdir(dir, params = {})
      request(:delete, KEYS_PREFIX, dir, :params => {:recursive => true}.merge(params))
    end

    def compareAndSwap(key, prevValue, form)
      request(:put, KEYS_PREFIX, key, :form => form, :params => {:prevValue => prevValue})
    end

    def compareAndDelete(key, prevValue)
      request(:delete, KEYS_PREFIX, key, :params => {:prevValue => prevValue})
    end

    def acquire_lock(name, ttl)
      request(:post, LOCK_PREFIX, name, :form => {:ttl => ttl})
    end

    def renew_lock(name, form)
      request(:put, LOCK_PREFIX, name, :form => form)
    end

    def release_lock(name, form)
      request(:delete, LOCK_PREFIX, name, :form => form)
    end

    def retrieve_lock(name, params)
      request(:get, LOCK_PREFIX, name, :params => params)
    end

    def set_leader(clustername, name, ttl)
      request(:put, LEADER_PREFIX, clustername, :form => {:name => name, :ttl => ttl})
    end

    def get_leader(clustername, params = {})
      request(:get, LEADER_PREFIX, clustername, :params => params)
    end

    def delete_leader(clustername, name)
      request(:delete, LEADER_PREFIX, clustername, :form => {:name => name})
    end

    def stats(type)
      request(:get, STATS_PREFIX, type)
    end

    private
    def request(verb, prefix, path, options = {})
      opts = @default_options.merge(options)

      if opts[:form] && !opts[:form].is_a?(Hash)
        opts = opts.with_form({:value => opts[:form]})
      end

      server  = servers.first
      retries = servers.count - 1
      req = nil

      begin
        client   = ::HTTP::Client.new(opts)
        req      = client.request(verb, "#{server}#{prefix}#{path}")
        response = MultiJson.load(req.body)
        unless response['errorCode']
          response
        else
          abort Error::CODES[response['errorCode']].new(response['message'])
        end
      rescue IOError => e
        abort e if retries < 1

        #sleep (@etcd_opts[:election_timeout] / 1000.0)

        old_server  = server
        new_servers = servers.dup
        new_servers.delete(old_server)
        # Would be nice if you could get the host:port combination of the new leader directly.
        server = new_servers.sample

        servers.swap!(servers.index(old_server), servers.index(server))

        retries -= 1

        retry
        # etcd is inconsistent in the way it handles http responses
        # instead of adopting their buggy behaviour (all 5** errors are text, 4** errors are json,
        # but both respond with text/plain content-type) i just use exceptions for flow control :<
      rescue MultiJson::LoadError => e
        case req.code
        when 200..299 then req.body.to_s
        when 300..399
          if req.headers['Location']
            debug req.headers['Location']
            request(verb, '', req.headers['Location'], opts)
          end
        when 400..499
          abort Error::HttpClientError.new("#{req.reason}\n\t#{req.body}")
        when 500..599
          abort Error::HttpServerError.new("#{req.reason}\n\t#{req.body}")
        else
          abort Error::EtzeteraError.new(e)
        end
      end
    end
  end
end

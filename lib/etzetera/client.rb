require 'celluloid/io'
require 'multi_json'
require 'time'

module Etzetera
  class Client
    include Celluloid::IO
    API_ENDPOINT = 'v2'.freeze

    execute_block_on_receiver :wait

    attr_accessor :servers

    def initialize(servers = ['http://127.0.0.1:4001'], default_options = {})

      self.servers = servers.dup

      def_opts = default_options.dup

      opts = {}
      opts[:headers]            = {:accept => 'application/json'}
      opts[:response]           = :object
      opts[:socket_class]       = Celluloid::IO::TCPSocket
      opts[:ssl_socket_class]   = Celluloid::IO::SSLSocket

      @etcd_opts = {}
      @etcd_opts[:election_timeout]   = def_opts.delete(:election_timeout) {|key| 200}
      @etcd_opts[:heartbeat_interval] = def_opts.delete(:heartbeat_interval) {|key| 50}


      @default_options = ::HTTP::Options.new(opts.merge(def_opts))
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

    def wait(key, params = {}, callback = nil)
      response = request(:get, keys_path(key), :params => params.merge({:wait => true}))

      if block_given?
        yield response
      elsif callback
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

      if opts[:form] && !opts[:form].is_a?(Hash)
        opts = opts.with_form({:value => opts[:form]})
      end

      client  = ::HTTP::Client.new(opts)
      server  = servers.first
      retries = servers.count - 1
      request = nil

      begin
        request = client.request(verb, "#{server}#{path}")
        response = MultiJson.load(request.body)
        if response['errorCode']
          abort Error::CODES[response['errorCode']].new(response['message'])
        end
        parse_response(response)
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

        #sleep (@etcd_opts[:election_timeout] / 1000.0)
        retry
      rescue MultiJson::LoadError => e
        if request.code.between?(200, 299)
          request.body.to_s
        elsif request.code.between?(300, 399)
          if request.headers['Location']
            request(verb, request.headers['Location'], opts)
          end
        elsif request.code.between?(400, 499)
          abort Error::HttpClientError.new("#{request.reason}\n#{request.body.to_s}")
        elsif request.code.between?(500, 599)
          abort Error::HttpServerError.new("#{request.reason}\n#{request.body.to_s}")
        else
          abort Error::EtzeteraError.new(e)
        end
      end
    end

    def parse_response(response)
      if response.is_a?(Hash)
        case response['action']
        when 'get'
          if response['node']['dir'] == true
            if response['node']['nodes']
              response['node']['nodes'].map do |hash|
                if hash['value']
                  {'key' => hash['key'], 'value' => hash['value']}
                elsif hash['dir']
                  {'key' => hash['key'], 'dir' => hash['dir']}
                else
                  hash
                end
              end
            else
              response['node']['key']
            end
          else
            response['node']['value']
          end
        when 'set'
          if response['prevNode']
            [response['node']['value'], response['prevNode']['value']]
          else
            response['node']['value']
          end
        when 'create'
          [response['node']['key'], response['node']['value']]
        when 'delete'
          response['prevNode']['value'] ? response['prevNode']['value'] : response['prevNode']['key']
        when 'expire'
          [response['prevNode']['key'], Time.iso8601(response['prevNode']['expire'])]
        when 'compareAndSwap'
          [response['prevNode']['value'], response['node']['value']]
        when 'compareAndDelete'
          response['prevNode']['value']
        else
          response
        end
      else
        response
      end
    end
  end
end

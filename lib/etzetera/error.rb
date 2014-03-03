module Etzetera
  module Error
    # Every Error thrown by Etzetera can be rescued by this, except IOErrors
    class EtzeteraError < StandardError; end

    class ClientError < EtzeteraError; end
    class ServerError < EtzeteraError; end

    class CommandError < ClientError; end
    class PostFormError < ClientError; end
    class RaftError < ServerError; end
    class EtcdError < ServerError; end

    class HttpClientError < ClientError; end
    class HttpServerError < ServerError; end

    class KeyNotFound < CommandError; end
    class TestFailed < CommandError; end
    class NotFile < CommandError; end
    class NoMorePeer < CommandError; end
    class NotDir < CommandError; end
    class NodeExist < CommandError; end
    class KeyIsPreserved < CommandError; end

    class ValueRequired < PostFormError; end
    class PrevValueRequired < PostFormError; end
    class TTLNaN < PostFormError; end
    class IndexNaN < PostFormError; end

    class RaftInternal < RaftError; end
    class LeaderElect < RaftError; end

    class WatcherCleared < EtcdError; end
    class EventIndexCleared < EtcdError; end

    CODES = {
      100 => KeyNotFound,
      101 => TestFailed,
      102 => NotFile,
      103 => NoMorePeer,
      104 => NotDir,
      105 => NodeExist,
      106 => KeyIsPreserved,
      200 => ValueRequired,
      201 => PrevValueRequired,
      202 => TTLNaN,
      203 => IndexNaN,
      300 => RaftInternal,
      301 => LeaderElect,
      400 => WatcherCleared,
      401 => EventIndexCleared
    }.freeze

  end
end

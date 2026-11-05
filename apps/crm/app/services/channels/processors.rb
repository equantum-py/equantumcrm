# Registry of processors per webhook object type. PR-1 registers none: events
# are stored durably and wait as "pending" until PR-2 adds the WhatsApp and
# Lead Ads processors. A processor responds to #call(webhook_event).
module Channels
  module Processors
    @registry = {}

    class << self
      def register(object_type, processor)
        @registry[object_type.to_s] = processor
      end

      def unregister(object_type)
        @registry.delete(object_type.to_s)
      end

      def for(event)
        @registry[event.object_type]
      end

      def registered_object_types
        @registry.keys
      end
    end
  end
end

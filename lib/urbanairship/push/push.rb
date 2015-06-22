require 'json'

require 'ext/object'
require 'urbanairship/common'
require 'urbanairship/loggable'

module Urbanairship
  module Push

    # A push notification.
    class Push
      attr_writer :client, :audience, :notification, :options,
                  :device_types, :message
      attr_reader :device_types
      include Urbanairship::Common
      include Urbanairship::Loggable

      def initialize(client)
        @client = client
      end

      def payload
        {
          audience: @audience,
          notification: @notification,
          options: @options,
          device_types: @device_types,
          message: @message
        }.compact
      end

      # Send the notification.
      # TODO
      # @raise [AirshipFailure (TBD)] if the request failed
      # @raise [Unauthorized (TBD)] if authentication failed
      # @return [PushResponse] with `push_ids` and other response data.
      def send_push
        response = @client.send_request(
          method: 'POST',
          body: JSON.dump(payload),
          url: PUSH_URL,
          content_type: 'application/json',
          version: 3
        )
        pr = PushResponse.new(http_response_body: response['body'], http_response_code: response['code'].to_s)
        logger.info { pr.format }
        pr
      end
    end


    class ScheduledPush
      attr_writer :schedule, :name, :push, :url
      attr_reader :url, :push
      include Urbanairship::Common
      include Urbanairship::Loggable

      def initialize(client)
        @client = client
      end

      def payload
        {
          name: @name,
          schedule: @schedule,
          push: @push.payload
        }.compact
      end

      # Schedule the notification
      # TODO
      # @raise [AirshipFailure (TBD)] if the request failed
      # @raise [Unauthorized (TBD)] if authentication failed
      # @return [PushResponse] with `schedule_url` and other response data.
      def send_push
        response = @client.send_request(
          method: 'POST',
          body: JSON.dump(payload),
          url: SCHEDULES_URL,
          content_type: 'application/json',
          version: 3
        )
        pr = PushResponse.new(http_response_body: response['body'], http_response_code: response['code'].to_s)
        logger.info { pr.format }
        @url = pr.schedule_url
        pr
      end

      def self.from_url(client:, url:)
        scheduled_push = ScheduledPush.new(client)
        response_body = client.send_request(
          method: 'GET',
          body: nil,
          url: url,
          version: 3
        )
        payload = JSON.load(response_body)

        p = Push.new(client)
        p.audience = payload['push']['audience']
        p.notification = payload['push']['notification']
        p.device_types = payload['push']['device_types']
        p.message = payload['push']['message']
        p.options = payload['push']['options']

        scheduled_push.name = payload['name']
        scheduled_push.schedule = payload['schedule']
        scheduled_push.push = p
        scheduled_push.url = url
        scheduled_push
      end

      def cancel
        fail ArgumentError,
             'Cannot cancel ScheduledPush without a url.' if @url.nil?

        response = @client.send_request(
          method: 'DELETE',
          body: nil,
          url: @url,
          content_type: 'application/json',
          version: 3
        )
        pr = PushResponse.new(http_response_body: response['body'], http_response_code: response['code'].to_s)
        logger.info { "Result of canceling scheduled push: #{@url} was a: [#{pr.status_code}]" }
        pr
      end

      def update
        fail ArgumentError,
             'Cannot update a ScheduledPush without a url.' if @url.nil?

        puts JSON.dump(@payload)
        puts @url
        response = @client.send_request(
          method: 'PUT',
          body: JSON.dump(self.payload),
          url: @url,
          content_type: 'application/json',
          version: 3
        )
        pr = PushResponse.new(http_response_body: response['body'], http_response_code: response['code'].to_s)
        logger.info { pr.format }
        pr
      end
    end


    # Response to a successful push notification send or schedule.
    class PushResponse
      attr_reader :ok, :push_ids, :schedule_url, :operation_id, :payload, :status_code

      def initialize(http_response_body:, http_response_code:)
        @payload = http_response_body || "No Content"
        @ok = @payload['ok'] || "None"
        @push_ids = @payload['push_ids'] || "None"
        @schedule_url = @payload['schedule_urls'].try(:first) || "None"
        @operation_id = @payload['operation_id'] || "None"
        @status_code = http_response_code
      end

      def format
        base = "Received [#{@status_code}] response code. \nHeaders: \tBody:\n"
        payload.each do |key, value|
          safe_value = value.to_s || "None"
          base << "#{key}:\t#{safe_value}\n"
        end
        base
      end

    end
  end
end

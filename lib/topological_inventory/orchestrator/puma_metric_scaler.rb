module TopologicalInventory
  module Orchestrator
    class PumaMetricScaler
      attr_reader :logger

      def initialize(logger)
        @logger = logger
      end

      def run
        service_name = "topological-inventory-api"
        metrics_prefix = "topological_inventory_api"
        minimum_replicas = 1
        maximum_replicas = 5
        target_usage_pct = 0.5
        scale_threshold_pct = 0.2

        loop do
          endpoint = object_manager.get_endpoint(service_name)
          pod_ips = endpoint.subsets.flat_map { |s| s.addresses.collect { |a| a[:ip] } }

          max_threads = 0
          busy_threads = 0

          require 'restclient'
          pod_ips.each do |ip|
            response = RestClient.get("http://#{ip}:9394/metrics")
            h = metrics_scrape_to_h(response)
            max_threads += h["#{metrics_prefix}_puma_max_threads"]
            busy_threads += h["#{metrics_prefix}_puma_busy_threads"]
          end

          current_usage_pct = busy_threads.to_f / max_threads.to_f
          difference = current_usage_pct - target_usage_pct
          if difference.abs > scale_threshold_pct
            difference.positive? ? scale_up : scale_down
          end
        end
      end

      def object_manager
        @object_manager ||= begin
          require "topological_inventory/orchestrator/object_manager"
          ObjectManager.new
        end
      end

      def metrics_scrape_to_h(metrics_scrape)
        metrics_scrape.each_line.with_object({}) do |line, h|
          next if line.start_with?("#") || line.chomp.empty?
          k, v = line.split(" ")
          h[k] = v
        end
      end

      def scale_up
      end

      def scale_down
      end
    end
  end
end





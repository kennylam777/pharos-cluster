# frozen_string_literal: true

require 'fugit'
require 'dry-validation'

module Pharos
  class ConfigSchema
    DEFAULT_DATA = {
      'hosts' => [],
      'api' => {},
      'network' => {},
      'authentication' => {},
      'kube_proxy' => {},
      'kubelet' => {},
      'telemetry' => {},
      'pod_security_policy' => {},
      'addon_paths' => [],
      'container_runtime' => {},
      'audit' => {
        'file' => {
          'path' => '/var/log/kubernetes/audit.json',
          'max_size' => 100, # Max 100M files
          'max_age' => 30, # Max 30 days old audits
          'max_backups' => 20 # Max 20 rolled files, each 100M
        }
      }
    }.freeze

    # @param data [Hash]
    # @raise [Pharos::ConfigError]
    # @return [Hash]
    def self.load(data)
      schema = build
      result = schema.call(DEFAULT_DATA.merge(data))
      raise Pharos::ConfigError, result.messages unless result.success?

      result.to_h
    end

    module HostPredicates
      include Dry::Logic::Predicates

      predicate(:hostname_or_ip?) do |value|
        value.match?(/\A\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\z/) || value.match?(/\A[a-z0-9\-\.]+\z/)
      end
    end

    # @return [Dry::Validation::Schema]
    def self.build
      # rubocop:disable Lint/NestedMethodDefinition
      Dry::Validation.Params do
        configure do
          def self.messages
            super.merge(
              en: {
                errors: {
                  network_dns_replicas: "network.dns_replicas cannot be larger than the number of hosts",
                  hostname_or_ip?: "is invalid",
                  unique_addresses?: "duplicate address:ssh_port"
                }
              }
            )
          end

          def unique_addresses?(hosts)
            hosts.size < 2 || hosts.group_by { |h| "#{h[:address]}:#{h[:ssh_port] || 22}" }.size == hosts.size
          end
        end

        required(:hosts).filled(:unique_addresses?, min_size?: 1) do
          each do
            schema do
              predicates(HostPredicates)
              required(:address).filled(:str?, :hostname_or_ip?)
              optional(:private_address).filled(:str?, :hostname_or_ip?)
              optional(:private_interface).filled
              required(:role).filled(included_in?: ['master', 'worker'])
              optional(:labels).filled
              optional(:taints).each do
                schema do
                  optional(:key).filled(:str?)
                  optional(:value).filled(:str?)
                  required(:effect).filled(included_in?: ['NoSchedule', 'NoExecute'])
                end
              end
              optional(:user).filled
              optional(:ssh_key_path).filled
              optional(:ssh_port).filled(:int?, gt?: 0, lt?: 65_536)
              optional(:ssh_proxy_command).filled(:str?)
              optional(:container_runtime).filled(included_in?: ['docker', 'custom_docker', 'cri-o'])
              optional(:environment).filled
              optional(:bastion).schema do
                predicates(HostPredicates)
                required(:address).filled(:str?, :hostname_or_ip?)
                optional(:user).filled(:str?)
                optional(:ssh_key_path).filled(:str?)
                optional(:ssh_port).filled(:int?, gt?: 0, lt?: 65_536)
                optional(:ssh_proxy_command).filled(:str?)
              end
              optional(:repositories).each do
                schema do
                  required(:name).filled(:str?)
                  required(:contents).filled(:str?)
                  optional(:key_url).filled(:str?)
                end
              end
            end
          end
        end

        optional(:name).filled(:str?)
        optional(:api).schema do
          optional(:endpoint).filled(:str?)
        end
        optional(:network).schema do
          optional(:provider).filled(included_in?: %w(weave calico custom))
          optional(:dns_replicas).filled(:int?, gt?: 0)
          optional(:service_cidr).filled(:str?)
          optional(:pod_network_cidr).filled(:str?)
          optional(:node_local_dns_cache).filled(:bool?)
          optional(:firewalld).schema do
            required(:enabled).filled(:bool?)
            optional(:open_ports).filled do
              each do
                schema do
                  required(:port).filled(:str?)
                  required(:protocol).filled(included_in?: %w(tcp udp))
                  required(:roles).each(type?: String, included_in?: %w(master worker *))
                end
              end
            end
            optional(:trusted_subnets).each(:str?)
          end
          optional(:weave).schema do
            optional(:trusted_subnets).each(type?: String)
            optional(:known_peers).each(type?: String)
            optional(:password).filled(:str?)
            optional(:ipalloc_default_subnet).filled(:str?)
            optional(:ipalloc_init).filled(included_in?: %w(observer))
            optional(:no_masq_local).filled(:bool?)
          end
          optional(:calico).schema do
            optional(:ipip_mode).filled(included_in?: %w(Always CrossSubnet Never))
            optional(:nat_outgoing).filled(:bool?)
            optional(:environment).filled(:hash?)
            optional(:mtu).filled(:int?, gt?: 0)
          end
          optional(:custom).schema do
            required(:manifest_path).filled(:str?)
            optional(:options).filled(:hash?)
          end
        end
        optional(:etcd).schema do
          required(:endpoints).each(type?: String)
          optional(:certificate).filled(:str?)
          optional(:ca_certificate).filled(:str?)
          optional(:key).filled(:str?)
        end
        optional(:authentication).schema do
          optional(:token_webhook).schema do
            required(:config).schema do
              required(:cluster).schema do
                required(:name).filled
                required(:server).filled
                optional(:certificate_authority).filled
              end
              required(:user).schema do
                required(:name).filled
                optional(:client_certificate).filled
                optional(:client_key).filled
              end
            end
            optional(:cache_ttl).filled
          end
          optional(:oidc).schema do
            required(:issuer_url).filled(:str?)
            required(:client_id).filled(:str?)
            optional(:username_claim).filled(:str?)
            optional(:username_prefix).filled(:str?)
            optional(:groups_claim).filled(:str?)
            optional(:groups_prefix).filled(:str?)
            optional(:ca_file).filled(:str?)
          end
        end
        optional(:cloud).schema do
          required(:provider).filled(included_in?: (Pharos::Configuration::Cloud.providers + ['external']))
          optional(:config).filled(:str?)
        end
        optional(:audit).schema do
          optional(:webhook).schema do
            required(:server).filled(:str?)
          end
          optional(:file).schema do
            required(:path).filled(:str?)
            required(:max_age).filled(:int?, gt?: 0)
            required(:max_size).filled(:int?, gt?: 0)
            required(:max_backups).filled(:int?, gt?: 0)
          end
        end
        optional(:kube_proxy).schema do
          optional(:mode).filled(included_in?: %w(userspace iptables ipvs))
        end
        optional(:addon_paths).each(type?: String)
        optional(:addons).value(type?: Hash)
        optional(:kubelet).schema do
          optional(:read_only_port).filled(:bool?)
          optional(:feature_gates).filled
          optional(:extra_args).each(type?: String)
          optional(:cpu_cfs_quota).filled(:bool?)
          optional(:cpu_cfs_quota_period).filled(:str?)
        end
        optional(:control_plane).schema do
          optional(:use_proxy).filled(:bool?)
          optional(:feature_gates).filled
        end
        optional(:telemetry).schema do
          optional(:enabled).filled(:bool?)
        end
        optional(:image_repository).filled(:str?)
        optional(:pod_security_policy).schema do
          optional(:default_policy).filled(:str?)
        end
        optional(:admission_plugins).filled do
          each do
            schema do
              required(:name).filled(:str?)
              optional(:enabled).filled(:bool?)
            end
          end
        end
        optional(:container_runtime).schema do
          optional(:insecure_registries).each(type?: String)
        end

        validate(network_dns_replicas: [:network, :hosts]) do |network, hosts|
          if network && network[:dns_replicas]
            network[:dns_replicas] <= hosts.length
          else
            true
          end
        end
      end
      # rubocop:enable Lint/NestedMethodDefinition
    end
  end
end

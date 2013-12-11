# == Class kafka::server
# Sets up a Kafka Broker Server and ensures that it is running.
#
# == Parameters:
# $enabled                     - If false, Kafka Broker Server will not be
#                                started.  Default: true.
#
# $log_dir                     - Directory in which the broker will store its
#                                received log event data.
#                                (This is log.dir in server.properties).
#                                Default: /var/spool/kafka
#
# $jmx_port                    - Port on which to expose JMX metrics.  Default: 9999
#
# $num_partitions              - The number of logical event partitions per
#                                topic per server.  Default: 1
#
# $num_network_threads         - The number of threads handling network
#                                requests.  Default: 2
#
# $num_io_threads              - The number of threads doing disk I/O.  Default: 2
#
# $socket_send_buffer_bytes    - The byte size of the send buffer (SO_SNDBUF)
#                                used by the socket server.  Default: 1048576
#
# $socket_receive_buffer_bytes - The byte size of receive buffer (SO_RCVBUF)
#                                used by the socket server.  Default: 1048576
#
# $socket_request_max_bytes    - The maximum size of a request that the socket
#                                server will accept.  Default: 104857600
#
# $log_flush_interval_messages - The number of messages to accept before
#                                forcing a flush of data to disk.  Default 10000
#
# $log_flush_interval_ms       - The maximum amount of time a message can sit
#                                in a log before we force a flush: Default 1000 (1 second)
#
# $log_retention_hours         - The minimum age of a log file to be eligible
#                                for deletion.  Default 1 week
#
# $log_retention_size          - A size-based retention policy for logs.
#                                Default: undef (disabled)
#
# $log_segment_bytes           - The maximum size of a log segment file. When
#                                this size is reached a new log segment will
#                                be created:  Default 536870912 (512MB)
#
# $log_cleanup_interval_mins   - The interval at which log segments are checked
#                                to see if they can be deleted according to the
#                                retention policies.  Default: 1
#
# $log_cleanup_policy          - The default policy for handling log tails.
#                                Can be either delete or dedupe.  Default: delete
#
# $metrics_dir                 - Directory in which to store metrics CSVs.  Default: undef (metrics disabled)
#
# $manage_firewall             - enable firewall management
#
class kafka::server(
  $enabled                         = true,
  $log_dir                         = $kafka::params::log_dir,
  $home_dir                        = $kafka::params::home_dir,
  $jmx_port                        = $kafka::params::jmx_port,
  $num_partitions                  = $kafka::params::num_partitions,

  $num_network_threads             = $kafka::params::num_network_threads,
  $num_io_threads                  = $kafka::params::num_io_threads,
  $socket_send_buffer_bytes        = $kafka::params::socket_send_buffer_bytes,
  $socket_receive_buffer_bytes     = $kafka::params::socket_receive_buffer_bytes,
  $socket_request_max_bytes        = $kafka::params::socket_request_max_bytes,

  $log_flush_interval_messages     = $kafka::params::log_flush_interval_messages,
  $log_flush_interval_ms           = $kafka::params::log_flush_interval_ms,
  $log_retention_hours             = $kafka::params::log_retention_hours,
  $log_retention_bytes             = $kafka::params::log_retention_bytes,
  $log_segment_bytes               = $kafka::params::log_segment_bytes,

  $log_cleanup_interval_mins       = $kafka::params::log_cleanup_interval_mins,
  $log_cleanup_policy              = $kafka::params::log_cleanup_policy,

  $metrics_dir                     = $kafka::params::metrics_dir,

  $server_properties_template      = $kafka::params::server_properties_template,
  $default_template                = $kafka::params::default_template,
  $manage_firewall                 = hiera('manage_firewall', false),
  $metrics_riemann                 = $kafka::params::metrics_riemann,
  $metrics_riemann_port            = $kafka::params::metrics_riemann_port
) inherits kafka::params
{
  # kafka class must be included before kafka::servver
  Class['kafka'] -> Class['kafka::server']

  # define local variables from kafka class for use in ERb template.
  $zookeeper_hosts                 = $kafka::zookeeper_hosts
  $zookeeper_connection_timeout_ms = $kafka::zookeeper_connection_timeout_ms
  $zookeeper_chroot                = $kafka::zookeeper_chroot
  $user                            = $kafka::user
  $group                           = $kafka::group

    # Get this broker's id and port out of the $kafka::hosts configuration hash
  $hosts     = $kafka::hosts
  $broker_id = $hosts["$::fqdn"]['id']

  # Using a conditional assignment selector with a
  # Hash value results in a puppet syntax error.
  # Using an if/else instead.
  if ($kafka::hosts[$::fqdn]['port']) {
    $broker_port = $kafka::hosts[$::fqdn]['port']
  }
  else {
    $broker_port = $kafka::params::default_broker_port
  }

  file { '/etc/default/kafka':
    content => template($default_template)
  }
  file { '/etc/kafka/server.properties':
    content => template($server_properties_template),
    tag     => 'kafka-server-conf'
  }

  File <| tag == 'kafka-server-conf' |> ~> Svcutils::Mixsvc['kafka']

    # If we are using Kafka Metrics Reporter, ensure
    # that the $metrics_dir exists.
  if $metrics_dir {
    file { $metrics_dir:
      ensure  => 'directory',
      owner   => $user,
      group   => $group,
      mode    => '0755',
    }
  }

  # Start the Kafka server.
  # We don't want to subscribe to the config files here.
  # It will be better to manually restart Kafka when
  # the config files changes.
  $kafka_ensure = $enabled ? {
    false   => 'stopped',
    default => 'running',
  }

  supervisor::service { 'kafka':
    ensure      => $kafka_ensure,
    user        => $user,
    group       => $group,
    directory   => $home_dir,
    command     => "java -Xmx1G -Xms1G -server -XX:+UseCompressedOops -XX:+UseParNewGC \
-XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled -XX:+CMSScavengeBeforeRemark \
-XX:+DisableExplicitGC -Xloggc:/var/log/kafka/kafkaServer-gc.log -verbose:gc -XX:+PrintGCDetails \
-XX:+PrintGCDateStamps -XX:+PrintGCTimeStamps -Dcom.sun.management.jmxremote \
-Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false \
-Dlog4j.configuration=file:/etc/kafka/log4j.properties -cp \
:${home_dir}/core/target/scala-2.9.2/kafka_2.9.2-0.8.0-beta1.jar\
:${home_dir}/core/target/scala-2.9.2/kafka-assembly-0.8.0-beta1-deps.jar\
:${home_dir}/perf/target/scala-2.9.2/kafka*.jar:${home_dir}/libs/*.jar:${home_dir}/kafka*.jar \
kafka.Kafka /etc/kafka/server.properties",
    environment => 'SCALA_VERSION="2.9.2"',
    require     => [
      File['/etc/kafka/server.properties'],
      File['/etc/default/kafka'],
      User[$user],
      Group[$group]
    ],
  }

  if $manage_firewall {
    firewall { "101 allow kafka_broker:$broker_port":
      proto  => 'tcp',
      state  => ['NEW'],
      dport  => $broker_port,
      action => 'accept',
    }
    firewall { "101 allow kafka_jmx:$jmx_port":
      proto  => 'tcp',
      state  => ['NEW'],
      dport  => $jmx_port,
      action => 'accept',
    }
  }
}

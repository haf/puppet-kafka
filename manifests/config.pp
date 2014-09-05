# == Class kafka
# Installs Kafka package and sets up defaults configs for clients (producer & consumer).
#
# == Parameters:
# $hosts                            - Hash of zookeeper hosts config keyed by
#                                     fqdn of each kafka broker host.  This Hash
#                                     should be of the form:
#                                       { 'hostA' => { 'id' => 1, 'port' => 12345 }, 'hostB' => { 'id' => 2 }, ... }
#                                     'port' is optional, and will default to 9092.
#                                     This Hash is used to configure both kafka
#                                     clients and broker servers.
#
# $zookeeper_hosts                  - Array of zookeeper hostname/IP(:port)s.
#                                     Default: ['localhost:2181]
#
# $zookeeper_connection_timeout_ms  - Timeout in ms for connecting to zookeeper.
#                                     Default: 1000000
#
# $zookeeper_chroot                 - Path in zookeeper in which to keep Kafka data.
#                                     Default: /, the root path.  This module will
#                                     Not create this znode for you, you must do so
#                                     manually yourself.  See the README for instructions
#                                     on how to do so.
#
# $kafka_log_file                   - File in which to store Kafka logs
#                                     (not event data).  Default: /var/log/kafka/kafka.log
#
# $producer_type                    - Specifies whether the messages are
#                                     (by default) sent asynchronously (async)
#                                     or synchronously (sync).  Default: async
#
# $producer_batch_num_messages      - The number of messages batched at the
#                                     producer.  Default: 200.
#
# $consumer_group_id                - The consumer group.id set in consumer.properties.
#                                     Default: test-consumer-group
#
# $version                          - Kafka package version number.  Set this
#                                     if you need to override the default
#                                     package version.  If you override this,
#                                     the version must be >= 0.8.  Default: installed.
class kafka::config(
  $declared_hosts                  = $kafka::params::hosts,
  $zookeeper_hosts                 = $kafka::params::zookeeper_hosts,
  $zookeeper_connection_timeout_ms = $kafka::params::zookeeper_connection_timeout_ms,
  $zookeeper_chroot                = $kafka::params::zookeeper_chroot,

  $kafka_log_file                  = $kafka::params::kafka_log_file,
  $producer_type                   = $kafka::params::producer_type,
  $producer_batch_num_messages     = $kafka::params::producer_batch_num_messages,
  $consumer_group_id               = $kafka::params::consumer_group_id,

  $version                         = $kafka::params::version,

  $producer_properties_template    = $kafka::params::producer_properties_template,
  $consumer_properties_template    = $kafka::params::consumer_properties_template,
  $log4j_properties_template       = $kafka::params::log4j_properties_template,
  $user                            = $kafka::params::user,
  $group                           = $kafka::params::group,
  $home                            = $kafka::params::home_dir,
  $host_id                         = $kafka::params::host_id
) inherits kafka::params {

  $_kafka = hiera_hash('kafka', { hosts => $declared_hosts })
  $hosts = $_kafka['hosts']

  anchor { 'kafka::start': }


  group { $group:
    ensure => present,
    system => true,
    require => Anchor['kafka::start'],
    before  => Anchor['kafka::end'],
  }

  user { $user:
    ensure  => 'present',
    gid     => $group,
    system  => true,
    home    => $home,
    require => [
      Anchor['kafka::start'],
      Group[$group]
    ],
    before  => Anchor['kafka::end'],
  }

  file { $home:
    ensure => directory,
    owner  => $user,
    group  => $group,
    mode   => '0755',
    require => [
      Anchor['kafka::start'],
      User[$user]
    ],
    before  => Anchor['kafka::end'],
  }

  file { '/var/log/kafka':
    ensure  => directory,
    owner   => $user,
    group   => $group,
    mode    => '0644',
    require => [
      #  Svcutils::Svcuser['kafka'],
      Group['kafka'],
      Anchor['kafka::start']
    ],
    before  => Anchor['kafka::end'],
  }

  file { '/etc/kafka':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => [
      Package['kafka'],
      Anchor['kafka::start']
    ],
    before  => Anchor['kafka::end'],
  }


  file { '/etc/kafka/producer.properties':
    content => template($producer_properties_template),
    require => [
      Package['kafka'],
      File['/etc/kafka'],
      Anchor['kafka::start']
    ],
    before  => Anchor['kafka::end'],
  }

  file { '/etc/kafka/consumer.properties':
    content => template($consumer_properties_template),
    require => [
      Package['kafka'],
      File['/etc/kafka'],
      Anchor['kafka::start']
    ],
    before  => Anchor['kafka::end'],
  }

  file { '/etc/kafka/log4j.properties':
    content => template($log4j_properties_template),
    require => [
      Package['kafka'],
      File['/etc/kafka'],
      Anchor['kafka::start']
    ],
    before  => Anchor['kafka::end'],
    tag     => 'kafka-server-conf'
  }

  anchor { 'kafka::end': }
}

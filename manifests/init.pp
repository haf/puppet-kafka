class kafka(
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
)  inherits kafka::params {

  include kafka::package
  include kafka::config
  include kafka::server

}



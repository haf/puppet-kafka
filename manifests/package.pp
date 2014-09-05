class kafka::package {

  package { 'kafka':
    ensure => '0.8.1.1-1',
  }

}

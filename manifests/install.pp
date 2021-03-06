# == Class: kibana::install
#
# This class installs kibana.  It should not be directly called.
#
#
class kibana::install (
  $version             = $::kibana::version,
  $base_url            = $::kibana::base_url,
  $tmp_dir             = $::kibana::tmp_dir,
  $install_path        = $::kibana::install_path,
  $group               = $::kibana::group,
  $user                = $::kibana::user,
  $log_file            = $::kibana::log_file,
  $pid_file            = $::kibana::pid_file,
  $manage_user         = $::kibana::manage_user,
  $manage_group        = $::kibana::manage_group,
) {
  if '4.6' in $version {
    $filename = $::architecture ? {
      /(i386|x86$)/    => "kibana-${version}-linux-x86",
      /(amd64|x86_64)/ => "kibana-${version}-linux-x86_64",
    }
  }
  else {
    $filename = $::architecture ? {
      /(i386|x86$)/    => "kibana-${version}-linux-x86",
      /(amd64|x86_64)/ => "kibana-${version}-linux-x64",
  }
  }

  $service_provider = $::kibana::params::service_provider
  $run_path         = $::kibana::params::run_path
  $log_path         = dirname($log_file)
  
  if($manage_group) {
    group { $group:
      ensure => 'present',
      system => true,
    }
  }

  if($manage_user) {
    user { $user:
      ensure  => 'present',
      system  => true,
      gid     => $group,
      home    => $install_path,
      require => Group[$group],
      managehome => true,
    }
  }

  exec { 'download_kibana':
    path        => [ '/bin', '/usr/bin', '/usr/local/bin' ],
    command     => "${::kibana::params::download_tool} ${tmp_dir}/${filename}.tar.gz ${base_url}/${filename}.tar.gz 2> /dev/null",
    require     => User[$user],
    unless      => "test -e ${install_path}/${filename}/LICENSE.txt",
  }

  exec { 'extract_kibana':
    command => "tar -xzf ${tmp_dir}/${filename}.tar.gz -C ${install_path}",
    path    => ['/bin', '/sbin'],
    creates => "${install_path}/${filename}",
    notify  => Exec['ensure_correct_owner'],
    require => Exec['download_kibana'],
  }

  exec { 'ensure_correct_owner':
    command     => "chown -R ${user}:${group} ${install_path}/${filename}",
    path        => ['/bin', '/sbin'],
    refreshonly => true,
    notify      => Exec['ensure_correct_permissions'],
    require     => [
      Exec['extract_kibana'],
      User[$user],
    ],
  }

  exec { 'ensure_correct_permissions':
    command     => "chmod -R o-rwX ${install_path}/${filename}",
    path        => ['/bin', '/sbin'],
    refreshonly => true,
    notify      => File["${install_path}/kibana"],
    require     => Exec['ensure_correct_owner'],
  }

  file { "${install_path}/kibana":
    ensure  => 'link',
    owner   => $user,
    group   => $group,
    target  => "${install_path}/${filename}",
    require => Exec['ensure_correct_owner'],
  }

  file { "${install_path}/kibana/installedPlugins":
    ensure  => directory,
    owner   => kibana,
    group   => kibana,
    require => User[$user],
  }

  file { "${log_path}":
    ensure  => directory,
    owner   => kibana,
    group   => kibana,
    require => User[$user],
  }

  if $service_provider == 'init' {

    file { 'kibana-init-script':
      ensure  => file,
      path    => '/etc/init.d/kibana',
      content => template('kibana/kibana.legacy.service.lsbheader.erb', "kibana/${::kibana::params::init_script_osdependend}", 'kibana/kibana.legacy.service.maincontent.erb'),
      mode    => '0755',
      notify  => Class['::kibana::service'],
    }

  }

  if $service_provider == 'systemd' {

    file { 'kibana-init-script':
      ensure  => file,
      path    => "${::kibana::params::systemd_provider_path}/kibana.service",
      content => template('kibana/kibana.service.erb'),
      notify  => Class['::kibana::service'],
    }

    file { 'kibana-run-dir':
      ensure => directory,
      path   => $run_path,
      owner  => $user,
      group  => $group,
      notify => Class['::kibana::service'],
    }

    file { 'kibana-tmpdir-d-conf':
      ensure  => file,
      path    => '/etc/tmpfiles.d/kibana.conf',
      owner   => root,
      group   => root,
      content => template('kibana/kibana.tmpfiles.d.conf.erb'),
    }
  }

}

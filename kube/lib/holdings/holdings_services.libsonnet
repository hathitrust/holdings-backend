(import 'ksonnet-util/kausal.libsonnet') +
(import './external_ip_service.libsonnet') +
(import './config.libsonnet') +
(import './holdings_container.libsonnet') +
{
  local config = $._config.holdings,
  holdings+: {
    mysql: $.phineas.external_ip_service.new("mysql",config.mysql.ip,config.mysql.port),
    mysql_htdev: $.phineas.external_ip_service.new("mysql-htdev",config.mysql_dev.ip,config.mysql_dev.port),
  },
}

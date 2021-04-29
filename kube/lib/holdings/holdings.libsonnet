(import 'ksonnet-util/kausal.libsonnet') +
(import './external_ip_service.libsonnet') +
(import './config.libsonnet') +
(import './holdings_container.libsonnet') +
{
  local cronJob = $.batch.v1beta1.cronJob,
  local cronJobSchedule(schedule) = { spec+: { schedule: schedule } },
  local config = $._config.holdings,

  local holdings_cron_job(name,command) = cronJob.new(
      name=name,
      containers = [ $.holdings_container.new(name,command) ]
    ).withVolumes($.holdings_container.volumes)
     .withRestartPolicy('OnFailure')
   + { spec+: { concurrencyPolicy: 'Forbid' } }
   + { spec+: { jobTemplate+: { spec+: { template+: { spec+: { securityContext+: config.runAs } } } } } },

  holdings: {
    mysql: $.phineas.external_ip_service.new("mysql",config.mysql.ip,config.mysql.port),
    mysql_htdev: $.phineas.external_ip_service.new("mysql-htdev",config.mysql_dev.ip,config.mysql_dev.port),

    hathifiles_loader: holdings_cron_job('hathifiles-loader',['bundle','exec','bin/daily_add_ht_items.rb'])
     + cronJobSchedule(config.schedules.hathifiles)
    # holdings_loader: holdings_cron_job('holdings-loader','run-holdings-loader'),
    # concordance_loader: holdings_cron_job('concordance-loader','run-concordance-loader'),

    # TODO:
    #   - cost report job (on-demand)
    #   - prod holdings exporter
    #   - mongodb backup (needs backup home env var)


  },
}

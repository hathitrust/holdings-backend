(import 'ksonnet-util/kausal.libsonnet') +
(import './config.libsonnet') +
(import './holdings_container.libsonnet') +
(import './holdings_services.libsonnet') +
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

  holdings+: {

    hathifiles: holdings_cron_job('hathifiles-loader',['bundle','exec','bin/daily_add_ht_items.rb'])
     + cronJobSchedule(config.schedules.hathifiles),

    #    concordance: holdings_cron_job('validate-concordance',
    #      ['/bin/sh','-c','date; ruby validate_and_delta.rb /htprep/holdings/concordance'])
    #     + cronJobSchedule(config.schedules.concordance)

    # holdings_loader: holdings_cron_job('holdings-loader','TBD'),

    # TODO:
    #   - cost report job (on-demand)
    #   - prod holdings exporter
    #   - mongodb backup (needs backup home env var)


  },
}

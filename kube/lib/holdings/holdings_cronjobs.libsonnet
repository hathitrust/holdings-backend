(import 'ksonnet-util/kausal.libsonnet') +
(import './config.libsonnet') +
(import './holdings_container.libsonnet') +
(import './holdings_services.libsonnet') +
{
  local env = $.core.v1.container.envType,
  local cronJob = $.batch.v1beta1.cronJob,
  local cronJobSchedule(schedule) = { spec+: { schedule: schedule } },
  local config = $._config.holdings,
  local images = $._images.holdings,

  local holdings_cron_job(name,containers,schedule,volumes) =
    cronJob.new( name=name, containers=containers )
     .withVolumes(volumes)
     .withRestartPolicy('OnFailure')
   + { spec+: { concurrencyPolicy: 'Forbid' } }
   + { spec+: { jobTemplate+: { spec+: { template+: { spec+: { securityContext+: config.runAs } } } } } }
   + { spec+: { schedule: schedule } },

  holdings+: {

    hathifiles: holdings_cron_job(
        name = 'hathifiles-loader',
        containers = [ $.holdings_container.new('hathifiles-loader',
                          ['bundle','exec','bin/daily_add_ht_items.rb']) ],
        volumes = $.holdings_container.volumes,
        schedule = config.schedules.hathifiles
    ),

    mongo_backup: holdings_cron_job(
      name = 'mongo-backup',
      containers = [$.mongo_backup_container.new('mongo-backup')],
      volumes = $.mongo_backup_container.volumes,
      schedule = config.schedules.mongo_backup
    ),

    #    concordance: holdings_cron_job('validate-concordance',
    #      ['/bin/sh','-c','date; ruby validate_and_delta.rb /htprep/holdings/concordance'])
    #     + cronJobSchedule(config.schedules.concordance)

    # holdings_loader: holdings_cron_job('holdings-loader','TBD'),

    # TODO:
    #   - cost report job (on-demand)
    #   - prod holdings exporter


  },
}

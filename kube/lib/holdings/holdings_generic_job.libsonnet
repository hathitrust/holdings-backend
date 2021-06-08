(import 'ksonnet-util/kausal.libsonnet') +
(import './config.libsonnet') +
(import './holdings_container.libsonnet') +
{
  local env = $.core.v1.container.envType,
  local job = $.batch.v1.job,
  local jobTemplateSpec = job.spec.template.spec,
  local jobSecurityContext = jobTemplateSpec.securityContext,
  local config = $._config.holdings,
  local images = $._images.holdings,

  holdings+: {
    local containers = [ $.holdings_container.new(name='holdings-client', command='$ARGS') ],

    job: job.new(name='holdings-client-$SUFFIX')
     + jobTemplateSpec.withContainers(containers)
     + jobTemplateSpec.withRestartPolicy('OnFailure')
     + jobTemplateSpec.withVolumes($.holdings_container.volumes)
     + jobSecurityContext.withRunAsUser(config.runAs.runAsUser)
     + jobSecurityContext.withRunAsGroup(config.runAs.runAsGroup)
     + jobSecurityContext.withFsGroup(config.runAs.fsGroup),

  },
}

(import 'ksonnet-util/kausal.libsonnet') +
(import './config.libsonnet') +
{
  local env = $.core.v1.container.envType,
  local port = $.core.v1.containerPort,
  local volumeMount = $.core.v1.volumeMount,
  local volume = $.core.v1.volume,

  local config = $._config.holdings,
  local images = $._images.holdings,

  local htprep_volume = {
    name: 'htprep',
    nfs: {
      server: 'nas-macc.sc.umdl.umich.edu',
      path: '/ifs/htprep'
    }
  },

  local htprep_volume_mount =
    { mountPath: '/htprep',    name: 'htprep' },

  local volumes = [
    {
      name: 'htapps',
      nfs: {
        server: 'nas-macc.sc.umdl.umich.edu',
        path: '/ifs/htapps'
      }
    },
    {
      name: 'htapps-dev',
      nfs: {
        server: 'htdev.value.storage.umich.edu',
        path: '/htdev/htapps'
      }
    },
    {
      name: 'holdings-config',
      configMap: { name: 'holdings-config' }
    },
    {
      name: 'large-cluster-ocns',
      configMap: { name: 'large-cluster-ocns' }
    },
    htprep_volume
  ],

  local volumeMounts = [
    { mountPath: '/htapps',    name: 'htapps' },
    { mountPath: '/htapps-dev',    name: 'htapps-dev' },
    {
      mountPath: '/usr/src/app/config/settings/production.local.yml',
      name: 'holdings-config',
      subPath: 'production.local.yml'
    },
    {
      mountPath: '/usr/src/app/config/large_cluster_ocns.txt',
      name: 'large-cluster-ocns',
      subPath: 'large_cluster_ocns.txt'
    },
    htprep_volume_mount
  ],

  holdings_container:: {
    new(name,command): $.core.v1.container.new(name, images.client)
               .withCommand(command)
               .withEnv([
                  env.fromSecretRef("MONGODB_PASSWORD","holdings-mongodb","mongodb-password"),
                  env.fromSecretRef("MYSQL_PASSWORD","holdings-mysql","mysql-password"),
                  env.new("MONGOID_ENV","production"),
                  env.new("TZ","America/Detroit")
               ])
               .withVolumeMounts(volumeMounts)
               .withImagePullPolicy('Always'),
    volumes: volumes
  },

  mongo_backup_container:: {
    new(name): $.core.v1.container.new(name, images.mongo_backup)
             .withCommand('/usr/local/bin/backup_mongo_rotate.sh')
             .withEnv([
                env.fromSecretRef("MONGODB_ROOT_PASSWORD","holdings-mongodb","mongodb-root-password"),
                env.new("MONGODB_HOST",config.mongo.host),
                env.new("BACKUP_HOME",config.mongo.backup_home)
             ])
             .withVolumeMounts([htprep_volume_mount])
             .withImagePullPolicy('Always'),
    volumes: [ htprep_volume ]
  }
}

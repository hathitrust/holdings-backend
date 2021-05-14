(import 'holdings/holdings_cronjobs.libsonnet') +
{
  _config+:: {
    holdings+: {
      mongo+: {
        host: 'holdings-mongodb-0.holdings-mongodb-headless.holdings.svc.cluster.local:27017',
      }
    },
  },
}

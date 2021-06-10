(import 'holdings/holdings_generic_job.libsonnet') +
{
  _config+:: {
    holdings+: {
      mongo+: {
        host: 'holdings-mongodb-0.holdings-mongodb-headless.holdings.svc.cluster.local:27017',
      }
    },
  },
}

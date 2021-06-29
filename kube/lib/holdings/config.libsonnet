{
  _config+:: {
    holdings: {
      mysql: {
        port: 3306,
        ip: '10.255.8.249',
      },
      mysql_dev: {
        port: 3306,
        ip: '10.255.10.143'
      },
      schedules: {
        hathifiles: "5 9 * * *",
        concordance: "0 23 * * * ",
        mongo_backup: "0 8 * * 6",
        etas_overlap: "0 10 * * *",
      },
      runAs: {
        runAsUser: 1000,
        runAsGroup: 1191,
        fsGroup: 1190
      },
      mongo: {
        host: 'mongodb',
        backup_home: '/htprep/holdings/mongo-backups'
      }
    },
  },

  _images+:: {
    holdings: {
      client: 'ghcr.io/hathitrust/holdings-client-unstable',
      mongo_backup: 'hathitrust/mongo-backup'
    }
  },

}
